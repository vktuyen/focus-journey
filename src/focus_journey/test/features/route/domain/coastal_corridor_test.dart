// Unit tests for the default COASTAL CORRIDOR (route-real-road / AC-1/AC-5):
// the inland-trimmed south→north sweep that replaces the all-34 tour.
//
// Verified against the REAL bundled geometry (the _loadRealGeometry pattern) so
// the corridor provably (a) stays on land — no new open-sea excursion beyond the
// ≤3-sample residual class — and (b) reads as a clean sweep with no south-going
// backtracking (the NW-mountain west-then-east zig-zag is gone). Deterministic +
// offline (asset read straight from disk, production pure parser).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/data/base_map_repository.dart';
import 'package:focus_journey/features/route/domain/base_map_geometry.dart';
import 'package:focus_journey/features/route/domain/coastal_corridor.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_curve.dart';
import 'package:focus_journey/features/route/domain/route_planner.dart';

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

void main() {
  final chain = vietnamProvinceGeography.chain;
  final geography = vietnamProvinceGeography;
  final corridor = coastalCorridorNodeIds(chain);

  group('corridor membership (AC-1/AC-5)', () {
    test('keeps the endpoints (Cà Mau south tip → Cao Bằng north tip)', () {
      expect(corridor.first, chain.southTip.id);
      expect(corridor.first, 'ca_mau');
      expect(corridor.last, chain.northTip.id);
      expect(corridor.last, 'cao_bang');
    });

    test('excludes the deep-inland detour provinces, keeps the coastal ones', () {
      // The NW-mountain zig-zag, Lâm Đồng, and the Red-River interior loop are
      // gone.
      for (final id in <String>[
        'son_la',
        'dien_bien',
        'lai_chau',
        'lao_cai',
        'tuyen_quang',
        'phu_tho',
        'lam_dong',
        'ha_noi',
        'bac_ninh',
        'thai_nguyen',
      ]) {
        expect(corridor, isNot(contains(id)), reason: '$id should be excluded');
      }
      // Gia Lai's centre is coastal Quy Nhơn — it stays on the sweep. Đắk Lắk is
      // kept as the only Khánh Hòa↔Gia Lai waypoint (dropping it bows the leg
      // into the sea — AC-5); Khánh Hòa is coastal Nha Trang.
      expect(corridor, contains('gia_lai'));
      expect(corridor, contains('khanh_hoa'));
      expect(corridor, contains('dak_lak'));
    });

    test('is a strict subset of the 34-unit spine in canonical order', () {
      expect(corridor.length, lessThan(chain.nodes.length));
      final spineOrder = <String>[for (final n in chain.nodes) n.id];
      var last = -1;
      for (final id in corridor) {
        final idx = spineOrder.indexOf(id);
        expect(idx, greaterThan(last), reason: '$id out of canonical order');
        last = idx;
      }
    });
  });

  group('clean northward sweep — no backtracking (AC-1)', () {
    test('every corridor step is broadly northward (no south reversal)', () {
      final coords = <GeoCoordinate>[
        for (final id in corridor)
          geography.coordinateOf(
            chain.nodes.firstWhere((n) => n.id == id),
          ),
      ];
      // No step drops south by more than a small coastal-wiggle tolerance — the
      // NW-mountain detour (which dived ~0.3° south) is gone.
      const maxSouthDipDeg = 0.05;
      final dips = <String>[];
      for (var i = 0; i < coords.length - 1; i++) {
        final dLat = coords[i + 1].latitude - coords[i].latitude;
        if (dLat < -maxSouthDipDeg) {
          dips.add('${corridor[i]}->${corridor[i + 1]}:${dLat.toStringAsFixed(3)}');
        }
      }
      expect(dips, isEmpty, reason: 'south-going backtracking steps: $dips');
    });

    test('no west-then-east reversal in the northern tail (Hạ Long → tip)', () {
      // Regression guard for the specific zig Kevin flagged: after the NE coast
      // (Quảng Ninh), the sweep arcs cleanly NW to the tip — longitude must be
      // monotonically NON-INCREASING (never bounces back east), so there is no
      // dart inland to Hà Nội and back.
      final coords = <GeoCoordinate>[
        for (final id in corridor)
          geography.coordinateOf(chain.nodes.firstWhere((n) => n.id == id)),
      ];
      final qnIndex = corridor.indexOf('quang_ninh');
      expect(qnIndex, greaterThan(0));
      for (var i = qnIndex; i < coords.length - 1; i++) {
        expect(
          coords[i + 1].longitude,
          lessThanOrEqualTo(coords[i].longitude + 1e-9),
          reason:
              '${corridor[i]}->${corridor[i + 1]} bounces east — an inland '
              'reversal in the northern tail',
        );
      }
    });
  });

  group('stays on land (AC-5)', () {
    // Same ratified ≤3-sample residual class as province-chain-2026, sampled on
    // the SMOOTHED corridor sweep. Two bounded residuals:
    //   - quang_tri->ha_tinh: the carried-over generalized-coastline SEA notch;
    //   - lang_son->cao_bang: a tiny bow across the generalized NORTHERN LAND
    //     BORDER at the inland NE tip (not open sea).
    // Every other leg must be fully on land, so a corridor edit that flings a
    // straight leg across open sea fails.
    const ratifiedResiduals = <String, int>{
      'quang_tri->ha_tinh': 3,
      'lang_son->cao_bang': 2,
    };

    test('the densely-sampled smoothed sweep introduces no new sea excursion', () {
      final geo = _loadRealGeometry();
      final coords = <GeoCoordinate>[
        for (final id in corridor)
          geography.coordinateOf(chain.nodes.firstWhere((n) => n.id == id)),
      ];
      const samplesPerSegment = 50;
      final curve = smoothCurve(coords, samplesPerSegment: samplesPerSegment);

      final seaByLeg = <String, int>{};
      for (var i = 0; i < coords.length - 1; i++) {
        var sea = 0;
        for (var s = 1; s <= samplesPerSegment; s++) {
          if (!geo.containsLandmass(curve[i * samplesPerSegment + s])) sea++;
        }
        if (sea > 0) seaByLeg['${corridor[i]}->${corridor[i + 1]}'] = sea;
      }

      final unexpected = <String, int>{
        for (final e in seaByLeg.entries)
          if (!ratifiedResiduals.containsKey(e.key)) e.key: e.value,
      };
      expect(
        unexpected,
        isEmpty,
        reason: 'new sea/off-land excursion on: $unexpected (all: $seaByLeg)',
      );
      for (final entry in ratifiedResiduals.entries) {
        expect(
          seaByLeg[entry.key] ?? 0,
          lessThanOrEqualTo(entry.value),
          reason: '${entry.key} residual exceeded ${entry.value}',
        );
      }
    });
  });

  group('pacing (route-real-road)', () {
    test('corridor total equals the full spine total (merge preserves km)', () {
      // The planner merges a removed unit's segments into its survivors (ADR-0005
      // decision 1 — the canonical km axis is preserved), so the corridor total
      // equals the full spine total (endpoints unchanged). kmPerActiveHour is
      // therefore numerically unchanged, now derived from the default route.
      final total = coastalCorridorTotalKm(chain, geography);
      expect(total, closeTo(chain.totalChainKm, 1e-6));
    });

    test('coastalCorridorTotalKm resolves a valid ≥2-node sub-path', () {
      final resolved = RoutePlanner.fromOrderedIds(
        fullChain: chain,
        fullGeography: geography,
        orderedNodeIds: corridor,
      );
      expect(resolved.orderedNodes.length, corridor.length);
      expect(resolved.subPathKm, greaterThan(0));
    });
  });
}
