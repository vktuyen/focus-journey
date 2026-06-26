// Smoke widget tests for the compact PiP view (mini-window slice). Confirms the
// compact view is a pure view of the journey Bloc — it renders the Bloc's
// distance + the parked readout (AC-2/AC-4) and routes a body drag to the
// WindowModeController seam (AC-6/AC-8) without importing window_manager. The
// formal suite is authored by unit-test-writer next.
//
// The embedded GameWidget triggers Flame's asset load (incl. the intentionally
// missing ship.png); its orphan "Unable to load asset" rejection is drained via
// tester.takeException so it does not mask real failures.

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_game.dart';
import 'package:focus_journey/features/journey/presentation/journey_cubit.dart';
import 'package:focus_journey/features/journey/presentation/journey_overlays.dart';
import 'package:focus_journey/features/journey/presentation/journey_view_state.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/mini_window/data/mock_window_mode_controller.dart';
import 'package:focus_journey/features/mini_window/domain/window_mode.dart';
import 'package:focus_journey/features/mini_window/presentation/app_shell_cubit.dart';
import 'package:focus_journey/features/mini_window/presentation/compact_view.dart';
import 'package:focus_journey/features/mini_window/presentation/journey_tray_mapper.dart';
import 'package:focus_journey/features/mini_window/domain/tray_state.dart';

class _ScriptableJourneyCubit extends JourneyCubit {
  void push(JourneyViewState state) => emit(state);
}

void _drainAssetException(WidgetTester tester) {
  final ex = tester.takeException();
  if (ex != null && !ex.toString().contains('Unable to load asset')) {
    throw ex as Object;
  }
}

Future<_ScriptableJourneyCubit> _pumpCompact(
  WidgetTester tester,
  MockWindowModeController controller,
) async {
  final cubit = _ScriptableJourneyCubit();
  addTearDown(cubit.close);
  // CompactView's expand control reads the AppShellCubit (see BUG-1 fix); the
  // shell is part of the app's MultiBlocProvider in production, so provide it
  // here too. The controller is driven to compact first so the cubit seeds in
  // compact mode (it is only ever shown while compact).
  await controller.enterCompact();
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
        child: CompactView(sharedGame: game, controller: controller),
      ),
    ),
  );
  await tester.pump();
  _drainAssetException(tester);
  return cubit;
}

void main() {
  group('CompactView (pure view of journey Bloc)', () {
    testWidgets('rendersBlocDistanceReadout', (tester) async {
      final controller = MockWindowModeController();
      addTearDown(controller.dispose);
      final cubit = await _pumpCompact(tester, controller);

      cubit.push(
        const JourneyViewState(
          motion: JourneyMotion.moving,
          mode: TravelMode.motorbike,
          distanceKm: 42.0,
          hasRealState: true,
        ),
      );
      await tester.pump();
      await tester.pump();
      _drainAssetException(tester);

      // The readout equals the Bloc's distanceKm (AC-4) — real text (NFR-6).
      expect(find.text('42.0 km'), findsOneWidget);
    });

    testWidgets('showsParkedReadoutWhenStopped', (tester) async {
      final controller = MockWindowModeController();
      addTearDown(controller.dispose);
      final cubit = await _pumpCompact(tester, controller);

      cubit.push(
        const JourneyViewState(
          motion: JourneyMotion.stopped,
          mode: TravelMode.motorbike,
          distanceKm: 10.0,
          hasRealState: true,
        ),
      );
      await tester.pump();
      await tester.pump();
      _drainAssetException(tester);

      expect(find.text(kPausedOverlayText), findsOneWidget);
    });

    testWidgets('bodyDrag_movesWindowViaControllerSeam', (tester) async {
      final controller = MockWindowModeController();
      addTearDown(controller.dispose);
      await _pumpCompact(tester, controller);

      // Drag the compact body: it should start an OS window-move via the seam
      // (AC-6) and persist the settled position on release (AC-8) — never
      // importing window_manager into presentation. Drag from the CENTER so the
      // pan lands on the body, not the top-right expand control.
      await tester.drag(
        find.byType(GameWidget<JourneyGame>),
        const Offset(30, 30),
        warnIfMissed: false,
      );
      await tester.pump();
      _drainAssetException(tester);

      expect(controller.calls, contains('startDragging'));
      expect(controller.calls, contains('persistCompactPosition'));
    });

    // BUG-1: the compact PiP must offer a way back to full. The expand control
    // is rendered over the scene and, when tapped, asks the AppShellCubit to
    // showApp() (→ controller.showApp() → exitFull() while compact). It must be
    // layered ABOVE the drag region so its tap is NOT swallowed by the
    // window-move pan.
    testWidgets('rendersExpandRestoreControl', (tester) async {
      final controller = MockWindowModeController();
      addTearDown(controller.dispose);
      await _pumpCompact(tester, controller);

      expect(find.byIcon(Icons.open_in_full), findsOneWidget);
      expect(find.byTooltip('Back to full window'), findsOneWidget);
    });

    testWidgets('tapExpandControl_restoresFullViaControllerSeam', (
      tester,
    ) async {
      final controller = MockWindowModeController();
      addTearDown(controller.dispose);
      await _pumpCompact(tester, controller);
      // Ignore the enterCompact recorded during pump setup; assert the tap
      // produces the restore call (showApp → exitFull while compact).
      controller.calls.clear();

      await tester.tap(find.byIcon(Icons.open_in_full));
      await tester.pump();
      _drainAssetException(tester);

      // showApp() routes to exitFull() while compact (BUG-1), and the tap must
      // NOT have started a window-move drag (it sits above the drag region).
      expect(controller.calls, contains('showApp'));
      expect(controller.calls, contains('exitFull'));
      expect(controller.calls, isNot(contains('startDragging')));
      expect(controller.mode, WindowMode.full);
    });
  });

  group('JourneyTrayMapper (pure mapping, AC-11/13)', () {
    test('movingMapsToActive', () {
      const s = JourneyViewState(
        motion: JourneyMotion.moving,
        mode: TravelMode.motorbike,
        distanceKm: 1240.0,
        hasRealState: true,
      );
      expect(JourneyTrayMapper.stateFor(s), TrayActivityState.active);
      expect(JourneyTrayMapper.statusLineFor(s), 'Travelling — 1240.0 km');
    });

    test('stoppedMapsToPaused', () {
      const s = JourneyViewState(
        motion: JourneyMotion.stopped,
        mode: TravelMode.motorbike,
        distanceKm: 5.0,
        hasRealState: true,
      );
      expect(JourneyTrayMapper.stateFor(s), TrayActivityState.paused);
      expect(JourneyTrayMapper.statusLineFor(s), 'Paused — 5.0 km');
    });
  });
}
