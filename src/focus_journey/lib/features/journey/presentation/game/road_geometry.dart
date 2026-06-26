/// Presentation layer (Flame). Pure-math model of the WINDING road centre-line
/// (journey-scene-v2 #1 / AC-6, Decision (d): a segmented heading-offset curve
/// over the existing fake-3D trapezoid). Pure Dart + `dart:math` only — no
/// Flutter, no Bloc, no engine, no OS. Frame-deterministic (a pure function of
/// the scroll offset), so tests and goldens are stable.
///
/// MODEL (segmented heading-offset, NOT a spline — cheaper, perf-friendly):
/// the road is a sequence of fixed-length segments along the travelled
/// distance. Each segment has a constant *heading* (a small lateral slope);
/// integrating heading over distance yields a smooth, continuously-bending
/// centre-line that drifts left and right. The headings come from a fixed,
/// allocation-free pseudo-sequence (no `Random`) so the curve is reproducible
/// and the same every run.
///
/// The output is a normalised lateral offset in roughly `[-1, 1]` for a given
/// world distance. The painter multiplies it by a depth-scaled amplitude so the
/// bend is strong near the camera and tucks back to (near) zero at the horizon,
/// preserving the near→horizon trapezoid read (AC-6). Lane markings and roadside
/// objects sample the SAME function at their own world distance so they follow
/// the curve (AC-6/AC-7).
library;

import 'dart:math' as math;

/// Computes the winding road centre-line as a pure function of world distance.
///
/// "World distance" is the shared scroll offset (logical px) plus a per-sample
/// depth contribution; the curve is therefore tied to the same single scroll
/// phase as everything else in the scene (frozen when stopped → curve frozen).
class RoadGeometry {
  /// Creates a geometry model.
  ///
  /// [segmentLength] is how far (in world px) each constant-heading segment
  /// runs before the heading steps to the next value. Longer → lazier bends.
  /// [maxHeading] caps the per-segment lateral slope (normalised lateral units
  /// per world px) so the road never bends implausibly hard.
  ///
  /// journey-dynamic-curve / AC-1 + AC-7: the default [maxHeading] was
  /// intensified from the journey-scene-v2 baseline `0.0016` to `0.0036`
  /// (≈2.25× peak per-distance slope — inside Kevin's 2–3× "sweeping but
  /// smooth" bracket) so the bend reads as a genuine sweeping drive. The cyclic
  /// heading table, [segmentLength], and therefore the precomputed prefix sums
  /// are UNCHANGED — `maxHeading` scales the integral linearly, so the O(1)
  /// closed form (NFR-1) and its byte-identical-to-naive-loop guard still hold.
  RoadGeometry({this.segmentLength = 900.0, this.maxHeading = 0.0036})
    : assert(segmentLength > 0, 'segmentLength must be positive'),
      assert(maxHeading > 0, 'maxHeading must be positive');

  /// World-distance length of one constant-heading segment (logical px).
  final double segmentLength;

  /// Maximum absolute heading (normalised lateral units per world px).
  final double maxHeading;

  // Fixed heading table — a smooth-ish hand-tuned wave of small signed
  // headings, repeated cyclically. Deterministic and allocation-free at runtime
  // (no Random, no per-call list creation). The values sum to ~0 over a cycle
  // so the road meanders without drifting permanently off to one side.
  static const List<double> _headings = <double>[
    0.55,
    0.85,
    0.35,
    -0.25,
    -0.75,
    -0.95,
    -0.45,
    0.15,
    0.65,
    0.9,
    0.4,
    -0.35,
    -0.8,
    -0.6,
    -0.1,
    0.5,
  ];

  /// Number of headings per cycle.
  static const int _cycle = 16;

  /// Prefix sums of [_headings]: `_prefix[k] == sum(headings[0..k-1])`, length
  /// 17 (`_prefix[0] == 0`, `_prefix[16] == cycle sum`). Precomputed so the
  /// integral is a true O(1) closed form (NFR-1) — no per-frame accumulating
  /// loop, regardless of how large `worldDistance` grows over a long session.
  static const List<double> _prefix = <double>[
    0.0, // [0]
    0.55, // +0.55
    1.40, // +0.85
    1.75, // +0.35
    1.50, // -0.25
    0.75, // -0.75
    -0.20, // -0.95
    -0.65, // -0.45
    -0.50, // +0.15
    0.15, // +0.65
    1.05, // +0.90
    1.45, // +0.40
    1.10, // -0.35
    0.30, // -0.80
    -0.30, // -0.60
    -0.40, // -0.10
    0.10, // +0.50  == cycle sum
  ];

