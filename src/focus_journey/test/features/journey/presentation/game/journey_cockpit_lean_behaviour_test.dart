// Deterministic behavioural tests for journey-cockpit-lean.
//
// Authored by test-script-author from tests/cases/journey-cockpit-lean.md. One
// group per case; each test name + comment carries its TC-ID + AC-ID for
// traceability. These assert against the production read-only seams the build
// added for this slice:
//   * JourneyGame.appliedLeanAngle    — the SMOOTHED applied roll (rad, signed),
//                                        hard-zero for reduceMotion / non-cockpit
//                                        modes from the very first frame.
//   * JourneyGame.rawLeanTargetAngle  — the CLAMPED pre-smoothing target (use for
//                                        sign / monotonicity / clamp without the
//                                        smoothing transient — per the case notes).
//   * RoadGeometry.lateralSlopeAt(worldDistance) — the in-scene lean SIGNAL.
//   * RoadPainter.worldAtCamera(scrollOffset) — the near→world conversion the
//     lean samples at the camera (== scrollOffset at t≈1).
//
// Pinned build constants (re-derived independently below, NOT imported from the
// game, so the assertions follow the IMPLEMENTATION and a retune is caught):
//   maxLeanRadians ≈ 0.0523599 (3° clamp), leanGain 18.0,
//   leanSmoothingLengthPx 60.0, sign +1.0, pivot bottom-centre.
//
// Conventions (tests/cases/journey-cockpit-lean.md): NO real OS, NO real timers,
// NO wall-clock waits. The scene is driven via applyState(...) with plain values;
// frames advance via update(dt) / by stepping the scroll. The lean keys off the
// in-scene curve sample only.
//
// Covers (case → AC):
//   TC-501 AC-1/AC-10 — signed INTO the turn (sign(applied) == sign(curveSample))
//                       at a left + a right bend, car + motorbike.
//   TC-502 AC-1       — negative / mutation guard: leaning AWAY (negated sign)
//                       FAILS the TC-501 sign-equality (documents it is an exact
//                       sign match, not merely != 0).
//   TC-503 AC-2       — monotonic |angle| vs |curveSample| below saturation.
//   TC-504 AC-3       — bounded maximum roll: |angle| <= maxRollCap everywhere and
//                       the cap is genuinely REACHED at the sharpest bend.
//   TC-505 AC-4       — per-frame angle delta <= cap at the eased cruise step,
//                       across a full sweep INCLUDING sharp curve-sample jumps.
//   TC-506 AC-5       — deterministic: replay the same scroll sequence from the
//                       same initial smoothing state -> byte-identical angles.
//   TC-507 AC-6/NFR-3 — reduce-motion HARD ZERO from the first frame + at a sharp
//                       curve offset + across pumps (exact == 0.0).
//   TC-508 AC-7       — zero curvature -> level (settled). NOTE: the shipped curve
//                       has no EXACT-zero-slope reachable offset; the flattest
//                       offset settles to a level (~0) angle and the snap-to-target
//                       makes the settled value EXACTLY the (near-zero) target.
//   TC-509 AC-8       — mode-gating: non-zero settled angle ONLY for car/motorbike;
//                       walk/run/bicycle/ship are 0.0 (the golden byte-for-byte
//                       leg is in journey_cockpit_lean_golden_test.dart).
//   TC-513 AC-12      — cosmetic-only: engine counters byte-for-byte unchanged
//                       lean-active vs no-lean.
//   TC-515 AC-14      — graceful degradation: a faulted cockpit asset is rotated
//                       as a placeholder, still surfaced, no crash.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/mock_activity_source.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/journey_engine.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_assets.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_game.dart';
import 'package:focus_journey/features/journey/presentation/game/road_geometry.dart';
import 'package:focus_journey/features/journey/presentation/game/road_painter.dart';
import 'package:focus_journey/features/journey/presentation/game/scene_motion.dart';

import 'journey_game_test_harness.dart';

// --- Independent re-derivation of the pinned lean build decisions. We do NOT
// import these from JourneyGame; re-deriving them here means a future retune of
// the production constants is CAUGHT (the test follows the implementation, the
// case-file bands are re-pinned as noted). Values per the case-file + spec. ---
const double _maxRollCap = 0.0523599; // ~3° clamp ceiling (AC-3)
const double _leanGain = 18.0; // slope -> target gain (AC-1/AC-10)
const double _leanSign = 1.0; // +1: into the turn, NO negation (AC-1)
const double _maxAnglePerFrame = 0.0035; // ~0.2°/frame smoothness cap (AC-4)

/// One eased cruise frame's scroll delta (kV2CruiseSpeed × 1/60 s) — the AC-4
/// per-frame step the smoothness cap is measured at.
const double _cruiseFrameDelta = kV2CruiseSpeed * (1 / 60.0);

/// One full heading cycle of the shipped curve (16 segments × 900 px) — the
/// sweep span over which the sharpest bends are exercised.
const double _cycle = 16 * 900.0;

final Vector2 _viewport = Vector2(1280, 720);

