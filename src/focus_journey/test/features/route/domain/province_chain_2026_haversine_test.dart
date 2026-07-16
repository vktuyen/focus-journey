// province-chain-2026 — great-circle segment distances (AC-3).
//
// Traceability (one test <-> one case; PC + AC ids in each description):
//   PC-905 (AC-3)  each of the 33 segments == the haversine distance between its
//                  consecutive admin-centre coordinates within +/-1% or <=1 km;
//                  totalChainKm == the summed 33 legs and sits in ~2500..3500 km.
//   PC-906 (AC-3)  one hand-computed haversine reference leg pins the radius +
//                  formula to <=1 km (catches a systematic haversine bug hidden
//                  in the aggregate sum).
//
// Pure-data test: no Flutter, no I/O, no timers, no network. The haversine is
// RE-IMPLEMENTED here independently of the production greatCircleKm so this pins
// the CONTRACT (mean Earth radius 6371 km, degrees, correct lat/lon order), not
// the code calling itself.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/vietnam_units_2026.dart';

/// Mean Earth radius (km) — the standard spherical approximation. Fixed here so
/// the test's reference is independent of the production constant.
const double _rEarthKm = 6371.0;

double _rad(double deg) => deg * math.pi / 180.0;

/// An independent great-circle (haversine) distance in km — deliberately NOT the
/// production `greatCircleKm`, so a systematic bug there can't hide.
double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  final dPhi = _rad(lat2 - lat1);
  final dLambda = _rad(lon2 - lon1);
  final a =
      math.sin(dPhi / 2) * math.sin(dPhi / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLambda / 2) *
          math.sin(dLambda / 2);
  return _rEarthKm * 2 * math.asin(math.sqrt(a));
}

void main() {
  final chain = vietnamProvinceChain;
  final coords = vietnamProvinceGeography.canonicalCoordinates;

  group('province-chain-2026 great-circle segments (AC-3)', () {
    test('PC-905 everySegmentEqualsIndependentHaversine_within1PercentOr1Km', () {
      expect(chain.segmentsKm.length, coords.length - 1);
      for (var i = 0; i < chain.segmentsKm.length; i++) {
        final from = coords[i];
        final to = coords[i + 1];
        final expected = _haversineKm(
          from.latitude,
          from.longitude,
          to.latitude,
          to.longitude,
        );
        // AC-3 tolerance: +/-1% OR <=1 km, whichever is looser per segment.
        final tolerance = math.max(1.0, expected * 0.01);
        expect(
          chain.segmentsKm[i],
          closeTo(expected, tolerance),
          reason:
              'segment $i (${chain.nodes[i].id}->${chain.nodes[i + 1].id}) '
              '${chain.segmentsKm[i]} != haversine $expected',
        );
      }
    });

    test('PC-905 totalChainKmEqualsSumOf33Legs_andSitsInSaneRange', () {
      final sum = chain.segmentsKm.fold<double>(0, (a, b) => a + b);
      expect(chain.totalChainKm, closeTo(sum, 1e-6));
      // Do NOT hardcode the exact total; assert the spec's ~2500..3500 km range.
      expect(chain.totalChainKm, greaterThan(2500));
      expect(chain.totalChainKm, lessThan(3500));
      // Sanity: the summed haversine over the raw seeded coords agrees too.
      var independent = 0.0;
      for (var i = 0; i < coords.length - 1; i++) {
        independent += _haversineKm(
          coords[i].latitude,
          coords[i].longitude,
          coords[i + 1].latitude,
          coords[i + 1].longitude,
        );
      }
      expect(chain.totalChainKm, closeTo(independent, 1e-6));
    });

    test('PC-906 handComputedReferenceLeg_pinsRadiusAndFormula_within1Km', () {
      // The south-most leg Cà Mau -> Cần Thơ. BOTH endpoints are offset-free
      // (Cà Mau uses its authoritative centre directly; Cần Thơ carries no
      // coast-alignment offset), so the seeded literals are unambiguous:
      //   Cà Mau   9.177 N / 105.152 E
      //   Cần Thơ 10.033 N / 105.784 E
      // Independently hand-computed offline with R = 6371 km:
      //   d = 117.731846 km  (rounded reference below).
      const expectedKm = 117.731846;
      final caMau = kVietnamUnits2026.firstWhere((u) => u.id == 'ca_mau');
      final canTho = kVietnamUnits2026.firstWhere((u) => u.id == 'can_tho');
      // Guard the assumption that the seeded coords are the offset-free literals.
      expect(caMau.lat, 9.177);
      expect(caMau.lon, 105.152);
      expect(canTho.lat, 10.033);
      expect(canTho.lon, 105.784);
      // segmentsKm[0] is the Cà Mau -> Cần Thơ leg (south tip is index 0).
      expect(chain.nodes[0].id, 'ca_mau');
      expect(chain.nodes[1].id, 'can_tho');
      expect(
        chain.segmentsKm[0],
        closeTo(expectedKm, 1.0),
        reason: 'a systematic haversine bug (wrong radius / deg-vs-rad / '
            'swapped lat-lon) would shift this pinned leg',
      );
    });
  });
}