  /// The signed heading sum over one full cycle (`_prefix[_cycle]`).
  static const double _cycleSum = 0.10;

  /// The normalised lateral centre-line offset at [worldDistance] (logical px),
  /// in roughly `[-1, 1]`. Pure, deterministic, allocation-free, O(1).
  ///
  /// Implementation: integrate the piecewise-constant heading from 0 to
  /// [worldDistance]. The integral is a TRUE closed form — the heading table is
  /// cyclic (16 entries) with a known per-cycle sum, so
  /// `integral = fullCycles * cycleSum + prefixSum[partialIndex]`, all over
  /// fully-crossed segments, plus the current partial segment's `heading *
  /// remainder`, then scaled by [segmentLength] and [maxHeading]. No loop, so
  /// the cost is constant no matter how far the session has scrolled (NFR-1).
  /// The integrated heading is folded through a gentle sine so the centre-line
  /// oscillates smoothly in `[-1, 1]` (the road stays on screen) while still
  /// reading as "constant heading per segment → continuous bend".
  double lateralAt(double worldDistance) {
    // Accumulated (signed) heading-distance up to worldDistance.
    final double phase = _integratedHeading(worldDistance);
    // Bounded meander: sine of the integrated heading phase.
    return math.sin(phase);
  }

  /// The analytic derivative `d(lateralAt)/d(worldDistance)` at [worldDistance]
  /// — the normalised centre-line slope per world px. Pure, deterministic,
  /// allocation-free, O(1) (same closed-form `_integratedHeading` plus the
  /// piecewise-constant heading of the current segment).
  ///
  /// journey-dynamic-curve / AC-6: the side-object pool uses this to spawn on
  /// equal ARC-LENGTH increments (`ds = √(1 + (ampPx · slope)²) · dworld`)
  /// rather than equal longitudinal distance, so arc-length spacing stays even
  /// (±20%, AC-5) even where the sharper bend leans hard. Since
  /// `lateralAt = sin(integral(heading)·maxHeading)`, the chain rule gives
  /// `d/dworld = cos(integral) · heading(currentSegment) · maxHeading`.
  double lateralSlopeAt(double worldDistance) {
    // Guarded `< 0` (not `<= 0` like _integratedHeading): at exactly d==0 this
    // returns the right-hand derivative `heading[0]·maxHeading` (the slope as
    // the road starts bending), which is correct — `lateralAt(0)` is 0 but its
    // rate of change there is non-zero. The asymmetry vs _integratedHeading's
    // `<= 0` is intentional; don't "align" them.
    if (worldDistance < 0) {
      return 0;
    }
    final double phase = _integratedHeading(worldDistance);
    final int segmentIndex = worldDistance ~/ segmentLength;
    return math.cos(phase) * _heading(segmentIndex) * maxHeading;
  }

  /// The integral of the piecewise-constant heading from 0 to [worldDistance],
  /// computed in O(1). Byte-identical to summing each segment, but without the
  /// unbounded per-call loop (NFR-1). Each fully-crossed segment contributes
  /// `heading * segmentLength`; the current partial segment contributes
  /// `heading * remainder`. Scaled by [maxHeading].
  double _integratedHeading(double worldDistance) {
    if (worldDistance <= 0) {
      return 0;
    }
    final int fullSegments = worldDistance ~/ segmentLength;
    final double remainder = worldDistance - fullSegments * segmentLength;

    // Sum of headings over the `fullSegments` fully-crossed segments, in O(1):
    // whole cycles contribute `cycleSum` each; the leftover head contributes a
    // prefix sum from the precomputed table.
    final int fullCycles = fullSegments ~/ _cycle;
    final int partialIndex = fullSegments % _cycle;
    final double headingSum = fullCycles * _cycleSum + _prefix[partialIndex];

    // Add the current partial segment's heading over its remainder, then scale.
    final double partialHeading = _heading(fullSegments);
    final double acc = headingSum * segmentLength + partialHeading * remainder;
    return acc * maxHeading;
  }

  /// Heading for segment [index] (cyclic over the fixed table).
  double _heading(int index) {
    return _headings[((index % _cycle) + _cycle) % _cycle];
  }
}
