import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'catalog.dart';
import 'domain.dart';
import 'routing.dart';

abstract interface class LocalUserStore {
  Future<UserData> read();

  Future<void> write(UserData data);
}

class SecureLocalUserStore implements LocalUserStore {
  SecureLocalUserStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _stateKey = 'pivo_pivo.local_state.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<UserData> read() async {
    final content = await _storage.read(key: _stateKey);
    if (content == null) return const UserData();
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      throw const FormatException('Некорректный формат локальных данных');
    }
    return UserData.fromJson(Map<String, Object?>.from(decoded));
  }

  @override
  Future<void> write(UserData data) =>
      _storage.write(key: _stateKey, value: jsonEncode(data.toJson()));
}

class MemoryLocalUserStore implements LocalUserStore {
  MemoryLocalUserStore([UserData initialData = const UserData()])
    : _data = initialData;

  UserData _data;

  @override
  Future<UserData> read() async => _data;

  @override
  Future<void> write(UserData data) async {
    _data = data;
  }
}

class AppController extends ChangeNotifier {
  AppController({
    required this.store,
    PlaceCatalogRepository? catalogRepository,
    RoutingProvider? routingProvider,
  }) : catalogRepository =
           catalogRepository ?? const DemoPlaceCatalogRepository(),
       routingProvider = routingProvider ?? const UnavailableRoutingProvider() {
    _catalogSnapshot = this.catalogRepository.initialSnapshot;
    _catalogStatus = _catalogSnapshot.isDemo
        ? CatalogLoadStatus.ready
        : CatalogLoadStatus.idle;
    for (final place in _catalogSnapshot.places) {
      _knownPlaces[place.id] = place;
    }
  }

  final LocalUserStore store;
  final PlaceCatalogRepository catalogRepository;
  final RoutingProvider routingProvider;
  UserData _data = const UserData();
  late PlaceCatalogSnapshot _catalogSnapshot;
  Future<void> _pendingWrite = Future<void>.value();
  bool _isReady = false;
  Object? _loadError;
  CatalogLoadStatus _catalogStatus = CatalogLoadStatus.idle;
  Object? _catalogError;
  int _catalogRequestVersion = 0;
  RouteEstimate? _routeEstimate;
  Object? _routeError;
  RouteLoadStatus _routeStatus = RouteLoadStatus.idle;
  int _routeRequestVersion = 0;
  final Map<String, Place> _knownPlaces = {};

  UserData get data => _data;
  bool get isReady => _isReady;
  Object? get loadError => _loadError;
  List<Place> get places => _catalogSnapshot.places;
  List<Place> get knownPlaces => List.unmodifiable(_knownPlaces.values);
  CatalogLoadStatus get catalogStatus => _catalogStatus;
  Object? get catalogError => _catalogError;
  bool get isDemoCatalog => _catalogSnapshot.isDemo;
  bool get catalogIsTruncated => _catalogSnapshot.isTruncated;
  bool get catalogIsCached => _catalogSnapshot.isCached;
  String get catalogSource => _catalogSnapshot.source;
  DateTime? get catalogFetchedAt => _catalogSnapshot.fetchedAt;
  RouteEstimate? get routeEstimate => _routeEstimate;
  Object? get routeError => _routeError;
  RouteLoadStatus get routeStatus => _routeStatus;

  Place? findPlace(String placeId) {
    final place = _knownPlaces[placeId];
    if (place != null) return place;
    final savedPlace = _data.savedPlaces[placeId];
    if (savedPlace != null) return savedPlace;
    for (final demoPlace in demoPlaces) {
      if (demoPlace.id == placeId) return demoPlace;
    }
    return null;
  }