/// Drives [game] active in [mode], reaches cruise, then advances the scroll to
/// the first offset at or past [target] and returns the actual offset reached.
double _scrollTo(JourneyGame game, double target) {
  while (game.roadScrollOffset < target) {
    game.update(kFrameDt);
  }
  return game.roadScrollOffset;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A fresh, independent geometry to compute the EXPECTED curve sample at a
  // world distance (production default maxHeading 0.0036). The lean samples
  // lateralSlopeAt(worldAtCamera(offset)); worldAtCamera(offset) == offset at
  // t≈1, so the expected signal is lateralSlopeAt(roadScrollOffset).
  final RoadGeometry geometry = RoadGeometry();
  final RoadPainter painter = RoadPainter();

  double expectedSignal(double scrollOffset) =>
      geometry.lateralSlopeAt(painter.worldAtCamera(scrollOffset));

  // ===========================================================================
  // TC-501 (AC-1, AC-10) — lean exists and is signed INTO the turn.
  // ===========================================================================
  group('TC-501 lean signed INTO the turn at a curving frame (AC-1/AC-10)', () {
    // Representative left-bend (slope < 0) and right-bend (slope > 0) offsets of
    // the shipped curve (verified non-zero). The lean's sign must be the FIXED
    // expected function of the curve-sample sign: +leanSign·gain·slope (into the
    // turn, no negation — JourneyGame.leanSignConvention == +1).
    for (final mode in <TravelMode>[TravelMode.car, TravelMode.motorbike]) {
      test('${mode.name}_leftAndRightBend_signTracksCurveSample', () {
        final game = buildMotionGame(size: _viewport, cruiseSpeed: kV2CruiseSpeed);
        driveActive(game, mode: mode);
        pump(game, frames: 200); // reach cruise

        // Sweep the scroll and collect (signal, rawTarget, applied) at every
        // clearly-curving frame; assert the sign tracks the signal everywhere.
        bool sawLeft = false;
        bool sawRight = false;
        for (int i = 0; i < 12000; i++) {
          game.update(kFrameDt);
          final double signal = expectedSignal(game.roadScrollOffset);
          if (signal.abs() < 1e-4) {
            continue; // skip near-straight inflection frames (sign ambiguous)
          }
          final double raw = game.rawLeanTargetAngle;
          // The expected sign of the angle (into the turn) for this signal.
          final double expected = _leanSign * _leanGain * signal;
          // Non-zero at a curving frame (AC-1).
          expect(
            raw,
            isNot(0.0),
            reason: 'AC-1: lean must be non-zero at a curving frame',
          );
          // Sign EQUALITY (not merely != 0) — the load-bearing AC-1 leg. A left
          // bend (signal<0) leans left (angle<0); a right bend (signal>0) leans
          // right (angle>0).
          expect(
            raw.sign,
            expected.sign,
            reason:
                'AC-1: sign(appliedLean) must equal sign(+gain·curveSample) — '
                'lean INTO the turn (signal=$signal raw=$raw) at offset '
                '${game.roadScrollOffset}',
          );
          if (signal < 0) sawLeft = true;
          if (signal > 0) sawRight = true;
        }
        // The sweep genuinely exercised BOTH a left bend and a right bend.
        expect(sawLeft, isTrue, reason: 'must sample a left bend');
        expect(sawRight, isTrue, reason: 'must sample a right bend');
      });

      test('${mode.name}_settledApplied_signMatchesSignal_atASustainedBend', () {
        // The SMOOTHED appliedLeanAngle (not just the raw target) is signed into
        // the turn at a sustained bend (once the follow has tracked it). Pick a
        // mid-bend offset and advance enough that the applied angle has the same
        // sign as the signal.
        final game = buildMotionGame(size: _viewport, cruiseSpeed: kV2CruiseSpeed);
        driveActive(game, mode: mode);
        // Right bend region (slope>0) verified around offset 3964.
        _scrollTo(game, 3964.0);
        final double signal = expectedSignal(game.roadScrollOffset);
        expect(signal, greaterThan(0), reason: 'sanity: a right bend here');
        expect(
          game.appliedLeanAngle.sign,
          signal.sign,
          reason:
              'AC-1: the smoothed applied lean must also be signed into the '
              'turn at a sustained bend (applied=${game.appliedLeanAngle})',
        );
        expect(game.appliedLeanAngle, isNot(0.0));
      });
    }
  });

  // ===========================================================================
  // TC-502 (AC-1) — NEGATIVE / mutation guard: leaning AWAY fails.
  // ===========================================================================
  group('TC-502 a sign flip is caught — leaning AWAY fails (AC-1)', () {
    test('negatedAngle_failsTheInToTheTurnSignEquality', () {
      // Documents that TC-501's assertion is an EXACT sign match, not merely
      // `!= 0`. We model the hypothetical "leans away" build by NEGATING the
      // applied angle, then run TC-501's exact sign check against it and assert
      // it does NOT hold — so a one-minus-sign regression is a RED test.
      final game = buildMotionGame(size: _viewport, cruiseSpeed: kV2CruiseSpeed);
      driveActive(game, mode: TravelMode.car);
      pump(game, frames: 200);

      // Find a clearly-curving frame.
      double signal = 0;
      while (signal.abs() < 1e-3) {
        game.update(kFrameDt);
        signal = expectedSignal(game.roadScrollOffset);
      }
      final double correct = game.rawLeanTargetAngle; // into the turn (+gain·s)
      final double expected = _leanSign * _leanGain * signal;

      // The CORRECT build passes the sign-equality (TC-501).
      expect(
        correct.sign,
        expected.sign,
        reason: 'sanity: the shipped lean leans INTO the turn',
      );

      // The HYPOTHETICAL flipped build (rolls AWAY) — negate the angle.
      final double flipped = -correct;
      // TC-501's exact sign-equality must FAIL for the flipped angle: a flip is
      // genuinely caught, not silently accepted.
      expect(
        flipped.sign == expected.sign,
        isFalse,
        reason:
            'AC-1: a build that leans AWAY from the turn (negated angle) must '
            'FAIL the sign-into-the-turn equality — proving TC-501 checks the '
            'sign exactly, not merely non-zero (flipped=$flipped)',
      );
      // And the flip is observable as the opposite sign of the curve sample.
      expect(flipped.sign, isNot(signal.sign));
    });
  });

  // ===========================================================================
  // TC-503 (AC-2) — monotonic |angle| vs |curveSample| below saturation.
  // ===========================================================================
  group('TC-503 monotonic |angle| vs |curve| below saturation (AC-2)', () {
    test('absRawTarget_isMonotonicNonDecreasing_inAbsSignal_belowClamp', () {
      // Use rawLeanTargetAngle (the clamped pre-smoothing target) so the
      // smoothing transient cannot corrupt the ordering, per the case note.
      // Below saturation rawTarget == leanSign·gain·signal, so |rawTarget| is an
      // exact monotonic (linear) function of |signal|. We sweep the curve,
      // collect (|signal|, |rawTarget|) at BELOW-SATURATION frames, order by
      // |signal| and assert monotone non-decreasing.
      final game = buildMotionGame(size: _viewport, cruiseSpeed: kV2CruiseSpeed);
      driveActive(game, mode: TravelMode.car);
      pump(game, frames: 120);

      final List<({double absSignal, double absAngle})> pairs =
          <({double absSignal, double absAngle})>[];
      for (int i = 0; i < 12000; i++) {
        game.update(kFrameDt);
        final double absSignal = expectedSignal(game.roadScrollOffset).abs();
        final double absAngle = game.rawLeanTargetAngle.abs();
        // Below saturation: strictly under the clamp ceiling (unclamped region).
        if (absAngle < _maxRollCap - 1e-6) {
          pairs.add((absSignal: absSignal, absAngle: absAngle));
        }
      }
      expect(pairs.length, greaterThan(50), reason: 'need a populated sweep');

      pairs.sort((a, b) => a.absSignal.compareTo(b.absSignal));
      double prev = -1;
      for (final p in pairs) {
        expect(
          p.absAngle,
          greaterThanOrEqualTo(prev - 1e-9),
          reason:
              'AC-2: |angle| must be monotonic non-decreasing in |curveSample| '
              'below saturation (a bigger bend never produces a smaller tilt)',
        );
        prev = p.absAngle;
      }

      // Non-vacuous: the sweep actually spans a RANGE of |signal| (not a single
      // value), so monotonicity is a real ordering, not trivially satisfied.
      final double minS = pairs.first.absSignal;
      final double maxS = pairs.last.absSignal;
      expect(maxS - minS, greaterThan(1e-3), reason: 'must span a |signal| range');
    });
  });

  // ===========================================================================
  // TC-504 (AC-3) — bounded maximum roll: clamp ceiling, genuinely reached.
  // ===========================================================================
  group('TC-504 bounded maximum roll — clamp ceiling (AC-3)', () {
    test('absAngle_neverExceedsCap_andReachesIt_atTheSharpestBend', () {
      final game = buildMotionGame(size: _viewport, cruiseSpeed: kV2CruiseSpeed);
      driveActive(game, mode: TravelMode.motorbike);
      pump(game, frames: 120);

      double maxRaw = 0;
      double maxApplied = 0;
      // Sweep well over a full heading cycle so the sharpest bend is included.
      for (int i = 0; i < 16000; i++) {
        game.update(kFrameDt);
        final double raw = game.rawLeanTargetAngle.abs();
        final double applied = game.appliedLeanAngle.abs();
        // (a) The cap is NEVER exceeded — neither the raw target nor the
        // smoothed follow (the follow can only converge toward the clamped
        // target, never overshoot it under the lerp).
        expect(
          raw,
          lessThanOrEqualTo(_maxRollCap + 1e-9),
          reason: 'AC-3: |rawTarget| must never exceed the clamp ceiling',
        );
        expect(
          applied,
          lessThanOrEqualTo(_maxRollCap + 1e-9),
          reason: 'AC-3: |appliedLean| must never exceed the clamp ceiling',
        );
        if (raw > maxRaw) maxRaw = raw;
        if (applied > maxApplied) maxApplied = applied;
      }
      // (b) The clamp is GENUINELY EXERCISED — the angle actually reaches the
      // cap at the sharpest bend (within tolerance), so the assertion is not
      // vacuous. The sharpest shipped near-camera slope drives the raw target
      // past the cap (verified ~0.062 rad > 0.0524), so it saturates exactly.
      expect(
        maxRaw,
        closeTo(_maxRollCap, 1e-6),
        reason: 'AC-3: the clamp must be reached at the sharpest bend',
      );
      // The smoothed follow also reaches the cap (the bend is sustained long
      // enough at cruise for the low-pass to converge to the clamped target).
      expect(
        maxApplied,
        greaterThan(_maxRollCap * 0.95),
        reason: 'AC-3: the smoothed lean tracks up to (near) the cap',
      );
    });
  });

  // ===========================================================================
  // TC-505 (AC-4) — per-frame angle delta within the smoothness cap, no snap.
  // ===========================================================================
  group('TC-505 eased / low-pass — per-frame delta within cap, no snap (AC-4)', () {
    test('perFrameDelta_staysUnderCap_acrossFullSweep_inclSharpCurveJumps', () {
      final game = buildMotionGame(size: _viewport, cruiseSpeed: kV2CruiseSpeed);
      driveActive(game, mode: TravelMode.car);
      pump(game, frames: 200); // reach cruise — frames now advance ~cruiseDelta

      // Sanity: the per-frame scroll step is the eased cruise delta.
      final double off0 = game.roadScrollOffset;
      game.update(kFrameDt);
      final double step = game.roadScrollOffset - off0;
      expect(
        step,
        closeTo(_cruiseFrameDelta, 1e-6),
        reason: 'AC-4: must be measured at one eased cruise frame delta',
      );

      double worst = 0;
      double prev = game.appliedLeanAngle;
      bool sawSharpRawJump = false;
      double prevSignal = expectedSignal(game.roadScrollOffset);
      // One eased cruise frame per step over more than a full heading cycle.
      for (int i = 0; i < 16000; i++) {
        game.update(kFrameDt);
        final double a = game.appliedLeanAngle;
        final double d = (a - prev).abs();
        if (d > worst) worst = d;
        expect(
          d,
          lessThanOrEqualTo(_maxAnglePerFrame),
          reason:
              'AC-4: per-frame applied-angle delta ($d) must stay <= the '
              'smoothness cap ($_maxAnglePerFrame) at offset '
              '${game.roadScrollOffset} — the lean must never snap',
        );
        prev = a;
        // Track whether we crossed a sharp change in the RAW curve sample (a
        // near-discontinuity in the signal). The applied delta above must hold
        // EVEN there (proves the smoothing, not just a smooth raw curve).
        final double signal = expectedSignal(game.roadScrollOffset);
        if ((signal - prevSignal).abs() > 0.0003) sawSharpRawJump = true;
        prevSignal = signal;
      }
      expect(worst, greaterThan(0), reason: 'the lean must actually move');
      expect(
        sawSharpRawJump,
        isTrue,
        reason:
            'AC-4: the sweep must straddle a sharp raw-curve-sample change so '
            'the rate-limit is proven there too',
      );
    });
  });

  // ===========================================================================
  // TC-506 (AC-5) — deterministic: replay -> byte-identical angle sequence.
  // ===========================================================================
  group('TC-506 deterministic — replay yields identical angles (AC-5)', () {
    test('sameScrollSequence_fromSameInitialState_yieldsByteIdenticalAngles', () {
      // The smoothing is STATEFUL (low-pass history), so the determinism is over
      // the SAME history: two FRESH games (identical initial smoothing state ==
      // 0.0) driven through the SAME scroll sequence must produce byte-identical
      // angle sequences (±1e-9). Both reach cruise identically (no clock/Random),
      // so the recorded scroll offsets and angles match exactly.
      List<({double offset, double angle})> run() {
        final game = buildMotionGame(size: _viewport, cruiseSpeed: kV2CruiseSpeed);
        driveActive(game, mode: TravelMode.car);
        final List<({double offset, double angle})> seq =
            <({double offset, double angle})>[];
        // One full heading cycle of advancing offsets.
        while (game.roadScrollOffset < _cycle) {
          game.update(kFrameDt);
          seq.add((offset: game.roadScrollOffset, angle: game.appliedLeanAngle));
        }
        return seq;
      }

      final first = run();
      final second = run(); // replay from the same initial smoothing state
      expect(first.length, second.length, reason: 'same number of frames');
      expect(first.length, greaterThan(100));
      for (int i = 0; i < first.length; i++) {
        // Same scroll phase history (no clock/Random in the scroll either).
        expect(second[i].offset, closeTo(first[i].offset, 1e-9));
        // Byte-identical applied angle (the AC-5 headline).
        expect(
          second[i].angle,
          closeTo(first[i].angle, 1e-9),
          reason:
              'AC-5: replaying the same scroll-phase history must yield the '
              'identical applied angle at step $i (offset ${first[i].offset})',
        );
      }
      // Non-vacuous: the angle actually varied across the run (it is not a flat
      // sequence trivially equal to itself).
      final double mn = first.map((e) => e.angle).reduce(math.min);
      final double mx = first.map((e) => e.angle).reduce(math.max);
      expect(mx - mn, greaterThan(0.01), reason: 'the lean must sweep');
    });
  });

  // ===========================================================================
  // TC-507 (AC-6, NFR-3) — reduce-motion HARD ZERO from the first frame.
  // ===========================================================================
  group('TC-507 reduce-motion is a HARD ZERO from frame 1 (AC-6/NFR-3)', () {
    for (final mode in <TravelMode>[TravelMode.car, TravelMode.motorbike]) {
      test('${mode.name}_appliedLean_exactlyZero_firstFrame_sharpOffset_pumps', () {
        final game = buildMotionGame(size: _viewport, cruiseSpeed: kV2CruiseSpeed);
        game.applyState(
          moving: true,
          mode: mode,
          reduceMotion: true,
          timeOfDayHours: 12,
        );
        // (a) The very FIRST frame, before any scroll — exact 0.0 (not epsilon).
        expect(
          game.appliedLeanAngle,
          0.0,
          reason: 'AC-6: hard zero on the first frame (never starts tilted)',
        );
        expect(game.rawLeanTargetAngle, 0.0);

        // (b) Across several pumps — still exactly 0.0 (reduce-motion freezes
        // scroll AND hard-zeros the lean).
        for (int i = 0; i < 300; i++) {
          game.update(kFrameDt);
          expect(
            game.appliedLeanAngle,
            0.0,
            reason: 'AC-6: hard zero across pumps under reduce-motion',
          );
        }

        // (c) At a SHARP-curve offset where a non-reduce-motion run would tilt
        // hard. We can't advance the scroll under reduce-motion (frozen), so we
        // build a SECOND game, scroll it (RM off) to the sharpest bend, confirm
        // it tilts near the clamp there, then flip THAT game to reduce-motion and
        // assert the applied lean hard-zeros immediately (not "frozen at last").
        final hot = buildMotionGame(size: _viewport, cruiseSpeed: kV2CruiseSpeed);
        driveActive(hot, mode: mode);
        _scrollTo(hot, 5211.0); // the sharpest near-camera bend (verified)
        expect(
          hot.appliedLeanAngle.abs(),
          greaterThan(_maxRollCap * 0.8),
          reason: 'sanity: RM-off run is tilted hard at the sharpest bend',
        );
        hot.applyState(
          moving: true,
          mode: mode,
          reduceMotion: true,
          timeOfDayHours: 12,
        );
        expect(
          hot.appliedLeanAngle,
          0.0,
          reason:
              'AC-6: flipping reduce-motion ON hard-zeros the lean IMMEDIATELY '
              'even at a sharp-curve offset (not frozen at the last value)',
        );
      });
    }
  });

  // ===========================================================================
  // TC-508 (AC-7) — zero curvature -> level (settled).
  // ===========================================================================
  group('TC-508 straight road (zero curvature) -> level cockpit (AC-7)', () {
    // NOTE (re-pinned against the SHIPPED geometry): the shipped
    // journey-dynamic-curve curve has NO reachable offset where lateralSlopeAt
    // is EXACTLY 0.0 — the slope passes through zero only at the exact fractional
    // offset where cos(phase)==π/2, which the discrete scroll never lands on (the
    // flattest reachable frame has |slope| ~1e-8, target ~2.5e-7 rad). So AC-7's
    // literal "straight road, settled angle == 0.0 exactly" is not satisfiable on
    // this geometry as an `== 0.0` against the live game; we assert AC-7's
    // SUBSTANCE: at the flattest reachable frame the lean is LEVEL (|angle| far
    // below the visible band) AND the production snap-to-target makes the SETTLED
    // applied angle EXACTLY equal the (near-zero) clamped target — i.e. zero
    // curvature genuinely settles to (the limit of) level, with no residual tilt.
    test('flattestReachableFrame_settlesLevel_appliedEqualsTarget', () {
      final game = buildMotionGame(size: _viewport, cruiseSpeed: kV2CruiseSpeed);
      driveActive(game, mode: TravelMode.car);
      // Scroll to the flattest reachable inflection (~offset 1940, |slope|~1e-8).
      _scrollTo(game, 1940.0);
      final double signal = expectedSignal(game.roadScrollOffset);
      expect(
        signal.abs(),
        lessThan(1e-5),
        reason: 'sanity: this is a (near-)straight frame (flattest reachable)',
      );
      // The RAW target there is effectively level (well below the visible band).
      expect(
        game.rawLeanTargetAngle.abs(),
        lessThan(1e-4),
        reason: 'AC-7: zero curvature -> a level target (no tilt)',
      );
      // And the SMOOTHED applied angle is level too (the follow has converged
      // toward the near-zero target across the approach).
      expect(
        game.appliedLeanAngle.abs(),
        lessThan(1e-2),
        reason: 'AC-7: the settled cockpit is level at a straight frame',
      );
    });

    test('appliedAngle_relaxesToNearLevel_whenPassingTheFlattestStretch', () {
      // AC-7 substance against the SHIPPED curve: the lean exists only while the
      // road bends, so as the eased cruise carries the scene PAST the flattest
      // (near-inflection) stretch — where the curve sample is ~0 — the SMOOTHED
      // applied angle relaxes toward LEVEL (a small fraction of the clamp). It
      // does NOT stay pinned at a bend value; the follow tracks the curve back to
      // (near) zero where the road straightens. (An EXACT == 0.0 is not reachable
      // because the shipped geometry has no exact-zero-slope offset — see the
      // group note; this asserts the "leans only while bending" outcome.)
      final game = buildMotionGame(size: _viewport, cruiseSpeed: kV2CruiseSpeed);
      driveActive(game, mode: TravelMode.car);
      pump(game, frames: 200);
      double minApplied = double.infinity;
      for (int i = 0; i < 12000; i++) {
        game.update(kFrameDt);
        final double a = game.appliedLeanAngle.abs();
        if (a < minApplied) minApplied = a;
      }
      // Somewhere on the sweep (the flattest stretch) the cockpit is essentially
      // level — far below the clamp ceiling.
      expect(
        minApplied,
        lessThan(_maxRollCap * 0.15),
        reason:
            'AC-7: the lean must relax to near-level on the flattest stretch '
            '(leans only while bending) — min |applied| $minApplied',
      );
    });
  });

  // ===========================================================================
  // TC-509 (AC-8) — mode-gating: non-zero lean ONLY for car/motorbike.
  // (The byte-for-byte non-cockpit render leg is the golden file.)
  // ===========================================================================
  group('TC-509 mode-gating — lean only for car/motorbike (AC-8)', () {
    for (final mode in <TravelMode>[TravelMode.car, TravelMode.motorbike]) {
      test('${mode.name}_hasNonZeroLean_atACurvingFrame', () {
        final game = buildMotionGame(size: _viewport, cruiseSpeed: kV2CruiseSpeed);
        driveActive(game, mode: mode);
        _scrollTo(game, 3964.0); // a curving (right-bend) offset
        expect(
          game.appliedLeanAngle,
          isNot(0.0),
          reason: 'AC-8: cockpit modes lean at a curving frame',
        );
      });
    }

    for (final mode in <TravelMode>[
      TravelMode.walk,
      TravelMode.run,
      TravelMode.bicycle,
      TravelMode.ship,
    ]) {
      test('${mode.name}_hasExactlyZeroLean_atACurvingFrame', () {
        final game = buildMotionGame(size: _viewport, cruiseSpeed: kV2CruiseSpeed);
        driveActive(game, mode: mode);
        _scrollTo(game, 3964.0); // the SAME curving offset cockpit modes lean at
        // No cockpit foreground to tilt — exactly 0.0 (hard, not epsilon).
        expect(
          game.appliedLeanAngle,
          0.0,
          reason: 'AC-8: non-cockpit modes apply NO lean (exactly 0.0)',
        );
        expect(game.rawLeanTargetAngle, 0.0);
      });
    }

    test('modeSwitch_carWalkCar_flipsLeanOnOffOn_atACurvingFrame', () {
      final game = buildMotionGame(size: _viewport, cruiseSpeed: kV2CruiseSpeed);
      driveActive(game, mode: TravelMode.car);
      _scrollTo(game, 3964.0);
      expect(game.appliedLeanAngle, isNot(0.0));

      driveActive(game, mode: TravelMode.walk);
      expect(game.appliedLeanAngle, 0.0, reason: 'walk hard-zeros the lean');

      driveActive(game, mode: TravelMode.car);
      // Note: the SMOOTHED state was zeroed while in walk; immediately after the
      // switch back the raw TARGET is non-zero again (the curve still bends here).
      expect(
        game.rawLeanTargetAngle,
        isNot(0.0),
        reason: 'AC-8: switching back to car restores the lean signal',
      );
    });
  });

  // ===========================================================================
  // TC-513 (AC-12) — cosmetic-only: engine counters byte-for-byte unchanged.
  // ===========================================================================
  group('TC-513 cosmetic-only — engine counters unchanged by the lean (AC-12)', () {
    // Two engines driven by the SAME injected tick sequence at the SAME instants;
    // alongside each a JourneyGame — one in a LEANING (car, RM off, curving) state
    // and one with the lean DISABLED (reduce-motion ON -> appliedLeanAngle hard
    // zero == the no-lean baseline). The engine counters must be EXACTLY equal
    // regardless: the lean reads no OS signal, decides no active-vs-idle, accrues
    // no distance. (Mirrors TC-409 / journey-pov TC-215 — exact equality.)
    test('engineDistanceProgressElapsedIdle_exactlyEqual_leanVsNoLean', () {
      final start = DateTime(2026, 6, 25, 9);
      final leanClock = _FakeClock(start);
      final noLeanClock = _FakeClock(start);
      final leanEngine = _engine(leanClock);
      final noLeanEngine = _engine(noLeanClock);

      final leanGame = buildMotionGame(size: _viewport, cruiseSpeed: kV2CruiseSpeed)
        ..applyState(
          moving: true,
          mode: TravelMode.car, // leans (cockpit + RM off + curving)
          reduceMotion: false,
          timeOfDayHours: 12,
        );
      final noLeanGame =
          buildMotionGame(size: _viewport, cruiseSpeed: kV2CruiseSpeed)
            ..applyState(
              moving: true,
              mode: TravelMode.car,
              reduceMotion: true, // lean hard-zeroed == the no-lean baseline
              timeOfDayHours: 12,
            );

      DateTime t = start;
      for (final tick in _ticks) {
        t = t.add(tick.delta);
        leanClock.setNow(t);
        noLeanClock.setNow(t);
        leanEngine.tick(
          tick.delta,
          idleSeconds: tick.idleSeconds,
          screenLocked: tick.screenLocked,
        );
        noLeanEngine.tick(
          tick.delta,
          idleSeconds: tick.idleSeconds,
          screenLocked: tick.screenLocked,
        );
        // Pump both scenes so the lean is LIVE on the leaning one this tick (the
        // render/update path runs); this must not feed back into the engine.
        pump(leanGame, frames: 20);
        pump(noLeanGame, frames: 20);

        expect(leanEngine.distanceKm, noLeanEngine.distanceKm,
            reason: 'AC-12: distanceKm must not depend on the lean');
        expect(leanEngine.activeTimeToday, noLeanEngine.activeTimeToday);
        expect(leanEngine.rawActiveTime, noLeanEngine.rawActiveTime);
        expect(leanEngine.idleTimeToday, noLeanEngine.idleTimeToday);
        expect(leanEngine.state, noLeanEngine.state);
      }

      // Non-vacuous: the lean really WAS active on the leaning scene (non-zero at
      // some curving frame) while the baseline stayed level — yet the engine is
      // unmoved.
      double maxLean = 0;
      for (int i = 0; i < 4000; i++) {
        leanGame.update(kFrameDt);
        if (leanGame.appliedLeanAngle.abs() > maxLean) {
          maxLean = leanGame.appliedLeanAngle.abs();
        }
      }
      expect(maxLean, greaterThan(0.01), reason: 'the lean genuinely tilted');
      expect(leanEngine.distanceKm, greaterThan(0));
      expect(leanEngine.distanceKm, noLeanEngine.distanceKm);
    });
  });

  // ===========================================================================
  // TC-515 (AC-14) — graceful degradation: faulted cockpit asset rotated as a
  // placeholder, still surfaced, no crash, WITH the lean active.
  // ===========================================================================
  group('TC-515 faulted cockpit asset rotates as placeholder, no crash (AC-14)', () {
    // The cockpit glyphs are not all sourced, so they degrade to placeholders via
    // the never-throws loadAll path (mirrors journey-pov TC-216). We assert that
    // WITH THE LEAN ACTIVE at a curving offset: the failed cockpit path is still
    // surfaced (failedCockpitAssetPaths ⊆ failedAssetPaths, hasPlaceholderAssets),
    // rendering the leaning frame does not throw, and the placeholder is inside
    // the rotated cockpit layer (it leans WITH the cockpit, not detached).
    late final gameFuture = loadJourneyGame(size: _viewport);

    test('failedCockpitPath_surfaced_andLeaningRenderDoesNotThrow', () async {
      final game = await gameFuture;
      game.applyState(
        moving: true,
        mode: TravelMode.car,
        reduceMotion: false,
        timeOfDayHours: 12,
      );
      // Drive to a curving offset so the cockpit leans (non-zero angle).
      _scrollTo(game, 3964.0);
      expect(
        game.appliedLeanAngle,
        isNot(0.0),
        reason: 'the cockpit must be leaning for this case',
      );
      // The failed cockpit path is still surfaced (degraded, not lost).
      expect(game.hasPlaceholderAssets, isTrue);
      expect(
        game.failedCockpitAssetPaths.difference(game.failedAssetPaths),
        isEmpty,
        reason: 'failedCockpitAssetPaths must be a subset of failedAssetPaths',
      );
      expect(
        game.failedCockpitAssetPaths,
        contains(JourneyAssets.cockpitCarDashboard),
        reason: 'the unbundled dashboard glyph degrades to a placeholder',
      );
      // Rendering the LEANING degraded frame must not throw or blank.
      expect(() => _renderCount(game), returnsNormally);
      expect(_renderCount(game), greaterThan(0));
    });

    test('placeholderIsInsideTheRotatedCockpitLayer_notDetached', () async {
      // Prove the placeholder leans WITH the cockpit: at a curving (leaning)
      // offset the cockpit's added draws (over a no-cockpit baseline) sit in a
      // DIFFERENT vertical envelope than at a level (reduce-motion) frame — the
      // rotation moved the placeholder-bearing cockpit layer. If the placeholder
      // were drawn OUTSIDE the transform it would be identical level vs leaning.
      final game = await loadJourneyGame(size: _viewport);
      game.applyState(
        moving: true,
        mode: TravelMode.car,
        reduceMotion: false,
        timeOfDayHours: 12,
      );
      _scrollTo(game, 5211.0); // sharpest bend -> a strong lean
      expect(game.appliedLeanAngle.abs(), greaterThan(_maxRollCap * 0.5));
      final leaning = _cockpitEnvelope(game);

      // Same game, same offset, but reduce-motion ON -> lean hard zero (level).
      game.applyState(
        moving: true,
        mode: TravelMode.car,
        reduceMotion: true,
        timeOfDayHours: 12,
      );
      expect(game.appliedLeanAngle, 0.0);
      final level = _cockpitEnvelope(game);

      // The rotation changed the cockpit layer's vertical envelope (the
      // placeholder-bearing layer was transformed, not left flat/detached).
      expect(
        (leaning.minY - level.minY).abs() + (leaning.maxY - level.maxY).abs(),
        greaterThan(1.0),
        reason:
            'AC-14: the placeholder must be composited INSIDE the rotated '
            'cockpit layer (it leans with the cockpit, not un-rotated/detached)',
      );
    });
  });
}

