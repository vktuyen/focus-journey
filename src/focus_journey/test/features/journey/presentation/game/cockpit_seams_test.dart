// Unit tests for the journey-pov cockpit SEAMS on JourneyGame and the
// CockpitPainter constant. Code-level + deterministic; no real Canvas, no
// wall-clock waits. Integration/widget/render behaviour is left to the
// test-script-author (tests/cases/journey-pov.md).
//
// Covers:
//   * isCockpitActive: true for car/motorbike, false for walk/run/bicycle/ship
//     (journey-pov AC-1/AC-3/AC-6).
//   * cockpitAssetPaths: car -> cockpitCar, motorbike -> cockpitMotorbike,
//     empty for non-cockpit modes (AC-6).
//   * Mode-switch car -> walk -> car flips the seams cleanly (AC-7/AC-8).
//   * failedCockpitAssetPaths is a subset of failedAssetPaths, and unbundled
//     cockpit glyphs degrade to placeholders without throwing (AC-13).
//   * cockpitViewportFraction is in the spec band (0.30-0.40) and equals
//     CockpitPainter.cockpitViewportFraction (AC-5).
//   * CockpitPainter.cockpitViewportFraction constant + no-op / null-tolerant
//     paint shape (a real Canvas is NOT exercised here — render-pixel checks
//     belong to the script-author).

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/cockpit_painter.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_assets.dart';

import 'journey_game_test_harness.dart';

