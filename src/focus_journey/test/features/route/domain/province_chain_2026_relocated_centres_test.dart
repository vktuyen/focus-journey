// province-chain-2026 — relocated administrative centres (AC-6).
//
// Traceability (one test <-> one case; PC + AC ids in each description):
//   PC-912 (AC-6)  each of the 7 relocated units is seeded EXACTLY at its
//                  administrative-centre coordinate (tight tolerance — no
//                  coast-alignment offset applies to a relocated centre), never
//                  at its nominal former territory.
//
// Pure-data test: no Flutter, no I/O, no timers, no network. Asserts the seeded
// GeoCoordinate for each relocated id against the documented admin-centre
// literal, and that the geography lookup agrees with the source-of-record.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/vietnam_units_2026.dart';

/// Tight tolerance — relocated centres are seeded EXACTLY (no display offset).
const double _tight = 1e-9;

void main() {
  // The 7 relocated units and their EXACT administrative-centre coordinate
  // (spec §Constraints / AC-6). These are the *admin centres* that sit in a
  // former partner province — never the nominal territory centroid.
  const relocated = <String, List<double>>{
    'gia_lai': <double>[13.782, 109.219], // coastal Quy Nhơn
    'an_giang': <double>[10.012, 105.081], // Rạch Giá
    'bac_ninh': <double>[21.281, 106.197], // Bắc Giang
    'quang_tri': <double>[17.468, 106.622], // Đồng Hới
    'tay_ninh': <double>[10.535, 106.413], // Tân An
    'dong_thap': <double>[10.360, 106.359], // Mỹ Tho
    'lao_cai': <double>[21.705, 104.870], // Yên Bái
  };

  group('province-chain-2026 relocated admin centres (AC-6 / PC-912)', () {
    relocated.forEach((id, latLon) {
      test('PC-912 ${id}_seededAtAdminCentre_exact', () {
        final unit = kVietnamUnits2026.firstWhere(
          (u) => u.id == id,
          orElse: () => fail('relocated unit "$id" missing from the dataset'),
        );
        expect(unit.lat, closeTo(latLon[0], _tight), reason: '$id latitude');
        expect(unit.lon, closeTo(latLon[1], _tight), reason: '$id longitude');
        // The production geography lookup agrees with the source-of-record.
        final coord = vietnamProvinceGeography.coordinateOf(
          Province(id: id, name: unit.name),
        );
        expect(coord.latitude, closeTo(latLon[0], _tight));
        expect(coord.longitude, closeTo(latLon[1], _tight));
      });
    });

    test('PC-912 giaLai_isSeededAtCoastalQuyNhon_notInlandHighland', () {
      // The nominal Gia Lai highland territory sits inland near lon ~108.0; the
      // relocated admin centre is coastal Quy Nhơn (lon ~109.22). Asserting the
      // seed is well east of the highland catches a regression to the nominal
      // territory (which would pull the coast-hugging leg inland — AC-5).
      final giaLai = kVietnamUnits2026.firstWhere((u) => u.id == 'gia_lai');
      expect(
        giaLai.lon,
        greaterThan(109.0),
        reason: 'Gia Lai must be seeded at coastal Quy Nhơn, not the highland',
      );
    });

    test('PC-912 anGiang_isSeededAtRachGia_westOfNominalLongXuyen', () {
      // An Giang's nominal seat Long Xuyên is near lon ~105.43; the relocated
      // centre Rạch Giá is clearly west of it (~105.08).
      final anGiang = kVietnamUnits2026.firstWhere((u) => u.id == 'an_giang');
      expect(anGiang.lon, lessThan(105.3));
    });
  });
}
