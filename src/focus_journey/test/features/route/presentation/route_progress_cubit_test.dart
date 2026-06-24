// Bloc/cubit (widget-test tier) automation for route-progress.
//
// Scope: RouteProgressCubit's WIRING of the pure resolver into emitted
// RouteViewState snapshots, driven by a SCRIPTED scalar via updateFromDistance
// (and startNewRoute for the offset cases). No real engine, no timers, no
// wall-clock — every distance is set directly (per the test-case conventions).
// The pure position math itself is covered by the parallel unit-test-writer's
// resolver suite; here we assert the cubit threads cumulative − offset through
// the resolver and emits the right view-state per case.
//
// Covers (cubit level):
//   TC-001  mid-chain passed/next/distance-to-next/segment/%
//   TC-002  distance 0 → origin only, in-progress
//   TC-003  exactly on a checkpoint → reached counts as passed, next advances
//   TC-004  just before a checkpoint
//   TC-005  just after a checkpoint
//   TC-006  monotonic advance over an increasing sequence
//   TC-007  south is the mirror of north from the same start
//   TC-008  direction sets destination tip; % = full-chain denominator
//   TC-011  reaching the chain end → completed + % capped at 100%
//   TC-012  completion retains progress, clamps to destination, no rollback
//   TC-013  no auto-advance — continued distance makes no forward progress
//   TC-014  new start captures the offset; route restarts at 0; engine never reset
//   TC-014b identical outputs under a non-zero offset
//
// Conventions mirror test/features/journey/presentation/journey_cubit_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/route_selection.dart';
import 'package:focus_journey/features/route/presentation/route_progress_cubit.dart';

import '../route_test_fixtures.dart';

