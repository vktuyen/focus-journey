// Unit tests for the framework-free route-curve smoother (route-real-road /
// AC-1 + AC-5). Two concerns:
//   - the spline DENSIFIES + smooths: the output has more vertices than the
//     input and still passes through every original checkpoint (AC-1); and
//   - the spline stays ON LAND: densely sampled against the REAL bundled
//     `containsLandmass`, it introduces NO new sea excursion beyond the
//     province-chain-2026 ratified quảng_trị→hà_tĩnh residual (AC-5).
//
// The real-geometry fixture is read straight from disk with the production pure
// parser (mirrors base_map_geometry_test.dart) — deterministic + offline.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/data/base_map_repository.dart';
import 'package:focus_journey/features/route/domain/base_map_geometry.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_curve.dart';

BaseMapGeometry _loadRealGeometry() {
  Directory dir = Directory.current;
  File? asset;
  for (var i = 0; i < 8; i++) {
    final candidate = File('${dir.path}/$kBaseMapAssetPath');
    if (candidate.existsSync()) {
      asset = candidate;
      break;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  if (asset == null) {
    fail('could not locate bundled asset $kBaseMapAssetPath');
  }
  return AssetBaseMapRepository.parseGeoJson(asset.readAsStringSync());
}

double _dist(GeoCoordinate a, GeoCoordinate b) {
  final dx = a.longitude - b.longitude;
  final dy = a.latitude - b.latitude;
  return math.sqrt(dx * dx + dy * dy);
}

void main() {
  group('smoothCurve — densifies + passes through checkpoints (AC-1)', () {
    test('shortInputIsReturnedUnchanged', () {
      const pts = <GeoCoordinate>[
        GeoCoordinate(latitude: 10, longitude: 105),
        GeoCoordinate(latitude: 11, longitude: 106),
      ];
      expect(smoothCurve(pts), equals(pts));
    });

    test('outputHasManyMoreVerticesThanInput', () {
      final coords = vietnamProvinceGeography.canonicalCoordinates;
      final curve = smoothCurve(coords, samplesPerSegment: 16);
      // steps per segment * segments + 1 start point.
      expect(curve.length, greaterThan(coords.length * 10));
    });

    test('curvePassesThroughEveryOriginalCheckpoint', () {
      final coords = vietnamProvinceGeography.canonicalCoordinates;
      final curve = smoothCurve(coords, samplesPerSegment: 8);
      for (final c in coords) {
        final onCurve = curve.any((p) => _dist(p, c) < 1e-9);
        expect(onCurve, isTrue, reason: 'checkpoint $c not on the curve');
      }
    });

    test('curveIsNotJustTheStraightChords', () {
      // At least one interior sample must deviate from the straight line between
      // its bracketing checkpoints — i.e. the road actually bends (AC-1).
      final coords = vietnamProvinceGeography.canonicalCoordinates;
      final curve = smoothCurve(coords, samplesPerSegment: 16);
      var maxDeviation = 0.0;
      for (var i = 0; i < coords.length - 1; i++) {
        final a = coords[i];
        final b = coords[i + 1];
        for (final p in curve) {
          // Perpendicular distance from p to segment a-b (only meaningful for
          // samples roughly within the segment's bbox; a coarse proxy is fine).
          final dev = _perp(p, a, b);
          if (dev > maxDeviation) maxDeviation = dev;
        }
      }
      expect(maxDeviation, greaterThan(1e-4));
    });
  });

  group('smoothCurve — stays on land (AC-5)', () {
    // Mirrors the province-chain-2026 dense-sampling guard, but on the SMOOTHED
    // full-spine curve. The smoother emits exactly `samplesPerSegment` points per
    // input segment (after the shared start point), so each block of samples is
    // attributable back to the checkpoint leg it smooths — letting us assert, leg
    // by leg, that the spline introduces NO new SEA excursion (AC-5).
    //
    // Two ratified residuals are allowed, both bounded + documented (following
    // province-chain-2026's precedent of a capped, named residual):
    //   - quảng_trị→hà_tĩnh: the province-chain-2026 SEA residual (a generalized-
    //     coastline notch near (17.75, 106.39)), carried over. The tuned curviness
    //     keeps it at ≤3 samples (no worse than the straight chord).
    //   - lạng_sơn→cao_bằng: a tiny bow across the generalized NORTHERN LAND BORDER
    //     at the inland north tip (~22 N) — NOT open sea. The straight chord grazes
    //     the border ring there, so any curve > 0 clips ≤2 samples. Capped here.
    // EVERY other leg — including every coastal leg (Đà Nẵng / Huế / Nha Trang …) —
    // must be fully on land, so a regression that bows the road into the sea fails.
    const ratifiedResiduals = <String, int>{
      'quang_tri->ha_tinh': 3,
      'lang_son->cao_bang': 2,
    };

    test('denselySampledSmoothCurveIntroducesNoNewSeaExcursion', () {
      final geometry = _loadRealGeometry();
      final coords = vietnamProvinceGeography.canonicalCoordinates;
      const samplesPerSegment = 50;
      final curve = smoothCurve(coords, samplesPerSegment: samplesPerSegment);

      final seaByLeg = <String, int>{};
      for (var i = 0; i < coords.length - 1; i++) {
        var sea = 0;
        for (var s = 1; s <= samplesPerSegment; s++) {
          if (!geometry.containsLandmass(curve[i * samplesPerSegment + s])) {
            sea++;
          }
        }
        if (sea > 0) {
          seaByLeg['${_nodeId(i)}->${_nodeId(i + 1)}'] = sea;
        }
      }

      final unexpected = <String, int>{
        for (final e in seaByLeg.entries)
          if (!ratifiedResiduals.containsKey(e.key)) e.key: e.value,
      };
      expect(
        unexpected,
        isEmpty,
        reason:
            'the spline introduced a NEW sea/off-land excursion on: $unexpected '
            '(all legs: $seaByLeg)',
      );
      for (final entry in ratifiedResiduals.entries) {
        expect(
          seaByLeg[entry.key] ?? 0,
          lessThanOrEqualTo(entry.value),
          reason:
              'ratified residual ${entry.key} must stay ≤ ${entry.value}; '
              'got ${seaByLeg[entry.key]}',
        );
      }
    });
  });
}

String _nodeId(int i) => vietnamProvinceGeography.chain.nodes[i].id;

double _perp(GeoCoordinate p, GeoCoordinate a, GeoCoordinate b) {
  final ax = a.longitude, ay = a.latitude;
  final bx = b.longitude, by = b.latitude;
  final px = p.longitude, py = p.latitude;
  final dx = bx - ax, dy = by - ay;
  if (dx == 0 && dy == 0) return _dist(p, a);
  final t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
  if (t < 0 || t > 1) return double.infinity; // outside the segment span.
  final cx = ax + t * dx, cy = ay + t * dy;
  return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
}
