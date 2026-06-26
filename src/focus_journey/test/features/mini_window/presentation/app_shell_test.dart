// Smoke widget tests for the AppShell — the single-window two-mode shell that
// owns the ONE shared JourneyGame (AC-9) and switches between full and compact.
// Confirms: (1) the SAME JourneyGame instance is rendered in both modes (no
// forked scene), and (2) the shell drives the shared scene from the journey
// Bloc (single applyState driver). The formal suite is authored next.
//
// The embedded GameWidget triggers Flame's asset load (incl. the intentionally
// missing ship.png); the orphan "Unable to load asset" rejection is drained.

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

void _drainAssetException(WidgetTester tester) {
  final ex = tester.takeException();
  if (ex != null && !ex.toString().contains('Unable to load asset')) {
    throw ex as Object;
  }
}

void main() {
  testWidgets('sharesOneGameAcrossModesAndDrivesIt', (tester) async {
    final controller = MockWindowModeController();
    addTearDown(controller.dispose);
    final cubit = _ScriptableJourneyCubit();
    addTearDown(cubit.close);
    final shellCubit = AppShellCubit(controller: controller);
    addTearDown(shellCubit.close);

    // Capture the shared game the shell creates so we can assert it is the same
    // instance across mode switches (AC-9 — one scene).
    late final JourneyGame sharedGame;

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
            gameFactory: () => JourneyGame(),
            fullBuilder: (game) {
              sharedGame = game;
              // A minimal full subtree embedding the shared scene.
              return Scaffold(body: GameWidget<JourneyGame>(game: game));
            },
          ),
        ),
      ),
    );
    await tester.pump();
    _drainAssetException(tester);

    // The shell drives the shared scene from the Bloc (single applyState
    // driver): a moving state makes the scene moving.
    cubit.push(
      const JourneyViewState(
        motion: JourneyMotion.moving,
        mode: TravelMode.motorbike,
        distanceKm: 7.0,
        hasRealState: true,
      ),
    );
    await tester.pump();
    await tester.pump();
    _drainAssetException(tester);
    expect(sharedGame.currentMode, TravelMode.motorbike);

    // Switch to compact mode via the shell cubit.
    await shellCubit.enterCompact();
    await tester.pump();
    await tester.pump();
    _drainAssetException(tester);

    // The compact view is shown and renders the SAME game instance (AC-9).
    final compact = tester.widget<CompactView>(find.byType(CompactView));
    expect(identical(compact.sharedGame, sharedGame), isTrue);
  });

  testWidgets('B1 (NFR-1): activeThenHideToTray_pausesSharedGame', (
    tester,
  ) async {
    final controller = MockWindowModeController();
    addTearDown(controller.dispose);
    final cubit = _ScriptableJourneyCubit();
    addTearDown(cubit.close);
    final shellCubit = AppShellCubit(controller: controller);
    addTearDown(shellCubit.close);

    final JourneyGame game = JourneyGame();

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

    // Active journey + visible window → the scene runs (NFR-1).
    cubit.push(
      const JourneyViewState(
        motion: JourneyMotion.moving,
        mode: TravelMode.motorbike,
        distanceKm: 1.0,
        hasRealState: true,
      ),
    );
    await tester.pump();
    await tester.pump();
    _drainAssetException(tester);
    expect(game.paused, isFalse, reason: 'active + visible should run');

    // Close→hide-to-tray while STILL active. On desktop this does NOT change
    // AppLifecycleState, so the scene must be paused by the visibility seam.
    await controller.hideToTray();
    await tester.pump();
    await tester.pump();
    _drainAssetException(tester);

    expect(
      game.paused,
      isTrue,
      reason: 'hidden-to-tray while active must pause the scene (B1/NFR-1)',
    );

    // Re-show the window → the scene resumes (still active).
    await controller.showApp();
    await tester.pump();
    await tester.pump();
    _drainAssetException(tester);
    expect(game.paused, isFalse, reason: 'visible + active should resume');
  });
}
