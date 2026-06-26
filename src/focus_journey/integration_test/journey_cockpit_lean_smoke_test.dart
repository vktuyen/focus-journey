// journey-cockpit-lean end-to-end smoke (TC-518 / AC-1, AC-6, AC-7, AC-8, AC-13).
//
// Authored by test-script-author from tests/cases/journey-cockpit-lean.md.
//
// ADR-0003: the full window and the always-on-top mini-window PiP render the
// SAME JourneyGame instance, so the lean flows to BOTH surfaces for free. We
// model the two surfaces by rendering the one shared game at the two sizes
// (onGameResize -> render), exactly as the per-surface render path does
// (mirrors integration_test/journey_dynamic_curve_smoke_test.dart +
// cockpit_two_surface_test.dart). The state is driven via applyState plain
// values — the deterministic mock-path twin of the manual real-OS PiP leg
// TC-M-PIP. NO real OS, NO real timers, NO wall-clock.
//
// Flow (mock-driven):
//   1) car + active into a BEND   -> the cockpit LEANS on both surfaces (AC-1/13)
//   2) reduce-motion ON           -> the lean HARD-ZEROS to level on both (AC-6)
//   3) reduce-motion OFF + straight-ish stretch -> settles level (AC-7)
//   4) mode = walk                -> NO cockpit, NO lean (AC-8)
//   5) back to car in a bend      -> the lean is RESTORED on both (AC-1/13)
//
//   fvm flutter test integration_test/journey_cockpit_lean_smoke_test.dart
//   fvm flutter test integration_test/journey_cockpit_lean_smoke_test.dart -d macos

import 'dart:async';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_game.dart';
import 'package:focus_journey/features/journey/presentation/game/road_geometry.dart';
import 'package:focus_journey/features/journey/presentation/game/road_painter.dart';
import 'package:integration_test/integration_test.dart';

final Vector2 kFullViewport = Vector2(1280, 800);
final Vector2 kPipViewport = Vector2(360, 220);
const double kFrameDt = 1 / 60;
const double _maxRollCap = 0.0523599;

/// A no-op canvas: render must not throw at either surface size, and counts draws.
class _SinkCanvas implements Canvas {
  int draws = 0;
  @override
  void noSuchMethod(Invocation invocation) {
    if (invocation.memberName.toString().contains('draw')) draws++;
  }
}

/// Renders [game] at [size] (resize first); must not throw and must draw.
void _renderAt(JourneyGame game, Vector2 size) {
  game.onGameResize(size);
  final canvas = _SinkCanvas();
  game.render(canvas);
  expect(canvas.draws, greaterThan(0));
}

/// Renders the shared game on BOTH surfaces; the lean angle is the SAME on each
/// (one shared game), so we read it once and confirm both surfaces render.
double _renderBothAndReadLean(JourneyGame game) {
  _renderAt(game, kFullViewport);
  _renderAt(game, kPipViewport);
  return game.appliedLeanAngle;
}

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

  // The in-scene curve sample (the lean's only input): lateralSlopeAt at the
  // camera (worldAtCamera(offset) == offset at t≈1).
  final RoadGeometry geometry = RoadGeometry();
  final RoadPainter painter = RoadPainter();
  double signalAt(double offset) =>
      geometry.lateralSlopeAt(painter.worldAtCamera(offset));

  /// Advances the shared game (RM off) until it reaches a clearly-curving frame
  /// (|signal| above [minAbs]) or [maxFrames] elapse. Returns whether it leaned.
  bool driveToBend(JourneyGame game, {double minAbs = 1e-3, int maxFrames = 8000}) {
    for (int i = 0; i < maxFrames; i++) {
      game.update(kFrameDt);
      if (signalAt(game.roadScrollOffset).abs() > minAbs &&
          game.appliedLeanAngle.abs() > 1e-4) {
        return true;
      }
    }
    return false;
  }

  testWidgets(
    'TC-518 lean on both surfaces: bend -> reduce-motion -> straight -> walk -> car',
    (tester) async {
      final game = await loadGame();

      // --- 1) car + active into a BEND -> the cockpit LEANS on both surfaces. ---
      game.applyState(
        moving: true,
        mode: TravelMode.car,
        reduceMotion: false,
        timeOfDayHours: 12,
      );
      final bool leaned = driveToBend(game);
      expect(leaned, isTrue, reason: 'AC-1: the cockpit must lean in a bend');
      final double bendLean = _renderBothAndReadLean(game);
      expect(bendLean, isNot(0.0), reason: 'AC-1/AC-13: leaning on both surfaces');
      expect(bendLean.abs(), lessThanOrEqualTo(_maxRollCap + 1e-9));
      // The sign tracks the curve sample (into the turn).
      expect(
        bendLean.sign,
        signalAt(game.roadScrollOffset).sign,
        reason: 'AC-1: signed INTO the turn on both surfaces',
      );

      // --- 2) reduce-motion ON -> the lean HARD-ZEROS to level on both. ---
      game.applyState(
        moving: true,
        mode: TravelMode.car,
        reduceMotion: true,
        timeOfDayHours: 12,
      );
      expect(
        _renderBothAndReadLean(game),
        0.0,
        reason: 'AC-6: reduce-motion hard-zeros the lean to level on both',
      );
      // Holds level across pumps (scroll frozen too).
      for (int i = 0; i < 120; i++) {
        game.update(kFrameDt);
      }
      expect(_renderBothAndReadLean(game), 0.0);

      // --- 3) reduce-motion OFF + a flatter stretch -> settles level-ish. ---
      game.applyState(
        moving: true,
        mode: TravelMode.car,
        reduceMotion: false,
        timeOfDayHours: 12,
      );
      // Advance toward a flatter (near-inflection) stretch and confirm the lean
      // relaxes well below the clamp (the shipped curve has no exact-zero point,
      // so "straight -> level" is asserted as "near-level at the flattest frame").
      double minSeen = double.infinity;
      for (int i = 0; i < 6000; i++) {
        game.update(kFrameDt);
        final double a = game.appliedLeanAngle.abs();
        if (a < minSeen) minSeen = a;
      }
      expect(
        minSeen,
        lessThan(_maxRollCap * 0.3),
        reason: 'AC-7: the lean relaxes toward level on a flatter stretch',
      );

      // --- 4) mode = walk -> NO cockpit, NO lean on either surface. ---
      game.applyState(
        moving: true,
        mode: TravelMode.walk,
        reduceMotion: false,
        timeOfDayHours: 12,
      );
      expect(game.isCockpitActive, isFalse);
      expect(
        _renderBothAndReadLean(game),
        0.0,
        reason: 'AC-8: walk applies NO lean on either surface',
      );

      // --- 5) back to car in a BEND -> the lean is RESTORED on both. ---
      game.applyState(
        moving: true,
        mode: TravelMode.car,
        reduceMotion: false,
        timeOfDayHours: 12,
      );
      expect(game.isCockpitActive, isTrue);
      final bool restored = driveToBend(game);
      expect(restored, isTrue, reason: 'AC-1: the lean restores cleanly');
      final double restoredLean = _renderBothAndReadLean(game);
      expect(
        restoredLean,
        isNot(0.0),
        reason: 'AC-1/AC-13: the lean is restored on both surfaces',
      );
      expect(restoredLean.abs(), lessThanOrEqualTo(_maxRollCap + 1e-9));
    },
  );
}
