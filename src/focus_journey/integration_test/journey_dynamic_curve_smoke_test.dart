// journey-dynamic-curve end-to-end smoke (TC-415 / AC-3, AC-10, AC-11).
//
// Authored by test-script-author from tests/cases/journey-dynamic-curve.md.
//
// ADR-0003: the full window and the always-on-top mini-window PiP render the
// SAME JourneyGame instance. The sharper winding curve flows to BOTH surfaces
// for free. We model the two surfaces by rendering the one shared game at the
// two sizes (onGameResize → render), exactly as the per-surface render path
// does — mirroring integration_test/cockpit_two_surface_test.dart's harness.
//
// Flow (deterministic, mock-driven — NO real OS, NO real timers, NO wall-clock):
//   1) active            → the curve SWEEPS as the scroll phase advances, on
//                          BOTH surfaces; the centre-line stays on-screen at the
//                          PiP size (TC-412 bound) on both surfaces.
//   2) reduce-motion ON  → the curve FREEZES (scroll phase held) on both.
//   3) reduce-motion OFF + active → the sweep RESUMES on both.
//
// Covers AC-3 (sweep) / AC-10 (freeze) / AC-11 (both surfaces, on-screen). The
// real-OS frameless-PiP visual read is the manual TC-M-PIP.
//
// Runs headless under `flutter test` and on a desktop device:
//   fvm flutter test integration_test/journey_dynamic_curve_smoke_test.dart
//   fvm flutter test integration_test/journey_dynamic_curve_smoke_test.dart -d macos

import 'dart:async';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_game.dart';
import 'package:focus_journey/features/journey/presentation/game/road_painter.dart';
import 'package:integration_test/integration_test.dart';

/// Full-window vs sized-down PiP viewports (the two surfaces share one game).
final Vector2 kFullViewport = Vector2(1280, 800);
final Vector2 kPipViewport = Vector2(360, 220);

/// A no-op canvas: render must not throw at either surface size.
class _SinkCanvas implements Canvas {
  int draws = 0;
  @override
  void noSuchMethod(Invocation invocation) {
    draws++;
  }
}

/// Renders [game] at [size] (resizing to that surface first). Returns the
/// near-camera centre-line offset observed at that surface for this phase — the
/// curve quantity each surface shows from the one shared game (ADR-0003).
double renderAndReadCentreLine(JourneyGame game, Vector2 size) {
  game.onGameResize(size);
  final canvas = _SinkCanvas();
  game.render(canvas); // must not throw at any surface size
  expect(canvas.draws, greaterThan(0));
  return game.centreLineOffsetAt(1.0);
}

