import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pivo_pivo/domain.dart';
import 'package:pivo_pivo/routing.dart';

void main() {
  test(
    'OSRM route uses ordered lon-lat coordinates and returns route metrics',
    () async {
      final provider = FossgisOsrmRoutingProvider(
        walkingEndpoint: Uri.https('router.example', '/routed-foot'),
        client: MockClient((request) async {
          expect(request.url.path, startsWith('/routed-foot/route/v1/foot/'));
          expect(
            request.url.path,
            contains('27.5618,53.9012;27.5537,53.9081;27.5743,53.8947'),
          );
          expect(request.url.queryParameters['geometries'], 'geojson');
          return http.Response(
            jsonEncode({
              'code': 'Ok',
              'routes': [
                {
                  'legs': [
                    {'distance': 120.5, 'duration': 90},
                    {'distance': 80, 'duration': 60},
                  ],
                  'geometry': {
                    'type': 'LineString',
                    'coordinates': [
                      [27.5618, 53.9012],
                      [27.56, 53.9],
                      [27.5743, 53.8947],
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
        clock: () => DateTime.utc(2025, 1, 1),
      );

      final estimate = await provider.calculateRoute(
        demoPlaces.take(3).toList(),
        DirectionsMode.walking,
      );

      expect(estimate.legs, hasLength(2));
      expect(estimate.legs.first.fromPlaceId, 'demo-01');
      expect(estimate.legs.last.toPlaceId, 'demo-03');
      expect(estimate.totalDistanceMeters, 200.5);
      expect(estimate.totalDurationSeconds, 150);
      expect(estimate.geometry.first.latitude, 53.9012);
      expect(estimate.source, 'FOSSGIS OSRM');
    },
  );

  test(
    'OSRM route rejects unsupported transit and malformed responses',
    () async {
      var requests = 0;
      final provider = FossgisOsrmRoutingProvider(
        client: MockClient((_) async {
          requests++;
          return http.Response('{"code":"NoRoute"}', 200);
        }),
      );

      await expectLater(
        provider.calculateRoute(
          demoPlaces.take(2).toList(),
          DirectionsMode.transit,
        ),
        throwsA(isA<UnsupportedRouteModeException>()),
      );
      await expectLater(
        provider.calculateRoute(
          demoPlaces.take(2).toList(),
          DirectionsMode.driving,
        ),
        throwsA(isA<RouteProviderException>()),
      );
      expect(requests, 1);
    },
  );

  test(
    'OSRM route rejects invalid coordinates and more than ten stops',
    () async {
      var requests = 0;
      final provider = FossgisOsrmRoutingProvider(
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      final invalidPlace = Place(
        id: 'invalid',
        name: 'Invalid',
        category: 'Кафе',
        latitude: double.nan,
        longitude: 27.56,
        description: '',
        source: PlaceSource.openStreetMap,
      );
      final tooManyPlaces = List.generate(
        11,
        (index) => Place(
          id: 'stop-$index',
          name: 'Stop $index',
          category: 'Кафе',
          latitude: 53.9,
          longitude: 27.56,
          description: '',
          source: PlaceSource.openStreetMap,
        ),
      );

      await expectLater(
        provider.calculateRoute([
          invalidPlace,
          demoPlaces.last,
        ], DirectionsMode.walking),
        throwsA(isA<RouteProviderException>()),
      );
      await expectLater(
        provider.calculateRoute(tooManyPlaces, DirectionsMode.walking),
        throwsA(isA<RouteProviderException>()),
      );
      expect(requests, 0);
    },
  );

  test(
    'coincident stops and provider timeouts become explicit failures',
    () async {
      var requests = 0;
      final duplicateProvider = FossgisOsrmRoutingProvider(
        client: MockClient((request) async {
          requests++;
          expect(request.url.path, contains('27.5618,53.9012;27.5618,53.9012'));
          return http.Response(
            '{"code":"NoRoute","message":"No route found"}',
            200,
          );
        }),
      );
      final duplicatePlace = Place(
        id: 'same-coordinate',
        name: 'Same coordinate',
        category: 'Бар',
        latitude: demoPlaces.first.latitude,
        longitude: demoPlaces.first.longitude,
        description: '',
        source: PlaceSource.openStreetMap,
      );

      await expectLater(
        duplicateProvider.calculateRoute([
          demoPlaces.first,
          duplicatePlace,
        ], DirectionsMode.walking),
        throwsA(isA<RouteProviderException>()),
      );
      expect(requests, 1);

      final timeoutProvider = FossgisOsrmRoutingProvider(
        client: MockClient((_) async => throw TimeoutException('test timeout')),
      );
      await expectLater(
        timeoutProvider.calculateRoute(
          demoPlaces.take(2).toList(),
          DirectionsMode.driving,
        ),
        throwsA(isA<TimeoutException>()),
      );
    },
  );

  test('OSRM route validates stop count and returned coordinates', () async {
    final provider = FossgisOsrmRoutingProvider(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'legs': [
                  {'distance': 1, 'duration': 1},
                ],
                'geometry': {
                  'type': 'LineString',
                  'coordinates': [
                    [200, 53],
                    [27, 53],
                  ],
                },
              },
            ],
          }),
          200,
        ),
      ),
    );

    await expectLater(
      provider.calculateRoute([demoPlaces.first], DirectionsMode.driving),
      throwsA(isA<RouteProviderException>()),
    );
    await expectLater(
      provider.calculateRoute(
        demoPlaces.take(2).toList(),
        DirectionsMode.driving,
      ),
      throwsA(isA<RouteProviderException>()),
    );
  });

  test('directions keep all stops in the user-defined order', () {
    final uri = buildGoogleMapsDirectionsUri(
      demoPlaces.take(3).toList(),
      DirectionsMode.walking,
    );

    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['travelmode'], 'walking');
    expect(uri.queryParameters['waypoints'], '53.9012,27.5618|53.9081,27.5537');
    expect(uri.queryParameters['destination'], '53.8947,27.5743');
  });

  test('directions support transit and driving without remapping modes', () {
    final transit = buildGoogleMapsDirectionsUri([
      demoPlaces.first,
    ], DirectionsMode.transit);
    final driving = buildGoogleMapsDirectionsUri([
      demoPlaces.first,
    ], DirectionsMode.driving);

    expect(transit.queryParameters['travelmode'], 'transit');
    expect(driving.queryParameters['travelmode'], 'driving');
    expect(transit.queryParameters.containsKey('waypoints'), isFalse);
  });

  test('directions allow the documented mobile waypoint limit', () {
    final uri = buildGoogleMapsDirectionsUri(
      demoPlaces.take(maxGoogleMapsMobileStops).toList(),
      DirectionsMode.walking,
    );

    expect(uri.queryParameters['waypoints']?.split('|'), hasLength(3));
  });

  test('directions reject an empty stop list', () {
    expect(
      () => buildGoogleMapsDirectionsUri([], DirectionsMode.walking),
      throwsArgumentError,
    );
  });

  test('directions reject routes beyond the mobile waypoint limit', () {
    expect(
      () => buildGoogleMapsDirectionsUri(demoPlaces, DirectionsMode.walking),
      throwsA(isA<DirectionsLinkException>()),
    );
  });
}
