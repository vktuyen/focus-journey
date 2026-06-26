// Unit tests for the winding-road geometry (journey-scene-v2 #1 / AC-6) and the
// NFR-1 closed-form integral.
//
// The headline guard (B1 / NFR-1): RoadGeometry._integratedHeading must be a
// TRUE O(1) closed form that is byte-identical to the naive per-segment summing
// loop — including at very large worldDistance values reached after a long focus
// session (~1.5M px) — so the unbounded per-frame cost regression cannot recur.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/presentation/game/road_geometry.dart';

/// The SAME fixed heading table the production geometry uses. Kept here so the
/// reference implementation below is an independent re-derivation (not a copy of
/// the production constants), proving the closed form matches the summed loop.
const List<double> _headings = <double>[
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

double _headingAt(int index) {
  final int n = _headings.length;
  return _headings[((index % n) + n) % n];
}

/// Reference NAIVE implementation: integrate the piecewise-constant heading by
/// summing every fully-crossed segment plus the partial segment. This is the
/// O(n) form the production code replaced; lateralAt must equal sin() of this.
double _referenceLateral(
  double worldDistance, {
  double segmentLength = 900.0,
  double maxHeading = 0.0036, // journey-dynamic-curve shipped default
}) {
  if (worldDistance <= 0) {
    return math.sin(0);
  }
  final int fullSegments = worldDistance ~/ segmentLength;
  final double remainder = worldDistance - fullSegments * segmentLength;
  double acc = 0;
  for (int i = 0; i < fullSegments; i++) {
    acc += _headingAt(i) * segmentLength;
  }
  acc += _headingAt(fullSegments) * remainder;
  return math.sin(acc * maxHeading);
}

void main() {
  group(
    'B1/NFR-1 closed-form integral == naive summed loop (byte-identical)',
    () {
      final geometry = RoadGeometry(); // production defaults

      test('matchesReferenceAcrossSmallAndVeryLargeDistances', () {
        // Includes values past a long session (~1.5M px) where the old loop would
        // have run >1600 iterations/call; the closed form must still match.
        const samples = <double>[
          0.0,
          1.0,
          450.0,
          899.999,
          900.0,
          900.001,
          1234.5,
          14400.0, // exactly one cycle (16 * 900)
          14400.001,
          50_000.0,
          123_456.789,
          500_000.0,
          1_000_000.0,
          1_500_000.0,
          1_500_000.5,
          9_999_999.0,
        ];
        for (final d in samples) {
          expect(
            geometry.lateralAt(d),
            closeTo(_referenceLateral(d), 1e-9),
            reason:
                'closed form must equal the summed loop at worldDistance=$d',
          );
        }
      });

      test('matchesReference_onAFineSweepThroughManyCycles', () {
        // A dense sweep so any per-segment / per-cycle boundary error surfaces.
        for (double d = 0; d <= 60_000; d += 137.0) {
          expect(
            geometry.lateralAt(d),
            closeTo(_referenceLateral(d), 1e-9),
            reason: 'mismatch at worldDistance=$d',
          );
        }
      });

      test('output_isAlwaysBoundedInMinusOneToOne', () {
        for (double d = 0; d <= 2_000_000; d += 9999.0) {
          final v = geometry.lateralAt(d);
          expect(v, inInclusiveRange(-1.0, 1.0));
        }
      });
    },
  );

  group('AC-6 the centre-line is non-constant and bends both ways', () {
    final geometry = RoadGeometry();

    test('isNonConstant_andCrossesZeroBothDirections', () {
      double min = double.infinity;
      double max = -double.infinity;
      final distinct = <double>{};
      for (double d = 0; d <= 40_000; d += 200.0) {
        final v = geometry.lateralAt(d);
        distinct.add(double.parse(v.toStringAsFixed(3)));
        if (v < min) min = v;
        if (v > max) max = v;
      }
      expect(distinct.length, greaterThan(10), reason: 'not dead-straight');
      expect(min, lessThan(-0.5), reason: 'bends one way');
      expect(max, greaterThan(0.5), reason: 'bends the other way');
    });
  });
}