  Future<void> loadPlaces(GeoBounds bounds, {bool forceRefresh = false}) async {
    final requestVersion = ++_catalogRequestVersion;
    _catalogStatus = CatalogLoadStatus.loading;
    _catalogError = null;
    notifyListeners();
    try {
      final snapshot = await catalogRepository.load(
        bounds,
        forceRefresh: forceRefresh,
      );
      if (requestVersion != _catalogRequestVersion) return;
      _catalogSnapshot = snapshot;
      for (final place in _catalogSnapshot.places) {
        _knownPlaces[place.id] = place;
      }
      _catalogStatus = CatalogLoadStatus.ready;
    } on Object catch (error) {
      if (requestVersion != _catalogRequestVersion) return;
      _catalogError = error;
      _catalogStatus = CatalogLoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> calculateRoute(DirectionsMode mode) async {
    final requestVersion = ++_routeRequestVersion;
    _routeEstimate = null;
    _routeError = null;
    _routeStatus = RouteLoadStatus.loading;
    notifyListeners();
    try {
      if (mode == DirectionsMode.transit) {
        throw const UnsupportedRouteModeException(
          'Внутренний общественный маршрут не поддерживается. '
          'Откройте остановки во внешней навигации.',
        );
      }
      if (_data.stops.length < 2) {
        throw const RouteProviderException(
          'Добавьте минимум две остановки для расчёта пути.',
        );
      }
      final orderedPlaces = <Place>[];
      for (final stop in _data.stops) {
        final place = findPlace(stop.placeId);
        if (place == null || place.isDemo) {
          throw const RouteProviderException(
            'Для расчёта нужны реальные места с координатами из каталога.',
          );
        }
        orderedPlaces.add(place);
      }
      final estimate = await routingProvider.calculateRoute(
        orderedPlaces,
        mode,
      );
      if (requestVersion != _routeRequestVersion) return;
      _routeEstimate = estimate;
      _routeStatus = RouteLoadStatus.ready;
    } on UnsupportedRouteModeException catch (error) {
      if (requestVersion != _routeRequestVersion) return;
      _routeError = error;
      _routeStatus = RouteLoadStatus.unsupported;
    } on Object catch (error) {
      if (requestVersion != _routeRequestVersion) return;
      _routeError = error;
      _routeStatus = RouteLoadStatus.error;
    }
    notifyListeners();
  }

  void clearRoute() {
    _routeRequestVersion++;
    _routeEstimate = null;
    _routeError = null;
    _routeStatus = RouteLoadStatus.idle;
    notifyListeners();
  }

  Future<void> initialize() async {
    _loadError = null;
    _isReady = false;
    notifyListeners();
    try {
      _data = await store.read();
      _knownPlaces.addAll(_data.savedPlaces);
      _isReady = true;
    } catch (error) {
      _loadError = error;
    }

    notifyListeners();
  }

  Future<void> toggleFavorite(String placeId) => _update((current) {
    final favorites = Set<String>.of(current.favorites);
    if (!favorites.add(placeId)) favorites.remove(placeId);
    return current.copyWith(favorites: favorites);
  });

  Future<void> addStop(String placeId) => _update((current) {
    if (current.stops.any((stop) => stop.placeId == placeId)) {
      return current;
    }
    return current.copyWith(
      stops: [
        ...current.stops,
        PlanStop(placeId: placeId),
      ],
    );
  });

  Future<void> removeStop(String placeId) => _update((current) {
    return current.copyWith(
      stops: current.stops
          .where((stop) => stop.placeId != placeId)
          .toList(growable: false),
    );
  });

  Future<void> removeStops(Iterable<String> placeIds) {
    final ids = placeIds.toSet();
    return _update(
      (current) => current.copyWith(
        stops: current.stops
            .where((stop) => !ids.contains(stop.placeId))
            .toList(growable: false),
      ),
    );
  }

  Future<void> reorderPlan(int oldIndex, int newIndex) => _update((current) {
    return current.copyWith(
      stops: reorderStops(current.stops, oldIndex, newIndex),
    );
  });

  Future<void> updateVisitCost(
    String placeId,
    int? costMinor, {
    DateTime? observedAt,
  }) => _update((current) {
    return current.copyWith(
      stops: current.stops
          .map(
            (stop) => stop.placeId == placeId
                ? stop.copyWith(
                    visitCostMinor: costMinor,
                    visitCostObservedAt: observedAt ?? DateTime.now().toUtc(),
                    visitCostSource: 'user_estimate',
                    visitCostStatus: PriceVerification.estimated,
                    clearVisitCost: costMinor == null,
                  )
                : stop,
          )
          .toList(growable: false),
    );
  });

  Future<void> updateTransportCost(int? costMinor) => _update((current) {
    return current.copyWith(
      transportCostMinor: costMinor,
      clearTransportCost: costMinor == null,
    );
  });

  Future<void> updateBudget(int? budgetMinor) {
    if (budgetMinor != null && budgetMinor < 0) {
      throw RangeError.value(budgetMinor, 'budgetMinor');
    }
    return _update(
      (current) => current.copyWith(
        budgetMinor: budgetMinor,
        clearBudget: budgetMinor == null,
      ),
    );
  }

  Future<void> updateParticipants(int participants) {
    if (participants < 1 || participants > 99) {
      throw RangeError.range(participants, 1, 99, 'participants');
    }
    return _update((current) => current.copyWith(participants: participants));
  }

  Future<void> updateNote(String placeId, String note) => _update((current) {
    final notes = Map<String, String>.of(current.noteByPlace);
    final content = note.trim();
    if (content.isEmpty) {
      notes.remove(placeId);
    } else {
      notes[placeId] = content;
    }
    return current.copyWith(noteByPlace: notes);
  });

  Future<void> _update(UserData Function(UserData current) update) {
    if (!_isReady) {
      return Future<void>.error(
        StateError('Локальные данные ещё не загружены'),
      );
    }
    final operation = _pendingWrite.then((_) async {
      var nextData = update(_data);
      final trackedPlaceIds = {
        ...nextData.favorites,
        ...nextData.stops.map((stop) => stop.placeId),
      };
      final savedPlaces = Map<String, Place>.of(nextData.savedPlaces)
        ..removeWhere((placeId, _) => !trackedPlaceIds.contains(placeId));
      for (final placeId in trackedPlaceIds) {
        final place = _knownPlaces[placeId];
        if (place != null) savedPlaces[placeId] = place;
      }
      nextData = nextData.copyWith(savedPlaces: savedPlaces);
      await store.write(nextData);
      final planChanged = !listEquals(
        _data.stops.map((stop) => stop.placeId).toList(),
        nextData.stops.map((stop) => stop.placeId).toList(),
      );
      _data = nextData;
      if (planChanged) {
        _routeRequestVersion++;
        _routeEstimate = null;
        _routeError = null;
        _routeStatus = RouteLoadStatus.idle;
      }
      notifyListeners();
    });
    _pendingWrite = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation;
  }
}

enum CatalogLoadStatus { idle, loading, ready, error }

enum RouteLoadStatus { idle, loading, ready, error, unsupported }
