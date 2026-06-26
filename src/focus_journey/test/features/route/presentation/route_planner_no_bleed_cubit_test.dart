// Cubit-behaviour tests for the route-planner-v2 "no idle-trace bleed across an
// abandon" invariant (ADR-0005 / AC-11). Drives the REAL MapCubit (the surface's
// red-trace source) fed by a route view state carrying the new offset + a segment
// record that still contains the abandoned route's old-offset segments. Pure: no
// engine, no timers, no network.
//
// Per the reconciled ADR-0005, abandoned-route segments are KEPT (NOT pruned):
// the new route paints only its own offset window, with no-bleed holding BY
// CONSTRUCTION — the IdleTraceMapper re-bases every prior-route segment by the new
// offset and clips it out of the new route's [0, routeLengthKm] window. These
// cases feed BOTH old and new segments and assert only the new window is painted,
// proving the no-bleed invariant without any segment store being mutated.
//
// Traceability (one test ↔ one case; TC + AC ids in each description):
//   TC-331 (AC-11) new route's red trace shows only the new offset's segments —
//                  no bleed from the abandoned route
//   TC-332 (AC-11) at km == 0 the new route's red trace is empty regardless of
//                  abandoned-route history
//   TC-333 (AC-11/AC-7) the overlay renders a custom sub-path via the same
//                  map-experience projector/trace path used for the spine

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/activity_segment.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_planner.dart';
import 'package:focus_journey/features/route/presentation/map_cubit.dart';
import 'package:focus_journey/features/route/presentation/route_progress_cubit.dart';
import 'package:focus_journey/features/route/presentation/route_view_state.dart';

import '../map_test_fixtures.dart';
import '../route_test_fixtures.dart' show RecordingRouteRepository;

void main() {
  // Fixture chain total = 1440 km. Cumulative-from-mui: 0/60/230/530/840/1440.
  late final ProvinceChain chain = buildFixtureChain();
  late final ProvinceGeography geography = buildFixtureGeography(chain);

  ResolvedRoute resolve(String startId, String endId) => RoutePlanner.resolve(
    fullChain: chain,
    fullGeography: geography,
    start: nodeById(chain, startId),
    end: nodeById(chain, endId),
  );

  /// Builds a RouteViewState for [resolved] at [cumulativeKm] with the offset
  /// [offsetKm], by driving the REAL RouteProgressCubit (so subGeography + the
  /// derived selection are exactly what production emits).
  Future<RouteViewState> routeStateFor(
    ResolvedRoute resolved, {
    required double offsetKm,
    required double cumulativeKm,
  }) async {
    final cubit = RouteProgressCubit(
      chain: chain,
      geography: geography,
      repository: RecordingRouteRepository(),
    );
    addTearDown(cubit.close);
    cubit.updateFromDistance(offsetKm);
    await cubit.confirmRoute(resolved);
    cubit.updateFromDistance(cumulativeKm);
    return cubit.state;
  }

  group('TC-331 (AC-11) new route trace shows only the new offset segments', () {
    test(
      'an abandoned-route old-offset idle segment never bleeds onto the new route',
      () async {
        // The new route da_lat → ha_giang stamped a NEW offset at cumulative
        // 1180. The new route's own length is 300+600 = 900 km, window
        // [1180, 1180 + routeKm). Advance the route 400 km in (cumulative 1580).
        final newRoute = resolve('da_lat', 'ha_giang');
        final routeState = await routeStateFor(
          newRoute,
          offsetKm: 1180,
          cumulativeKm: 1580,
        );

        final mapCubit = MapCubit(geography: geography);
        addTearDown(mapCubit.close);

        // The record contains BOTH:
        //   - an OLD abandoned-route idle span at absolute [200, 240] km (before
        //     the new offset 1180 → fully outside the new window), and
        //   - a NEW-route idle span at absolute [1300, 1340] km (inside the new
        //     [1180, 1580) window → 120..160 route km).
        final segments = <ActivitySegment>[
          idleSegment(200, 240), // abandoned-route span (old offset)
          idleSegment(1300, 1340), // new-route span (new offset)
        ];

        mapCubit
          ..updateFromRoute(routeState)
          ..updateFromSnapshot(
            progressWith(segments: segments, distanceKm: 1580),
          );

        // Exactly ONE red stretch is painted — the new-route span. The old
        // abandoned-route span is clipped out entirely (no bleed — AC-11).
        expect(
          mapCubit.state.idleStretches,
          hasLength(1),
          reason: 'only the new offset window paints; the old span is dropped',
        );
      },
    );
  });

  group('TC-332 (AC-11) new route at km == 0 has an empty red trace', () {
    test(
      'no abandoned-route segment appears at or before the new route origin',
      () async {
        // New route just started: cumulative == offset (1180), routeKm == 0.
        final newRoute = resolve('da_lat', 'ha_giang');
        final routeState = await routeStateFor(
          newRoute,
          offsetKm: 1180,
          cumulativeKm: 1180,
        );

        final mapCubit = MapCubit(geography: geography);
        addTearDown(mapCubit.close);

        // The record still holds the abandoned route's old-offset idle spans.
        final segments = <ActivitySegment>[
          idleSegment(200, 240),
          idleSegment(800, 900),
        ];
        mapCubit
          ..updateFromRoute(routeState)
          ..updateFromSnapshot(
            progressWith(segments: segments, distanceKm: 1180),
          );

        // At km 0 there is no idle for the new offset yet → empty red trace,
        // even though the record is non-empty (lower boundary of no-bleed).
        expect(mapCubit.state.idleStretches, isEmpty);
      },
    );
  });

  group('TC-333 (AC-11/AC-7) custom sub-path renders via the same trace path', () {
    test(
      'an authored sub-path produces a base polyline + an in-window red stretch '
      'through the unchanged MapCubit projection (no new path)',
      () async {
        // An authored sub-path with offset 0 and an in-window idle span.
        final route = resolve('can_tho', 'da_nang'); // 470-km sub-path
        final routeState = await routeStateFor(
          route,
          offsetKm: 0,
          cumulativeKm: 235,
        );

        final mapCubit = MapCubit(geography: geography);
        addTearDown(mapCubit.close);

        final segments = <ActivitySegment>[
          idleSegment(60, 120),
        ]; // route km 60..120
        mapCubit
          ..updateFromRoute(routeState)
          ..updateFromSnapshot(
            progressWith(segments: segments, distanceKm: 235),
          );

        // The SAME map-experience surface contract: a projected base road over
        // the sub-path's checkpoints + a current-route red stretch — no
        // route-planner-v2-specific overlay.
        expect(mapCubit.state.hasRoute, isTrue);
        expect(mapCubit.state.baseRoutePolyline.points, isNotEmpty);
        // The sub-path checkpoints (can_tho/da_lat/da_nang) are the ordered nodes.
        expect(mapCubit.state.orderedNodes.map((p) => p.id), <String>[
          'can_tho',
          'da_lat',
          'da_nang',
        ]);
        // The in-window idle span paints (the trace honours the current route).
        expect(mapCubit.state.idleStretches, isNotEmpty);
      },
    );
  });
}
