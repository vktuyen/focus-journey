// Cubit-tier automation for MapCubit — the pure projection of a JourneyProgress
// snapshot (segments + cumulative distance) plus the route RouteViewState
// (selection + resolved position) into a MapViewState (base polyline, marker,
// red idle stretches).
//
// No real engine, no timers, no network: snapshots and route states are
// SCRIPTED directly (per the test-case conventions). The resolver is the real
// route-progress position math (AC-5 reuse), driven by a hand-set routeDistance.
//
// Covers (cubit level):
//   AC-5   marker projected from the resolved routeDistanceKm (reused math)
//   AC-6   idle segments produce red stretches; active do not
//   AC-7   zero-idle route → empty idleStretches
//   AC-8   re-base/clip to current route; seeded (restored) selection reproduces
//   AC-12  pure projection — no route → empty/start state; re-emit on new snapshot
//   TC-NF1 holds no engine/plugin reference (true by construction)

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/activity_segment.dart';
import 'package:focus_journey/features/journey/domain/journey_progress.dart';
import 'package:focus_journey/features/journey/domain/journey_state.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_progress_resolver.dart';
import 'package:focus_journey/features/route/domain/route_selection.dart';
import 'package:focus_journey/features/route/presentation/map_cubit.dart';
import 'package:focus_journey/features/route/presentation/map_view_state.dart';
import 'package:focus_journey/features/route/presentation/route_view_state.dart';

const double kTol = 1e-6;

const Province a = Province(id: 'a', name: 'A');
const Province b = Province(id: 'b', name: 'B');
const Province c = Province(id: 'c', name: 'C');

const GeoCoordinate coordA = GeoCoordinate(latitude: 10.0, longitude: 105.0);
const GeoCoordinate coordB = GeoCoordinate(latitude: 12.0, longitude: 106.0);
const GeoCoordinate coordC = GeoCoordinate(latitude: 20.0, longitude: 104.0);

ProvinceChain _chain() => ProvinceChain(
  nodes: const <Province>[a, b, c],
  segmentsKm: const <double>[100, 100],
);

ProvinceGeography _geography(ProvinceChain chain) => ProvinceGeography(
  chain: chain,
  coordinates: const <String, GeoCoordinate>{
    'a': coordA,
    'b': coordB,
    'c': coordC,
  },
);

RouteSelection _selection(ProvinceChain chain, {double offset = 0}) =>
    RouteSelection.create(
      start: a,
      direction: JourneyDirection.towardHaGiang, // A → B → C, route length 200
      routeStartOffsetKm: offset,
      chain: chain,
    );

/// Builds a RouteViewState at a given route distance using the REAL resolver
/// (AC-5: the same math route-progress uses).
RouteViewState _routeState(
  ProvinceChain chain,
  RouteSelection selection,
  double routeDistanceKm,
) {
  final position = RouteProgressResolver.resolve(
    routeDistanceKm: routeDistanceKm,
    selection: selection,
    chain: chain,
  );
  return RouteViewState(
    selection: selection,
    position: position,
    cumulativeDistanceKm: selection.routeStartOffsetKm + routeDistanceKm,
  );
}

JourneyProgress _snapshot(List<ActivitySegment> segments) => JourneyProgress(
  distanceKm: 0,
  activeTimeToday: Duration.zero,
  rawActiveTime: Duration.zero,
  idleTimeToday: Duration.zero,
  state: JourneyState.active,
  mode: TravelMode.motorbike,
  storedDate: DateTime(2026, 6, 24),
  segments: segments,
);

ActivitySegment _idle(
  double fromKm,
  double toKm, {
  SegmentCause cause = SegmentCause.voluntary,
}) => ActivitySegment(
  fromKm: fromKm,
  toKm: toKm,
  elapsed: Duration.zero,
  classification: SegmentClassification.idle,
  cause: cause,
);

ActivitySegment _active(double fromKm, double toKm) => ActivitySegment(
  fromKm: fromKm,
  toKm: toKm,
  elapsed: Duration.zero,
  classification: SegmentClassification.active,
  cause: SegmentCause.none,
);

