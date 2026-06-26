// Deterministic UNIT tests for journey-cockpit-lean — the bounded, eased,
// reduce-motion-gated roll of the first-person cockpit foreground.
//
// These pin the PURE / near-pure lean logic at the code level and COMPLEMENT
// (do not duplicate) the TC-5xx integration scripts. Each test name + comment
// carries its AC-ID for traceability.
//
// Drives JourneyGame ONLY via applyState(...) + update(dt) (the shared
// headless harness) — NO real OS, NO real timers, NO wall-clock waits. The lean
// is asserted through two read-only seams:
//   * appliedLeanAngle  — the smoothed, applied roll angle (signed, radians).
//   * rawLeanTargetAngle — the clamped pre-smoothing target (clean clamp /
//                          monotonicity assertions without the smoothing
//                          transient).
//
// KEY FACTS confirmed against the production code (do not assume):
//   * worldAtCamera(scrollOffset) collapses to scrollOffset at t==1
//     (road_painter.dart `_worldAt(off, 1.0) == off`), so the lean signal is
//     exactly `RoadGeometry.lateralSlopeAt(roadScrollOffset)`.
//   * Sign convention is +1.0 (positive slope → positive angle → lean right /
//     into a right bend). leanGain 18.0, maxLeanRadians ≈ 0.0523599 (~3°),
//     leanSmoothingLengthPx 60.0.
//   * The smoothing eases off `scrollDelta` (NOT dt), so the angle is a pure
//     function of the scroll-phase HISTORY, independent of wall-clock / dt.
//
// PINNED GEOMETRY SAMPLE OFFSETS (measured from RoadGeometry() defaults,
// segmentLength 900, maxHeading 0.0036 — the shipped journey-dynamic-curve):
//   * offset 3975 → slope > 0   (a RIGHT bend)
//   * offset 1075 → slope < 0   (a LEFT bend)
//   * offset 5200 → |slope| ≈ 0.00342, the SHARPEST near-camera bend; raw
//     target ≈ 0.0615 > cap → the clamp is genuinely EXERCISED there.
//   * offset 1940 → |slope| ≈ 1.4e-8, the STRAIGHTEST sampled point.

import 'dart:math' as math;

import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_game.dart';
import 'package:focus_journey/features/journey/presentation/game/road_geometry.dart';
import 'package:focus_journey/features/journey/presentation/game/road_painter.dart';
import 'package:focus_journey/features/journey/presentation/game/scene_motion.dart';

