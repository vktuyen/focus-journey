// Formal widget tests for the AppShell's single-shared-scene + pause invariants.
// Extends the existing app_shell smoke test (which asserts one identity across a
// single switch).
//
// Covers (headless legs):
//   TC-009  — full and compact render the SAME JourneyGame object (identity),
//             driven by the SAME JourneyCubit; no second engine/scene.
//   TC-013  — the shared game survives full → compact → full re-parenting with
//             identity preserved and onLoad NOT re-run (no scene re-init/reset).
//   TC-020  — NFR-1: the scene's update loop is PAUSED (not just hidden) when
//             the journey is idle/paused, and RESUMES on returning to active.
//             (Visibility/mode pausing is exercised via the lifecycle seam.)

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_game.dart';
import 'package:focus_journey/features/journey/presentation/journey_cubit.dart';
import 'package:focus_journey/features/journey/presentation/journey_view_state.dart';
import 'package:focus_journey/features/mini_window/data/mock_window_mode_controller.dart';
import 'package:focus_journey/features/mini_window/presentation/app_shell.dart';
import 'package:focus_journey/features/mini_window/presentation/app_shell_cubit.dart';
import 'package:focus_journey/features/mini_window/presentation/compact_view.dart';

class _ScriptableJourneyCubit extends JourneyCubit {
  void push(JourneyViewState state) => emit(state);
}

class _FixedClock implements Clock {
  _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

/// A JourneyGame that counts onLoad invocations, so TC-013 can prove the scene
/// is NOT re-initialised when re-parented between the full and compact subtrees.
class _OnLoadCountingGame extends JourneyGame {
  int onLoadCount = 0;

