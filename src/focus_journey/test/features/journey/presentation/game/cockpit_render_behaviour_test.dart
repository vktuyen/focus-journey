// Case-level / behavioural tests for journey-pov, driven through the PUBLIC
// scene render path (`JourneyGame.render(canvas)` + `applyState` + `update`).
//
// These are the BEHAVIOURAL cases from tests/cases/journey-pov.md that the
// seam-level units (cockpit_seams_test.dart / cockpit_assets_test.dart) do NOT
// already assert — they exercise the actual composited render, the framing
// ratio in pixels, mode-gating + clean revert/restore at the render level,
// reduce-motion, and the parked/idle parks.
//
// Conventions (tests/cases/journey-pov.md): NO real OS, NO real timers, NO
// wall-clock waits. The scene is driven through applyState(...) with plain
// values; frames advance via update(dt). Render is exercised against a
// bounds-recording Canvas (no raster surface needed) — the COCKPIT is isolated
// as the DIFFERENCE between a cockpit-mode render and the no-cockpit baseline
// render at the same scroll phase, so we measure exactly the cockpit's draws.
//
// The game is sprite-backed via the shared harness `loadJourneyGame()` (which
// runs the real never-throws `loadAll`; the cockpit glyphs degrade to original
// flat-shape fallbacks where unsourced — AC-13), because `render()` needs the
// sprite store initialised. Motion-only seam tests use `buildMotionGame()`.
//
// Covers (case → AC):
//   TC-201 AC-1  — car cockpit composited over the road; upper viewport still scrolls
//   TC-203 AC-3  — motorbike cockpit composited; upper viewport still scrolls
//   TC-202 AC-2  — gauges decorative: cockpit geometry varies ONLY with `moving`
//   TC-205 AC-5  — framing ratio: cockpit's added draws sit in the lower 30%..40%
//   TC-206 AC-6  — walk/run/bicycle/ship: no cockpit drawn + side-view sprite path
//   TC-207 AC-7  — clean revert: no residual cockpit draws after switch away
//   TC-208 AC-8  — restore on switch back to car/motorbike
//   TC-217 AC-14 — reduce-motion: cockpit adds no new motion; scroll still suppressed
//   TC-218 AC-15 — first-frame parked + idle/paused parks preserved under a cockpit
//   TC-220 NFR-1 — cockpit adds no per-frame growth in draw work across pumps
//
// Already covered by the unit tests (NOT re-authored here, see report):
//   the isCockpitActive / cockpitAssetPaths seams (cockpit_seams_test.dart),
//   the manifest membership + draw-order (cockpit_assets_test.dart), the
//   placeholder/never-throws degradation (cockpit_seams + journey_assets), the
//   cockpitViewportFraction CONSTANT band (cockpit_seams_test.dart).

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/cockpit_painter.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_game.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_skins.dart';

import 'journey_game_test_harness.dart';

const double kEps = 1e-6;
double get _viewW => kTestViewport.x;
double get _viewH => kTestViewport.y;

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

/// A no-op [Canvas] that records, per primitive-draw call, the vertical extent
/// (`minY`..`maxY`) of the geometry it was handed. Lets us measure WHERE the
/// scene drew without a raster surface. We intercept the draw* primitives the
/// scene + cockpit use (rect/rrect/circle/line/path/imageRect); anything else
/// is an untracked no-op (those calls touch no geometry we measure).
class _BoundsCanvas implements Canvas {
  final List<({double minY, double maxY})> draws =
      <({double minY, double maxY})>[];

  void _add(double a, double b) =>
      draws.add((minY: a < b ? a : b, maxY: a < b ? b : a));

  @override
  void drawRect(Rect rect, Paint paint) => _add(rect.top, rect.bottom);
  @override
  void drawRRect(RRect rrect, Paint paint) => _add(rrect.top, rrect.bottom);
  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      _add(c.dy - radius, c.dy + radius);
  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => _add(p1.dy, p2.dy);
  @override
  void drawPath(Path path, Paint paint) {
    final Rect b = path.getBounds();
    _add(b.top, b.bottom);
  }