void main() {
  late ProvinceChain chain;
  late ProvinceGeography geography;

  setUp(() {
    chain = _chain();
    geography = _geography(chain);
  });

  group('no route selected → start/empty state (AC-12)', () {
    blocTest<MapCubit, MapViewState>(
      'snapshotAlone_withoutRoute_staysInitial',
      build: () => MapCubit(geography: geography),
      act: (cubit) => cubit.updateFromSnapshot(_snapshot(<ActivitySegment>[])),
      verify: (cubit) {
        expect(cubit.state.hasRoute, isFalse);
        expect(cubit.state.selection, isNull);
        expect(cubit.state.baseRoutePolyline.points, isEmpty);
        expect(cubit.state.idleStretches, isEmpty);
      },
    );
  });

  group('route + snapshot projection (AC-5 / AC-6)', () {
    test('markerAtMidLeg_matchesResolverDrivenProjection (AC-5)', () {
      final cubit = MapCubit(geography: geography);
      addTearDown(cubit.close);
      final selection = _selection(chain);
      cubit.updateFromRoute(_routeState(chain, selection, 150));
      cubit.updateFromSnapshot(_snapshot(<ActivitySegment>[]));

      final marker = cubit.state.markerPosition!;
      // 150 km = 50 km into B→C (fraction 0.5): lat 16, long 105.
      expect(marker.latitude, closeTo(16.0, kTol));
      expect(marker.longitude, closeTo(105.0, kTol));
      expect(cubit.state.baseRoutePolyline.points, hasLength(3));
      expect(cubit.state.orderedNodes, <Province>[a, b, c]);
    });

    test('idleSegment_producesRedStretch_activeDoesNot (AC-6)', () {
      final cubit = MapCubit(geography: geography);
      addTearDown(cubit.close);
      final selection = _selection(chain);
      cubit.updateFromRoute(_routeState(chain, selection, 200));
      cubit.updateFromSnapshot(
        _snapshot(<ActivitySegment>[_idle(25, 75), _active(75, 150)]),
      );
      expect(cubit.state.idleStretches, hasLength(1));
      expect(cubit.state.idleStretches.single.cause, SegmentCause.voluntary);
    });

    test('zeroIdleRoute_emitsNoRedStretches (AC-7)', () {
      final cubit = MapCubit(geography: geography);
      addTearDown(cubit.close);
      final selection = _selection(chain);
      cubit.updateFromRoute(_routeState(chain, selection, 200));
      cubit.updateFromSnapshot(_snapshot(<ActivitySegment>[_active(0, 200)]));
      expect(cubit.state.idleStretches, isEmpty);
      // Base road + marker still present.
      expect(cubit.state.baseRoutePolyline.points, hasLength(3));
      expect(cubit.state.markerPosition, isNotNull);
    });
  });

  group('current route only — offset re-base (AC-8)', () {
    test('idleKeyedToAbsoluteKm_isReBasedByOffset', () {
      // offset 1000, absolute idle [1025, 1075] → route km [25, 75].
      final cubit = MapCubit(geography: geography);
      addTearDown(cubit.close);
      final selection = _selection(chain, offset: 1000);
      cubit.updateFromRoute(_routeState(chain, selection, 200));
      cubit.updateFromSnapshot(_snapshot(<ActivitySegment>[_idle(1025, 1075)]));
      expect(cubit.state.idleStretches, hasLength(1));
      // First red point at route km 25 (A→B fraction 0.25): lat 10.5.
      final first = cubit.state.idleStretches.single.polyline.points.first;
      expect(first.latitude, closeTo(10.5, kTol));
    });

    test('idleFromAPriorRoute_isExcluded', () {
      final cubit = MapCubit(geography: geography);
      addTearDown(cubit.close);
      final selection = _selection(chain, offset: 1000);
      cubit.updateFromRoute(_routeState(chain, selection, 200));
      // Absolute [500, 600] is before the route window [1000, 1200].
      cubit.updateFromSnapshot(_snapshot(<ActivitySegment>[_idle(500, 600)]));
      expect(cubit.state.idleStretches, isEmpty);
    });
  });

  group('re-emits on a new snapshot (AC-12)', () {
    test('feedingNewSegments_updatesIdleStretches', () {
      final cubit = MapCubit(geography: geography);
      addTearDown(cubit.close);
      final selection = _selection(chain);
      cubit.updateFromRoute(_routeState(chain, selection, 200));

      cubit.updateFromSnapshot(_snapshot(<ActivitySegment>[]));
      expect(cubit.state.idleStretches, isEmpty);

      cubit.updateFromSnapshot(
        _snapshot(<ActivitySegment>[_idle(25, 75), _idle(120, 160)]),
      );
      expect(cubit.state.idleStretches, hasLength(2));
    });
  });

  group('seeded (restored) selection reproduces the trace (AC-8 restart)', () {
    test('initialSelectionPlusSnapshot_reproducesSameStateAsLiveWiring', () {
      final selection = _selection(chain);
      // Seeded cubit (restore path).
      final seeded = MapCubit(
        geography: geography,
        initialSelection: selection,
      );
      addTearDown(seeded.close);
      seeded.updateFromRoute(_routeState(chain, selection, 150));
      seeded.updateFromSnapshot(_snapshot(<ActivitySegment>[_idle(25, 75)]));

      // Live cubit reaching the same inputs without seeding.
      final live = MapCubit(geography: geography);
      addTearDown(live.close);
      live.updateFromRoute(_routeState(chain, selection, 150));
      live.updateFromSnapshot(_snapshot(<ActivitySegment>[_idle(25, 75)]));

      expect(seeded.state, equals(live.state));
      expect(seeded.state.idleStretches, equals(live.state.idleStretches));
      expect(seeded.state.markerPosition, equals(live.state.markerPosition));
    });
  });

  group('NFR-1 / TC-229 — projector cached; no needless geometry recompute', () {
    // The cubit caches the RoutePolylineProjector keyed on route identity
    // (start / direction / offset) and invalidates it only when that identity
    // changes — NOT on a bare cumulative-distance tick. The projector instance
    // is private and the emitted baseRoutePolyline is freshly wrapped per emit,
    // so projector instance identity is NOT observable through the public API.
    // The honest, observable seam is the emitted MapViewState's VALUE-equality
    // (mirrors route-progress TC-NF2 "static geometry not reallocated per
    // frame"): a bare distance tick must leave the static base polyline /
    // ordered nodes / idle layers value-equal so a BlocBuilder suppresses the
    // rebuild, while a route/selection change MUST change the base polyline so
    // the cache is correct, not merely sticky.

    test('bareDistanceTick_sameRoute_baseGeometryAndIdleLayersValueEqual '
        '(NFR-1 / TC-229)', () {
      final cubit = MapCubit(geography: geography);
      addTearDown(cubit.close);
      final selection = _selection(chain);
      // Stable idle set for the whole life of this route.
      final segments = <ActivitySegment>[_idle(25, 75)];

      cubit.updateFromRoute(_routeState(chain, selection, 100));
      cubit.updateFromSnapshot(_snapshot(segments));
      final first = cubit.state;

      // A bare cumulative-distance tick: SAME selection, SAME segments, the
      // marker moves along the SAME route (100 km → 140 km).
      cubit.updateFromRoute(_routeState(chain, selection, 140));
      final second = cubit.state;

      // Static base geometry is not re-derived into anything different — the
      // projector was reused, so the base road + pins are value-equal.
      expect(second.baseRoutePolyline, equals(first.baseRoutePolyline));
      expect(second.orderedNodes, equals(first.orderedNodes));
      // The red idle layers are unchanged too — only the marker advanced.
      expect(second.idleStretches, equals(first.idleStretches));
      // The marker DID advance along the route (the tick was real, not a
      // no-op — keeps this from being a tautology).
      expect(second.markerPosition, isNot(equals(first.markerPosition)));
    });

    test(
      'bareDistanceTick_markerUnchanged_emitsValueEqualState_blocBuilderSkips '
      '(NFR-1 / TC-229)',
      () {
        final cubit = MapCubit(geography: geography);
        addTearDown(cubit.close);
        final selection = _selection(chain); // route length 200
        final segments = <ActivitySegment>[_idle(25, 75)];

        // Two ticks past the destination: both clamp to the destination pin, so
        // the marker coordinate is identical even though cumulative distance
        // differs. Geometry + marker + idle all unchanged → the whole
        // MapViewState is value-equal, so Cubit.emit is a no-op and a
        // BlocBuilder rebuilds nothing.
        cubit.updateFromRoute(_routeState(chain, selection, 300));
        cubit.updateFromSnapshot(_snapshot(segments));
        final stateChanges = <MapViewState>[];
        final sub = cubit.stream.listen(stateChanges.add);
        addTearDown(sub.cancel);
        final before = cubit.state;

        cubit.updateFromRoute(_routeState(chain, selection, 400));

        // Cubit suppresses an equal emit, so a BlocBuilder never rebuilds.
        expect(cubit.state, equals(before));
        expect(stateChanges, isEmpty);
      },
    );

    test('routeIdentityChange_rebuildsProjector_baseGeometryChanges '
        '(NFR-1 / TC-229)', () {
      final cubit = MapCubit(geography: geography);
      addTearDown(cubit.close);
      final fromA = _selection(chain); // A → B → C, 3 nodes, length 200
      cubit.updateFromRoute(_routeState(chain, fromA, 100));
      cubit.updateFromSnapshot(_snapshot(<ActivitySegment>[_idle(25, 75)]));
      final routeA = cubit.state;

      // Selection CHANGE: start at B instead of A (B → C, 2 nodes, length
      // 100) — a different route identity. The cache MUST invalidate.
      final fromB = RouteSelection.create(
        start: b,
        direction: JourneyDirection.towardHaGiang,
        routeStartOffsetKm: 0,
        chain: chain,
      );
      cubit.updateFromRoute(_routeState(chain, fromB, 50));
      cubit.updateFromSnapshot(_snapshot(<ActivitySegment>[]));
      final routeB = cubit.state;

      // The projector was rebuilt: the base road + pins genuinely changed
      // (3-node A→B→C road vs 2-node B→C road) — the cache is correct, not
      // sticky.
      expect(routeB.baseRoutePolyline, isNot(equals(routeA.baseRoutePolyline)));
      expect(routeB.orderedNodes, isNot(equals(routeA.orderedNodes)));
      expect(routeB.orderedNodes, <Province>[b, c]);
      expect(routeB.baseRoutePolyline.points, hasLength(2));
    });
  });

  group('completion state passthrough (AC-10)', () {
    test('routeAtDestination_markerOnDestinationPin_isCompleted', () {
      final cubit = MapCubit(geography: geography);
      addTearDown(cubit.close);
      final selection = _selection(chain);
      cubit.updateFromRoute(_routeState(chain, selection, 200));
      cubit.updateFromSnapshot(_snapshot(<ActivitySegment>[]));
      final marker = cubit.state.markerPosition!;
      expect(marker.latitude, closeTo(coordC.latitude, kTol));
      expect(marker.longitude, closeTo(coordC.longitude, kTol));
      expect(cubit.state.isCompleted, isTrue);
    });

    test('routeAtStart_markerOnOriginPin_noRed (AC-10)', () {
      final cubit = MapCubit(geography: geography);
      addTearDown(cubit.close);
      final selection = _selection(chain);
      cubit.updateFromRoute(_routeState(chain, selection, 0));
      cubit.updateFromSnapshot(_snapshot(<ActivitySegment>[]));
      final marker = cubit.state.markerPosition!;
      expect(marker.latitude, closeTo(coordA.latitude, kTol));
      expect(marker.longitude, closeTo(coordA.longitude, kTol));
      expect(cubit.state.idleStretches, isEmpty);
    });
  });

  group('route-real-road — emphasized ids + smoothed road', () {
    RouteViewState routeStateWithStops(
      double routeDistanceKm,
      List<String> markedStopIds,
    ) {
      final selection = _selection(chain);
      final position = RouteProgressResolver.resolve(
        routeDistanceKm: routeDistanceKm,
        selection: selection,
        chain: chain,
      );
      return RouteViewState(
        selection: selection,
        position: position,
        cumulativeDistanceKm: routeDistanceKm,
        markedStopIds: markedStopIds,
      );
    }

    test('default full-spine route emphasizes ONLY start + end (AC-3)', () {
      final cubit = MapCubit(geography: geography);
      addTearDown(cubit.close);
      cubit.updateFromRoute(routeStateWithStops(100, const <String>[]));
      // A → B → C: only the endpoints are big; B is pass-through.
      expect(cubit.state.emphasizedNodeIds, <String>{'a', 'c'});
    });

    test('a user-marked stop is added to the emphasized set (AC-4)', () {
      final cubit = MapCubit(geography: geography);
      addTearDown(cubit.close);
      cubit.updateFromRoute(routeStateWithStops(100, const <String>['b']));
      expect(cubit.state.emphasizedNodeIds, <String>{'a', 'b', 'c'});
    });

    test('the road is smoothed to more vertices than the checkpoints (AC-1)', () {
      final cubit = MapCubit(geography: geography);
      addTearDown(cubit.close);
      cubit.updateFromRoute(routeStateWithStops(100, const <String>[]));
      final smoothed = cubit.state.smoothedRoutePolyline.points;
      expect(smoothed.length, greaterThan(cubit.state.orderedNodes.length));
    });

    test('the smoothed road + emphasized ids are cached across a tick (NFR-1)', () {
      final cubit = MapCubit(geography: geography);
      addTearDown(cubit.close);
      cubit.updateFromRoute(routeStateWithStops(50, const <String>['b']));
      final firstSmoothed = cubit.state.smoothedRoutePolyline;
      final firstEmphasized = cubit.state.emphasizedNodeIds;
      // A mere distance tick (same route identity) must reuse the cached geometry.
      cubit.updateFromSnapshot(_snapshot(<ActivitySegment>[]));
      cubit.updateFromRoute(routeStateWithStops(120, const <String>['b']));
      expect(
        identical(cubit.state.smoothedRoutePolyline, firstSmoothed),
        isTrue,
      );
      expect(identical(cubit.state.emphasizedNodeIds, firstEmphasized), isTrue);
    });
  });
}