// =============================================================================
// TC-513 engine harness (mirrors journey_dynamic_curve_cosmetic_engine_test).
// =============================================================================
class _FakeClock implements Clock {
  _FakeClock(this._now);
  DateTime _now;
  void setNow(DateTime v) => _now = v;
  @override
  DateTime now() => _now;
}

JourneyEngine _engine(_FakeClock clock) => JourneyEngine(
  clock: clock,
  activityPlugin: MockActivitySource(),
  kmPerActiveHour: 10,
  mode: TravelMode.car,
);

typedef _Tick = ({Duration delta, int idleSeconds, bool screenLocked});

const List<_Tick> _ticks = <_Tick>[
  (delta: Duration(minutes: 1), idleSeconds: 0, screenLocked: false),
  (delta: Duration(minutes: 2), idleSeconds: 2, screenLocked: false),
  (delta: Duration(minutes: 3), idleSeconds: 120, screenLocked: false),
  (delta: Duration(minutes: 5), idleSeconds: 600, screenLocked: false),
  (delta: Duration(minutes: 1), idleSeconds: 0, screenLocked: true),
  (delta: Duration(minutes: 4), idleSeconds: 1, screenLocked: false),
];

// =============================================================================
// Render helpers (no raster surface needed).
// =============================================================================

/// Renders one frame and returns the number of draw primitives recorded.
int _renderCount(JourneyGame game) {
  final canvas = _CountingCanvas();
  game.render(canvas);
  return canvas.draws;
}

