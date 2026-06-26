// Deterministic behavioural tests for journey-dynamic-curve.
//
// Authored by test-script-author from tests/cases/journey-dynamic-curve.md. One
// group per case; each test name + comment carries its TC-ID + AC-ID for
// traceability. Sits alongside the build-time measurement guards in
// journey_dynamic_curve_test.dart (TC-401/402/405/407/408) — DO NOT duplicate
// those; this file is the remaining behavioural/freeze/PiP/golden suite.
//
//   TC-403 (AC-3, AC-4) — bend sweeps, is smooth, and is a deterministic,
//                         repeatable function of scroll phase only (replay same
//                         scrollOffset → byte-identical ±1e-9). The static
//                         "no second clock" leg is in
//                         journey_dynamic_curve_separation_static_test.dart.
//   TC-404 (AC-4)       — single shared phase (behavioural): phase frozen → the
//                         bend is constant frame-to-frame (no second motion src).
//   TC-406 (AC-6, NFR-1)— the arc-length-aware fork stays alloc-free / O(1):
//                         no per-frame allocation on advance (stable render draw
//                         structure), bounded-pool plateau ≤ capacity over a long
//                         sharper-curve run, and the cadence math is constant-cost
//                         (reuses the geometry's closed-form slope, not a growing
//                         loop). An ADR for the arc-length-aware fork is PENDING
//                         (spec Resolved decision 4) — see report.
//   TC-411 (AC-10,NFR-3)— reduce-motion freeze: frozen roadScrollOffset AND
//                         identical centreLineOffsetAt(t) across pumps (±1e-6).
//   TC-412 (AC-11,NFR-3)— PiP read: the road CENTRE-LINE stays on screen
//                         (|centreLineOffset| ≤ width/2) across a full sweep at a
//                         PiP size and a full-window size, and the bend sweeps.
//   TC-413 (AC-1/2/3/7) — golden (structural, per repo precedent — no PNG
//                         baseline): swept sharper-curve active frame is stable.
//   TC-414 (AC-10)      — golden (structural): reduce-motion held frame is stable.
//
// Drives JourneyGame ONLY via applyState(...) + update(dt) — no real OS, no real
// timers, no wall-clock waits (tests/cases/journey-dynamic-curve.md conventions).
//
// GOLDEN PRECEDENT: this repo ships NO committed golden PNG baselines and uses
// NO matchesGoldenFile anywhere (see journey_scene_art_v3_test.dart TC-313/314 +
// its header). So TC-413/TC-414 are expressed as DETERMINISTIC frame-render
// structural assertions (render the pinned frame into a recording canvas; assert
// the curve is composited and re-rendering the SAME frame is byte-stable in draw
// structure). No `--update-goldens` run is required.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/road_painter.dart';
import 'package:focus_journey/features/journey/presentation/game/scene_motion.dart';

import 'journey_game_test_harness.dart';

const double kEps = 1e-6;

/// A canvas that records each draw's vertical extent + counts drawImageRect /
/// drawPath calls — the structural fingerprint of one rendered frame (used by
/// the golden-structural cases per the repo's no-PNG-baseline precedent).
class _RecordingCanvas implements Canvas {
  final List<({double minY, double maxY})> rects =
      <({double minY, double maxY})>[];
  int imageRectCount = 0;
  int pathCount = 0;

