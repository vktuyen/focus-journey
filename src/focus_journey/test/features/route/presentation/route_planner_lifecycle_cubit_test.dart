// Cubit-behaviour tests for the route-planner-v2 confirm/abandon lifecycle
// (ADR-0005). Drives the REAL RouteProgressCubit via its test seam (a scripted
// cumulative `double` through updateFromDistance + an in-memory recording
// repository). No engine, no timers, no network — deterministic only.
//
// Traceability (one test ↔ one case; TC + AC ids in each description):
//   TC-317 (AC-7)  confirm stamps exactly one offset == cumulative; routeKm = 0
//   TC-318 (AC-7)  custom-route position == the UNCHANGED resolver over the
//                  authored sub-chain (no second position function)
//   TC-319 (AC-7)  single canonical-km axis: same routeDistanceKm ⇒ same position
//                  regardless of cumulative/offset (ADR-0004)
//   TC-321 (AC-8)  route % = routeDistanceKm ÷ subPathKm, capped at 100%
//   TC-322 (AC-8)  country % = routeDistanceKm ÷ totalChainKm, distinct from route %
//   TC-325 (AC-9)  NOT calling abandon (cancel) leaves offset/position untouched
//   TC-327 (AC-10) confirm abandon stamps a NEW offset == cumulative at abandon
//   TC-328 (AC-10) abandon never resets lifetime cumulative; only an offset write
//   TC-329 (AC-10) abandoned route is NOT completion (no celebration state)
//   TC-330 (AC-10/AC-7) abandon→new round-trip: new offset, preserved cumulative,
//                  position resolves via the unchanged resolver over the new list

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_planner.dart';
import 'package:focus_journey/features/route/domain/route_progress_resolver.dart';
import 'package:focus_journey/features/route/presentation/route_progress_cubit.dart';

import '../map_test_fixtures.dart' as mapfx;
import '../route_test_fixtures.dart';

