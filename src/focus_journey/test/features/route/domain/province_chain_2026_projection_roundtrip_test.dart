// province-chain-2026 — canonical-km projection round-trip over the 34-unit
// spine (AC-11), via the UNCHANGED RoutePolylineProjector.
//
// Traceability (one test <-> one case; PC + AC ids in each description):
//   PC-925 (AC-11) a mid-leg canonical distance d resolves to the correct chain
//                  leg and the km-fraction-interpolated coordinate.
//   PC-926 (AC-11) every one of the 34 checkpoints round-trips
//                  checkpoint -> cumulative km -> coordinate to its seeded centre
//                  within ~1e-6° (node boundaries interpolate exactly).
//   PC-927 (AC-11) boundaries: d=0 -> south tip, d=total -> north tip, and
//                  overshoot/underflow clamp to the nearest tip (no NaN/wrap).
//
// Pure-data test over the production geography: no Flutter, no I/O, no timers.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_polyline_projector.dart';

/// Round-trip coordinate tolerance (~1e-6°) — node boundaries are exact
/// (fraction 0/1), so this is tight per the case brief.
const double _coordTol = 1e-6;

void main() {
  final chain = vietnamProvinceChain;
  final geography = vietnamProvinceGeography;
  final coords = geography.canonicalCoordinates;

  // Project over the FULL spine south->north (origin = south tip Cà Mau). The
  // projector's canonical km axis then equals the chain's cumulative km.
  final projector = RoutePolylineProjector.fromRoute(
    start: chain.southTip,
    direction: JourneyDirection.towardHaGiang,
    geography: geography,
  );

  /// Cumulative canonical km from the south tip to node [index].
  double cumulativeTo(int index) {
    var sum = 0.0;
    for (var i = 0; i < index; i++) {
      sum += chain.segmentsKm[i];
    }
    return sum;
  }

  group('canonical-km projection over the 34-unit spine (AC-11)', () {
    test('PC-925 midLegDistance_resolvesToCorrectLegAndInterpolatedCoordinate', () {
      // Midway into leg index 1 (can_tho -> an_giang).
      const legIndex = 1;
      final legStartKm = cumulativeTo(legIndex);
      final d = legStartKm + chain.segmentsKm[legIndex] / 2;
      final projected = projector.coordinateAt(d);
      final expected = coords[legIndex].lerpTo(coords[legIndex + 1], 0.5);
      expect(projected.latitude, closeTo(expected.latitude, _coordTol));
      expect(projected.longitude, closeTo(expected.longitude, _coordTol));
      // The projected point must lie strictly BETWEEN the two leg endpoints.
      final loLat = coords[legIndex].latitude;
      final hiLat = coords[legIndex + 1].latitude;
      expect(
        projected.latitude,
        inInclusiveRange(
          loLat < hiLat ? loLat : hiLat,
          loLat < hiLat ? hiLat : loLat,
        ),
      );
    });

    test('PC-926 all34Checkpoints_roundTripCumulativeKmToSeededCentre', () {
      expect(coords, hasLength(34));
      expect(projector.routeLengthKm, closeTo(chain.totalChainKm, 1e-6));
      for (var i = 0; i < coords.length; i++) {
        final atNode = projector.coordinateAt(cumulativeTo(i));
        expect(
          atNode.latitude,
          closeTo(coords[i].latitude, _coordTol),
          reason: 'node $i (${chain.nodes[i].id}) latitude round-trip',
        );
        expect(
          atNode.longitude,
          closeTo(coords[i].longitude, _coordTol),
          reason: 'node $i (${chain.nodes[i].id}) longitude round-trip',
        );
      }
    });

    test('PC-927 boundariesAndOutOfRange_clampToTips_noNaNNoWrap', () {
      final total = projector.routeLengthKm;
      // d = 0 -> south tip centre.
      final atZero = projector.coordinateAt(0);
      expect(atZero.latitude, closeTo(coords.first.latitude, _coordTol));
      expect(atZero.longitude, closeTo(coords.first.longitude, _coordTol));
      // d = total -> north tip centre.
      final atTotal = projector.coordinateAt(total);
      expect(atTotal.latitude, closeTo(coords.last.latitude, _coordTol));
      expect(atTotal.longitude, closeTo(coords.last.longitude, _coordTol));
      // Underflow clamps to the south tip; overshoot clamps to the north tip.
      final under = projector.coordinateAt(-500);
      expect(under, atZero);
      final over = projector.coordinateAt(total + 5000);
      expect(over, atTotal);
      // No NaN anywhere.
      for (final c in <GeoCoordinate>[atZero, atTotal, under, over]) {
        expect(c.latitude.isNaN, isFalse);
        expect(c.longitude.isNaN, isFalse);
      }
    });
  });
}
