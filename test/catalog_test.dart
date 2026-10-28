import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pivo_pivo/catalog.dart';
import 'package:pivo_pivo/domain.dart';

void main() {
  const bounds = GeoBounds(
    south: 53.89,
    west: 27.54,
    north: 53.92,
    east: 27.59,
  );

  test('loads named POIs and preserves their OSM provenance', () async {
    final repository = OverpassPlaceCatalogRepository(
      client: MockClient((request) async {
        expect(request.bodyFields['data'], contains('(53.89,27.54'));
        expect(request.bodyFields['data'], contains('out center tags 201;'));
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'elements': [
                {
                  'type': 'node',
                  'id': 42,
                  'lat': 53.9,
                  'lon': 27.56,
                  'tags': {'name': 'Бар у парка', 'amenity': 'bar'},
                },
                {
                  'type': 'way',
                  'id': 77,
                  'center': {'lat': 53.91, 'lon': 27.57},
                  'tags': {
                    'name': 'Кафе',
                    'amenity': 'cafe',
                    'addr:street': 'Улица',
                    'addr:housenumber': '5',
                  },
                },
                {
                  'type': 'node',
                  'id': 43,
                  'lat': 53.9,
                  'lon': 27.56,
                  'tags': {'amenity': 'pub'},
                },
                {
                  'type': 'node',
                  'id': 44,
                  'lat': 53.9,
                  'lon': 27.56,
                  'tags': {'name': 'Офис', 'amenity': 'office'},
                },
              ],
            }),
          ),
          200,
        );
      }),
      clock: () => DateTime.utc(2025, 1, 1),
    );

    final snapshot = await repository.load(bounds);

    expect(snapshot.source, 'OpenStreetMap');
    expect(snapshot.isDemo, isFalse);
    expect(snapshot.places, hasLength(2));
    expect(snapshot.places.first.id, 'osm-node-42');
    expect(snapshot.places.first.source, PlaceSource.openStreetMap);
    expect(
      snapshot.places.first.sourceReference,
      'https://www.openstreetmap.org/node/42',
    );
    expect(snapshot.places.last.address, 'Улица, 5');
    expect(snapshot.places.last.latitude, 53.91);
  });

  test('limits returned POIs and marks the result as partial', () async {
    final repository = OverpassPlaceCatalogRepository(
      client: MockClient((_) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'elements': List.generate(
                201,
                (index) => {
                  'type': 'node',
                  'id': index + 1,
                  'lat': 53.9,
                  'lon': 27.56,
                  'tags': {'name': 'Место $index', 'amenity': 'bar'},
                },
              ),
            }),
          ),
          200,
        );
      }),
    );

    final snapshot = await repository.load(bounds);

    expect(snapshot.places, hasLength(200));
    expect(snapshot.isTruncated, isTrue);
  });

  test('uses the bounded-area cache for ten minutes', () async {
    var requests = 0;
    var now = DateTime.utc(2025, 1, 1);
    final repository = OverpassPlaceCatalogRepository(
      client: MockClient((_) async {
        requests++;
        return http.Response('{"elements":[]}', 200);
      }),
      clock: () => now,
    );

    final first = await repository.load(bounds);
    final cached = await repository.load(bounds);
    now = now.add(const Duration(minutes: 11));
    final refreshed = await repository.load(bounds);

    expect(requests, 2);
    expect(first.isCached, isFalse);
    expect(cached.isCached, isTrue);
    expect(refreshed.isCached, isFalse);
  });

  test('keeps nearby areas with sub-0.0001-degree differences separate', () {
    const nearbyBounds = GeoBounds(
      south: 53.89001,
      west: 27.54,
      north: 53.92,
      east: 27.59,
    );

    expect(nearbyBounds.cacheKey, isNot(bounds.cacheKey));
  });

  test(
    'force refresh bypasses cache and concurrent loads share a request',
    () async {
      var requests = 0;
      final repository = OverpassPlaceCatalogRepository(
        client: MockClient((_) async {
          requests++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response('{"elements":[]}', 200);
        }),
      );

      final simultaneous = await Future.wait([
        repository.load(bounds),
        repository.load(bounds),
      ]);
      final cached = await repository.load(bounds);
      final refreshed = await repository.load(bounds, forceRefresh: true);

      expect(requests, 2);
      expect(simultaneous.map((snapshot) => snapshot.isCached), [false, false]);
      expect(cached.isCached, isTrue);
      expect(refreshed.isCached, isFalse);
    },
  );

  test('does not treat an Overpass remark as an empty successful result', () {
    final repository = OverpassPlaceCatalogRepository(
      client: MockClient(
        (_) async => http.Response(
          '{"remark":"runtime error: query timed out","elements":[]}',
          200,
        ),
      ),
    );

    expect(
      repository.load(bounds),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('query timed out'),
        ),
      ),
    );
  });

  test('rejects oversized responses while streaming the response body', () {
    final repository = OverpassPlaceCatalogRepository(
      client: MockClient(
        (_) async =>
            http.Response.bytes(List<int>.filled(2 * 1024 * 1024 + 1, 32), 200),
      ),
    );

    expect(repository.load(bounds), throwsFormatException);
  });

  test('surfaces request timeouts instead of reporting an empty catalogue', () {
    final repository = OverpassPlaceCatalogRepository(
      client: MockClient((_) async {
        throw TimeoutException('test timeout');
      }),
    );

    expect(repository.load(bounds), throwsA(isA<TimeoutException>()));
  });

  test('rejects invalid and overly broad search areas', () async {
    final repository = OverpassPlaceCatalogRepository(
      client: MockClient((_) async => http.Response('{"elements":[]}', 200)),
    );

    await expectLater(
      repository.load(
        const GeoBounds(south: 53, west: 27, north: 52, east: 28),
      ),
      throwsFormatException,
    );
    await expectLater(
      repository.load(
        const GeoBounds(south: 53, west: 27, north: 54, east: 28),
      ),
      throwsFormatException,
    );
  });

  test('surfaces service errors instead of returning demo places', () async {
    final repository = OverpassPlaceCatalogRepository(
      client: MockClient((_) async => http.Response('unavailable', 503)),
    );

    await expectLater(
      repository.load(bounds),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('HTTP 503'),
        ),
      ),
    );
  });
}