  @override
  Future<void> onLoad() async {
    onLoadCount++;
    await super.onLoad();
  }
}

void _drainAssetException(WidgetTester tester) {
  final ex = tester.takeException();
  if (ex != null && !ex.toString().contains('Unable to load asset')) {
    throw ex as Object;
  }
}

JourneyViewState _moving() => const JourneyViewState(
  motion: JourneyMotion.moving,
  mode: TravelMode.motorbike,
  distanceKm: 7.0,
  hasRealState: true,
);

JourneyViewState _stopped() => const JourneyViewState(
  motion: JourneyMotion.stopped,
  mode: TravelMode.motorbike,
  distanceKm: 7.0,
  hasRealState: true,
);

void main() {
  group('AppShell single shared scene (AC-9 / TC-009 / TC-013)', () {
    testWidgets('TC-013 fullToCompactToFull_reusesSameGame_withoutReInit', (
      tester,
    ) async {
      final controller = MockWindowModeController();
      addTearDown(controller.dispose);
      final cubit = _ScriptableJourneyCubit();
      addTearDown(cubit.close);
      final shellCubit = AppShellCubit(controller: controller);
      addTearDown(shellCubit.close);

      final _OnLoadCountingGame game = _OnLoadCountingGame();
      late JourneyGame fullGameSeen;

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<JourneyCubit>.value(value: cubit),
              BlocProvider<AppShellCubit>.value(value: shellCubit),
            ],
            child: AppShell(
              clock: _FixedClock(DateTime(2026, 6, 24, 12)),
              controller: controller,
              gameFactory: () => game,
              fullBuilder: (g) {
                fullGameSeen = g;
                return Scaffold(body: GameWidget<JourneyGame>(game: g));
              },
            ),
          ),
        ),
      );
      await tester.pump();
      _drainAssetException(tester);

      cubit.push(_moving());
      await tester.pump();
      await tester.pump();
      _drainAssetException(tester);

      final int loadsAfterFull = game.onLoadCount;
      expect(identical(fullGameSeen, game), isTrue);

      // full → compact: the compact subtree renders the SAME instance (AC-9).
      await shellCubit.enterCompact();
      await tester.pump();
      await tester.pump();
      _drainAssetException(tester);
      final compact = tester.widget<CompactView>(find.byType(CompactView));
      expect(identical(compact.sharedGame, game), isTrue);

      // compact → full: back to the full subtree, still the same instance.
      await shellCubit.showApp();
      await tester.pump();
      await tester.pump();
      _drainAssetException(tester);
      expect(find.byType(CompactView), findsNothing);
      expect(identical(fullGameSeen, game), isTrue);

      // Across the full round-trip onLoad was NOT re-run: no scene re-init,
      // no reset, no second engine created by the transition (TC-013).
      expect(game.onLoadCount, loadsAfterFull);
    });

    testWidgets(
      'TC-009 bothModes_consumeSameCubit_andSameGame_noSecondInstance',
      (tester) async {
        final controller = MockWindowModeController();
        addTearDown(controller.dispose);
        final cubit = _ScriptableJourneyCubit();
        addTearDown(cubit.close);
        final shellCubit = AppShellCubit(controller: controller);
        addTearDown(shellCubit.close);

        final game = JourneyGame();
        final gamesSeen = <JourneyGame>[];

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<JourneyCubit>.value(value: cubit),
                BlocProvider<AppShellCubit>.value(value: shellCubit),
              ],
              child: AppShell(
                clock: _FixedClock(DateTime(2026, 6, 24, 12)),
                controller: controller,
                gameFactory: () => game,
                fullBuilder: (g) {
                  gamesSeen.add(g);
                  return Scaffold(body: GameWidget<JourneyGame>(game: g));
                },
              ),
            ),
          ),
        );
        await tester.pump();
        _drainAssetException(tester);

        await shellCubit.enterCompact();
        await tester.pump();
        await tester.pump();
        _drainAssetException(tester);

        final compact = tester.widget<CompactView>(find.byType(CompactView));
        // Exactly one game object backs both subtrees (identity).
        expect(identical(compact.sharedGame, game), isTrue);
        for (final g in gamesSeen) {
          expect(identical(g, game), isTrue);
        }
      },
    );

    testWidgets('TC-020 NFR-1: idle_pausesUpdateLoop_resumesOnActive', (
      tester,
    ) async {
      final controller = MockWindowModeController();
      addTearDown(controller.dispose);
      final cubit = _ScriptableJourneyCubit();
      addTearDown(cubit.close);
      final shellCubit = AppShellCubit(controller: controller);
      addTearDown(shellCubit.close);

      final game = JourneyGame();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<JourneyCubit>.value(value: cubit),
              BlocProvider<AppShellCubit>.value(value: shellCubit),
            ],
            child: AppShell(
              clock: _FixedClock(DateTime(2026, 6, 24, 12)),
              controller: controller,
              gameFactory: () => game,
              fullBuilder: (g) =>
                  Scaffold(body: GameWidget<JourneyGame>(game: g)),
            ),
          ),
        ),
      );
      await tester.pump();
      _drainAssetException(tester);

      // Active + foregrounded → the shell resumes the update loop.
      cubit.push(_moving());
      await tester.pump();
      await tester.pump();
      _drainAssetException(tester);
      expect(game.paused, isFalse, reason: 'active+visible must run (NFR-1)');

      // Idle → the shell PAUSES the loop (not merely hidden): no per-frame
      // work, motion does not advance.
      cubit.push(_stopped());
      await tester.pump();
      await tester.pump();
      _drainAssetException(tester);
      expect(game.paused, isTrue, reason: 'idle must pause the loop (NFR-1)');
      final offsetWhilePaused = game.roadScrollOffset;
      game.update(1 / 60); // a paused game does no motion work.
      expect(game.roadScrollOffset, offsetWhilePaused);

      // Back to active → it resumes from the correct (preserved) state.
      cubit.push(_moving());
      await tester.pump();
      await tester.pump();
      _drainAssetException(tester);
      expect(game.paused, isFalse, reason: 'must resume on active (NFR-1)');
    });
  });
}