  void _add(double a, double b) =>
      rects.add((minY: a < b ? a : b, maxY: a < b ? b : a));

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
    pathCount++;
    final Rect b = path.getBounds();
    _add(b.top, b.bottom);
  }

  @override
  void drawImageRect(Image image, Rect src, Rect dst, Paint paint) {
    imageRectCount++;
    _add(dst.top, dst.bottom);
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const double width = 1280;
  const double height = 720;
  final Vector2 viewport = Vector2(width, height);
  // One full heading cycle of the curve (16 segments × 900 px) — the sweep span
  // over which the sharpest bends are exercised. The baseline segmentLength
  // (900) is the pinned journey-scene-v2 value, used here only to size the
  // sweep window (independent of the shipped params).
  const double cycle = 16 * 900.0;

  // ===========================================================================
  // TC-403 (AC-3, AC-4) — sweeps, smooth, deterministic + repeatable (behaviour).
  // ===========================================================================
  group('TC-403 bend sweeps smoothly + deterministically with scroll (AC-3/4)', () {
    test('sweepsNonConstant_thenReplaysByteIdentical_andStaysSmooth', () {
      final game = buildMotionGame(size: viewport, cruiseSpeed: kV2CruiseSpeed);
      driveActive(game);
      pump(game, frames: 120); // reach cruise

      // PASS 1 — advance the scroll phase one full cycle, recording (scrollOffset,
      // near-camera centre-line) on each frame.
      final List<double> recordedOffsets = <double>[];
      final List<double> pass1 = <double>[];
      while (game.roadScrollOffset < cycle) {
        game.update(kFrameDt);
        recordedOffsets.add(game.roadScrollOffset);
        pass1.add(game.centreLineOffsetAt(1.0));
      }
      expect(recordedOffsets.length, greaterThan(50));

      // (a) SWEEPS — the offset is non-constant as the phase advances.
      final double minV = pass1.reduce(math.min);
      final double maxV = pass1.reduce(math.max);
      expect(
        maxV - minV,
        greaterThan(1.0),
        reason: 'AC-3: the bend must sweep (non-constant centre-line offset)',
      );

      // (c) DETERMINISTIC / REPEATABLE — a painter sampling the SAME recorded
      // scrollOffset values a second time yields byte-identical output (±1e-9).
      // (Re-deriving via a fresh painter at the same size + the recorded offsets,
      // exactly as the scene would on a replay of the same phase.)
      final RoadPainter replay = RoadPainter();
      const Size size = Size(width, height);
      for (int i = 0; i < recordedOffsets.length; i++) {
        final double second = replay.centreLineOffset(
          size,
          recordedOffsets[i],
          1.0,
        );
        expect(
          second,
          closeTo(pass1[i], 1e-9),
          reason:
              'AC-3: same scrollOffset must yield byte-identical centre-line '
              '(deterministic/repeatable) at offset ${recordedOffsets[i]}',
        );
      }

      // (b) SMOOTH — consecutive cruise-frame steps show no discontinuity: every
      // frame-to-frame change stays under the AC-7 per-frame cap (≤ 2% width).
      const double cap = 0.02 * width;
      double worstStep = 0;
      for (int i = 1; i < pass1.length; i++) {
        final double step = (pass1[i] - pass1[i - 1]).abs();
        if (step > worstStep) worstStep = step;
      }
      expect(
        worstStep,
        lessThanOrEqualTo(cap),
        reason:
            'AC-3/AC-7: per-frame centre-line step ($worstStep px) must be '
            'smooth (≤ $cap px = 2% width)',
      );
    });
  });

  // ===========================================================================
  // TC-404 (AC-4) — single shared phase (behavioural): frozen phase → bend const.
  // ===========================================================================
  group('TC-404 single shared phase — frozen phase freezes the bend (AC-4)', () {
    test('phaseHeldViaReduceMotion_bendIsConstantFrameToFrame', () {
      // Hold the scroll phase by freezing it (reduce-motion ⇒ scrollDelta 0).
      // If the curve had a SECOND motion source (a clock/timer/RNG), the bend
      // would animate even with the phase frozen. It must not.
      final game = buildMotionGame(size: viewport, cruiseSpeed: kV2CruiseSpeed);
      game.applyState(
        moving: true,
        mode: TravelMode.motorbike,
        reduceMotion: true,
        timeOfDayHours: 12,
      );
      // Sample the bend at several depths across many pumps; with the phase
      // frozen every sample must be identical frame-to-frame (no second clock).
      const List<double> depths = <double>[0.25, 0.5, 0.75, 1.0];
      final List<double> first = <double>[
        for (final t in depths) game.centreLineOffsetAt(t),
      ];
      for (int frame = 0; frame < 300; frame++) {
        game.update(kFrameDt);
        for (int d = 0; d < depths.length; d++) {
          expect(
            game.centreLineOffsetAt(depths[d]),
            closeTo(first[d], kEps),
            reason:
                'AC-4: with the shared phase frozen the bend must be constant '
                'frame-to-frame at depth ${depths[d]} (no second motion source)',
          );
        }
      }
      // The phase really is frozen (nothing advanced it).
      expect(game.roadScrollOffset, closeTo(0, kEps));
    });
  });

  // ===========================================================================
  // TC-406 (AC-6, NFR-1) — arc-length-aware fork stays alloc-free / O(1).
  // ===========================================================================
  group('TC-406 arc-length-aware cadence stays alloc-free / O(1) (AC-6/NFR-1)', () {
    // ADR PENDING: the spawn cadence took the arc-length-aware fork (spec
    // Resolved decision 4 — a fixed longitudinal cadence broke ±20% at wide
    // viewports with the sharper curve). An ADR documenting that fork is being
    // added (docs/architecture/decisions/) — see the test-script-author report.

    test('liveCount_plateausAtOrBelowCapacity_overLongSharperCurveRun', () {
      const int capacity = 24;
      final game = buildMotionGame(
        size: viewport,
        cruiseSpeed: kV2CruiseSpeed,
        sideObjectCapacity: capacity,
      );
      driveActive(game);
      int maxLive = 0;
      for (int i = 0; i < 12000; i++) {
        game.update(kFrameDt);
        if (game.liveSideObjectCount > maxLive) {
          maxLive = game.liveSideObjectCount;
        }
        expect(
          game.liveSideObjectCount,
          lessThanOrEqualTo(capacity),
          reason:
              'AC-6/NFR-1: bounded pool — live count must never exceed '
              'capacity with the sharper arc-length cadence',
        );
      }
      expect(game.sideObjectCapacity, capacity);
      expect(maxLive, greaterThan(0), reason: 'the pool must actually fill');
    });

    test(
      'renderDrawStructure_isStableFrameToFrame_noPerFrameGeometryLeak',
      () async {
        // No-per-frame-allocation PROXY (the repo's structural convention — see
        // cockpit_render_behaviour_test.dart): a per-frame heap allocation of new
        // geometry would manifest as a GROWING draw structure across frames. The
        // recorded draw counts must be STABLE between two consecutive frozen-phase
        // renders (same live pool, same scratch paths reused). The render path
        // needs the sprite store initialised → use the sprite-backed harness.
        final game = await loadJourneyGame(size: viewport);
        driveActive(game);
        pump(game, frames: 400); // fill the pool with the sharper curve live.
        game.applyState(
          moving: true,
          mode: TravelMode.motorbike,
          reduceMotion: true, // freeze so the two frames are identical inputs.
          timeOfDayHours: 12,
        );
        final a = _RecordingCanvas();
        game.render(a);
        final b = _RecordingCanvas();
        game.render(b);
        expect(
          a.rects.length,
          b.rects.length,
          reason:
              'NFR-1: draw count must be stable (no per-frame geometry alloc)',
        );
        expect(a.pathCount, b.pathCount);
        expect(a.imageRectCount, b.imageRectCount);
      },
    );

    test('arcLengthCadenceCost_isConstant_independentOfWorldDistanceMagnitude', () {
      // The cadence math reuses the geometry's CLOSED-FORM slope (one slope +
      // one sqrt per frame), NOT a growing accumulating loop. Proxy: advancing
      // the SAME single frame's scroll delta produces the SAME number of spawns
      // whether the pool is fresh (small worldDistance) or has scrolled a huge
      // distance — the per-frame work does not grow with worldDistance. We check
      // the spawn cadence keeps emitting at a bounded steady rate over a very
      // long run (it would stall or blow up if the cost grew with distance).
      final game = buildMotionGame(
        size: viewport,
        cruiseSpeed: kV2CruiseSpeed,
        sideObjectCapacity: 64,
      );
      driveActive(game);
      pump(game, frames: 120);

      int countSpawnsOver(int frames) {
        double lastMax = game.liveSpawnDistances.isEmpty
            ? -1
            : game.liveSpawnDistances.last;
        int spawned = 0;
        for (int i = 0; i < frames; i++) {
          game.update(kFrameDt);
          final live = game.liveSpawnDistances;
          if (live.isNotEmpty && live.last > lastMax) {
            for (final d in live) {
              if (d > lastMax) spawned++;
            }
            lastMax = live.last;
          }
        }
        return spawned;
      }

      // Early window (small worldDistance).
      final int early = countSpawnsOver(3000);
      // Skip far ahead so worldDistance is large, then measure again.
      pump(game, frames: 30000);
      final int late = countSpawnsOver(3000);

      expect(early, greaterThan(0));
      expect(late, greaterThan(0));
      // Constant-cost: the spawn rate over equal windows stays comparable at a
      // huge worldDistance (no growth/decay from a distance-dependent loop). The
      // arc factor varies the longitudinal rate slightly with the bend, so allow
      // a generous band — what we reject is the rate collapsing toward 0 (a
      // growing-loop stall) or exploding.
      expect(
        late,
        greaterThan(early ~/ 2),
        reason:
            'NFR-1: arc-length cadence cost must stay constant — the spawn '
            'rate must not collapse at huge worldDistance (no growing loop)',
      );
      expect(late, lessThan(early * 3), reason: 'rate must not explode either');
    });
  });

  // ===========================================================================
  // TC-411 (AC-10, NFR-3) — reduce-motion freezes the sweep.
  // ===========================================================================
  group(
    'TC-411 reduce-motion freezes the sweep — sharper curve still freezes (AC-10/NFR-3)',
    () {
      test('frozenScrollOffset_andIdenticalCentreLineSamples_acrossPumps', () {
        final game = buildMotionGame(
          size: viewport,
          cruiseSpeed: kV2CruiseSpeed,
        );
        game.applyState(
          moving: true,
          mode: TravelMode.motorbike,
          reduceMotion: true,
          timeOfDayHours: 12,
        );
        const List<double> depths = <double>[0.2, 0.5, 0.8, 1.0];
        final List<double> baselineSamples = <double>[
          for (final t in depths) game.centreLineOffsetAt(t),
        ];
        double prevOffset = game.roadScrollOffset;
        for (int frame = 0; frame < 300; frame++) {
          game.update(kFrameDt);
          // Frozen scroll offset (scrollDelta == 0 under reduce-motion).
          expect(
            game.roadScrollOffset,
            closeTo(prevOffset, kEps),
            reason: 'AC-10: reduce-motion must freeze the scroll phase',
          );
          prevOffset = game.roadScrollOffset;
          // Identical centre-line samples frame-to-frame (the sharper curve adds
          // no clock that would animate it under reduce-motion).
          for (int d = 0; d < depths.length; d++) {
            expect(
              game.centreLineOffsetAt(depths[d]),
              closeTo(baselineSamples[d], kEps),
              reason:
                  'AC-10/NFR-3: bend must be frozen at depth ${depths[d]} under '
                  'reduce-motion (sharper curve introduced no new motion source)',
            );
          }
        }
        expect(game.scrollVelocity, 0);
      });
    },
  );

  // ===========================================================================
  // TC-412 (AC-11, NFR-3) — road centre-line stays on screen at PiP + full size.
  // ===========================================================================
  group(
    'TC-412 sharper curve centre-line stays on-screen at PiP + full size (AC-11/NFR-3)',
    () {
      // CORRECTED BOUND (spec AC-11; cases-file literal was rejected). The original
      // cases-file literal `|centreLineOffset| + nearHalf ≤ width/2` (road EDGE
      // inside the viewport) is UNSATISFIABLE EVEN AT BASELINE: the trapezoid's
      // _roadNearHalfFrac = 0.46 plus the amplitude already pushes the near road
      // EDGE past width/2 BY DESIGN (the road edge intentionally extends past the
      // viewport so the road fills the bottom of the frame — true at the
      // journey-scene-v2 baseline too, NOT a sharper-curve regression). Per spec
      // AC-11 the satisfiable invariant is the road CENTRE-LINE staying on screen:
      // |centreLineOffset(size, off, 1.0)| ≤ width/2 (really ≤ curveAmplitudeFrac·
      // width = 0.20·width, a comfortable margin). The real frameless-PiP edge
      // visual read is the manual TC-M-PIP.
      final List<({String label, Size size})> surfaces =
          <({String label, Size size})>[
            (label: 'PiP', size: const Size(360, 220)),
            (label: 'full', size: const Size(1280, 800)),
          ];

      for (final s in surfaces) {
        test('centreLineStaysOnScreen_andSweeps_at_${s.label}', () {
          final painter = RoadPainter(); // shipped sharper geometry + amplitude
          final Size size = s.size;
          final double half = size.width / 2;
          final double amplitudeBound =
              size.width * RoadPainter.curveAmplitudeFrac;
          double minOff = double.infinity;
          double maxOff = -double.infinity;
          for (double off = 0; off <= cycle; off += 2.0) {
            final double c = painter.centreLineOffset(size, off, 1.0);
            // On screen: the centre-line never leaves the viewport.
            expect(
              c.abs(),
              lessThanOrEqualTo(half),
              reason:
                  'AC-11: road centre-line must stay on screen at ${s.label} '
                  '(|$c| ≤ $half) for offset $off',
            );
            // And in fact within the design amplitude margin (≤ 0.20·width).
            expect(
              c.abs(),
              lessThanOrEqualTo(amplitudeBound + kEps),
              reason:
                  'AC-11: |centreLineOffset| ($c) ≤ curveAmplitudeFrac·width '
                  '($amplitudeBound) at ${s.label}, offset $off',
            );
            if (c < minOff) minOff = c;
            if (c > maxOff) maxOff = c;
          }
          // The bend still READS as a sweeping curve (non-constant excursion).
          expect(
            maxOff - minOff,
            greaterThan(1.0),
            reason:
                'AC-11: the bend must still sweep at ${s.label} '
                '(non-constant centre-line)',
          );
        });
      }
    },
  );

  // ===========================================================================
  // TC-413 (AC-1/2/3/7) — golden (structural): swept sharper-curve active frame.
  // ===========================================================================
  group('TC-413 swept sharper-curve active frame is stable (AC-1/2/3/7 golden)', () {
    test('pinnedSweptActiveFrame_isDeterministicAndCompositesTheCurve', () async {
      // Fixed mode + fixed injected day-time + a fixed (non-zero) scroll phase
      // mid-sweep + active + reduce-motion OFF → ON to hold the phase. Per the
      // repo's no-PNG-baseline golden precedent we assert the pinned frame's
      // draw structure is byte-stable across re-renders (determinism guard).
      final game = await loadJourneyGame(size: viewport);
      // Advance to a fixed non-zero phase mid-sweep with the sharper curve live.
      game.applyState(
        moving: true,
        mode: TravelMode.motorbike,
        reduceMotion: false,
        timeOfDayHours: 12,
      );
      while (game.roadScrollOffset < 3500) {
        game.update(kFrameDt);
      }
      // Freeze the phase so the pinned frame is reproducible.
      game.applyState(
        moving: true,
        mode: TravelMode.motorbike,
        reduceMotion: true,
        timeOfDayHours: 12,
      );

      final a = _RecordingCanvas();
      game.render(a);
      final b = _RecordingCanvas();
      game.render(b);

      // Determinism (the "golden is stable" leg, structural): identical draw
      // structure on a re-render of the SAME pinned frame.
      expect(a.rects.length, b.rects.length);
      expect(a.pathCount, b.pathCount);
      expect(a.imageRectCount, b.imageRectCount);

      // The sharper bend is actually rendered on screen at this phase (AC-2):
      // the near-camera centre-line is materially displaced from straight.
      final double nearOffset = game.centreLineOffsetAt(1.0).abs();
      expect(
        nearOffset,
        greaterThan(1.0),
        reason: 'AC-2/AC-3: the swept active frame must show a displaced bend',
      );
      // The road body + lanes are drawn (paths present) — the trapezoid scene.
      expect(a.pathCount, greaterThan(0));
    });
  });

  // ===========================================================================
  // TC-414 (AC-10) — golden (structural): reduce-motion held frame (curve frozen).
  // ===========================================================================
  group('TC-414 reduce-motion held frame is stable (AC-10 golden)', () {
    test(
      'reduceMotionHeldFrame_isFrozenAcrossPumps_andStableOnReRender',
      () async {
        final game = await loadJourneyGame(size: viewport);
        game.applyState(
          moving: true,
          mode: TravelMode.motorbike,
          reduceMotion: true,
          timeOfDayHours: 12,
        );
        // First render of the held frame.
        final first = _RecordingCanvas();
        game.render(first);
        final double heldNear = game.centreLineOffsetAt(1.0);

        // Pump several frames — under reduce-motion the bend must not animate.
        pump(game, frames: 120);
        final second = _RecordingCanvas();
        game.render(second);

        // The held frame is identical in draw structure after the pumps (frozen).
        expect(first.rects.length, second.rects.length);
        expect(first.pathCount, second.pathCount);
        expect(first.imageRectCount, second.imageRectCount);
        // And the bend itself is unchanged (curve does not animate under RM).
        expect(
          game.centreLineOffsetAt(1.0),
          closeTo(heldNear, kEps),
          reason: 'AC-10: the curve must be frozen under reduce-motion',
        );
        expect(game.roadScrollOffset, closeTo(0, kEps));
      },
    );
  });
}
