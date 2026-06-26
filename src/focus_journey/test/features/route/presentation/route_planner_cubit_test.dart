// Smoke tests for the route-planner-v2 cubit behaviour (ADR-0005): confirmRoute
// stamps one offset + persists a plan + resolves over the SUB-CHAIN (AC-6/AC-7),
// country % is computed over the full chain (AC-8), and abandonAndStartNew stamps
// a NEW offset without resetting cumulative (AC-10). No engine, no timers.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/route_planner.dart';
import 'package:focus_journey/features/route/presentation/route_progress_cubit.dart';

import '../map_test_fixtures.dart' as mapfx;
import '../route_test_fixtures.dart';

void main() {
  // Fixture chain total = 1440 km. can_tho cumulative-from-mui = 60.
  late final chain = buildFixtureChain();
  late final geography = mapfx.buildFixtureGeography(chain);

  ResolvedRoute canThoToDaNang() => RoutePlanner.resolve(
    fullChain: chain,
    fullGeography: geography,
    start: nodeById(chain, 'can_tho'),
    end: nodeById(chain, 'da_nang'),
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

  group('confirmRoute (AC-6/AC-7)', () {
    test(
      'stamps one offset, persists a plan, resolves over the sub-chain',
      () async {
        final repo = RecordingRouteRepository();
        final cubit = buildCubit(repo);
        cubit.updateFromDistance(1500); // engine lifetime keeps climbing.

        await cubit.confirmRoute(canThoToDaNang());

        // Exactly one plan persisted; no legacy selection write.
        expect(repo.planSaveCount, 1);
        expect(repo.saveCount, 0);
        expect(repo.planSaves.single.routeStartOffsetKm, closeTo(1500, kTol));
        // Resolves over the sub-chain (route length 470 = 170 + 300).
        final pos = cubit.state.position!;
        expect(pos.routeDistanceKm, closeTo(0, kTol));
        expect(pos.distanceToDestinationKm, closeTo(470, kTol));
        // The view state carries the sub-geography (so the map projects the
        // sub-path — AC-7).
        expect(cubit.state.subGeography, isNotNull);
      },
    );
  });

  group('country % over the full chain (AC-8)', () {
    test(
      'route % uses subPathKm; country % uses the full 1440-km chain',
      () async {
        final repo = RecordingRouteRepository();
        final cubit = buildCubit(repo);
        cubit.updateFromDistance(0);
        await cubit.confirmRoute(canThoToDaNang()); // offset 0.

        // Advance 235 km into the route (half of the 470 sub-path).
        cubit.updateFromDistance(235);
        final pos = cubit.state.position!;
        // Route %: 235 / 470 = 50% (resolver's percentOfCountry over the sub-chain).
        expect(pos.percentOfCountry, closeTo(50, 1e-3));
        // Country %: (canonicalOriginKm 60 + 235) / 1440 = 295/1440 ≈ 20.49%.
        expect(cubit.state.countryPercent, closeTo(295 / 1440 * 100, 1e-3));
      },
    );
  });

  group('abandonAndStartNew (AC-9/AC-10)', () {
    test('stamps a NEW offset, never resets cumulative, no completion', () async {
      final repo = RecordingRouteRepository();
      final cubit = buildCubit(repo);
      cubit.updateFromDistance(0);
      await cubit.confirmRoute(canThoToDaNang()); // offset 0.
      cubit.updateFromDistance(200); // progress on the first route.
      expect(cubit.hasProgressToLose, isTrue);

      // Abandon at cumulative 200 → a fresh da_lat→ha_giang route.
      final fresh = RoutePlanner.resolve(
        fullChain: chain,
        fullGeography: geography,
        start: nodeById(chain, 'da_lat'),
        end: nodeById(chain, 'ha_giang'),
      );
      await cubit.abandonAndStartNew(fresh);

      // New offset == cumulative at the abandon instant (200); cumulative kept.
      expect(cubit.state.selection!.routeStartOffsetKm, closeTo(200, kTol));
      expect(cubit.state.cumulativeDistanceKm, closeTo(200, kTol));
      // The new route restarts at routeDistanceKm 0; NOT completed (abandon ≠
      // completion — no celebration fires).
      expect(cubit.state.position!.routeDistanceKm, closeTo(0, kTol));
      expect(cubit.state.isCompleted, isFalse);
      // Two plans persisted (the original + the new active one).
      expect(repo.planSaveCount, 2);
    });
  });
}