  @override
  void drawImageRect(Image image, Rect src, Rect dst, Paint paint) =>
      _add(dst.top, dst.bottom);
  @override
  void noSuchMethod(Invocation invocation) {}
}

/// The recorded draws of one rendered frame: per-draw vertical extents.
typedef FrameDraws = List<({double minY, double maxY})>;

/// Renders one frame of [game] and returns the recorded per-draw y-extents.
FrameDraws renderFrame(JourneyGame game) {
  final canvas = _BoundsCanvas();
  game.render(canvas);
  return canvas.draws;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A render-ready (sprite-backed) game with a frozen scroll for a
  // deterministic frame compare.
  Future<JourneyGame> frozenGame(TravelMode mode) async {
    final game = await loadJourneyGame();
    game.applyState(
      moving: true,
      mode: mode,
      reduceMotion: true, // freeze scroll so the scene portion is identical
      timeOfDayHours: 12,
    );
    return game;
  }

  // ===========================================================================
  // TC-201 / TC-203 — the cockpit foreground is composited over the road and
  // the upper viewport (road/scenery) stays visible and still scrolls (AC-1/3).
  // ===========================================================================
  group('TC-201/TC-203 cockpit composited over the road (AC-1/AC-3)', () {
    for (final mode in _cockpitModes) {
      test(
        '${mode.name}_render_addsCockpitDrawsOverTheBaselineScene',
        () async {
          // Baseline: a non-cockpit mode (walk) at the SAME (frozen) phase.
          final baseline = await frozenGame(TravelMode.walk);
          final int baselineDraws = renderFrame(baseline).length;

          // Cockpit mode at the same frozen phase.
          final cockpit = await frozenGame(mode);
          final int cockpitDraws = renderFrame(cockpit).length;

          expect(
            cockpitDraws,
            greaterThan(baselineDraws),
            reason:
                '$mode must composite a cockpit foreground over the road '
                '(more draw calls than the no-cockpit baseline)',
          );
          expect(cockpit.isCockpitActive, isTrue);
        },
      );

      test('${mode.name}_upperViewport_remainsVisibleAndStillScrolls', () async {
        // AC-1/AC-3: the road "through the windshield / over the handlebars"
        // is NOT fully occluded — the scene keeps scrolling above the cockpit.
        final game = await loadJourneyGame();
        driveActive(game, mode: mode);
        pump(game, frames: 120); // reach cruise
        final double before = game.roadScrollOffset;
        pump(game, frames: 120);
        expect(
          game.roadScrollOffset,
          greaterThan(before),
          reason: 'road must keep scrolling beneath/through the cockpit',
        );

        // The render touches the UPPER viewport (road/horizon drawn there), so
        // the cockpit has not fully occluded it.
        final frame = renderFrame(game);
        final double cockpitTop = _viewH * (1 - game.cockpitViewportFraction);
        final bool drewInUpperRegion = frame.any(
          (d) => d.minY < cockpitTop - 1.0,
        );
        expect(
          drewInUpperRegion,
          isTrue,
          reason: 'the road/scenery must still draw above the cockpit band',
        );
      });
    }
  });

  // ===========================================================================
  // TC-202 — gauges are DECORATIVE: the cockpit's drawn geometry must vary ONLY
  // with the `moving` flag, NEVER with timeOfDayHours (no numeric speed/fuel
  // input exists on the scene) (AC-2).
  // ===========================================================================
  group('TC-202 gauges decorative — geometry keys only off `moving` (AC-2)', () {
    // The COCKPIT-ONLY draws = the suffix the cockpit adds over the no-cockpit
    // (walk) baseline rendered with the SAME inputs. Differencing against walk
    // cancels the scene + day/night tint (which legitimately vary with the
    // clock) so we measure ONLY the cockpit's own geometry.
    Future<FrameDraws> draws({
      required TravelMode mode,
      required bool moving,
      required double timeOfDayHours,
    }) async {
      final cockpit = await loadJourneyGame();
      cockpit.applyState(
        moving: moving,
        mode: mode,
        reduceMotion: true, // freeze scroll → only the cockpit + tint can vary
        timeOfDayHours: timeOfDayHours,
      );
      final baseline = await loadJourneyGame();
      baseline.applyState(
        moving: moving,
        mode: TravelMode.walk,
        reduceMotion: true,
        timeOfDayHours: timeOfDayHours,
      );
      final all = renderFrame(cockpit);
      final base = renderFrame(baseline);
      // Cockpit-only = the draws beyond the shared (walk) scene + tint.
      return all.sublist(base.length);
    }

    test('car_geometryIndependentOf_timeOfDayHours_whenMovingFixed', () async {
      final atNoon = await draws(
        mode: TravelMode.car,
        moving: true,
        timeOfDayHours: 12,
      );
      final atMidnight = await draws(
        mode: TravelMode.car,
        moving: true,
        timeOfDayHours: 0,
      );
      // Same `moving`, wildly different clock → identical cockpit geometry
      // (it reads NO clock value; the day/night tint is a colour, not geometry).
      expect(atNoon.length, atMidnight.length);
      for (int i = 0; i < atNoon.length; i++) {
        expect(atNoon[i].minY, closeTo(atMidnight[i].minY, kEps));
        expect(atNoon[i].maxY, closeTo(atMidnight[i].maxY, kEps));
      }
    });

    test('car_needlePose_varies_ONLY_with_movingFlag', () {
      // Painter-level (no scene noise): the cockpit geometry responds to the
      // binary `moving` flag (decorative parked-vs-running needle pose) — and to
      // NOTHING else (there is no numeric speed/fuel input). All glyphs null so
      // the painter draws its flat fallback incl. the decorative needle.
      FrameDraws paintCar({required bool moving}) {
        final painter = CockpitPainter();
        final canvas = _BoundsCanvas();
        painter.paint(
          canvas,
          Size(_viewW, _viewH),
          TravelMode.car,
          moving: moving,
          glyphFor: (_) => null,
        );
        return canvas.draws;
      }

      final running = paintCar(moving: true);
      final parked = paintCar(moving: false);

      // Same element set drawn (count identical) — only the needle pose moves.
      expect(running.length, parked.length);
      bool anyDiff = false;
      for (int i = 0; i < running.length; i++) {
        if ((running[i].maxY - parked[i].maxY).abs() > 1e-3 ||
            (running[i].minY - parked[i].minY).abs() > 1e-3) {
          anyDiff = true;
          break;
        }
      }
      expect(
        anyDiff,
        isTrue,
        reason: 'the decorative needle pose must respond to the moving flag',
      );

      // And re-painting with the SAME moving flag is byte-identical (the pose is
      // a pure function of `moving` — no hidden numeric/continuous input).
      final parkedAgain = paintCar(moving: false);
      expect(parkedAgain.length, parked.length);
      for (int i = 0; i < parked.length; i++) {
        expect(parkedAgain[i].minY, closeTo(parked[i].minY, kEps));
        expect(parkedAgain[i].maxY, closeTo(parked[i].maxY, kEps));
      }
    });
  });

  // ===========================================================================
  // TC-205 — framing ratio: the cockpit's ADDED draws (vs the no-cockpit
  // baseline) sit in the lower portion of the viewport; the band is 30%..40% of
  // viewport height and the upper region stays unobscured (AC-5).
  // ===========================================================================
  group('TC-205 framing ratio — cockpit in the lower 30%..40% (AC-5)', () {
    for (final mode in _cockpitModes) {
      test('${mode.name}_cockpitBand_isWithin30to40pct_lowerViewport', () async {
        final game = await loadJourneyGame();
        driveActive(game, mode: mode);
        final double fraction = game.cockpitViewportFraction;
        expect(fraction, inInclusiveRange(0.30, 0.40));

        // The painter's cockpitTop equals height * (1 - fraction): the cockpit
        // occupies the lower `fraction` of the viewport.
        final double cockpitTop = CockpitPainter().cockpitTop(
          Size(_viewW, _viewH),
        );
        expect(cockpitTop, closeTo(_viewH * (1 - fraction), kEps));
        final double bandFraction = (_viewH - cockpitTop) / _viewH;
        expect(bandFraction, inInclusiveRange(0.30, 0.40));
      });

      test('${mode.name}_cockpitBulk_belowDashLine_roadUnobscuredAbove', () async {
        final double cockpitTop =
            _viewH * (1 - CockpitPainter.cockpitViewportFraction);

        final game = await frozenGame(mode);
        final cockpitDraws = renderFrame(game);

        final baseline = await frozenGame(TravelMode.walk);
        final baselineDraws = renderFrame(baseline);

        // The added draws are the suffix beyond the shared baseline scene (the
        // cockpit is composited AFTER the scene + tint).
        expect(cockpitDraws.length, greaterThan(baselineDraws.length));
        final added = cockpitDraws.sublist(baselineDraws.length);
        expect(added, isNotEmpty);

        // Most cockpit draws sit predominantly in the lower band (their VERTICAL
        // CENTRE is below the dash line). A few framing draws (A-pillars rising
        // to the top edge) are allowed, so we require a strong majority.
        final int inLowerBand = added
            .where((d) => (d.minY + d.maxY) / 2 >= cockpitTop - 1.0)
            .length;
        expect(
          inLowerBand,
          greaterThanOrEqualTo((added.length * 0.6).ceil()),
          reason:
              'the cockpit foreground must occupy the LOWER portion of the '
              'viewport (AC-5); added=${added.length} lower-band=$inLowerBand',
        );

        // The upper-region road/scenery draws are SHARED with the baseline
        // (the first baselineDraws.length draws are byte-identical) — the
        // cockpit did not alter them.
        for (int i = 0; i < baselineDraws.length; i++) {
          expect(cockpitDraws[i].minY, closeTo(baselineDraws[i].minY, kEps));
          expect(cockpitDraws[i].maxY, closeTo(baselineDraws[i].maxY, kEps));
        }
      });
    }
  });

  // ===========================================================================
  // TC-206 — mode-gating: walk/run/bicycle/ship draw NO cockpit and keep their
  // side-view sprite path (AC-6). Seam values are unit-tested; this is the
  // RENDER-level proof that no cockpit draws are added vs a bare scene.
  // ===========================================================================
  group('TC-206 mode-gating — no cockpit for non-cockpit modes (AC-6)', () {
    // A car cockpit render adds a substantial, fixed set of cockpit draws over
    // the bare scene. A non-cockpit mode must add NONE — so its render is
    // strictly SMALLER than the car-cockpit render (the cockpit layer absent)
    // and `isCockpitActive` is false. (We can't compare raw counts BETWEEN two
    // non-cockpit modes because their vehicle sprite/placeholder draws differ,
    // e.g. ship.png is intentionally missing → a placeholder.)
    for (final mode in _nonCockpitModes) {
      test(
        '${mode.name}_addsNoCockpitLayer_renderSmallerThanCarCockpit',
        () async {
          final nonCockpit = await frozenGame(mode);
          final carCockpit = await frozenGame(TravelMode.car);

          final int nonCockpitDraws = renderFrame(nonCockpit).length;
          final int carCockpitDraws = renderFrame(carCockpit).length;

          expect(nonCockpit.isCockpitActive, isFalse);
          expect(
            nonCockpitDraws,
            lessThan(carCockpitDraws),
            reason:
                '$mode must add NO cockpit foreground (AC-6); its render must be '
                'smaller than the car-cockpit render',
          );
          // Side-view sprite path is that mode's own skin (unchanged behaviour).
          expect(
            nonCockpit.currentVehicleAsset,
            JourneySkins.of(mode).assetPath,
          );
        },
      );
    }
  });

  // ===========================================================================
  // TC-207 / TC-208 — clean revert + restore at the RENDER level (AC-7/AC-8):
  // after switching to a non-cockpit mode the render has NO residual cockpit
  // draws (identical count to the bare scene); switching back restores them.
  // ===========================================================================
  group('TC-207/TC-208 clean revert + restore at render level (AC-7/AC-8)', () {
    for (final mode in _cockpitModes) {
      test('${mode.name}_thenWalk_leavesNoResidualCockpitDraws', () async {
        final game = await frozenGame(mode);
        final int withCockpit = renderFrame(game).length;

        // Switch away → revert.
        game.applyState(
          moving: true,
          mode: TravelMode.walk,
          reduceMotion: true,
          timeOfDayHours: 12,
        );
        final int afterRevert = renderFrame(game).length;

        // A freshly-built bare walk scene at the same frozen phase (the
        // reference for "no residual cockpit").
        final bare = await frozenGame(TravelMode.walk);
        final int bareWalk = renderFrame(bare).length;

        expect(withCockpit, greaterThan(bareWalk));
        expect(
          afterRevert,
          bareWalk,
          reason: 'revert must leave NO residual cockpit layer (AC-7)',
        );
        expect(game.isCockpitActive, isFalse);
      });

      test('${mode.name}_walk_${mode.name}_restoresCockpitCleanly', () async {
        final game = await frozenGame(mode);
        final int firstCockpit = renderFrame(game).length;

        game.applyState(
          moving: true,
          mode: TravelMode.walk,
          reduceMotion: true,
          timeOfDayHours: 12,
        );
        renderFrame(game);

        // Switch back → restored, identical render to the first cockpit render
        // (stateless painter, no carry-over from walk).
        game.applyState(
          moving: true,
          mode: mode,
          reduceMotion: true,
          timeOfDayHours: 12,
        );
        final int restored = renderFrame(game).length;

        expect(
          restored,
          firstCockpit,
          reason: 'restore must reproduce the cockpit cleanly (AC-8)',
        );
        expect(game.isCockpitActive, isTrue);
      });
    }
  });

  // ===========================================================================
  // TC-217 — reduce-motion: the cockpit adds NO new motion across pumps and the
  // inherited reduce-motion suppressed-scroll is unchanged by the cockpit
  // (AC-14 / NFR-3 reduce-motion leg).
  // ===========================================================================
  group('TC-217 reduce-motion — cockpit adds no new motion (AC-14)', () {
    for (final mode in _cockpitModes) {
      test(
        '${mode.name}_reduceMotionOn_cockpitGeometryFrozenAcrossPumps',
        () async {
          final game = await frozenGame(mode);
          final frame0 = renderFrame(game);
          pump(game, frames: 60);
          final frame1 = renderFrame(game);

          // With reduce-motion ON, NOTHING moves (scroll suppressed) — including
          // the cockpit (static foreground). Frame-over-frame is byte-identical.
          expect(frame0.length, frame1.length);
          for (int i = 0; i < frame0.length; i++) {
            expect(frame0[i].minY, closeTo(frame1[i].minY, kEps));
            expect(frame0[i].maxY, closeTo(frame1[i].maxY, kEps));
          }
          // And the inherited suppressed-scroll behaviour still holds.
          expect(game.roadScrollOffset, closeTo(0, kEps));
          expect(game.scrollVelocity, 0);
        },
      );

      test(
        '${mode.name}_reduceMotion_suppressedScroll_matchesNonCockpitBaseline',
        () {
          // The suppressed-scroll behaviour must be IDENTICAL with vs without
          // the cockpit (the cockpit does not re-introduce scroll). Motion-only
          // (no sprites needed — this checks the motion model, not the render).
          final cockpit = buildMotionGame();
          cockpit.applyState(
            moving: true,
            mode: mode,
            reduceMotion: true,
            timeOfDayHours: 12,
          );
          final baseline = buildMotionGame();
          baseline.applyState(
            moving: true,
            mode: TravelMode.walk,
            reduceMotion: true,
            timeOfDayHours: 12,
          );
          pump(cockpit, frames: 120);
          pump(baseline, frames: 120);
          expect(cockpit.roadScrollOffset, closeTo(0, kEps));
          expect(baseline.roadScrollOffset, closeTo(0, kEps));
          expect(cockpit.scrollVelocity, baseline.scrollVelocity);
        },
      );
    }
  });

  // ===========================================================================
  // TC-218 — first-frame parked + idle/paused parks preserved under a cockpit
  // (AC-15). The cockpit overlays the parks without forcing motion.
  // ===========================================================================
  group('TC-218 first-frame parked + idle parks under a cockpit (AC-15)', () {
    test('beforeFirstApplyState_parkedDefault_rendersWithoutMotion', () async {
      // hasReceivedState == false: the parked/stopped default holds, and the
      // scene renders (the default mode is a cockpit mode — motorbike).
      final game = await loadJourneyGame();
      expect(game.hasReceivedState, isFalse);
      final f0 = renderFrame(game);
      pump(game, frames: 60);
      final f1 = renderFrame(game);
      // No motion before any state (the scene is parked at offset 0).
      expect(game.roadScrollOffset, closeTo(0, kEps));
      expect(f0.length, f1.length);
      for (int i = 0; i < f0.length; i++) {
        expect(f0[i].minY, closeTo(f1[i].minY, kEps));
      }
    });

    for (final mode in _cockpitModes) {
      test(
        '${mode.name}_idleStopped_freezesRoad_cockpitDoesNotForceMotion',
        () {
          // Motion-only (no render needed): the cockpit mode must not keep the
          // road moving when stopped.
          final game = buildMotionGame();
          driveActive(game, mode: mode);
          pump(game, frames: 120);
          expect(game.roadScrollOffset, greaterThan(0));

          driveStopped(game, mode: mode);
          pump(game, frames: 90); // settle the ease
          final double parked = game.roadScrollOffset;
          pump(game, frames: 200);
          expect(game.roadScrollOffset, closeTo(parked, kEps));
          expect(game.isVehicleRunning, isFalse);
          expect(game.scrollVelocity, 0);
          expect(game.isCockpitActive, isTrue);
        },
      );
    }
  });

  // ===========================================================================
  // TC-220 — NFR-1 hot-path: across many pumps the cockpit adds NO growth in
  // per-frame draw work (static composited layer; bounded). Deterministic proxy
  // for "no per-frame allocation / no new per-frame geometry" — the draw count
  // for a cockpit frame is stable across the run (no leak/growth).
  // ===========================================================================
  group('TC-220 NFR-1 hot-path — cockpit draw work is bounded/stable', () {
    for (final mode in _cockpitModes) {
      test('${mode.name}_drawCount_isStableAcrossManyPumps', () async {
        final game = await loadJourneyGame();
        driveActive(game, mode: mode);
        pump(game, frames: 200); // fill the bounded pool, reach cruise

        final int first = renderFrame(game).length;
        int maxSeen = first;
        int minSeen = first;
        for (int i = 0; i < 400; i++) {
          pump(game, frames: 3);
          final int n = renderFrame(game).length;
          if (n > maxSeen) maxSeen = n;
          if (n < minSeen) minSeen = n;
        }
        // The draw count stays bounded — it does not grow without bound (which
        // a per-frame leak/allocation of cockpit geometry would cause). The
        // pool is bounded and the cockpit is a fixed set of draws.
        expect(
          maxSeen - minSeen,
          lessThanOrEqualTo(game.sideObjectCapacity),
          reason:
              'draw count must stay bounded with the cockpit loaded '
              '(min=$minSeen max=$maxSeen); a per-frame cockpit leak would grow '
              'it unboundedly',
        );
        expect(
          game.liveSideObjectCount,
          lessThanOrEqualTo(game.sideObjectCapacity),
        );
      });
    }
  });
}
