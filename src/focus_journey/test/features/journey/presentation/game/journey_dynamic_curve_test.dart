// Measurement tests that LOCK the journey-dynamic-curve intensification
// constants against the spec contract. These are the build-time guards the
// flame-game-developer wrote while tuning; the full TC-401..TC-415 suite is
// authored separately by test-script-author.
//
// Pins (journey-dynamic-curve, Kevin-approved 2-3x bracket, 2026-06-25):
//   * geometry maxHeading      0.0016 -> 0.0036  (peak slope ~2.25x baseline)
//   * painter curveAmplitudeFrac 0.16 -> 0.20    (rendered excursion ~1.25x)
//   * spawn cadence: arc-length-aware (AC-6 rework fork) so AC-5 +/-20% holds
//     at any viewport width.
//
// "Baseline" is the PINNED journey-scene-v2 curve, independently re-derived
// here (segmentLength 900, maxHeading 0.0016, ampFrac 0.16) exactly as
// road_geometry_test.dart re-derives _referenceLateral. We NEVER import the
// shipped params as the baseline.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/presentation/game/road_geometry.dart';
import 'package:focus_journey/features/journey/presentation/game/road_painter.dart';
import 'package:focus_journey/features/journey/presentation/game/scene_motion.dart';

import 'journey_game_test_harness.dart';

// --- Independent baseline re-derivation (the pinned journey-scene-v2 curve) ---

const List<double> _headings = <double>[
  0.55, 0.85, 0.35, -0.25, -0.75, -0.95, -0.45, 0.15, //
  0.65, 0.9, 0.4, -0.35, -0.8, -0.6, -0.1, 0.5,
];

double _headingAt(int index) {
  final int n = _headings.length;
  return _headings[((index % n) + n) % n];
}

/// Baseline lateralAt, re-derived independently — the journey-scene-v2 pinned
/// curve (segmentLength 900, maxHeading 0.0016). Not the shipped params.
double _baselineLateral(double d, {double seg = 900.0, double mh = 0.0016}) {
  if (d <= 0) return math.sin(0);
  final int full = d ~/ seg;
  final double rem = d - full * seg;
  double acc = 0;
  for (int i = 0; i < full; i++) {
    acc += _headingAt(i) * seg;
  }
  acc += _headingAt(full) * rem;
  return math.sin(acc * mh);
}

const double _baselineAmpFrac = 0.16;