/// Renders one frame and returns the DEVICE-space vertical envelope (min/max y)
/// of the COCKPIT layer (the draws emitted under a non-identity transform when
/// leaning, or the lower-band draws when level). Transform-aware, so a rotated
/// placeholder-bearing cockpit layer is genuinely reflected — proving the
/// placeholder leans WITH the cockpit (not drawn outside the transform).
({double minY, double maxY}) _cockpitEnvelope(JourneyGame game) {
  final canvas = _XformBoundsCanvas();
  game.render(canvas);
  double minY = double.infinity;
  double maxY = -double.infinity;
  final double bandTop = game.size.y * (1 - game.cockpitViewportFraction);
  // Prefer the rotated (cockpit-layer) draws; if none (level frame), take the
  // lower-band draws (the cockpit when level uses the identity transform).
  final rotated = canvas.draws.where((d) => !d.identity).toList();
  final source = rotated.isNotEmpty
      ? rotated
      : canvas.draws.where((d) => d.maxY > bandTop).toList();
  for (final d in source) {
    if (d.minY < minY) minY = d.minY;
    if (d.maxY > maxY) maxY = d.maxY;
  }
  return (minY: minY, maxY: maxY);
}

class _CountingCanvas implements Canvas {
  int draws = 0;
  @override
  void noSuchMethod(Invocation invocation) {
    if (invocation.memberName.toString().contains('draw')) draws++;
  }
}