void main() {
  // Fixture chain total = 1440 km. Cumulative-from-mui: 0/60/230/530/840/1440.
  late final ProvinceChain chain = buildFixtureChain();
  late final ProvinceGeography geography = mapfx.buildFixtureGeography(chain);

  ResolvedRoute resolve(String startId, String endId) => RoutePlanner.resolve(
    fullChain: chain,
    fullGeography: geography,
    start: nodeById(chain, startId),
    end: nodeById(chain, endId),
  );

  RouteProgressCubit buildCubit(RecordingRouteRepository repo) {
    final cubit = RouteProgressCubit(
      chain: chain,
      geography: geography,
      repository: repo,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  group('TC-317 (AC-7) confirm stamps exactly one offset == cumulative', () {
    test(
      'offset == cumulative at confirm; routeDistanceKm starts at 0',
      () async {
        final repo = RecordingRouteRepository();
        final cubit = buildCubit(repo);
        // A non-zero lifetime total from prior travel.
        cubit.updateFromDistance(740);

        await cubit.confirmRoute(resolve('can_tho', 'da_nang'));

        // Exactly one mutation: one plan persisted, no legacy selection write.
        expect(repo.planSaveCount, 1);
        expect(repo.saveCount, 0);
        // The stamped offset equals the cumulative at the confirm instant (740).
        expect(repo.planSaves.single.routeStartOffsetKm, closeTo(740, kTol));
        // routeDistanceKm = cumulative − offset = 0 at the confirm instant.
        expect(cubit.state.position!.routeDistanceKm, closeTo(0, kTol));
      },
    );
  });

  group(
    'TC-318 (AC-7) position == the unchanged resolver over the sub-chain',
    () {
      test(
        'cubit position equals RouteProgressResolver.resolve over the authored '
        'sub-chain for the same routeDistanceKm',
        () async {
          final repo = RecordingRouteRepository();
          final cubit = buildCubit(repo);
          cubit.updateFromDistance(0);
          final resolved = resolve('can_tho', 'da_nang'); // 470-km sub-path
          await cubit.confirmRoute(resolved);

          // Advance to 235 km of route distance (offset 0 → cumulative 235).
          cubit.updateFromDistance(235);
          final cubitPosition = cubit.state.position!;

          // Independently resolve the SAME routeDistanceKm via the UNCHANGED
          // resolver over the SAME authored sub-chain + the derived selection.
          final selection = cubit.state.selection!;
          final expected = RouteProgressResolver.resolve(
            routeDistanceKm: 235,
            selection: selection,
            chain: resolved.subChain,
          );
          // The cubit introduces NO second position function — it IS the resolver.
          expect(cubitPosition, equals(expected));
        },
      );
    },
  );

  group('TC-319 (AC-7) single canonical-km axis (ADR-0004)', () {
    test(
      'same routeDistanceKm yields the same position regardless of offset',
      () async {
        const routeKm = 235.0;
        // Run A: offset 0, cumulative = routeKm.
        final repoA = RecordingRouteRepository();
        final cubitA = buildCubit(repoA);
        cubitA.updateFromDistance(0);
        await cubitA.confirmRoute(resolve('can_tho', 'da_nang'));
        cubitA.updateFromDistance(routeKm);

        // Run B: offset 740, cumulative = routeKm + 740.
        final repoB = RecordingRouteRepository();
        final cubitB = buildCubit(repoB);
        cubitB.updateFromDistance(740);
        await cubitB.confirmRoute(resolve('can_tho', 'da_nang'));
        cubitB.updateFromDistance(routeKm + 740);

        // Identical resolved position — keyed off routeDistanceKm, never raw
        // cumulative; no parallel axis introduced.
        expect(cubitA.state.position, equals(cubitB.state.position));
        expect(
          cubitA.state.position!.routeDistanceKm,
          closeTo(cubitB.state.position!.routeDistanceKm, kTol),
        );
      },
    );
  });

  group(
    'TC-321 (AC-8) route % = routeDistanceKm ÷ subPathKm, capped at 100',
    () {
      test(
        '0% at start, 50% mid, 100% at subPathKm and on over-shoot',
        () async {
          final repo = RecordingRouteRepository();
          final cubit = buildCubit(repo);
          cubit.updateFromDistance(0);
          await cubit.confirmRoute(resolve('can_tho', 'da_nang')); // 470 km

          cubit.updateFromDistance(0);
          expect(cubit.state.position!.percentOfCountry, closeTo(0, 1e-3));

          cubit.updateFromDistance(235); // half of 470
          expect(cubit.state.position!.percentOfCountry, closeTo(50, 1e-3));

          cubit.updateFromDistance(470); // the chosen end
          expect(cubit.state.position!.percentOfCountry, closeTo(100, 1e-3));

          cubit.updateFromDistance(900); // over-shoot beyond subPathKm
          expect(
            cubit.state.position!.percentOfCountry,
            closeTo(100, 1e-3),
            reason: 'route % is capped at 100% (never exceeds — AC-8)',
          );
        },
      );
    },
  );

  group(
    'TC-322 (AC-8) country % = routeDistanceKm ÷ totalChainKm, distinct',
    () {
      test(
        'for a strict sub-path, country % < route % and both are shown',
        () async {
          final repo = RecordingRouteRepository();
          final cubit = buildCubit(repo);
          cubit.updateFromDistance(0);
          await cubit.confirmRoute(resolve('can_tho', 'da_nang')); // 470 km
          cubit.updateFromDistance(235); // half the route

          final routePercent = cubit.state.position!.percentOfCountry; // 50%
          final countryPercent = cubit.state.countryPercent!;
          // country % = (canonicalOriginKm 60 + 235) / 1440 = 295/1440 ≈ 20.49%.
          expect(countryPercent, closeTo(295 / 1440 * 100, 1e-3));
          // The two diverge for a strict sub-path (subPathKm < totalChainKm).
          expect(routePercent, closeTo(50, 1e-3));
          expect(
            countryPercent,
            lessThan(routePercent),
            reason: 'country % < route % when subPathKm < totalChainKm (AC-8)',
          );
        },
      );
    },
  );

  group('TC-325 (AC-9) not abandoning (cancel) leaves the route untouched', () {
    test(
      'a cancelled guard means abandon is never called; offset/position/writes '
      'are unchanged',
      () async {
        final repo = RecordingRouteRepository();
        final cubit = buildCubit(repo);
        cubit.updateFromDistance(0);
        await cubit.confirmRoute(resolve('can_tho', 'da_nang')); // offset 0
        cubit.updateFromDistance(200); // progress on the route

        // Snapshot the state the moment the (hypothetical) guard would show.
        final offsetBefore = cubit.state.selection!.routeStartOffsetKm;
        final positionBefore = cubit.state.position;
        final cumulativeBefore = cubit.state.cumulativeDistanceKm;
        final writesBefore = repo.planSaveCount;
        expect(cubit.hasProgressToLose, isTrue);

        // The user CANCELS the guard → the caller does nothing (abandon is never
        // invoked). Subsequent ticks keep resolving the SAME route.
        cubit.updateFromDistance(200);

        // Everything is byte-for-byte unchanged — no new offset, no extra write.
        expect(
          cubit.state.selection!.routeStartOffsetKm,
          closeTo(offsetBefore, kTol),
        );
        expect(cubit.state.position, equals(positionBefore));
        expect(
          cubit.state.cumulativeDistanceKm,
          closeTo(cumulativeBefore, kTol),
        );
        expect(repo.planSaveCount, writesBefore);
      },
    );
  });

  group('TC-327 (AC-10) confirm abandon stamps a NEW offset at the instant', () {
    test(
      'new offset == cumulative at abandon; new route restarts at km 0',
      () async {
        final repo = RecordingRouteRepository();
        final cubit = buildCubit(repo);
        cubit.updateFromDistance(0);
        await cubit.confirmRoute(resolve('can_tho', 'da_nang')); // offset 0
        cubit.updateFromDistance(1180); // travelled; now abandon at D2 = 1180

        await cubit.abandonAndStartNew(resolve('da_lat', 'ha_giang'));

        // The new route's offset is the cumulative at the abandon instant (1180).
        expect(cubit.state.selection!.routeStartOffsetKm, closeTo(1180, kTol));
        // The new route's routeDistanceKm restarts at 0 (offset-relative).
        expect(cubit.state.position!.routeDistanceKm, closeTo(0, kTol));
      },
    );
  });

  group('TC-328 (AC-10) abandon never resets lifetime cumulative', () {
    test(
      'cumulative is preserved across abandon; only an offset is written',
      () async {
        final repo = RecordingRouteRepository();
        final cubit = buildCubit(repo);
        cubit.updateFromDistance(0);
        await cubit.confirmRoute(resolve('can_tho', 'da_nang')); // 470-km route
        cubit.updateFromDistance(200); // mid-route (< 470 → not completed)
        final cumulativeBefore = cubit.state.cumulativeDistanceKm;

        await cubit.abandonAndStartNew(resolve('da_lat', 'ha_giang'));

        // Lifetime cumulative is unbroken (no engine reset API exists — AC-10).
        expect(
          cubit.state.cumulativeDistanceKm,
          closeTo(cumulativeBefore, kTol),
        );
        expect(cubit.state.cumulativeDistanceKm, closeTo(200, kTol));
        // The mutation set is offset writes only (two plans: original + new active);
        // never a cumulative mutation (the cubit holds no engine).
        expect(repo.planSaveCount, 2);
      },
    );
  });

  group('TC-329 (AC-10) abandoned route is NOT completion (no celebration)', () {
    test('after an abandon mid-way the new route is not completed', () async {
      final repo = RecordingRouteRepository();
      final cubit = buildCubit(repo);
      cubit.updateFromDistance(0);
      await cubit.confirmRoute(resolve('can_tho', 'da_nang')); // 470 km
      cubit.updateFromDistance(200); // mid-way, < 470 (not completed)

      await cubit.abandonAndStartNew(resolve('da_lat', 'ha_giang'));

      // The new route is fresh (km 0) and NOT completed — abandon ≠ completion,
      // so the arrival celebration state never fires for the abandon.
      expect(cubit.state.isCompleted, isFalse);
      expect(cubit.state.position!.routeDistanceKm, closeTo(0, kTol));
      expect(cubit.state.position!.isCompleted, isFalse);
    });
  });

  group('TC-330 (AC-10/AC-7) abandon→new-route round-trip is clean', () {
    test('offset sequence old→new, cumulative preserved, new position via the '
        'unchanged resolver over the new authored list', () async {
      final repo = RecordingRouteRepository();
      final cubit = buildCubit(repo);
      cubit.updateFromDistance(0);
      await cubit.confirmRoute(resolve('can_tho', 'da_nang')); // offset 0
      cubit.updateFromDistance(200); // mid-route (< 470 → not completed)
      await cubit.abandonAndStartNew(
        resolve('da_lat', 'ha_giang'),
      ); // offset 200

      // Offset sequence: the first plan offset 0, the new active plan offset 200.
      expect(repo.planSaves.first.routeStartOffsetKm, closeTo(0, kTol));
      expect(repo.planSaves.last.routeStartOffsetKm, closeTo(200, kTol));
      // Cumulative preserved across the round-trip.
      expect(cubit.state.cumulativeDistanceKm, closeTo(200, kTol));

      // Advance 200 km into the NEW route and verify position equals the
      // unchanged resolver over the new authored sub-chain.
      cubit.updateFromDistance(400); // 400 − 200 = 200 route km
      final newResolved = RoutePlanner.fromOrderedIds(
        fullChain: chain,
        fullGeography: geography,
        orderedNodeIds: repo.planSaves.last.orderedNodeIds,
      );
      final expected = RouteProgressResolver.resolve(
        routeDistanceKm: 200,
        selection: cubit.state.selection!,
        chain: newResolved.subChain,
      );
      expect(cubit.state.position, equals(expected));
    });
  });
}