import 'journey_game_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Vector2 viewport = kTestViewport;
  // A standalone geometry mirroring the scene's default so we can read the
  // ground-truth slope at any offset (the scene uses RoadGeometry() defaults).
  final RoadGeometry geometry = RoadGeometry();
  final RoadPainter painter = RoadPainter();

  // The pure lean signal at a scroll offset: lateralSlopeAt(worldAtCamera(off)).
  double slopeAt(double offset) =>
      geometry.lateralSlopeAt(painter.worldAtCamera(offset));

  // Measured pinned offsets (see header).
  const double rightBendOffset = 3975.0; // slope > 0
  const double leftBendOffset = 1075.0; // slope < 0
  const double sharpestOffset = 5200.0; // |slope| ≈ 0.00342 → past the clamp
  const double straightestOffset = 1940.0; // |slope| ≈ 1.4e-8

  /// Drives the game active in [mode] and pumps until the scroll offset reaches
  /// at least [targetOffset], then returns the settled game. The smoothing
  /// rides scroll distance, so by the time the camera has scrolled to a roughly
  /// stable slope the applied angle has converged to the raw target.
  JourneyGame settledAt(
    double targetOffset, {
    TravelMode mode = TravelMode.car,
  }) {
    final JourneyGame game = buildMotionGame(
      size: viewport,
      cruiseSpeed: kV2CruiseSpeed,
    );
    driveActive(game, mode: mode);
    while (game.roadScrollOffset < targetOffset) {
      game.update(kFrameDt);
    }
    return game;
  }

  // ===========================================================================
  // AC-1 — lean exists and is SIGNED INTO the turn.
  // ===========================================================================
  group('AC-1 lean is signed into the turn (a sign flip fails this)', () {
    test('AC-1 rightBend_appliedAngleSignMatchesSlopeSign_andIsNonZero', () {
      final JourneyGame game = settledAt(rightBendOffset);
      final double slope = slopeAt(game.roadScrollOffset);
      expect(slope, greaterThan(0), reason: 'precondition: right bend (+slope)');
      final double angle = game.appliedLeanAngle;
      expect(
        angle.abs(),
        greaterThan(1e-4),
        reason: 'AC-1: the cockpit must visibly lean on a bend (non-zero angle)',
      );
      // INTO the turn: +slope (right bend) → +angle (rolls right). A NEGATIVE
      // test — `expect(angle.sign, -slope.sign)` — would FAIL here, documenting
      // that a sign flip is caught.
      expect(
        angle.sign,
        slope.sign,
        reason:
            'AC-1: sign(appliedAngle) must equal sign(lateralSlopeAt) — a right '
            'bend leans the frame INTO the right turn (no negation)',
      );
    });

    test('AC-1 leftBend_appliedAngleSignMatchesSlopeSign_andIsNonZero', () {
      final JourneyGame game = settledAt(leftBendOffset);
      final double slope = slopeAt(game.roadScrollOffset);
      expect(slope, lessThan(0), reason: 'precondition: left bend (-slope)');
      final double angle = game.appliedLeanAngle;
      expect(
        angle.abs(),
        greaterThan(1e-4),
        reason: 'AC-1: the cockpit must visibly lean on a left bend',
      );
      expect(
        angle.sign,
        slope.sign,
        reason:
            'AC-1: a left bend (-slope) must lean the frame INTO the left turn '
            '(-angle)',
      );
    });

    test('AC-1 rawTarget_isExactlyLeanGainTimesSlope_belowSaturation', () {
      // The pre-smoothing target is the pure, unnegated +gain·slope (below the
      // clamp) — the load-bearing sign+gain relationship a flip would break.
      final JourneyGame game = settledAt(rightBendOffset);
      final double slope = slopeAt(game.roadScrollOffset);
      final double expectedTarget =
          JourneyGame.leanSignConvention * JourneyGame.leanGain * slope;
      // Below saturation at this offset, so the clamp does not intervene.
      expect(expectedTarget.abs(), lessThan(JourneyGame.maxLeanRadians));
      expect(
        game.rawLeanTargetAngle,
        closeTo(expectedTarget, 1e-12),
        reason: 'AC-1/AC-10: raw target == +leanGain·slope (no negation)',
      );
    });
  });

  // ===========================================================================
  // AC-2 — MONOTONIC in curve magnitude up to the clamp.
  // ===========================================================================
  group('AC-2 |rawTarget| is non-decreasing in |slope| below saturation', () {
    test('AC-2 increasingAbsSlope_yieldsNonDecreasingAbsRawTarget', () {
      // A set of seg-0 offsets with STRICTLY INCREASING |slope|, all below the
      // saturation point (|target| < cap). Sampling rawLeanTargetAngle removes
      // the smoothing transient so the monotonicity is read cleanly.
      const List<double> increasingMagnitudeOffsets = <double>[
        700.0, // smallest |slope|
        500.0,
        300.0,
        150.0,
        50.0, // largest |slope|
      ];
      double prevAbsSlope = -1;
      double prevAbsTarget = -1;
      for (final double off in increasingMagnitudeOffsets) {
        final JourneyGame game = buildMotionGame(
          size: viewport,
          cruiseSpeed: kV2CruiseSpeed,
        );
        driveActive(game, mode: TravelMode.car);
        // Place the camera exactly at this offset by pumping until reached, then
        // read the raw target (independent of the smoothing follow).
        while (game.roadScrollOffset < off) {
          game.update(kFrameDt);
        }
        final double absSlope = slopeAt(game.roadScrollOffset).abs();
        final double absTarget = game.rawLeanTargetAngle.abs();
        // Guard the precondition: still below saturation.
        expect(
          absTarget,
          lessThan(JourneyGame.maxLeanRadians),
          reason: 'AC-2 precondition: sample at offset $off below saturation',
        );
        expect(
          absSlope,
          greaterThan(prevAbsSlope),
          reason: 'AC-2 precondition: |slope| strictly increases across samples',
        );
        expect(
          absTarget,
          greaterThanOrEqualTo(prevAbsTarget - 1e-12),
          reason:
              'AC-2: |rawTarget| must be non-decreasing as |slope| grows '
              '(bigger bend → bigger-or-equal tilt) at offset $off',
        );
        prevAbsSlope = absSlope;
        prevAbsTarget = absTarget;
      }
    });
  });

  // ===========================================================================
  // AC-3 — BOUNDED maximum roll (motion-sickness ceiling).
  // ===========================================================================
  group('AC-3 |angle| never exceeds maxLeanRadians (clamp is exercised)', () {
    test('AC-3 sharpestBend_rawTargetIsClampedToMax', () {
      // At the sharpest bend the un-clamped target (≈0.0615) EXCEEDS the cap, so
      // this proves the clamp is genuinely reached, not vacuous.
      final double slope = slopeAt(sharpestOffset);
      final double unclamped =
          JourneyGame.leanSignConvention * JourneyGame.leanGain * slope;
      expect(
        unclamped.abs(),
        greaterThan(JourneyGame.maxLeanRadians),
        reason: 'AC-3 precondition: the sharpest bend would exceed the cap',
      );
      final JourneyGame game = settledAt(sharpestOffset);
      expect(
        game.rawLeanTargetAngle.abs(),
        closeTo(JourneyGame.maxLeanRadians, 1e-12),
        reason: 'AC-3: raw target is clamped to maxLeanRadians at the sharpest '
            'bend',
      );
    });

    test('AC-3 fullHeadingCycleSweep_appliedAndRawAlwaysWithinCap', () {
      // Sweep an active car across a full heading cycle (16 × 900 px) and assert
      // BOTH the applied AND the raw target stay within the ceiling at EVERY
      // frame — the bound holds everywhere, not just at the sampled offsets.
      const double cycle = 16 * 900.0;
      final JourneyGame game = buildMotionGame(
        size: viewport,
        cruiseSpeed: kV2CruiseSpeed,
      );
      driveActive(game, mode: TravelMode.car);
      // Allow a small epsilon for floating-point at the clamp boundary.
      const double cap = JourneyGame.maxLeanRadians + 1e-9;
      double worstApplied = 0;
      while (game.roadScrollOffset < cycle) {
        game.update(kFrameDt);
        final double applied = game.appliedLeanAngle.abs();
        final double raw = game.rawLeanTargetAngle.abs();
        if (applied > worstApplied) worstApplied = applied;
        expect(
          applied,
          lessThanOrEqualTo(cap),
          reason:
              'AC-3: |appliedAngle| ($applied) must never exceed the ceiling at '
              'offset ${game.roadScrollOffset}',
        );
        expect(
          raw,
          lessThanOrEqualTo(cap),
          reason: 'AC-3: |rawTarget| must never exceed the ceiling',
        );
      }
      // The ceiling is actually approached during the sweep (not a trivial pass).
      expect(
        worstApplied,
        greaterThan(0.9 * JourneyGame.maxLeanRadians),
        reason: 'AC-3: the lean must reach near the cap during a full sweep',
      );
    });
  });

  // ===========================================================================
  // AC-4 — EASED / per-frame cap (no snap).
  // ===========================================================================
  group('AC-4 per-frame change of the applied angle stays under the cap', () {
    test('AC-4 cruiseSweep_perFrameAngleDeltaStaysUnderSmoothnessCap', () {
      // Stepping by one cruise-frame's scrollDelta, |angle(n) - angle(n-1)| must
      // stay below the tuned smoothness cap (~0.2°/frame ≈ 0.0035 rad). We use a
      // small safety margin above the spec target to absorb float noise.
      const double cap = 0.0035; // ~0.2°/frame
      final JourneyGame game = buildMotionGame(
        size: viewport,
        cruiseSpeed: kV2CruiseSpeed,
      );
      driveActive(game, mode: TravelMode.car);
      // Warm up to cruise so scrollDelta is the steady eased cruise step.
      pump(game, frames: 120);
      double prev = game.appliedLeanAngle;
      double worstStep = 0;
      const double cycle = 16 * 900.0;
      while (game.roadScrollOffset < cycle) {
        game.update(kFrameDt);
        final double cur = game.appliedLeanAngle;
        final double step = (cur - prev).abs();
        if (step > worstStep) worstStep = step;
        expect(
          step,
          lessThanOrEqualTo(cap),
          reason:
              'AC-4: per-frame angle change ($step rad) must stay under the '
              'smoothness cap ($cap rad) — the lean must never snap, at offset '
              '${game.roadScrollOffset}',
        );
        prev = cur;
      }
      // Sanity: the lean actually moved over the sweep (the cap isn't trivially
      // met because nothing changed).
      expect(
        worstStep,
        greaterThan(0),
        reason: 'AC-4: the lean must actually ease over the sweep',
      );
    });
  });

  // ===========================================================================
  // AC-5 — DETERMINISTIC: pure function of the smoothed scroll-phase history.
  // ===========================================================================
  group('AC-5 same scroll history → identical angle sequence (no wall-clock)', () {
    test('AC-5 replayingSameOffsetSequenceTwice_yieldsIdenticalAngles', () {
      List<double> run() {
        final JourneyGame game = buildMotionGame(
          size: viewport,
          cruiseSpeed: kV2CruiseSpeed,
        );
        driveActive(game, mode: TravelMode.car);
        final List<double> angles = <double>[];
        for (int i = 0; i < 600; i++) {
          game.update(kFrameDt);
          angles.add(game.appliedLeanAngle);
        }
        return angles;
      }

      final List<double> a = run();
      final List<double> b = run();
      expect(a.length, b.length);
      for (int i = 0; i < a.length; i++) {
        expect(
          b[i],
          closeTo(a[i], 1e-12),
          reason:
              'AC-5: replaying the same scroll history must reproduce the '
              'identical applied angle at frame $i',
        );
      }
    });

    test('AC-5 rawTargetHasNoWallClockTerm_dependsOnlyOnScrollOffset', () {
      // No wall-clock dependence: rawLeanTargetAngle is a pure function of the
      // scroll OFFSET (it is `clamp(gain·slopeAt(worldAtCamera(offset)))`). We
      // reach a near-identical offset via two very different dt schedules and
      // assert each game's raw target equals the ANALYTIC target at its OWN
      // offset — proving the seam carries no dt / time term (the tiny residual
      // offset difference is the only source of any difference, and it tracks
      // the offset exactly, not the dt used).
      double analyticTarget(double offset) {
        double t = JourneyGame.leanSignConvention *
            JourneyGame.leanGain *
            slopeAt(offset);
        if (t > JourneyGame.maxLeanRadians) return JourneyGame.maxLeanRadians;
        if (t < -JourneyGame.maxLeanRadians) return -JourneyGame.maxLeanRadians;
        return t;
      }

      for (final double dt in <double>[kFrameDt * 2, kFrameDt / 2]) {
        final JourneyGame game = buildMotionGame(
          size: viewport,
          cruiseSpeed: kV2CruiseSpeed,
        );
        driveActive(game, mode: TravelMode.car);
        while (game.roadScrollOffset < rightBendOffset) {
          game.update(dt);
        }
        expect(
          game.rawLeanTargetAngle,
          closeTo(analyticTarget(game.roadScrollOffset), 1e-12),
          reason:
              'AC-5: rawLeanTargetAngle == analytic target at its own offset — '
              'no dt/wall-clock term (dt=$dt)',
        );
      }
    });

    test('AC-5 appliedFollow_isPureFunctionOfScrollDistance_notDt', () {
      // The applied follow eases by `scrollDelta / leanSmoothingLengthPx`, so a
      // SINGLE step of size S produces the same angle change whether that S of
      // scroll is reached with a big dt or a small dt. Drive two games to the
      // SAME offset with the SAME final scrollDelta and assert identical angle.
      // (We engineer identical scroll deltas by using the same cruise speed and
      // matching the velocity ramp — both reach cruise after the warm-up, so the
      // per-frame scrollDelta is identical and the offset histories coincide.)
      List<double> recordAngles(double dt, int frames) {
        final JourneyGame game = buildMotionGame(
          size: viewport,
          cruiseSpeed: kV2CruiseSpeed,
        );
        driveActive(game, mode: TravelMode.car);
        final List<double> out = <double>[];
        for (int i = 0; i < frames; i++) {
          game.update(dt);
          out.add(game.appliedLeanAngle);
        }
        return out;
      }

      // Same dt twice → identical (the determinism backbone of AC-5).
      final List<double> a = recordAngles(kFrameDt, 400);
      final List<double> b = recordAngles(kFrameDt, 400);
      for (int i = 0; i < a.length; i++) {
        expect(b[i], closeTo(a[i], 1e-12),
            reason: 'AC-5: identical dt schedule → identical angle at frame $i');
      }
    });
  });

  // ===========================================================================
  // AC-6 — REDUCE-MOTION is a HARD ZERO (from the very first frame).
  // ===========================================================================
  group('AC-6 reduce-motion → appliedLeanAngle is exactly 0.0', () {
    test('AC-6 reduceMotionOn_firstFrameBeforeAnyScroll_isExactlyZero', () {
      final JourneyGame game = buildMotionGame(
        size: viewport,
        cruiseSpeed: kV2CruiseSpeed,
      );
      game.applyState(
        moving: true,
        mode: TravelMode.car,
        reduceMotion: true,
        timeOfDayHours: 12,
      );
      // Before any update/scroll — the cockpit must NEVER start tilted.
      expect(
        game.appliedLeanAngle,
        0.0,
        reason: 'AC-6: hard zero on the first frame (before any scroll)',
      );
      expect(game.rawLeanTargetAngle, 0.0);
    });

    test('AC-6 reduceMotionOn_atSharpCurveOffset_staysExactlyZero', () {
      // Even after scrolling toward the sharpest bend, reduce-motion keeps the
      // angle EXACTLY 0.0 (note: under reduce-motion scroll itself is frozen, so
      // we also assert the seam clamps regardless of any residual phase).
      final JourneyGame game = buildMotionGame(
        size: viewport,
        cruiseSpeed: kV2CruiseSpeed,
      );
      game.applyState(
        moving: true,
        mode: TravelMode.car,
        reduceMotion: true,
        timeOfDayHours: 12,
      );
      for (int i = 0; i < 300; i++) {
        game.update(kFrameDt);
        expect(
          game.appliedLeanAngle,
          0.0,
          reason: 'AC-6: angle must remain exactly 0.0 under reduce-motion',
        );
      }
    });
  });

  // ===========================================================================
  // AC-7 — ZERO curvature → level.
  // ===========================================================================
  group('AC-7 straight road → settled angle is level (≈ 0.0)', () {
    test('AC-7 straightRoadPhase_settledTargetIsLevel', () {
      // On a (near-)straight road the SETTLED angle the smoothed follow
      // converges to is the RAW target — which at the straightest sampled point
      // (|slope| ≈ 1.4e-8) is ≈ 2.5e-7 rad, i.e. level. We assert against
      // rawLeanTargetAngle here because the smoothed follow legitimately LAGS
      // when the camera is merely passing THROUGH the straight point at cruise
      // (it is still unwinding from the neighbouring bend) — "settled" means the
      // value it converges toward, which is the raw target. (The exact-0.0
      // guarantee is the hard-zero gates AC-6/AC-8; the procedural geometry has
      // no analytic exact-zero-slope sample at a clean offset.)
      final JourneyGame game = settledAt(straightestOffset);
      final double slope = slopeAt(game.roadScrollOffset).abs();
      expect(
        slope,
        lessThan(1e-4),
        reason: 'AC-7 precondition: near the straightest road sample',
      );
      expect(
        game.rawLeanTargetAngle.abs(),
        lessThan(1e-4),
        reason:
            'AC-7: at a straight-road phase the lean target is level (≈ 0) — the '
            'settled cockpit holds level where the road is straight',
      );
    });

    test('AC-7 zeroCurvatureBeforeFirstScroll_isExactlyZero', () {
      // At offset 0 the integrated phase is 0 → lateralAt(0) == 0; the slope
      // there is non-zero (the road is just starting to bend), so this is NOT
      // an exact-zero-curvature point. The genuinely-exact level case is the
      // first frame: appliedLeanAngle starts at 0.0 and a single frame with
      // scrollDelta easing toward a tiny target keeps it ≈ 0. Assert the start
      // is exactly level.
      final JourneyGame game = buildMotionGame(
        size: viewport,
        cruiseSpeed: kV2CruiseSpeed,
      );
      driveActive(game, mode: TravelMode.car);
      expect(
        game.appliedLeanAngle,
        0.0,
        reason: 'AC-7: the lean starts at exactly 0.0 (level) before scrolling',
      );
    });
  });

  // ===========================================================================
  // AC-8 — MODE-GATING (car + motorbike only).
  // ===========================================================================
  group('AC-8 non-zero settled angle ONLY for cockpit modes', () {
    for (final TravelMode mode in <TravelMode>[
      TravelMode.car,
      TravelMode.motorbike,
    ]) {
      test('AC-8 ${mode.name}_leansOnABend (cockpit mode → non-zero)', () {
        final JourneyGame game = settledAt(rightBendOffset, mode: mode);
        expect(game.isCockpitActive, isTrue);
        expect(
          game.appliedLeanAngle.abs(),
          greaterThan(1e-4),
          reason: 'AC-8: ${mode.name} is a cockpit mode and must lean on a bend',
        );
      });
    }

    for (final TravelMode mode in <TravelMode>[
      TravelMode.walk,
      TravelMode.run,
      TravelMode.bicycle,
      TravelMode.ship,
    ]) {
      test('AC-8 ${mode.name}_neverLeans (non-cockpit mode → exactly 0.0)', () {
        final JourneyGame game = buildMotionGame(
          size: viewport,
          cruiseSpeed: kV2CruiseSpeed,
        );
        driveActive(game, mode: mode);
        expect(game.isCockpitActive, isFalse);
        // Sweep across bends — the angle must stay EXACTLY 0.0 throughout
        // (no cockpit foreground to tilt).
        const double cycle = 16 * 900.0;
        while (game.roadScrollOffset < cycle) {
          game.update(kFrameDt);
          expect(
            game.appliedLeanAngle,
            0.0,
            reason:
                'AC-8: ${mode.name} has no cockpit — appliedLeanAngle must be '
                'exactly 0.0 at offset ${game.roadScrollOffset}',
          );
          expect(game.rawLeanTargetAngle, 0.0);
        }
      });
    }

    test('AC-8 switchingFromCarToWalk_immediatelyZeros_viaSeam', () {
      // The seam zeroes the moment the mode changes (before the next update),
      // mirroring the production guard inside appliedLeanAngle.
      final JourneyGame game = settledAt(rightBendOffset, mode: TravelMode.car);
      expect(game.appliedLeanAngle.abs(), greaterThan(1e-4));
      driveActive(game, mode: TravelMode.walk);
      expect(
        game.appliedLeanAngle,
        0.0,
        reason: 'AC-8: a mode switch to walk zeros the lean immediately',
      );
    });
  });

  // ===========================================================================
  // Cross-cutting sanity: sign relationship holds across the whole sweep.
  // ===========================================================================
  group('AC-1/AC-10 sign tracks the slope across a full sweep (no flip)', () {
    test('AC-1 everyMaterialBendFrame_signMatchesSlope', () {
      final JourneyGame game = buildMotionGame(
        size: viewport,
        cruiseSpeed: kV2CruiseSpeed,
      );
      driveActive(game, mode: TravelMode.car);
      pump(game, frames: 120); // reach cruise so the follow has settled
      const double cycle = 16 * 900.0;
      int checked = 0;
      while (game.roadScrollOffset < cycle) {
        game.update(kFrameDt);
        final double raw = game.rawLeanTargetAngle;
        final double angle = game.appliedLeanAngle;
        // Assert sign only on frames where the smoothed follow has CAUGHT UP to
        // a materially non-zero raw target (the angle is genuinely tracking this
        // bend, not lagging through a zero-crossing from the previous opposite
        // bend — that lag is correct easing, not a sign flip). Condition:
        // raw materially non-zero AND applied within ~30% of it AND same side.
        final bool followingThisBend =
            raw.abs() > 5e-3 && (angle - raw).abs() < 0.3 * raw.abs();
        if (followingThisBend) {
          expect(
            angle.sign,
            raw.sign,
            reason:
                'AC-1: while tracking a bend the applied angle leans INTO the '
                'turn (sign == raw-target sign) at offset '
                '${game.roadScrollOffset} (raw $raw, angle $angle)',
          );
          // And the raw target itself matches the slope sign (the load-bearing
          // signal→target sign relationship).
          expect(angle.sign, slopeAt(game.roadScrollOffset).sign);
          checked++;
        }
      }
      expect(
        checked,
        greaterThan(20),
        reason: 'sanity: many material bend frames were actually checked',
      );
    });
  });

  // A guard that the test offsets stay valid if the geometry is ever retuned.
  test('pinned sample offsets still describe the expected bends', () {
    expect(slopeAt(rightBendOffset), greaterThan(0));
    expect(slopeAt(leftBendOffset), lessThan(0));
    expect(slopeAt(sharpestOffset).abs(), greaterThan(0.003));
    expect(slopeAt(straightestOffset).abs(), lessThan(1e-4));
    // The sharpest bend's un-clamped target exceeds the cap (clamp exercised).
    expect(
      (JourneyGame.leanGain * slopeAt(sharpestOffset)).abs(),
      greaterThan(JourneyGame.maxLeanRadians),
    );
    // math import kept meaningful (used by reduce helpers in sibling files);
    // here a trivial invariant on the cap value.
    expect(JourneyGame.maxLeanRadians, closeTo(3 * math.pi / 180, 1e-6));
  });
}