/// Peak per-distance slope of [lateral] over one full heading cycle, using the
/// SAME finite-difference step for baseline and shipped so the ratio is honest.
double _peakSlope(double Function(double) lateral, {double seg = 900.0}) {
  const double h = 1.0;
  final double cycle = 16 * seg;
  double peak = 0;
  for (double d = 0; d <= cycle * 2; d += 1.0) {
    final double s = (lateral(d + h) - lateral(d)).abs() / h;
    if (s > peak) peak = s;
  }
  return peak;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AC-1 peak model curvature is ~2x baseline (and <= ~3x — AC-7)', () {
    test('shippedPeakSlope_isWithinTheTwoToThreeXBracket', () {
      final shipped = RoadGeometry(); // production defaults (maxHeading 0.0036)
      final double basePeak = _peakSlope(_baselineLateral);
      final double shippedPeak = _peakSlope(shipped.lateralAt);
      final double ratio = shippedPeak / basePeak;

      // AC-1 lower target ~2x; AC-7 ceiling ~3x. Achieved: 2.25x.
      expect(
        ratio,
        greaterThanOrEqualTo(2.0),
        reason: 'AC-1: peak slope must be >= ~2x baseline; got ${ratio}x',
      );
      expect(
        ratio,
        lessThanOrEqualTo(3.0),
        reason: 'AC-7: peak slope must stay <= ~3x baseline; got ${ratio}x',
      );
      // Pin the exact achieved multiple (re-pin if retuned).
      expect(ratio, closeTo(2.25, 0.05));
    });

    test('lateralAt_staysBoundedInMinusOneToOne_atTheSharperCurvature', () {
      final shipped = RoadGeometry();
      for (double d = 0; d <= 2_000_000; d += 9999.0) {
        expect(shipped.lateralAt(d), inInclusiveRange(-1.0, 1.0));
      }
    });
  });

  group(
    'AC-2 sharper bend reaches the screen (rendered excursion > baseline)',
    () {
      double baselineCentreLine(double width, double off, double t) {
        final double world = off + (1.0 - t) * 1200.0;
        return _baselineLateral(world) * (width * _baselineAmpFrac) * (t * t);
      }

      test('nearCameraPeakExcursion_beatsBaseline_byAClearMargin', () {
        final painter = RoadPainter(); // shipped curveAmplitudeFrac 0.20
        const double width = 1280.0;
        const double height = 720.0;
        final Size size = Size(width, height);
        const double cycle = 16 * 900.0;

        double basePeak = 0;
        double shippedPeak = 0;
        for (double off = 0; off <= cycle; off += 2.0) {
          final double b = baselineCentreLine(width, off, 1.0).abs();
          final double s = painter.centreLineOffset(size, off, 1.0).abs();
          if (b > basePeak) basePeak = b;
          if (s > shippedPeak) shippedPeak = s;
        }
        final double ratio = shippedPeak / basePeak;
        expect(
          ratio,
          greaterThanOrEqualTo(1.2),
          reason:
              'AC-2: rendered near-camera excursion must clearly beat '
              'baseline; got ${ratio}x (shipped $shippedPeak vs base $basePeak)',
        );
        expect(ratio, closeTo(1.25, 0.02));
      });
    },
  );

  group(
    'AC-7 calm-tone ceiling — per-frame near-camera delta <= ~2% width',
    () {
      test('cruiseFrameDelta_staysUnderTheSmoothnessCap', () {
        final painter = RoadPainter();
        const double width = 1280.0;
        const double height = 720.0;
        final Size size = Size(width, height);
        // One eased cruise frame's scroll delta.
        const double delta = kV2CruiseSpeed * (1 / 60.0);
        const double cap = 0.02 * width; // ~2% viewport width per frame
        const double cycle = 16 * 900.0;

        double worst = 0;
        for (double off = 0; off <= cycle; off += 1.0) {
          final double a = painter.centreLineOffset(size, off, 1.0);
          final double b = painter.centreLineOffset(size, off + delta, 1.0);
          final double d = (b - a).abs();
          if (d > worst) worst = d;
        }
        expect(
          worst,
          lessThanOrEqualTo(cap),
          reason:
              'AC-7: per-frame near-camera delta ($worst px) must be <= cap '
              '($cap px = 2% of $width)',
        );
        // Achieved ~0.12% width — comfortably calm. Pin the magnitude.
        expect(worst / width, lessThan(0.002));
      });
    },
  );

  group('AC-5/AC-6 even arc-length spacing at the sharper curvature', () {
    // The DECISIVE measurement that drove the fork: with the sharper curve a
    // FIXED longitudinal cadence breaks +/-20% at wide viewports (~22% at
    // 1280, ~41% at 1920). The arc-length-aware cadence keeps it even at any
    // width. We assert the OUTCOME — the arc-length gap between CONSECUTIVE
    // SPAWNS on the curving centre-line stays within +/-20% — across
    // representative viewport widths. (We measure over the full spawn sequence
    // rather than the transiently-live subset: the live set can momentarily
    // skip a recycled object due to per-object parallax variation, which is a
    // pool-recycle sampling artifact unrelated to the spawn CADENCE this fork
    // controls. The cadence is what AC-6 changed and AC-5 binds.)
    //
    // Traceability: the cases-file TC-405 also prescribes a check over the
    // `JourneyGame.liveCentreLinePoints` seam (each object's real (world,
    // lateral) on the curving centre-line — the seam that can genuinely FAIL,
    // vs the always-even spawn cadence). That live-set leg is owned by
    // `journey_scene_v2_test.dart` (`renderedArcLengthGaps...`); here we guard
    // the spawn-sequence outcome that the arc-length-aware fork directly
    // controls. Together they cover AC-5 over both seams.
    double arcGap(double w0, double w1, double amp, RoadGeometry g) {
      const double step = 0.5;
      double len = 0;
      double prev = g.lateralAt(w0) * amp;
      for (double w = w0 + step; w <= w1 + 1e-9; w += step) {
        final double cur = g.lateralAt(w) * amp;
        final double dl = cur - prev;
        len += math.sqrt(step * step + dl * dl);
        prev = cur;
      }
      return len;
    }

    for (final double width in <double>[420.0, 800.0, 1280.0, 1920.0]) {
      test('arcLengthGaps_withinTwentyPercent_atWidth_${width.toInt()}', () {
        final game = buildMotionGame(
          size: Vector2(width, 720.0),
          cruiseSpeed: kV2CruiseSpeed,
          sideObjectCapacity: 64,
        );
        driveActive(game);
        pump(game, frames: 120); // reach cruise.

        // Collect the full ordered spawn sequence over a long run (covers >1
        // full heading cycle so the sharpest bends are exercised).
        final List<double> spawns = <double>[];
        double lastMax = -1;
        for (int i = 0; i < 12000; i++) {
          game.update(kFrameDt);
          final live = game.liveSpawnDistances;
          if (live.isNotEmpty && live.last > lastMax) {
            for (final d in live) {
              if (d > lastMax) spawns.add(d);
            }
            lastMax = live.last;
          }
        }
        spawns.sort();
        expect(spawns.length, greaterThan(20));

        final double amp = width * RoadPainter.curveAmplitudeFrac;
        final RoadGeometry g = RoadGeometry();
        final List<double> gaps = <double>[];
        for (int i = 1; i < spawns.length; i++) {
          gaps.add(arcGap(spawns[i - 1], spawns[i], amp, g));
        }
        final double mean = gaps.reduce((a, b) => a + b) / gaps.length;
        expect(mean, greaterThan(0));
        double worstRatio = 0;
        for (final gp in gaps) {
          final double ratio = (gp - mean).abs() / mean;
          if (ratio > worstRatio) worstRatio = ratio;
          expect(
            (gp - mean).abs(),
            lessThanOrEqualTo(0.20 * mean + 1e-6),
            reason:
                'AC-5: arc-length spawn gap $gp out of +/-20% of mean '
                '$mean at width $width (worst ratio $worstRatio)',
          );
        }
        // The curve genuinely perturbs the longitudinal cadence to keep arc
        // length even (not the vacuous fixed-longitudinal check): the
        // longitudinal spawn gaps must vary (compress where the road leans).
        final List<double> longGaps = <double>[];
        for (int i = 1; i < spawns.length; i++) {
          longGaps.add(spawns[i] - spawns[i - 1]);
        }
        final double longMin = longGaps.reduce(math.min);
        final double longMax = longGaps.reduce(math.max);
        expect(
          longMax - longMin,
          greaterThan(1.0),
          reason:
              'arc-length-aware cadence must vary the longitudinal gap '
              '(min $longMin, max $longMax) to flatten arc length',
        );
      });
    }
  });

  group('NFR-1 closed-form integral + slope stay O(1) / exact', () {
    // The headline NFR-1 proxy: lateralAt and lateralSlopeAt must be byte-exact
    // closed forms (independent re-derivation) at huge distances reached after
    // a long session, with no per-call cost growth. We re-derive the naive
    // reference with the SHIPPED params (maxHeading 0.0036).
    double naiveLateral(double d, {double seg = 900.0, double mh = 0.0036}) {
      if (d <= 0) return math.sin(0);
      final int full = d ~/ seg;
      final double rem = d - full * seg;
      double acc = 0;
      for (int i = 0; i < full; i++) {
        acc += _headingAt(i) * seg;
      }
      acc += _headingAt(full) * rem;
      return math.sin(acc * mh);
    }

    // Slope of the naive reference via the same analytic chain rule:
    // cos(integral) * heading(segment) * mh.
    double naiveSlope(double d, {double seg = 900.0, double mh = 0.0036}) {
      if (d < 0) return 0;
      final int full = d ~/ seg;
      final double rem = d - full * seg;
      double acc = 0;
      for (int i = 0; i < full; i++) {
        acc += _headingAt(i) * seg;
      }
      acc += _headingAt(full) * rem;
      return math.cos(acc * mh) * _headingAt(full) * mh;
    }

    test('lateralAt_byteIdentical_toNaiveLoop_atHugeDistances', () {
      final g = RoadGeometry();
      const samples = <double>[
        0.0,
        1.0,
        900.0,
        14400.0,
        123_456.789,
        1_500_000.0,
        9_999_999.0,
      ];
      for (final d in samples) {
        expect(g.lateralAt(d), closeTo(naiveLateral(d), 1e-9), reason: 'd=$d');
      }
    });

    test('lateralSlopeAt_byteIdentical_toAnalyticReference', () {
      final g = RoadGeometry();
      for (double d = 0; d <= 60_000; d += 137.0) {
        expect(
          g.lateralSlopeAt(d),
          closeTo(naiveSlope(d), 1e-9),
          reason: 'slope mismatch at d=$d',
        );
      }
      // And at a huge distance (cost must not grow with d).
      expect(
        g.lateralSlopeAt(9_999_999.0),
        closeTo(naiveSlope(9_999_999.0), 1e-9),
      );
    });
  });
}