const List<TravelMode> _cockpitModes = <TravelMode>[
  TravelMode.car,
  TravelMode.motorbike,
];
const List<TravelMode> _nonCockpitModes = <TravelMode>[
  TravelMode.walk,
  TravelMode.run,
  TravelMode.bicycle,
  TravelMode.ship,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JourneyGame.isCockpitActive (AC-1/AC-3/AC-6)', () {
    for (final mode in _cockpitModes) {
      test('isTrue_for_${mode.name}', () {
        final game = buildMotionGame();
        driveActive(game, mode: mode);
        expect(game.isCockpitActive, isTrue);
      });
    }

    for (final mode in _nonCockpitModes) {
      test('isFalse_for_${mode.name}', () {
        final game = buildMotionGame();
        driveActive(game, mode: mode);
        expect(game.isCockpitActive, isFalse);
      });
    }

    test('tracksMode_independentOfMovingFlag', () {
      final game = buildMotionGame();
      driveStopped(game, mode: TravelMode.car);
      expect(game.isCockpitActive, isTrue);
      driveStopped(game, mode: TravelMode.walk);
      expect(game.isCockpitActive, isFalse);
    });
  });

  group('JourneyGame.cockpitAssetPaths (AC-1/AC-3/AC-6/AC-17)', () {
    test('carMode_returnsCockpitCarPaths', () {
      final game = buildMotionGame();
      driveActive(game, mode: TravelMode.car);
      expect(game.cockpitAssetPaths, orderedEquals(JourneyAssets.cockpitCar));
    });

    test('motorbikeMode_returnsCockpitMotorbikePaths', () {
      final game = buildMotionGame();
      driveActive(game, mode: TravelMode.motorbike);
      expect(
        game.cockpitAssetPaths,
        orderedEquals(JourneyAssets.cockpitMotorbike),
      );
    });

    for (final mode in _nonCockpitModes) {
      test('isEmpty_for_${mode.name}', () {
        final game = buildMotionGame();
        driveActive(game, mode: mode);
        expect(game.cockpitAssetPaths, isEmpty);
      });
    }
  });

  group('JourneyGame cockpit mode-switch (AC-7/AC-8)', () {
    test('carThenWalkThenCar_flipsActiveTrueFalseTrue', () {
      final game = buildMotionGame();

      driveActive(game, mode: TravelMode.car);
      expect(game.isCockpitActive, isTrue);
      expect(game.cockpitAssetPaths, orderedEquals(JourneyAssets.cockpitCar));

      driveActive(game, mode: TravelMode.walk);
      expect(game.isCockpitActive, isFalse);
      expect(game.cockpitAssetPaths, isEmpty);

      driveActive(game, mode: TravelMode.car);
      expect(game.isCockpitActive, isTrue);
      expect(game.cockpitAssetPaths, orderedEquals(JourneyAssets.cockpitCar));
    });

    test('carThenMotorbike_swapsTheRequestedCockpitPaths', () {
      final game = buildMotionGame();
      driveActive(game, mode: TravelMode.car);
      expect(game.cockpitAssetPaths, orderedEquals(JourneyAssets.cockpitCar));
      driveActive(game, mode: TravelMode.motorbike);
      expect(
        game.cockpitAssetPaths,
        orderedEquals(JourneyAssets.cockpitMotorbike),
      );
    });
  });

  group('JourneyGame.cockpitViewportFraction (AC-5)', () {
    test('isWithinSpecBand_0_30_to_0_40', () {
      final game = buildMotionGame();
      expect(game.cockpitViewportFraction, greaterThanOrEqualTo(0.30));
      expect(game.cockpitViewportFraction, lessThanOrEqualTo(0.40));
    });

    test('equalsCockpitPainterConstant', () {
      final game = buildMotionGame();
      expect(
        game.cockpitViewportFraction,
        CockpitPainter.cockpitViewportFraction,
      );
    });

    test('isInvariantAcrossModes', () {
      final game = buildMotionGame();
      driveActive(game, mode: TravelMode.car);
      final carFraction = game.cockpitViewportFraction;
      driveActive(game, mode: TravelMode.ship);
      expect(game.cockpitViewportFraction, carFraction);
    });
  });

  group('JourneyGame.failedCockpitAssetPaths (AC-13)', () {
    // Load the sprite-backed game once. The cockpit glyphs are not yet sourced,
    // so they degrade to placeholders (drawn as original flat-shape fallbacks).
    late final gameFuture = loadJourneyGame();

    test('subsetOfFailedAssetPaths_forCarMode', () async {
      final game = await gameFuture;
      game.applyState(
        moving: true,
        mode: TravelMode.car,
        reduceMotion: false,
        timeOfDayHours: 12,
      );
      expect(
        game.failedCockpitAssetPaths.difference(game.failedAssetPaths),
        isEmpty,
        reason: 'failedCockpitAssetPaths must be a subset of failedAssetPaths',
      );
    });

    test('unbundledCarGlyphs_degradeToPlaceholders_notThrow', () async {
      final game = await gameFuture;
      game.applyState(
        moving: true,
        mode: TravelMode.car,
        reduceMotion: false,
        timeOfDayHours: 12,
      );
      // /source-assets populated the 3 car glyph primitives (steering wheel,
      // speedometer, fuel gauge); only the procedural dashboard shape is
      // unbundled, so it alone degrades to a placeholder (AC-13).
      expect(game.failedCockpitAssetPaths, <String>{
        JourneyAssets.cockpitCarDashboard,
      });
      expect(game.hasPlaceholderAssets, isTrue);
    });

    test('nonCockpitMode_hasEmptyFailedCockpitSet', () async {
      final game = await gameFuture;
      game.applyState(
        moving: true,
        mode: TravelMode.walk,
        reduceMotion: false,
        timeOfDayHours: 12,
      );
      expect(game.failedCockpitAssetPaths, isEmpty);
    });

    test('pumpingWithDegradedCockpit_doesNotThrow', () async {
      final game = await gameFuture;
      game.applyState(
        moving: true,
        mode: TravelMode.motorbike,
        reduceMotion: false,
        timeOfDayHours: 12,
      );
      expect(() => pump(game, frames: 30), returnsNormally);
    });
  });

  group('CockpitPainter constant + paint contract', () {
    test('cockpitViewportFraction_is0_36_withinSpecBand', () {
      expect(CockpitPainter.cockpitViewportFraction, 0.36);
      expect(
        CockpitPainter.cockpitViewportFraction,
        greaterThanOrEqualTo(0.30),
      );
      expect(CockpitPainter.cockpitViewportFraction, lessThanOrEqualTo(0.40));
    });

    test('cockpitTop_isAboveTheBottomBand', () {
      final painter = CockpitPainter();
      const size = Size(800, 600);
      final top = painter.cockpitTop(size);
      // Top of the cockpit band == height * (1 - fraction).
      expect(top, closeTo(600 * (1 - 0.36), 1e-9));
      // Leaves the upper portion of the viewport for the road.
      expect(top, greaterThan(0));
      expect(top, lessThan(size.height));
    });

    test('paint_forNonCockpitMode_isNoOp_doesNotTouchCanvas', () {
      final painter = CockpitPainter();
      final canvas = _RecordingCanvas();
      for (final mode in _nonCockpitModes) {
        painter.paint(
          canvas,
          const Size(800, 600),
          mode,
          moving: true,
          glyphFor: (_) => null,
        );
      }
      expect(
        canvas.drawCalls,
        0,
        reason: 'non-cockpit modes must paint nothing (AC-6)',
      );
    });

    test('paint_carWithNullGlyphs_drawsFallback_doesNotThrow', () {
      final painter = CockpitPainter();
      final canvas = _RecordingCanvas();
      expect(
        () => painter.paint(
          canvas,
          const Size(800, 600),
          TravelMode.car,
          moving: false,
          glyphFor: (_) => null, // every glyph missing -> flat-shape fallback
        ),
        returnsNormally,
      );
      // It actually drew the procedural fallback (non-zero canvas activity).
      expect(canvas.drawCalls, greaterThan(0));
    });

    test('paint_motorbikeWithNullGlyphs_drawsFallback_doesNotThrow', () {
      final painter = CockpitPainter();
      final canvas = _RecordingCanvas();
      expect(
        () => painter.paint(
          canvas,
          const Size(800, 600),
          TravelMode.motorbike,
          moving: true,
          glyphFor: (_) => null,
        ),
        returnsNormally,
      );
      expect(canvas.drawCalls, greaterThan(0));
    });

    test('paint_movingTrueAndFalse_bothDrawWithoutThrowing', () {
      final painter = CockpitPainter();
      for (final moving in <bool>[true, false]) {
        final canvas = _RecordingCanvas();
        expect(
          () => painter.paint(
            canvas,
            const Size(800, 600),
            TravelMode.car,
            moving: moving,
            glyphFor: (_) => null,
          ),
          returnsNormally,
        );
        expect(canvas.drawCalls, greaterThan(0));
      }
    });
  });
}

/// A no-op [Canvas] that counts draw* invocations. Lets us assert "painted
/// nothing" vs "painted something" without a real raster surface. Only the
/// draw primitives the CockpitPainter uses need real behaviour (none — they
/// are pure sinks here), so every method is a counted no-op.
class _RecordingCanvas implements Canvas {
  int drawCalls = 0;

  @override
  void noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (name.contains('draw')) {
      drawCalls++;
    }
  }
}
