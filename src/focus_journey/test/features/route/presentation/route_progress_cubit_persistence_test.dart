// Complementary cubit unit tests for the persistence / completion-latch / guard
// behaviours not exercised by route_progress_cubit_test.dart (which covers the
// position-math wiring TC-001..TC-014b). Here we pin:
//   - completion is latched into the persisted selection exactly once (AC-10);
//   - a restored completed selection stays completed and never auto-advances
//     (AC-10 / AC-13);
//   - a restored in-progress selection is honoured, not silently reset (AC-9);
//   - startNewRoute rejects an off-direction tip pair and commits nothing
//     (AC-15 cubit leg);
//   - the cubit holds NO engine reference and never writes engine state — its
//     only write path is the repository selection save (AC-16/AC-17).
//
// No real engine, no timers, no wall-clock — distance is set directly. Reuses
// the shared RecordingRouteRepository / fixture chain from route_test_fixtures.

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

  group('RouteProgressCubit — completion latch persistence (AC-10/AC-13)', () {
    test('reachingDestination_persistsCompletedSelectionExactlyOnce', () async {
      final cubit = RouteProgressCubit(chain: chain, repository: repo);
      addTearDown(cubit.close);
      await cubit.startNewRoute(
        nodeById(chain, 'can_tho'),
        JourneyDirection.towardHaGiang,
        currentCumulativeKm: 0,
      );
      final savesAfterStart = repo.saveCount;

      // Cần Thơ → Hà Giang = 1380 km. Reach it, then overshoot repeatedly.
      cubit.updateFromDistance(1380);
      cubit.updateFromDistance(1500);
      cubit.updateFromDistance(2000);

      // Exactly one additional save: the completion latch (not once per tick).
      expect(repo.saveCount, savesAfterStart + 1);
      expect(repo.saves.last.completed, isTrue);
      expect(cubit.state.selection!.completed, isTrue);
    });
  });

  group('RouteProgressCubit — restore from persisted selection (AC-9/AC-10)', () {
    test('restoredInProgressSelection_isHonoured_notReset (AC-9)', () {
      final restored = RouteSelection.create(
        start: nodeById(chain, 'can_tho'),
        direction: JourneyDirection.towardHaGiang,
        routeStartOffsetKm: 0,
        chain: chain,
      );
      final cubit = RouteProgressCubit(
        chain: chain,
        repository: RecordingRouteRepository(seed: restored),
        initialSelection: restored,
      );
      addTearDown(cubit.close);

      expect(cubit.state.selection, restored);
      expect(cubit.state.position, isNotNull);
      expect(cubit.state.selection!.start.id, 'can_tho');
      expect(cubit.state.selection!.direction, JourneyDirection.towardHaGiang);
    });

    test('restoredCompletedSelection_staysCompleted_noAutoAdvance (AC-10/13)', () {
      final restored = RouteSelection.create(
        start: nodeById(chain, 'can_tho'),
        direction: JourneyDirection.towardHaGiang,
        routeStartOffsetKm: 0,
        chain: chain,
        completed: true,
      );
      final cubit = RouteProgressCubit(
        chain: chain,
        repository: RecordingRouteRepository(seed: restored),
        initialSelection: restored,
      );
      addTearDown(cubit.close);

      // A realistic relaunch: the engine cumulative is still at/above the route
      // destination (1380 km), so the restored completed route stays completed
      // and never auto-starts a new route.
      cubit.updateFromDistance(1380);
      expect(cubit.state.position!.isCompleted, isTrue);
      expect(cubit.state.selection!.completed, isTrue);
      expect(cubit.state.position!.next, isNull);
      // It also stays completed for any further increase (terminal — AC-13).
      cubit.updateFromDistance(5000);
      expect(cubit.state.position!.isCompleted, isTrue);
    });
  });

  group('RouteProgressCubit — off-direction tip guard (AC-15 cubit leg)', () {
    test('startNewRoute_northTipHeadingNorth_throws_commitsNothing', () async {
      final cubit = RouteProgressCubit(chain: chain, repository: repo);
      addTearDown(cubit.close);

      await expectLater(
        cubit.startNewRoute(
          nodeById(chain, 'ha_giang'),
          JourneyDirection.towardHaGiang,
        ),
        throwsArgumentError,
      );
      expect(cubit.state.selection, isNull);
      expect(repo.saveCount, 0);
    });

    test('startNewRoute_southTipHeadingSouth_throws_commitsNothing', () async {
      final cubit = RouteProgressCubit(chain: chain, repository: repo);
      addTearDown(cubit.close);

      await expectLater(
        cubit.startNewRoute(
          nodeById(chain, 'mui'),
          JourneyDirection.towardMuiCaMau,
        ),
        throwsArgumentError,
      );
      expect(cubit.state.selection, isNull);
      expect(repo.saveCount, 0);
    });
  });

  group('RouteProgressCubit — write-free consumer (AC-16/AC-17)', () {
    test('drivingArbitraryDistances_onlyWritePathIsSelectionSave', () async {
      final cubit = RouteProgressCubit(chain: chain, repository: repo);
      addTearDown(cubit.close);
      await cubit.startNewRoute(
        nodeById(chain, 'can_tho'),
        JourneyDirection.towardHaGiang,
        currentCumulativeKm: 0,
      );

      // Feed a long, arbitrary sequence — the cubit only consumes the scalar.
      for (final d in <double>[10, 50, 169, 170, 400, 900, 1380, 9999]) {
        cubit.updateFromDistance(d);
      }

      // Every recorded write is a RouteSelection for this route (the start
      // selection + the single completion latch) — never an engine/state reset.
      expect(repo.saves.every((s) => s.start.id == 'can_tho'), isTrue);
      // The raw cumulative is preserved (read, never zeroed by the cubit).
      expect(cubit.state.cumulativeDistanceKm, closeTo(9999, kTol));
    });
  });
}
