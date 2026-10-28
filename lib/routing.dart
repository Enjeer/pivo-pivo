import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'domain.dart';

enum DirectionsMode { walking, transit, driving }

const maxGoogleMapsMobileStops = 4;

class DirectionsLinkException implements Exception {
  const DirectionsLinkException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RoutePoint {
  const RoutePoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class RouteLeg {
  const RouteLeg({
    required this.fromPlaceId,
    required this.toPlaceId,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final String fromPlaceId;
  final String toPlaceId;
  final double distanceMeters;
  final double durationSeconds;
}

class RouteEstimate {
  const RouteEstimate({
    required this.mode,
    required this.legs,
    required this.geometry,
    required this.source,
    required this.observedAt,
  });

  final DirectionsMode mode;
  final List<RouteLeg> legs;
  final List<RoutePoint> geometry;
  final String source;
  final DateTime observedAt;

  double get totalDistanceMeters =>
      legs.fold(0, (total, leg) => total + leg.distanceMeters);

  double get totalDurationSeconds =>
      legs.fold(0, (total, leg) => total + leg.durationSeconds);
}

abstract interface class RoutingProvider {
  Future<RouteEstimate> calculateRoute(
    List<Place> orderedPlaces,
    DirectionsMode mode,
  );
}

class UnavailableRoutingProvider implements RoutingProvider {
  const UnavailableRoutingProvider();

  @override
  Future<RouteEstimate> calculateRoute(
    List<Place> orderedPlaces,
    DirectionsMode mode,
  ) {
    throw const RouteProviderException('Маршрутизатор не настроен.');
  }
}

class UnsupportedRouteModeException implements Exception {
  const UnsupportedRouteModeException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RouteProviderException implements Exception {
  const RouteProviderException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FossgisOsrmRoutingProvider implements RoutingProvider {
  FossgisOsrmRoutingProvider({
    http.Client? client,
    Uri? drivingEndpoint,
    Uri? walkingEndpoint,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _drivingEndpoint =
           drivingEndpoint ??
           Uri.https('routing.openstreetmap.de', '/routed-car'),
       _walkingEndpoint =
           walkingEndpoint ??
           Uri.https('routing.openstreetmap.de', '/routed-foot'),
       _clock = clock ?? DateTime.now;

  static const _maxStops = 10;

  final http.Client _client;
  final Uri _drivingEndpoint;
  final Uri _walkingEndpoint;
  final DateTime Function() _clock;
  Future<void> _requestQueue = Future<void>.value();
  DateTime? _lastRequestAt;

  @override
  Future<RouteEstimate> calculateRoute(
    List<Place> orderedPlaces,
    DirectionsMode mode,
  ) async {
    if (orderedPlaces.length < 2) {
      throw const RouteProviderException(
        'Для маршрута нужны минимум две остановки.',
      );
    }
    if (orderedPlaces.length > _maxStops) {
      throw const RouteProviderException(
        'Маршрут ограничен десятью остановками.',
      );
    }
    if (mode == DirectionsMode.transit) {
      throw const UnsupportedRouteModeException(
        'Внутренний общественный маршрут пока недоступен. '
        'Его можно открыть во внешней навигации.',
      );
    }
    for (final place in orderedPlaces) {
      if (!place.latitude.isFinite ||
          !place.longitude.isFinite ||
          place.latitude < -90 ||
          place.latitude > 90 ||
          place.longitude < -180 ||
          place.longitude > 180) {
        throw const RouteProviderException(
          'Одна из остановок имеет некорректные координаты.',
        );
      }
    }

    final endpoint = mode == DirectionsMode.walking
        ? _walkingEndpoint
        : _drivingEndpoint;
    final profile = mode == DirectionsMode.walking ? 'foot' : 'driving';
    final coordinates = orderedPlaces
        .map((place) => '${place.longitude},${place.latitude}')
        .join(';');
    final uri =
        Uri.parse(
          '${endpoint.toString().replaceFirst(RegExp(r'/$'), '')}'
          '/route/v1/$profile/$coordinates',
        ).replace(
          queryParameters: const {
            'overview': 'full',
            'geometries': 'geojson',
            'steps': 'false',
          },
        );

    final response = await _sendRequest(uri);
    if (response.statusCode != 200) {
      throw RouteProviderException(
        'Маршрутизатор вернул HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const RouteProviderException(
        'Маршрутизатор вернул ответ неверного формата.',
      );
    }
    if (decoded['code'] != 'Ok') {
      final message = decoded['message'];
      throw RouteProviderException(
        message is String && message.isNotEmpty
            ? message
            : 'Маршрут не найден (${decoded['code'] ?? 'unknown'}).',
      );
    }
    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty || routes.first is! Map) {
      throw const RouteProviderException('Маршрут не найден.');
    }
    final route = Map<String, dynamic>.from(routes.first as Map);
    final rawLegs = route['legs'];
    final geometry = _geometryFromRoute(route['geometry']);
    if (rawLegs is! List || rawLegs.length != orderedPlaces.length - 1) {
      throw const RouteProviderException(
        'Маршрутизатор вернул неполные данные по участкам.',
      );
    }
    final legs = <RouteLeg>[];
    for (var index = 0; index < rawLegs.length; index++) {
      final rawLeg = rawLegs[index];
      if (rawLeg is! Map) {
        throw const RouteProviderException(
          'Маршрутизатор вернул некорректный участок.',
        );
      }
      final leg = Map<String, dynamic>.from(rawLeg);
      final distance = leg['distance'];
      final duration = leg['duration'];
      if (distance is! num ||
          duration is! num ||
          distance < 0 ||
          duration < 0) {
        throw const RouteProviderException(
          'Маршрутизатор вернул некорректное расстояние или время.',
        );
      }
      legs.add(
        RouteLeg(
          fromPlaceId: orderedPlaces[index].id,
          toPlaceId: orderedPlaces[index + 1].id,
          distanceMeters: distance.toDouble(),
          durationSeconds: duration.toDouble(),
        ),
      );
    }

    return RouteEstimate(
      mode: mode,
      legs: legs,
      geometry: geometry,
      source: 'FOSSGIS OSRM',
      observedAt: _clock().toUtc(),
    );
  }

  Future<http.Response> _sendRequest(Uri uri) {
    final completer = Completer<http.Response>();
    _requestQueue = _requestQueue.then((_) async {
      try {
        final lastRequestAt = _lastRequestAt;
        if (lastRequestAt != null) {
          final wait =
              const Duration(seconds: 1) -
              DateTime.now().difference(lastRequestAt);
          if (wait > Duration.zero) await Future<void>.delayed(wait);
        }
        _lastRequestAt = DateTime.now();
        final response = await _client
            .get(
              uri,
              headers: const {
                'Accept': 'application/json',
                'User-Agent':
                    'PivoPivo/1.0 (+https://github.com/Enjeer/pivo-pivo)',
              },
            )
            .timeout(const Duration(seconds: 20));
        completer.complete(response);
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  List<RoutePoint> _geometryFromRoute(Object? rawGeometry) {
    if (rawGeometry is! Map || rawGeometry['coordinates'] is! List) {
      throw const RouteProviderException(
        'В ответе маршрутизатора нет геометрии маршрута.',
      );
    }
    final points = <RoutePoint>[];
    for (final coordinate in rawGeometry['coordinates'] as List) {
      if (coordinate is! List ||
          coordinate.length < 2 ||
          coordinate[0] is! num ||
          coordinate[1] is! num) {
        throw const RouteProviderException(
          'Маршрутизатор вернул некорректную геометрию.',
        );
      }
      final longitude = (coordinate[0] as num).toDouble();
      final latitude = (coordinate[1] as num).toDouble();
      if (latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
        throw const RouteProviderException(
          'Маршрутизатор вернул координаты вне допустимого диапазона.',
        );
      }
      points.add(RoutePoint(latitude: latitude, longitude: longitude));
    }
    if (points.length < 2) {
      throw const RouteProviderException(
        'Маршрут имеет недостаточно точек для отображения.',
      );
    }
    return points;
  }
}

extension DirectionsModeLabel on DirectionsMode {
  String get label => switch (this) {
    DirectionsMode.walking => 'Пешком',
    DirectionsMode.transit => 'Транспорт',
    DirectionsMode.driving => 'Автомобиль',
  };

  String get googleMapsValue => switch (this) {
    DirectionsMode.walking => 'walking',
    DirectionsMode.transit => 'transit',
    DirectionsMode.driving => 'driving',
  };
}

Uri buildGoogleMapsDirectionsUri(
  List<Place> orderedStops,
  DirectionsMode mode,
) {
  if (orderedStops.isEmpty) {
    throw ArgumentError.value(orderedStops, 'orderedStops', 'Cannot be empty');
  }
  if (orderedStops.length > maxGoogleMapsMobileStops) {
    throw const DirectionsLinkException(
      'Мобильная ссылка Google Maps поддерживает до трёх промежуточных '
      'точек (четыре запланированные остановки).',
    );
  }

  final destination = orderedStops.last;
  final parameters = <String, String>{
    'api': '1',
    'destination': '${destination.latitude},${destination.longitude}',
    'travelmode': mode.googleMapsValue,
  };
  if (orderedStops.length > 1) {
    parameters['waypoints'] = orderedStops
        .take(orderedStops.length - 1)
        .map((place) => '${place.latitude},${place.longitude}')
        .join('|');
  }

  final uri = Uri.https('www.google.com', '/maps/dir/', parameters);
  if (uri.toString().length > 2048) {
    throw ArgumentError.value(
      orderedStops.length,
      'orderedStops',
      'Route link exceeds Google Maps URL length limit',
    );
  }
  return uri;
}