/// Loads a sprite-backed game (render needs the sprite store initialised),
/// swallowing ONLY Flame's expected orphan "Unable to load asset" rejection for
/// the intentionally-absent assets. Mirrors the unit harness loadJourneyGame().
Future<JourneyGame> loadGame() async {
  late JourneyGame game;
  final Completer<void> done = Completer<void>();
  Object? unexpected;
  runZonedGuarded(
    () async {
      game = JourneyGame();
      await game.onLoad();
      game.onGameResize(kFullViewport);
      if (!done.isCompleted) done.complete();
    },
    (Object error, StackTrace stack) {
      if (error.toString().contains('Unable to load asset')) return;
      unexpected ??= error;
      if (!done.isCompleted) done.completeError(error, stack);
    },
  );
  await done.future;
  await Future<void>.delayed(const Duration(milliseconds: 10));
  if (unexpected != null) {
    throw StateError('Unexpected zone error during onLoad: $unexpected');
  }
  return game;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TC-415 sharper curve on both surfaces: sweep → freeze → resume (AC-3/10/11)',
    (tester) async {
      final game = await loadGame();

      // --- 1) ACTIVE: the curve SWEEPS as the scroll phase advances. ---
      game.applyState(
        moving: true,
        mode: TravelMode.motorbike,
        reduceMotion: false,
        timeOfDayHours: 12,
      );

      // Advance the shared scroll phase and sample the bend on BOTH surfaces.
      final List<double> fullSweep = <double>[];
      final List<double> pipSweep = <double>[];
      for (int i = 0; i < 600; i++) {
        for (int f = 0; f < 4; f++) {
          game.update(1 / 60);
        }
        // Both surfaces render the SAME shared game (resize → render → read).
        final double full = renderAndReadCentreLine(game, kFullViewport);
        final double pip = renderAndReadCentreLine(game, kPipViewport);
        fullSweep.add(full);
        pipSweep.add(pip);

        // AC-11: the centre-line stays on screen at BOTH surfaces (corrected
        // bound — see TC-412). It is in fact within curveAmplitudeFrac·width.
        expect(
          full.abs(),
          lessThanOrEqualTo(kFullViewport.x / 2),
          reason: 'centre-line off-screen on the full window at frame $i',
        );
        expect(
          pip.abs(),
          lessThanOrEqualTo(kPipViewport.x / 2),
          reason: 'centre-line off-screen on the PiP at frame $i',
        );
        expect(
          pip.abs(),
          lessThanOrEqualTo(
            kPipViewport.x * RoadPainter.curveAmplitudeFrac + 1e-6,
          ),
        );
      }

      // AC-3: the curve SWEPT on BOTH surfaces (non-constant excursion).
      expect(
        fullSweep.reduce((a, b) => a > b ? a : b) -
            fullSweep.reduce((a, b) => a < b ? a : b),
        greaterThan(1.0),
        reason: 'AC-3: the bend must sweep on the full window while active',
      );
      expect(
        pipSweep.reduce((a, b) => a > b ? a : b) -
            pipSweep.reduce((a, b) => a < b ? a : b),
        greaterThan(0.5),
        reason: 'AC-3: the bend must sweep on the PiP while active',
      );

      // --- 2) REDUCE-MOTION ON: the curve FREEZES on both surfaces. ---
      game.applyState(
        moving: true,
        mode: TravelMode.motorbike,
        reduceMotion: true,
        timeOfDayHours: 12,
      );
      // SceneMotion eases (bounded ≤ ~0.5 s) to a stop on reduce-motion rather
      // than snapping (prevents a jump). Pump past the ease so the phase is
      // truly frozen before we record the held frame.
      for (int i = 0; i < 60; i++) {
        game.update(1 / 60);
      }
      expect(game.scrollVelocity, 0, reason: 'ease must settle to a full stop');
      final double frozenOffset = game.roadScrollOffset;
      final double frozenFull = renderAndReadCentreLine(game, kFullViewport);
      final double frozenPip = renderAndReadCentreLine(game, kPipViewport);
      for (int i = 0; i < 120; i++) {
        game.update(1 / 60);
      }
      // Scroll phase held → bend identical on both surfaces (no second clock).
      expect(game.roadScrollOffset, closeTo(frozenOffset, 1e-6));
      expect(
        renderAndReadCentreLine(game, kFullViewport),
        closeTo(frozenFull, 1e-6),
        reason: 'AC-10: the curve must freeze on the full window',
      );
      expect(
        renderAndReadCentreLine(game, kPipViewport),
        closeTo(frozenPip, 1e-6),
        reason: 'AC-10: the curve must freeze on the PiP',
      );

      // --- 3) REDUCE-MOTION OFF + ACTIVE: the sweep RESUMES on both. ---
      game.applyState(
        moving: true,
        mode: TravelMode.motorbike,
        reduceMotion: false,
        timeOfDayHours: 12,
      );
      final double resumeFull0 = renderAndReadCentreLine(game, kFullViewport);
      final double resumePip0 = renderAndReadCentreLine(game, kPipViewport);
      bool fullMoved = false;
      bool pipMoved = false;
      for (int i = 0; i < 300; i++) {
        for (int f = 0; f < 4; f++) {
          game.update(1 / 60);
        }
        if ((renderAndReadCentreLine(game, kFullViewport) - resumeFull0).abs() >
            1e-3) {
          fullMoved = true;
        }
        if ((renderAndReadCentreLine(game, kPipViewport) - resumePip0).abs() >
            1e-3) {
          pipMoved = true;
        }
        if (fullMoved && pipMoved) break;
      }
      expect(game.roadScrollOffset, greaterThan(frozenOffset),
          reason: 'AC-3: the scroll phase must resume advancing');
      expect(fullMoved, isTrue, reason: 'AC-3: sweep must resume on full window');
      expect(pipMoved, isTrue, reason: 'AC-3: sweep must resume on the PiP');
    },
  );
}
