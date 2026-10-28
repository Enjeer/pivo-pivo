import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'domain.dart';

class GeoBounds {
  const GeoBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  String get cacheKey => '$south:$west:$north:$east';

  bool get isValid =>
      south >= -90 &&
      north <= 90 &&
      west >= -180 &&
      east <= 180 &&
      south < north &&
      west < east;

  bool get isSmallEnough =>
      isValid &&
      north - south <= 0.05 &&
      east - west <= 0.08 &&
      (north - south) * (east - west) <= 0.003;
}

class PlaceCatalogSnapshot {
  const PlaceCatalogSnapshot({
    required this.places,
    required this.source,
    required this.fetchedAt,
    this.isDemo = false,
    this.isCached = false,
    this.isTruncated = false,
  });

  final List<Place> places;
  final String source;
  final DateTime? fetchedAt;
  final bool isDemo;
  final bool isCached;
  final bool isTruncated;
}

abstract interface class PlaceCatalogRepository {
  PlaceCatalogSnapshot get initialSnapshot;

  Future<PlaceCatalogSnapshot> load(
    GeoBounds bounds, {
    bool forceRefresh = false,
  });
}

class DemoPlaceCatalogRepository implements PlaceCatalogRepository {
  const DemoPlaceCatalogRepository();

  @override
  PlaceCatalogSnapshot get initialSnapshot => const PlaceCatalogSnapshot(
    places: demoPlaces,
    source: 'Демонстрационные данные',
    fetchedAt: null,
    isDemo: true,
  );

  @override
  Future<PlaceCatalogSnapshot> load(
    GeoBounds bounds, {
    bool forceRefresh = false,
  }) async => initialSnapshot;
}

class OverpassPlaceCatalogRepository implements PlaceCatalogRepository {
  OverpassPlaceCatalogRepository({
    http.Client? client,
    Uri? endpoint,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _endpoint = endpoint ?? Uri.https('overpass-api.de', '/api/interpreter'),
       _clock = clock ?? DateTime.now;

  static const _cacheDuration = Duration(minutes: 10);
  static const _maxResponseBytes = 2 * 1024 * 1024;
  static const _maxCachedAreas = 16;
  static const _maxResults = 200;
  static const _minimumRequestInterval = Duration(seconds: 1);
  static const _amenities =
      'bar|pub|cafe|restaurant|fast_food|nightclub|hookah_lounge|food_court';

  final http.Client _client;
  final Uri _endpoint;
  final DateTime Function() _clock;
  final Map<String, PlaceCatalogSnapshot> _cache = {};
  final Map<String, Future<PlaceCatalogSnapshot>> _inFlight = {};
  Future<void> _requestSlot = Future<void>.value();
  DateTime? _lastRequestStartedAt;

  @override
  PlaceCatalogSnapshot get initialSnapshot => const PlaceCatalogSnapshot(
    places: [],
    source: 'OpenStreetMap',
    fetchedAt: null,
  );

  @override
  Future<PlaceCatalogSnapshot> load(
    GeoBounds bounds, {
    bool forceRefresh = false,
  }) {
    if (!bounds.isValid) {
      return Future.error(
        const FormatException('Границы области поиска некорректны.'),
      );
    }
    if (!bounds.isSmallEnough) {
      return Future.error(
        const FormatException(
          'Область поиска слишком широкая. Приблизьте карту и повторите.',
        ),
      );
    }

    final key = bounds.cacheKey;
    final pending = _inFlight[key];
    if (pending != null) return pending;

    final cached = _cache[key];
    final fetchedAt = cached?.fetchedAt;
    if (!forceRefresh &&
        cached != null &&
        fetchedAt != null &&
        !_clock().isBefore(fetchedAt) &&
        _clock().isBefore(fetchedAt.add(_cacheDuration))) {
      return Future.value(
        PlaceCatalogSnapshot(
          places: cached.places,
          source: cached.source,
          fetchedAt: fetchedAt,
          isCached: true,
          isTruncated: cached.isTruncated,
        ),
      );
    }

    final request = _fetch(bounds).whenComplete(() {
      _inFlight.remove(key);
    });
    _inFlight[key] = request;
    return request;
  }

  Future<PlaceCatalogSnapshot> _fetch(GeoBounds bounds) async {
    final query =
        '[out:json][timeout:20];'
        'nwr["amenity"~"^($_amenities)\$"]'
        '(${bounds.south},${bounds.west},${bounds.north},${bounds.east});'
        'out center tags ${_maxResults + 1};';

    await _waitForRequestSlot();
    final request = http.Request('POST', _endpoint)
      ..headers.addAll(const {
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'PivoPivo/1.0 (+https://github.com/Enjeer/pivo-pivo)',
      })
      ..bodyFields = {'data': query};
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      await response.stream.listen((_) {}).cancel();
      throw StateError(
        'Каталог OpenStreetMap вернул HTTP ${response.statusCode}.',
      );
    }

    final contentLength = int.tryParse(
      response.headers['content-length'] ?? '',
    );
    if (contentLength != null && contentLength > _maxResponseBytes) {
      await response.stream.listen((_) {}).cancel();
      throw const FormatException(
        'Ответ каталога слишком большой. Приблизьте карту и повторите.',
      );
    }

    final responseBytes = await _readResponse(
      response.stream.timeout(const Duration(seconds: 25)),
    );
    final decoded = jsonDecode(utf8.decode(responseBytes));
    if (decoded is! Map<String, dynamic> || decoded['elements'] is! List) {
      throw const FormatException('Ответ каталога имеет неверный формат.');
    }
    final remark = decoded['remark'];
    if (remark != null && (remark is! String || remark.trim().isNotEmpty)) {
      throw StateError(
        'Overpass не выполнил запрос: '
        '${remark is String ? remark.trim() : 'ошибка ответа сервера'}.',
      );
    }

    final rawElements = decoded['elements'] as List;
    final parsedPlaces = rawElements
        .whereType<Map<String, dynamic>>()
        .map(_placeFromElement)
        .whereType<Place>()
        .toList(growable: false);
    final isTruncated = rawElements.length > _maxResults;
    final snapshot = PlaceCatalogSnapshot(
      places: parsedPlaces.take(_maxResults).toList(growable: false),
      source: 'OpenStreetMap',
      fetchedAt: _clock().toUtc(),
      isTruncated: isTruncated,
    );
    _cache.remove(bounds.cacheKey);
    _cache[bounds.cacheKey] = snapshot;
    while (_cache.length > _maxCachedAreas) {
      _cache.remove(_cache.keys.first);
    }
    return snapshot;
  }

  Future<void> _waitForRequestSlot() {
    final previous = _requestSlot;
    final ready = Completer<void>();
    _requestSlot = ready.future;
    return () async {
      await previous;
      try {
        final lastStartedAt = _lastRequestStartedAt;
        if (lastStartedAt != null) {
          final wait =
              _minimumRequestInterval -
              DateTime.now().difference(lastStartedAt);
          if (wait > Duration.zero) await Future<void>.delayed(wait);
        }
        _lastRequestStartedAt = DateTime.now();
      } finally {
        ready.complete();
      }
    }();
  }

  Future<List<int>> _readResponse(Stream<List<int>> stream) async {
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in stream) {
      if (chunk.length > _maxResponseBytes - length) {
        throw const FormatException(
          'Ответ каталога слишком большой. Приблизьте карту и повторите.',
        );
      }
      bytes.add(chunk);
      length += chunk.length;
    }
    return bytes.takeBytes();
  }

