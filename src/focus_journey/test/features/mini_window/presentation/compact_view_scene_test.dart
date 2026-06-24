// Formal widget tests for the compact PiP view as a PURE VIEW of the journey
// Bloc (mini-window slice). Extends the existing compact_view smoke test.
//
// The CompactView embeds the SHARED JourneyGame and a tiny readout. The scene's
// scroll is governed by the game's applyState/update (driven by the shell), and
// the readout (distance + parked/reduce-motion indication) is driven by the
// journey Bloc state. These tests assert both halves headlessly: motion via
// explicit game.update() pumps (no wall-clock waits), the readout via the
// semantics/text tree.
//
// Covers (headless legs):
//   TC-001     — compact scene scrolls + shows distance while active.
//   TC-002     — parks (no motion) + parked readout while idle/paused.
//   TC-003     — stops on the NEXT update tick after the state flips to stopped.
//   TC-004     — distance readout EQUALS the Bloc's distanceKm.
//   TC-005     — first-frame / pre-state default is parked (no auto-scroll).
//   TC-021-RM  — reduce-motion: scroll suppressed, active-vs-stopped still
//                conveyed via the textual indicator.
//   TC-021     — readout exposed to the accessibility tree AS TEXT (NFR-6).

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_game.dart';
import 'package:focus_journey/features/journey/presentation/journey_cubit.dart';
import 'package:focus_journey/features/journey/presentation/journey_overlays.dart';
import 'package:focus_journey/features/journey/presentation/journey_view_state.dart';
import 'package:focus_journey/features/mini_window/data/mock_window_mode_controller.dart';
import 'package:focus_journey/features/mini_window/presentation/compact_view.dart';

/// Float tolerance for "equal"/"unchanged" scroll comparisons (per conventions).
const double kEps = 1e-6;

class _ScriptableJourneyCubit extends JourneyCubit {
  void push(JourneyViewState state) => emit(state);
}

JourneyViewState _moving({double distanceKm = 0}) => JourneyViewState(
  motion: JourneyMotion.moving,
  mode: TravelMode.motorbike,
  distanceKm: distanceKm,
  hasRealState: true,
);

JourneyViewState _stopped({double distanceKm = 0}) => JourneyViewState(
  motion: JourneyMotion.stopped,
  mode: TravelMode.motorbike,
  distanceKm: distanceKm,
  hasRealState: true,
);

void _drainAssetException(WidgetTester tester) {
  final ex = tester.takeException();
  if (ex != null && !ex.toString().contains('Unable to load asset')) {
    throw ex as Object;
  }
}

/// Pumps the CompactView over [cubit] + [game]. The game is resized so headless
/// motion pumps work (the embedded GameWidget does not give it a size in tests).
Future<_ScriptableJourneyCubit> _pump(
  WidgetTester tester, {
  required JourneyGame game,
  required MockWindowModeController controller,
  bool reduceMotion = false,
}) async {
  final cubit = _ScriptableJourneyCubit();
  addTearDown(cubit.close);
  game.onGameResize(Vector2(CompactGeometryTestSize.w, CompactGeometryTestSize.h));
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(
        home: BlocProvider<JourneyCubit>.value(
          value: cubit,
          child: CompactView(sharedGame: game, controller: controller),
        ),
      ),
    ),
  );
  await tester.pump();
  _drainAssetException(tester);
  return cubit;
}

/// Pushes [state] to the Bloc AND drives the shared scene the way the shell's
/// single applyState driver does, then renders. Returns after two frame pumps.
Future<void> _apply(
  WidgetTester tester,
  _ScriptableJourneyCubit cubit,
  JourneyGame game,
  JourneyViewState state, {
  bool reduceMotion = false,
}) async {
  cubit.push(state);
  game.applyState(
    moving: state.motion == JourneyMotion.moving,
    mode: state.mode,
    reduceMotion: reduceMotion,
    timeOfDayHours: 12,
  );
  await tester.pump();
  await tester.pump();
  _drainAssetException(tester);
}

/// Pumps the game's update loop [frames] times and returns the offset trace.
List<double> _pumpGame(JourneyGame game, {int frames = 60}) {
  final List<double> offsets = <double>[];
  for (int i = 0; i < frames; i++) {
    game.update(1 / 60);
    offsets.add(game.roadScrollOffset);
  }
  return offsets;
}