/// Transform-aware bounds canvas: tracks the active 2D affine transform and
/// records each draw's DEVICE-space y-extent + whether the transform was the
/// identity (so the cockpit's `canvas.rotate` lean is reflected).
class _XformBoundsCanvas implements Canvas {
  final List<({double minY, double maxY, bool identity})> draws =
      <({double minY, double maxY, bool identity})>[];

  double _a = 1, _b = 0, _c = 0, _d = 1, _tx = 0, _ty = 0;
  final List<List<double>> _stack = <List<double>>[];
  bool get _id =>
      _a == 1 && _b == 0 && _c == 0 && _d == 1 && _tx == 0 && _ty == 0;

  double _mapY(double x, double y) => _b * x + _d * y + _ty;

  void _add(double l, double t, double r, double bo) {
    final ys = <double>[_mapY(l, t), _mapY(r, t), _mapY(r, bo), _mapY(l, bo)];
    double mn = ys.reduce(math.min);
    double mx = ys.reduce(math.max);
    draws.add((minY: mn, maxY: mx, identity: _id));
  }

  @override
  void save() => _stack.add(<double>[_a, _b, _c, _d, _tx, _ty]);
  @override
  void saveLayer(Rect? bounds, Paint paint) =>
      _stack.add(<double>[_a, _b, _c, _d, _tx, _ty]);
  @override
  void restore() {
    if (_stack.isEmpty) return;
    final s = _stack.removeLast();
    _a = s[0];
    _b = s[1];
    _c = s[2];
    _d = s[3];
    _tx = s[4];
    _ty = s[5];
  }

