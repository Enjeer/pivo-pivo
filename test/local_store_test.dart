import 'package:flutter_test/flutter_test.dart';
import 'package:pivo_pivo/catalog.dart';
import 'package:pivo_pivo/domain.dart';
import 'package:pivo_pivo/local_store.dart';
import 'package:pivo_pivo/routing.dart';

void main() {
  test('controller calculates routes from the ordered OSM stops', () async {
    final provider = _FakeRoutingProvider();
    final controller = _controller(provider);
    await controller.initialize();

    await controller.calculateRoute(DirectionsMode.walking);

    expect(controller.routeStatus, RouteLoadStatus.ready);
    expect(controller.routeEstimate?.mode, DirectionsMode.walking);
    expect(provider.lastPlaceIds, ['osm-1', 'osm-2']);

    await controller.reorderPlan(0, 1);

    expect(controller.routeEstimate, isNull);
    expect(controller.routeStatus, RouteLoadStatus.idle);
    expect(controller.data.stops.map((stop) => stop.placeId), [
      'osm-2',
      'osm-1',
    ]);
  });

  test(
    'controller reports unsupported transit without calling provider',
    () async {
      final provider = _FakeRoutingProvider();
      final controller = _controller(provider);
      await controller.initialize();

      await controller.calculateRoute(DirectionsMode.transit);

      expect(controller.routeStatus, RouteLoadStatus.unsupported);
      expect(controller.routeError, isA<UnsupportedRouteModeException>());
      expect(provider.lastPlaceIds, isEmpty);
    },
  );

  test(
    'controller distinguishes an empty catalogue from a failed load',
    () async {
      const bounds = GeoBounds(
        south: 53.89,
        west: 27.54,
        north: 53.92,
        east: 27.59,
      );
      final emptyController = AppController(
        store: MemoryLocalUserStore(),
        catalogRepository: const _ControlledCatalogRepository(),
      );
      final failedController = AppController(
        store: MemoryLocalUserStore(),
        catalogRepository: const _ControlledCatalogRepository(fail: true),
      );

      await emptyController.loadPlaces(bounds);
      await failedController.loadPlaces(bounds);

      expect(emptyController.catalogStatus, CatalogLoadStatus.ready);
      expect(emptyController.places, isEmpty);
      expect(emptyController.catalogError, isNull);
      expect(failedController.catalogStatus, CatalogLoadStatus.error);
      expect(failedController.places, isEmpty);
      expect(failedController.catalogError, isA<StateError>());
    },
  );

  test(
    'persists only favorited or planned OSM places for the next launch',
    () async {
      final store = MemoryLocalUserStore();
      final catalog = _FakeCatalogRepository();
      final controller = AppController(
        store: store,
        catalogRepository: catalog,
        routingProvider: _FakeRoutingProvider(),
      );
      await controller.initialize();
      await controller.loadPlaces(
        const GeoBounds(south: 53.89, west: 27.54, north: 53.92, east: 27.59),
      );
      await controller.toggleFavorite('osm-1');
      await controller.addStop('osm-2');

      final restored = AppController(
        store: store,
        catalogRepository: const DemoPlaceCatalogRepository(),
        routingProvider: _FakeRoutingProvider(),
      );
      await restored.initialize();

      expect(restored.findPlace('osm-1')?.name, 'Место 1');
      expect(restored.findPlace('osm-2')?.name, 'Место 2');
      expect(restored.data.savedPlaces.keys, {'osm-1', 'osm-2'});
    },
  );
}

AppController _controller(_FakeRoutingProvider provider) => AppController(
  store: MemoryLocalUserStore(
    const UserData(
      stops: [
        PlanStop(placeId: 'osm-1'),
        PlanStop(placeId: 'osm-2'),
      ],
    ),
  ),
  catalogRepository: _FakeCatalogRepository(),
  routingProvider: provider,
);

class _FakeCatalogRepository implements PlaceCatalogRepository {
  static const _places = [
    Place(
      id: 'osm-1',
      name: 'Место 1',
      category: 'Кафе',
      latitude: 53.9,
      longitude: 27.56,
      description: 'OSM POI',
      source: PlaceSource.openStreetMap,
    ),
    Place(
      id: 'osm-2',
      name: 'Место 2',
      category: 'Бар',
      latitude: 53.91,
      longitude: 27.57,
      description: 'OSM POI',
      source: PlaceSource.openStreetMap,
    ),
  ];

  @override
  PlaceCatalogSnapshot get initialSnapshot => const PlaceCatalogSnapshot(
    places: _places,
    source: 'OpenStreetMap',
    fetchedAt: null,
  );

  @override
  Future<PlaceCatalogSnapshot> load(
    GeoBounds bounds, {
    bool forceRefresh = false,
  }) async => initialSnapshot;
}

class _ControlledCatalogRepository implements PlaceCatalogRepository {
  const _ControlledCatalogRepository({this.fail = false});

  final bool fail;

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
  }) async {
    if (fail) throw StateError('Каталог недоступен');
    return initialSnapshot;
  }
}

class _FakeRoutingProvider implements RoutingProvider {
  List<String> lastPlaceIds = [];

  @override
  Future<RouteEstimate> calculateRoute(
    List<Place> orderedPlaces,
    DirectionsMode mode,
  ) async {
    lastPlaceIds = orderedPlaces.map((place) => place.id).toList();
    return RouteEstimate(
      mode: mode,
      legs: [
        RouteLeg(
          fromPlaceId: orderedPlaces.first.id,
          toPlaceId: orderedPlaces.last.id,
          distanceMeters: 100,
          durationSeconds: 60,
        ),
      ],
      geometry: const [
        RoutePoint(latitude: 53.9, longitude: 27.56),
        RoutePoint(latitude: 53.91, longitude: 27.57),
      ],
      source: 'test',
      observedAt: DateTime.utc(2025),
    );
  }
}