void main() {
  group('CompactView scene as a pure view (mini-window)', () {
    testWidgets(
      'TC-001 active_compactSceneScrolls_andReadoutShowsDistance',
      (tester) async {
        final controller = MockWindowModeController();
        addTearDown(controller.dispose);
        final game = JourneyGame();
        final cubit = await _pump(tester, game: game, controller: controller);

        await _apply(tester, cubit, game, _moving(distanceKm: 42.0));
        // The compact instance of the shared scene scrolls forward (motion
        // advances monotonically across explicit update pumps).
        final offsets = _pumpGame(game, frames: 120);
        for (int i = 1; i < offsets.length; i++) {
          expect(offsets[i], greaterThanOrEqualTo(offsets[i - 1] - kEps));
        }
        expect(offsets.last, greaterThan(offsets.first));
        expect(game.isVehicleRunning, isTrue);

        await tester.pump();
        _drainAssetException(tester);
        // The readout shows the live distance (AC-1/AC-4) as real text.
        expect(find.text('42.0 km'), findsOneWidget);
      },
    );

    testWidgets('TC-002 idle_compactSceneParks_andShowsParkedReadout', (
      tester,
    ) async {
      final controller = MockWindowModeController();
      addTearDown(controller.dispose);
      final game = JourneyGame();
      final cubit = await _pump(tester, game: game, controller: controller);

      await _apply(tester, cubit, game, _stopped(distanceKm: 10.0));
      // The scene never advances while the last state is stopped.
      final offsets = _pumpGame(game, frames: 300);
      for (final o in offsets) {
        expect(o, closeTo(offsets.first, kEps));
      }
      expect(game.isStopped, isTrue);

      await tester.pump();
      _drainAssetException(tester);
      // The parked readout is shown (AC-2).
      expect(find.text(kPausedOverlayText), findsOneWidget);
    });

    testWidgets('TC-003 activeToStopped_stopsOnNextUpdateTick', (tester) async {
      final controller = MockWindowModeController();
      addTearDown(controller.dispose);
      final game = JourneyGame();
      final cubit = await _pump(tester, game: game, controller: controller);

      // Reach cruise while active.
      await _apply(tester, cubit, game, _moving(distanceKm: 5));
      _pumpGame(game, frames: 120);
      expect(game.scrollVelocity, greaterThan(0));

      // Flip to stopped; the scene reacts on the NEXT update tick (it begins to
      // ease down — no extra frame of delay before motion responds).
      await _apply(tester, cubit, game, _stopped(distanceKm: 5));
      final vBefore = game.scrollVelocity;
      game.update(1 / 60);
      expect(
        game.scrollVelocity,
        lessThan(vBefore),
        reason: 'velocity must begin decreasing on the next tick (TC-003)',
      );

      // And it does NOT jump to a halt in a single step (no jank): it eases.
      expect(game.scrollVelocity, greaterThan(0));
      // It eventually fully stops.
      _pumpGame(game, frames: 120);
      expect(game.isStopped, isTrue);
    });

    testWidgets('TC-004 distanceReadout_equalsBlocValue_acrossSnapshots', (
      tester,
    ) async {
      final controller = MockWindowModeController();
      addTearDown(controller.dispose);
      final game = JourneyGame();
      final cubit = await _pump(tester, game: game, controller: controller);

      for (final km in <double>[0.0, 12.3, 1240.0]) {
        await _apply(tester, cubit, game, _moving(distanceKm: km));
        // The readout EQUALS the Bloc's distanceKm (the PiP computes nothing).
        expect(find.text('${km.toStringAsFixed(1)} km'), findsOneWidget);
      }
    });

    testWidgets(
      'TC-005 firstFrame_preState_isParked_neverAutoScrolls',
      (tester) async {
        final controller = MockWindowModeController();
        addTearDown(controller.dispose);
        final game = JourneyGame();
        // No state pushed: the Bloc is at its pre-state initial default.
        await _pump(tester, game: game, controller: controller);

        // The scene must not auto-scroll before a real active state arrives.
        final offsets = _pumpGame(game, frames: 120);
        for (final o in offsets) {
          expect(o, closeTo(offsets.first, kEps));
        }
        expect(game.isStopped, isTrue);

        // Pre-state shows NO "Paused — idle" overlay (parked WITHOUT message).
        expect(find.text(kPausedOverlayText), findsNothing);
      },
    );

    testWidgets(
      'TC-021-RM reduceMotion_suppressesScroll_butStillConveysState',
      (tester) async {
        final controller = MockWindowModeController();
        addTearDown(controller.dispose);
        final game = JourneyGame();
        final cubit = await _pump(
          tester,
          game: game,
          controller: controller,
          reduceMotion: true,
        );

        await _apply(
          tester,
          cubit,
          game,
          _moving(distanceKm: 8),
          reduceMotion: true,
        );
        // Reduce-motion suppresses the full scroll even while "active".
        final offsets = _pumpGame(game, frames: 120);
        for (final o in offsets) {
          expect(o, closeTo(offsets.first, kEps));
        }
        expect(game.reduceMotion, isTrue);

        // ...but active-vs-stopped is STILL conveyed by the textual indicator.
        expect(find.byType(ReduceMotionIndicator), findsOneWidget);
        expect(find.text('Travelling'), findsOneWidget);

        // Flip to stopped: the indicator updates so the distinction is visible.
        await _apply(
          tester,
          cubit,
          game,
          _stopped(distanceKm: 8),
          reduceMotion: true,
        );
        expect(find.text('Stopped'), findsOneWidget);
      },
    );

    testWidgets('TC-021 readout_isRealTextInTheSemanticsTree_NFR6', (
      tester,
    ) async {
      final controller = MockWindowModeController();
      addTearDown(controller.dispose);
      final game = JourneyGame();
      final cubit = await _pump(tester, game: game, controller: controller);

      await _apply(tester, cubit, game, _moving(distanceKm: 123.4));

      // The distance is exposed to the a11y tree as text, NOT baked into the
      // sprite/bitmap (the DistanceCounter wraps it in a Semantics label).
      expect(
        find.bySemanticsLabel(RegExp(r'Distance travelled 123\.4 km')),
        findsOneWidget,
      );

      // The parked message is likewise a real semantics label when stopped.
      await _apply(tester, cubit, game, _stopped(distanceKm: 123.4));
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(kPausedOverlayText))),
        findsOneWidget,
      );
    });
  });
}

/// The fixed compact size used to resize the headless game (matches
/// CompactGeometry 280x180; kept local to avoid importing geometry for a size).
abstract final class CompactGeometryTestSize {
  static const double w = 280;
  static const double h = 180;
}