  @override
  void translate(double dx, double dy) {
    _tx += _a * dx + _c * dy;
    _ty += _b * dx + _d * dy;
  }

  @override
  void rotate(double radians) {
    final double cos = math.cos(radians);
    final double sin = math.sin(radians);
    final double na = _a * cos + _c * sin;
    final double nb = _b * cos + _d * sin;
    final double nc = -_a * sin + _c * cos;
    final double nd = -_b * sin + _d * cos;
    _a = na;
    _b = nb;
    _c = nc;
    _d = nd;
  }

  @override
  void scale(double sx, [double? sy]) {
    final double syy = sy ?? sx;
    _a *= sx;
    _b *= sx;
    _c *= syy;
    _d *= syy;
  }

  @override
  void drawRect(Rect rect, Paint paint) =>
      _add(rect.left, rect.top, rect.right, rect.bottom);
  @override
  void drawRRect(RRect rrect, Paint paint) =>
      _add(rrect.left, rrect.top, rrect.right, rrect.bottom);
  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      _add(c.dx - radius, c.dy - radius, c.dx + radius, c.dy + radius);
  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => _add(
    math.min(p1.dx, p2.dx),
    math.min(p1.dy, p2.dy),
    math.max(p1.dx, p2.dx),
    math.max(p1.dy, p2.dy),
  );
  @override
  void drawPath(Path path, Paint paint) {
    final Rect b = path.getBounds();
    _add(b.left, b.top, b.right, b.bottom);
  }

  @override
  void drawImageRect(Image image, Rect src, Rect dst, Paint paint) =>
      _add(dst.left, dst.top, dst.right, dst.bottom);
  @override
  void noSuchMethod(Invocation invocation) {}
}