void main() {
  late ProvinceChain chain;
  late RecordingRouteRepository repo;

  setUp(() {
    chain = buildFixtureChain();
    repo = RecordingRouteRepository();
  });

  /// Builds a cubit pre-seeded with a [RouteSelection] so updateFromDistance
  /// resolves immediately (mirrors main.dart's restore path; offset defaults 0).
  RouteProgressCubit cubitFor(
    String startId,
    JourneyDirection direction, {
    double offset = 0,
    bool completed = false,
  }) {
    final initial = RouteSelection.create(
      start: nodeById(chain, startId),
      direction: direction,
      routeStartOffsetKm: offset,
      chain: chain,
      completed: completed,
    );
    final cubit = RouteProgressCubit(
      chain: chain,
      repository: repo,
      initialSelection: initial,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  group('TC-001 mid-chain position (Cần Thơ north @ routeDistanceKm 400)', () {
    test('emits passed/next/distance-to-next/segment/% per the fixture', () {
      final cubit = cubitFor('can_tho', JourneyDirection.towardHaGiang);
      cubit.updateFromDistance(400);
      final pos = cubit.state.position!;

      expect(pos.passed.map((p) => p.id), <String>['can_tho', 'da_lat']);
      expect(pos.next!.id, 'da_nang');
      expect(pos.distanceToNextKm, closeTo(70, kTol)); // 470 − 400
      expect(pos.currentSegmentFrom.id, 'da_lat');
      expect(pos.currentSegmentTo.id, 'da_nang');
      expect(pos.percentOfCountry, closeTo(400 / 1440 * 100, 1e-3)); // ≈ 27.8%
      expect(cubit.state.isCompleted, isFalse);
    });
  });

  group('TC-002 distance 0 at the start', () {
    test('origin only passed, in-progress, marker on start pin', () {
      final cubit = cubitFor('can_tho', JourneyDirection.towardHaGiang);
      cubit.updateFromDistance(0);
      final pos = cubit.state.position!;

      expect(pos.passed.map((p) => p.id), <String>['can_tho']);
      expect(pos.next!.id, 'da_lat');
      expect(pos.distanceToNextKm, closeTo(170, kTol)); // first segment length
      expect(pos.currentSegmentFrom.id, 'can_tho');
      expect(pos.currentSegmentTo.id, 'da_lat');
      expect(pos.percentOfCountry, 0);
      expect(cubit.state.isCompleted, isFalse);
      // Marker sits exactly on the start pin (fraction 0 → centers.first).
      expect(pos.fractionAlongRoute, closeTo(0, kTol));
    });
  });

  group('TC-003 distance exactly on a checkpoint (170 → Đà Lạt)', () {
    test('reached counts as passed, next advances, deterministic', () {
      final cubit = cubitFor('can_tho', JourneyDirection.towardHaGiang);
      cubit.updateFromDistance(170);
      final pos = cubit.state.position!;

      expect(pos.passed.map((p) => p.id), contains('da_lat'));
      expect(pos.next!.id, 'da_nang');
      expect(pos.distanceToNextKm, closeTo(300, kTol)); // full next segment
      expect(pos.currentSegmentFrom.id, 'da_lat');
      expect(pos.currentSegmentTo.id, 'da_nang');

      // Determinism at the boundary: re-feeding the same value emits an equal
      // (Equatable-suppressed) state with identical fields — no flicker.
      cubit.updateFromDistance(170);
      expect(cubit.state.position, equals(pos));
    });
  });

  group('TC-004 just before a checkpoint (169, 1 km short of Đà Lạt)', () {
    test('not yet passed, distance-to-next is the small remainder', () {
      final cubit = cubitFor('can_tho', JourneyDirection.towardHaGiang);
      cubit.updateFromDistance(169);
      final pos = cubit.state.position!;

      expect(pos.passed.map((p) => p.id), isNot(contains('da_lat')));
      expect(pos.next!.id, 'da_lat');
      expect(pos.distanceToNextKm, closeTo(1, kTol));
      expect(pos.currentSegmentFrom.id, 'can_tho');
      expect(pos.currentSegmentTo.id, 'da_lat');
      expect(pos.percentOfCountry, closeTo(169 / 1440 * 100, 1e-3)); // ≈ 11.7%
    });
  });

  group('TC-005 just after a checkpoint (171, 1 km past Đà Lạt)', () {
    test('passed, next is the following checkpoint, remainder applied', () {
      final cubit = cubitFor('can_tho', JourneyDirection.towardHaGiang);
      cubit.updateFromDistance(171);
      final pos = cubit.state.position!;

      expect(pos.passed.map((p) => p.id), contains('da_lat'));
      expect(pos.next!.id, 'da_nang');
      expect(pos.distanceToNextKm, closeTo(299, kTol)); // 300 − 1 already in
      expect(pos.currentSegmentFrom.id, 'da_lat');
      expect(pos.currentSegmentTo.id, 'da_nang');
    });
  });

  group('TC-006 monotonic advance over an increasing sequence', () {
    test('passed-count, % and marker fraction are all non-decreasing', () {
      final cubit = cubitFor('can_tho', JourneyDirection.towardHaGiang);
      const sequence = <double>[0, 60, 169, 170, 171, 400, 1000, 1380, 1500];

      var lastPassedCount = -1;
      var lastPercent = -1.0;
      var lastFraction = -1.0;
      for (final d in sequence) {
        cubit.updateFromDistance(d);
        final pos = cubit.state.position!;
        expect(
          pos.passed.length,
          greaterThanOrEqualTo(lastPassedCount),
          reason: 'passed count must not regress at d=$d',
        );
        expect(
          pos.percentOfCountry,
          greaterThanOrEqualTo(lastPercent - kTol),
          reason: '% must not regress at d=$d',
        );
        expect(
          pos.fractionAlongRoute,
          greaterThanOrEqualTo(lastFraction - kTol),
          reason: 'marker fraction must not regress at d=$d',
        );
        lastPassedCount = pos.passed.length;
        lastPercent = pos.percentOfCountry;
        lastFraction = pos.fractionAlongRoute;
      }
    });
  });

  group('TC-007 south is the mirror of north from the same start', () {
    test('south from Đà Nẵng @ 300 walks the chain in opposite order', () {
      final south = cubitFor('da_nang', JourneyDirection.towardMuiCaMau);
      south.updateFromDistance(300);
      final s = south.state.position!;
      expect(s.passed.map((p) => p.id), <String>['da_nang', 'da_lat']);
      expect(s.next!.id, 'can_tho');
      expect(s.distanceToNextKm, closeTo(170, kTol));
      expect(s.currentSegmentFrom.id, 'da_lat');
      expect(s.currentSegmentTo.id, 'can_tho');
      expect(s.destination.id, 'mui');

      // North from the same start + distance: the mirror result. Đà Nẵng→Hà Nội
      // is 310 km, so 300 km north lands 10 km short of Hà Nội ⇒ Hà Nội is the
      // next checkpoint (structural; the old AC-7 prose pre-dated the corrected
      // fixture). The destination tip is Hà Giang regardless.
      final north = cubitFor('da_nang', JourneyDirection.towardHaGiang);
      north.updateFromDistance(300);
      final n = north.state.position!;
      expect(n.passed.map((p) => p.id), <String>['da_nang']);
      expect(n.next!.id, 'ha_noi');
      expect(n.distanceToNextKm, closeTo(10, kTol));
      expect(n.destination.id, 'ha_giang');

      // Only the traversal direction differs — same distance, mirrored walk.
      expect(s.routeDistanceKm, closeTo(n.routeDistanceKm, kTol));
    });
  });

  group('TC-008 direction sets destination tip; % = full-chain denom', () {
    test('north → Hà Giang, south → Mũi Cà Mau, both % over total 1440', () {
      final north = cubitFor('da_lat', JourneyDirection.towardHaGiang);
      north.updateFromDistance(200);
      final south = cubitFor('da_lat', JourneyDirection.towardMuiCaMau);
      south.updateFromDistance(200);

      expect(north.state.position!.destination.id, 'ha_giang');
      expect(south.state.position!.destination.id, 'mui');
      // Full-chain denominator (1440), NOT the chosen-direction span.
      expect(
        north.state.position!.percentOfCountry,
        closeTo(200 / 1440 * 100, 1e-3),
      );
      expect(
        south.state.position!.percentOfCountry,
        closeTo(200 / 1440 * 100, 1e-3),
      );
    });
  });

  group('TC-011 reaching the chain end → completed + % capped at 100%', () {
    // NOTE: % is distance-based against the FULL chain (locked decision 3 /
    // AC-8): routeDistanceKm ÷ totalChainKm, capped at 100. A route that reaches
    // the destination tip reports 100% ONLY when it covered the whole chain
    // (a tip-to-tip route). A MID-CHAIN start (e.g. Cần Thơ, 60 km from the
    // south tip) structurally maxes at < 100% on completion — its routeDistance
    // at the destination is 1380 of the 1440-km chain ⇒ 95.8%. AC-11's literal
    // "100% for Cần Thơ→Hà Giang" is illustrative prose; we assert the
    // STRUCTURAL ratio (and verify the true-100% on a tip-to-tip route below).
    // See the run report's "production issue" note.
    test('mid-chain completion: capped ratio, completed, no next, marker at end', () {
      final start = nodeById(chain, 'can_tho');
      final dest = chain.distanceToDestination(
        start,
        JourneyDirection.towardHaGiang,
      ); // structural = 1380

      final atEnd = cubitFor('can_tho', JourneyDirection.towardHaGiang);
      atEnd.updateFromDistance(dest);
      expect(atEnd.state.isCompleted, isTrue);
      expect(atEnd.state.position!.destination.id, 'ha_giang');
      expect(atEnd.state.position!.next, isNull);
      expect(atEnd.state.position!.fractionAlongRoute, closeTo(1, kTol));
      // Structural %: covered ÷ full chain, capped at 100.
      expect(
        atEnd.state.position!.percentOfCountry,
        closeTo((dest / 1440 * 100).clamp(0, 100), 1e-3),
      );

      // Well beyond the threshold — completion is TERMINAL (AC-13): every output
      // is FROZEN at the arrival value, not just the marker. The % does NOT
      // drift upward toward 100 over the [dest, totalChainKm] band; it stays at
      // the honest mid-chain arrival % (Kevin's ratified fix; was a low-severity
      // drift bug — completion now clamps the % and the path, not only the pin).
      final beyond = cubitFor('can_tho', JourneyDirection.towardHaGiang);
      beyond.updateFromDistance(dest + 500);
      expect(beyond.state.position!.percentOfCountry, lessThanOrEqualTo(100));
      expect(beyond.state.position!.fractionAlongRoute, closeTo(1, kTol));
      expect(beyond.state.position!.next, isNull);
      // FROZEN, not merely non-decreasing — equal to the at-arrival %.
      expect(
        beyond.state.position!.percentOfCountry,
        closeTo(atEnd.state.position!.percentOfCountry, kTol),
      );
    });

    test('tip-to-tip completion reports exactly 100% (% cap is reachable)', () {
      // From the south tip the route covers the entire chain ⇒ 100% at the end.
      final cubit = cubitFor('mui', JourneyDirection.towardHaGiang);
      final dest = chain.distanceToDestination(
        nodeById(chain, 'mui'),
        JourneyDirection.towardHaGiang,
      ); // == totalChainKm == 1440
      cubit.updateFromDistance(dest);
      expect(cubit.state.isCompleted, isTrue);
      expect(cubit.state.position!.percentOfCountry, closeTo(100, 1e-3));
      // Over the cap stays exactly 100% (never > 100%).
      cubit.updateFromDistance(dest + 1000);
      expect(cubit.state.position!.percentOfCountry, closeTo(100, 1e-3));
    });
  });

  group('TC-012 completion retains progress, clamps marker, no rollback', () {
    test('marker clamps to destination and engine is never written', () {
      final start = nodeById(chain, 'can_tho');
      final dest = chain.distanceToDestination(
        start,
        JourneyDirection.towardHaGiang,
      );
      final cubit = cubitFor('can_tho', JourneyDirection.towardHaGiang);

      cubit.updateFromDistance(dest); // arrive
      final atDest = cubit.state.position!;
      cubit.updateFromDistance(dest + 999); // overshoot
      final beyond = cubit.state.position!;

      // Displayed marker (the load-bearing AC-12 claim) is CLAMPED to the
      // destination pin and never overshoots, even though the raw cumulative
      // keeps climbing.
      expect(beyond.fractionAlongRoute, closeTo(1, kTol));
      expect(beyond.routeDistanceKm, closeTo(dest, kTol));
      // % is distance-based on the FULL chain and capped at 100. Completion is
      // TERMINAL (AC-13): once arrived, the % is FROZEN at the arrival value —
      // for a MID-CHAIN start it stays at the honest < 100 ratio and does NOT
      // drift toward 100 over the [dest, totalChainKm] band (the completion
      // clamp now freezes the % and path, not only the displayed marker).
      expect(beyond.percentOfCountry, lessThanOrEqualTo(100));
      expect(beyond.percentOfCountry, closeTo(atDest.percentOfCountry, kTol));
      // No backward movement for a forward distance change.
      expect(
        beyond.fractionAlongRoute,
        greaterThanOrEqualTo(atDest.fractionAlongRoute - kTol),
      );
      // Cumulative is read, not zeroed — the cubit still tracks the raw value.
      expect(cubit.state.cumulativeDistanceKm, closeTo(dest + 999, kTol));
      // The repository (proxy for engine state) saw only the completion latch
      // — no reset/zero write originates from feeding more distance.
      expect(
        repo.saves.every((s) => s.start.id == 'can_tho' && s.completed),
        isTrue,
        reason: 'only the completed selection is persisted, never a reset',
      );
    });
  });

  group('TC-013 no auto-advance — continued distance makes no progress', () {
    test('state is unchanged across several increasing post-arrival values', () {
      final start = nodeById(chain, 'can_tho');
      final dest = chain.distanceToDestination(
        start,
        JourneyDirection.towardHaGiang,
      );
      final cubit = cubitFor('can_tho', JourneyDirection.towardHaGiang);

      cubit.updateFromDistance(dest);
      final completed = cubit.state.position!;
      final selectionAfterArrival = cubit.state.selection!;

      for (final d in <double>[dest + 50, dest + 500, dest + 5000]) {
        cubit.updateFromDistance(d);
        final pos = cubit.state.position!;
        // No forward CHAIN progress: same passed list, same destination, no new
        // "next", marker still clamped to the destination pin — terminal until
        // an explicit start. (% is capped at 100 and non-decreasing — it does
        // not constitute chain progress; the marker/passed/next are frozen.)
        expect(pos.passed.map((p) => p.id), completed.passed.map((p) => p.id));
        expect(pos.next, isNull);
        expect(pos.destination.id, completed.destination.id);
        expect(pos.fractionAlongRoute, closeTo(1, kTol));
        expect(pos.percentOfCountry, lessThanOrEqualTo(100));
        // Did NOT start a new route or flip direction on its own.
        expect(cubit.state.selection!.start.id, selectionAfterArrival.start.id);
        expect(
          cubit.state.selection!.direction,
          selectionAfterArrival.direction,
        );
      }
    });
  });

  group('TC-014 new start captures the offset; route restarts at 0', () {
    test(
      'offset == cumulative at new-start; routeDistanceKm 0; no engine write',
      () async {
        // No initial selection: a fresh cubit, cumulative climbing to 1500.
        final cubit = RouteProgressCubit(chain: chain, repository: repo);
        addTearDown(cubit.close);
        cubit.updateFromDistance(1500); // engine lifetime total keeps climbing

        await cubit.startNewRoute(
          nodeById(chain, 'can_tho'),
          JourneyDirection.towardHaGiang,
        );

        // (a) offset captured == cumulative at the moment of the new start.
        expect(cubit.state.selection!.routeStartOffsetKm, closeTo(1500, kTol));
        // (b) the new route resolves at routeDistanceKm == 0 (start-only state).
        final pos = cubit.state.position!;
        expect(pos.routeDistanceKm, closeTo(0, kTol));
        expect(pos.passed.map((p) => p.id), <String>['can_tho']);
        expect(pos.percentOfCountry, 0);
        expect(cubit.state.isCompleted, isFalse);
        // (c) the recording repo observed only a selection write — no reset, no
        // engine-state write (the cubit holds no engine ref by construction).
        expect(repo.saveCount, 1);
        expect(repo.saves.single.routeStartOffsetKm, closeTo(1500, kTol));
        // Cumulative is preserved (read, not reset).
        expect(cubit.state.cumulativeDistanceKm, closeTo(1500, kTol));
      },
    );

    test('first route offset is the cumulative at first start (0)', () async {
      final cubit = RouteProgressCubit(chain: chain, repository: repo);
      addTearDown(cubit.close);
      // No distance seen yet → first start captures 0.
      await cubit.startNewRoute(
        nodeById(chain, 'can_tho'),
        JourneyDirection.towardHaGiang,
      );
      expect(cubit.state.selection!.routeStartOffsetKm, closeTo(0, kTol));
    });
  });

  group('TC-014b identical outputs under a non-zero offset', () {
    test(
      'same routeDistanceKm (400) → identical position regardless of offset',
      () {
        // Run A: offset 0, cumulative 400 → routeDistanceKm 400.
        final a = cubitFor('can_tho', JourneyDirection.towardHaGiang);
        a.updateFromDistance(400);

        // Run B: offset 1100, cumulative 1500 → routeDistanceKm 400.
        final b = cubitFor(
          'can_tho',
          JourneyDirection.towardHaGiang,
          offset: 1100,
        );
        b.updateFromDistance(1500);

        // Identical resolved position — position math keys off cumulative − offset,
        // never raw cumulative (guards the % and the walk).
        expect(a.state.position, equals(b.state.position));
      },
    );
  });
}
