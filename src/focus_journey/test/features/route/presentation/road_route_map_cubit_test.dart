// MapCubit road-model tests (route-real-road / AC-2/AC-3/AC-5).
//
// When the route view state carries a RoadRoute, the MapCubit draws the ROAD:
//   - the drawn geometry is the road sub-path (curves along the road)
//   - the ONLY markers are the waypoints (start/end/stops) — NO per-province dots
//   - the current-position marker rides the road by the progress fraction

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/road_path.dart';
import 'package:focus_journey/features/route/domain/road_route.dart';
import 'package:focus_journey/features/route/domain/route_progress_resolver.dart';
import 'package:focus_journey/features/route/presentation/map_cubit.dart';
import 'package:focus_journey/features/route/presentation/route_view_state.dart';

import '../map_test_fixtures.dart';

GeoCoordinate _c(double lon, double lat) =>
    GeoCoordinate(longitude: lon, latitude: lat);

RoadPath _road() => RoadPath(<GeoCoordinate>[
  for (var i = 0; i <= 20; i++) _c(105.0, 8.6 + i * 0.72),
]);

void main() {
  final chain = buildFixtureChain();
  final geography = buildFixtureGeography(chain);

  RouteViewState roadRouteState({
    required List<Province> waypoints,
    required RoadRoute roadRoute,
    required double routeDistanceKm,
  }) {
    final selection = selectionFor(chain, 'mui', JourneyDirection.towardHaGiang);
    final position = RouteProgressResolver.resolve(
      routeDistanceKm: routeDistanceKm,
      selection: selection,
      chain: chain,
    );
    return RouteViewState(
      selection: selection,
      position: position,
      cumulativeDistanceKm: routeDistanceKm,
      roadRoute: roadRoute,
      waypoints: waypoints,
    );
  }

  test('default route: exactly two waypoint markers (start + end), no dots', () {
    final road = _road();
    final start = geography.coordinateOf(nodeById(chain, 'mui'));
    final end = geography.coordinateOf(nodeById(chain, 'ha_giang'));
    final roadRoute = RoadRoute.build(
      road: road,
      waypoints: <GeoCoordinate>[start, end],
    );
    final cubit = MapCubit(geography: geography);
    cubit.updateFromRoute(
      roadRouteState(
        waypoints: <Province>[
          nodeById(chain, 'mui'),
          nodeById(chain, 'ha_giang'),
        ],
        roadRoute: roadRoute,
        routeDistanceKm: 0,
      ),
    );
    final state = cubit.state;
    expect(state.roadRoute, isNotNull);
    // Only the two endpoints are markers — no per-province dots (AC-3).
    expect(state.waypoints.map((p) => p.id).toList(), <String>[
      'mui',
      'ha_giang',
    ]);
    expect(state.orderedNodes.length, 2);
    expect(state.emphasizedNodeIds, <String>{'mui', 'ha_giang'});
    // The drawn line is the road sub-path (many vertices, curves along the road).
    expect(state.baseRoutePolyline.points.length, greaterThan(2));
    // Marker sits at the start at km 0.
    expect(state.markerPosition, isNotNull);
    cubit.close();
  });

  test('with a stop: a third waypoint marker appears (AC-4)', () {
    final road = _road();
    final waypoints = <Province>[
      nodeById(chain, 'mui'),
      nodeById(chain, 'da_nang'),
      nodeById(chain, 'ha_giang'),
    ];
    final coords = <GeoCoordinate>[
      for (final w in waypoints) geography.coordinateOf(w),
    ];
    final roadRoute = RoadRoute.build(road: road, waypoints: coords);
    final cubit = MapCubit(geography: geography);
    cubit.updateFromRoute(
      roadRouteState(
        waypoints: waypoints,
        roadRoute: roadRoute,
        routeDistanceKm: 100,
      ),
    );
    expect(cubit.state.waypoints.length, 3);
    expect(cubit.state.emphasizedNodeIds.length, 3);
    cubit.close();
  });

  test('current marker rides the road by the progress fraction (AC-5)', () {
    final road = _road();
    final start = geography.coordinateOf(nodeById(chain, 'mui'));
    final end = geography.coordinateOf(nodeById(chain, 'ha_giang'));
    final roadRoute = RoadRoute.build(
      road: road,
      waypoints: <GeoCoordinate>[start, end],
    );
    final cubit = MapCubit(geography: geography);
    // Halfway along the chain (total 1440 → 720) → fraction 0.5 → mid road.
    cubit.updateFromRoute(
      roadRouteState(
        waypoints: <Province>[
          nodeById(chain, 'mui'),
          nodeById(chain, 'ha_giang'),
        ],
        roadRoute: roadRoute,
        routeDistanceKm: 720,
      ),
    );
    final marker = cubit.state.markerPosition!;
    final mid = roadRoute.coordinateAtFraction(0.5);
    expect(marker.latitude, closeTo(mid.latitude, 1e-6));
    expect(marker.longitude, closeTo(mid.longitude, 1e-6));
    cubit.close();
  });
}