  Place? _placeFromElement(Map<String, dynamic> element) {
    final type = element['type'];
    final id = element['id'];
    final tags = element['tags'];
    if (type is! String || id is! int || tags is! Map<String, dynamic>) {
      return null;
    }

    final name = _stringTag(tags, 'name')?.trim();
    final category = _categoryFor(tags);
    final coordinates = element['lat'] is num && element['lon'] is num
        ? element
        : element['center'];
    if (name == null ||
        name.isEmpty ||
        category == null ||
        coordinates is! Map<String, dynamic> ||
        coordinates['lat'] is! num ||
        coordinates['lon'] is! num) {
      return null;
    }

    final latitude = (coordinates['lat'] as num).toDouble();
    final longitude = (coordinates['lon'] as num).toDouble();
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    final address =
        _stringTag(tags, 'addr:full') ??
        [
          _stringTag(tags, 'addr:street'),
          _stringTag(tags, 'addr:housenumber'),
        ].whereType<String>().where((part) => part.isNotEmpty).join(', ');
    final description = _stringTag(tags, 'description')?.trim();
    final osmType = switch (type) {
      'node' => 'node',
      'way' => 'way',
      'relation' => 'relation',
      _ => null,
    };
    if (osmType == null) return null;

    return Place(
      id: 'osm-$osmType-$id',
      name: name,
      category: category,
      latitude: latitude,
      longitude: longitude,
      description: description == null || description.isEmpty
          ? 'Объект каталога OpenStreetMap.'
          : description,
      source: PlaceSource.openStreetMap,
      sourceReference: 'https://www.openstreetmap.org/$osmType/$id',
      address: address.isEmpty ? null : address,
      website: _stringTag(tags, 'website'),
      openingHours: _stringTag(tags, 'opening_hours'),
      phone: _stringTag(tags, 'phone'),
      cuisine: _stringTag(tags, 'cuisine'),
    );
  }

  String? _stringTag(Map<String, dynamic> tags, String key) {
    final value = tags[key];
    return value is String ? value : null;
  }

  String? _categoryFor(Map<String, dynamic> tags) => switch (tags['amenity']) {
    'bar' => 'Бар',
    'pub' => 'Паб',
    'cafe' => 'Кафе',
    'restaurant' => 'Ресторан',
    'fast_food' => 'Фастфуд',
    'nightclub' => 'Клуб',
    'hookah_lounge' => 'Кальянная',
    'food_court' => 'Фудкорт',
    _ => null,
  };
}
