// province-chain-2026 — GOLDEN coordinate-table guard (deferred test required by
// ratified ADR-0009(c) and spec AC-7; it is the guard the self-review's B1
// finding demanded).
//
// PURPOSE
//   Pin ALL 34 shipped checkpoint coordinates against a documented, LITERAL
//   reference table so every coast-alignment offset is explicit and any future
//   coordinate change in `kVietnamUnits2026` is a VISIBLE, reviewed diff (this
//   test fails until the golden table — and its review — is updated in lockstep),
//   never a silent deviation.
//
// Traceability (AC ids in each group/description):
//   AC-7  every shipped coordinate == its golden-table literal (tight 1e-9); the
//         golden table also encodes each unit's TRUE admin centre + its class
//         (EXACT / RELOCATED / OFFSET) so each deviation is documented in-test.
//   AC-6  the 7 RELOCATED admin centres are byte-exact to their admin-centre
//         coords — they carry NO offset (shipped == true).
//   AC-3  every coast-alignment offset (shipped − true admin centre) is within
//         the ratified 0.1° cap for the 6 non-relocated OFFSET units, and is
//         exactly ZERO for every EXACT/RELOCATED unit — the cap is machine-
//         enforced here.
//
// Pure-data test: no Flutter widgets, no I/O, no timers, no network, no latlong2.
// The golden literals below were TRANSCRIBED (not computed) from the current
// `kVietnamUnits2026` source-of-record; do not regenerate them from the source.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/vietnam_units_2026.dart';

/// Tight tolerance — the golden table pins the EXACT shipped literals, so any
/// production coordinate change must fail this test (byte-for-byte intent).
const double _tight = 1e-9;

/// The ratified coast-alignment offset cap (ADR-0009(c) / B1): a non-relocated
/// coastal unit may be nudged at most this far (° ≈ 10 km) from its true admin
/// centre to clear the generalized coastline.
const double _capDegrees = 0.1;

/// How a unit's shipped coordinate relates to its true administrative centre.
enum _Kind {
  /// Authoritative admin centre used directly — zero offset.
  exactCentre,

  /// Admin centre sits in a former partner province; seeded EXACTLY there —
  /// zero offset (AC-6).
  relocated,

  /// A non-relocated coastal centre carrying a MINIMAL coast-alignment offset
  /// (≤ cap) so its chords stay landward of the generalized coastline (AC-3).
  offset,
}

/// One golden row: the id, the EXACT shipped coordinate (the golden literal),
/// the TRUE admin centre, and the class of deviation.
class _Golden {
  const _Golden(
    this.id,
    this.shipLat,
    this.shipLon,
    this.trueLat,
    this.trueLon,
    this.kind,
  );

  final String id;
  final double shipLat;
  final double shipLon;
  final double trueLat;
  final double trueLon;
  final _Kind kind;

  /// Euclidean magnitude (°) of the applied offset: shipped − true admin centre.
  double get offsetMagnitude =>
      math.sqrt(math.pow(shipLat - trueLat, 2) + math.pow(shipLon - trueLon, 2))
          .toDouble();
}

// ---------------------------------------------------------------------------
// THE GOLDEN TABLE — all 34 current units (2026), in canonical south→north
// spine order. Each row: (id, shipped lat, shipped lon, true lat, true lon,
// class). For EXACT/RELOCATED rows the true centre == the shipped literal (zero
// offset). For OFFSET rows the true admin centre is the documented one from
// `kVietnamUnits2026` and the shipped literal is the nudged value.
// ---------------------------------------------------------------------------
const List<_Golden> _goldenTable = <_Golden>[
  // Cà Mau — EXACT authoritative centre (display-nudge retired, PC-914).
  _Golden('ca_mau', 9.177, 105.152, 9.177, 105.152, _Kind.exactCentre),
  // Cần Thơ — EXACT.
  _Golden('can_tho', 10.033, 105.784, 10.033, 105.784, _Kind.exactCentre),
  // An Giang @ Rạch Giá — RELOCATED, exact (no offset).
  _Golden('an_giang', 10.012, 105.081, 10.012, 105.081, _Kind.relocated),
  // Vĩnh Long — EXACT.
  _Golden('vinh_long', 10.253, 105.972, 10.253, 105.972, _Kind.exactCentre),
  // Đồng Tháp @ Mỹ Tho — RELOCATED, exact.
  _Golden('dong_thap', 10.360, 106.359, 10.360, 106.359, _Kind.relocated),
  // Tây Ninh @ Tân An — RELOCATED, exact.
  _Golden('tay_ninh', 10.535, 106.413, 10.535, 106.413, _Kind.relocated),
  // Hồ Chí Minh — EXACT.
  _Golden('ho_chi_minh', 10.776, 106.701, 10.776, 106.701, _Kind.exactCentre),
  // Đồng Nai — EXACT.
  _Golden('dong_nai', 10.957, 106.842, 10.957, 106.842, _Kind.exactCentre),
  // Lâm Đồng — EXACT (inland).
  _Golden('lam_dong', 11.940, 108.458, 11.940, 108.458, _Kind.exactCentre),
  // Khánh Hòa — EXACT.
  _Golden('khanh_hoa', 12.238, 109.196, 12.238, 109.196, _Kind.exactCentre),
  // Đắk Lắk — EXACT (inland).
  _Golden('dak_lak', 12.688, 108.050, 12.688, 108.050, _Kind.exactCentre),
  // Gia Lai @ coastal Quy Nhơn — RELOCATED, exact (PC-913).
  _Golden('gia_lai', 13.782, 109.219, 13.782, 109.219, _Kind.relocated),
  // Quảng Ngãi — EXACT admin centre (no offset needed).
  _Golden('quang_ngai', 15.120, 108.800, 15.120, 108.800, _Kind.exactCentre),
  // Đà Nẵng — OFFSET lat −0.004° (~0.44 km); lon at true. true 16.060/108.221.
  _Golden('da_nang', 16.056, 108.221, 16.060, 108.221, _Kind.offset),
  // Huế — OFFSET lat −0.020°/lon +0.004° (mag 0.020°, ~2.3 km). true 16.463/107.590.
  _Golden('hue', 16.443, 107.594, 16.463, 107.590, _Kind.offset),
  // Quảng Trị @ Đồng Hới — RELOCATED, exact.
  _Golden('quang_tri', 17.468, 106.622, 17.468, 106.622, _Kind.relocated),
  // Hà Tĩnh — EXACT admin centre (true 18.343/105.900). NO offset: the
  // quảng_trị→hà_tĩnh residual was WAIVED by holding Hà Tĩnh at its true centre
  // (full clearance would need ~0.114° > cap), so this asserts ZERO offset.
  _Golden('ha_tinh', 18.343, 105.900, 18.343, 105.900, _Kind.exactCentre),
  // Nghệ An @ Vinh — OFFSET lon −0.098°/lat +0.002° (mag 0.098° < cap). true 18.679/105.681.
  _Golden('nghe_an', 18.681, 105.583, 18.679, 105.681, _Kind.offset),
  // Thanh Hóa — OFFSET lon −0.062°/lat +0.012° (mag 0.063°). true 19.807/105.776.
  _Golden('thanh_hoa', 19.819, 105.714, 19.807, 105.776, _Kind.offset),
  // Ninh Bình — EXACT.
  _Golden('ninh_binh', 20.251, 105.975, 20.251, 105.975, _Kind.exactCentre),
  // Hưng Yên — EXACT.
  _Golden('hung_yen', 20.646, 106.051, 20.646, 106.051, _Kind.exactCentre),
  // Hải Phòng — OFFSET lat +0.016°/lon −0.002° (mag 0.016°). true 20.970/106.620.
  _Golden('hai_phong', 20.986, 106.618, 20.970, 106.620, _Kind.offset),
  // Quảng Ninh @ Hạ Long — OFFSET lat +0.096°/lon −0.012° (mag 0.097° < cap). true 20.951/107.076.
  _Golden('quang_ninh', 21.047, 107.064, 20.951, 107.076, _Kind.offset),
  // Hà Nội — EXACT.
  _Golden('ha_noi', 21.028, 105.854, 21.028, 105.854, _Kind.exactCentre),
  // Bắc Ninh @ Bắc Giang — RELOCATED, exact.
  _Golden('bac_ninh', 21.281, 106.197, 21.281, 106.197, _Kind.relocated),
  // Thái Nguyên — EXACT.
  _Golden('thai_nguyen', 21.593, 105.844, 21.593, 105.844, _Kind.exactCentre),
  // Phú Thọ — EXACT (inland).
  _Golden('phu_tho', 21.322, 105.402, 21.322, 105.402, _Kind.exactCentre),
  // Tuyên Quang — EXACT (inland).
  _Golden('tuyen_quang', 21.823, 105.214, 21.823, 105.214, _Kind.exactCentre),
  // Lào Cai @ Yên Bái — RELOCATED, exact.
  _Golden('lao_cai', 21.705, 104.870, 21.705, 104.870, _Kind.relocated),
  // Sơn La — EXACT (inland).
  _Golden('son_la', 21.327, 103.914, 21.327, 103.914, _Kind.exactCentre),
  // Điện Biên — EXACT (inland).
  _Golden('dien_bien', 21.386, 103.017, 21.386, 103.017, _Kind.exactCentre),
  // Lai Châu — EXACT (inland).
  _Golden('lai_chau', 22.386, 103.458, 22.386, 103.458, _Kind.exactCentre),
  // Lạng Sơn — EXACT.
  _Golden('lang_son', 21.853, 106.761, 21.853, 106.761, _Kind.exactCentre),
  // Cao Bằng — EXACT (northernmost, max latitude).
  _Golden('cao_bang', 22.666, 106.258, 22.666, 106.258, _Kind.exactCentre),
];

VietnamUnit _unit(String id) => kVietnamUnits2026.firstWhere(
  (u) => u.id == id,
  orElse: () => fail('golden id "$id" is missing from kVietnamUnits2026'),
);

void main() {
  // -------------------------------------------------------------------------
  // AC-7 — the golden table must be complete and 1:1 with the source-of-record,
  // so a new/removed/renamed unit can't sneak past the byte-exact match below.
  // -------------------------------------------------------------------------
  group('AC-7 golden table integrity (B1 golden guard)', () {
    test('AC7_goldenTable_hasExactly34Rows', () {
      expect(_goldenTable, hasLength(34));
    });

    test('AC7_goldenTable_idsMatchSourceOfRecordExactly', () {
      final goldenIds = _goldenTable.map((g) => g.id).toSet();
      final sourceIds = kVietnamUnits2026.map((u) => u.id).toSet();
      expect(
        goldenIds,
        equals(sourceIds),
        reason: 'golden ids must be 1:1 with kVietnamUnits2026 ids',
      );
      // No duplicate ids in the golden table.
      expect(goldenIds, hasLength(_goldenTable.length));
    });

    test('AC7_goldenTable_rowOrderMatchesCanonicalSpineOrder', () {
      // The golden rows are authored in canonical south→north spine order — pin
      // it so a re-ordering of the source is also a visible diff here.
      final goldenOrder = _goldenTable.map((g) => g.id).toList();
      final sourceOrder = kVietnamUnits2026.map((u) => u.id).toList();
      expect(goldenOrder, orderedEquals(sourceOrder));
    });

    test('AC7_classCounts_are21exact_7relocated_6offset', () {
      int exact = 0, relocated = 0, offset = 0;
      for (final g in _goldenTable) {
        switch (g.kind) {
          case _Kind.exactCentre:
            exact++;
          case _Kind.relocated:
            relocated++;
          case _Kind.offset:
            offset++;
        }
      }
      expect(exact, 21, reason: 'exact-centre units');
      expect(relocated, 7, reason: 'relocated units');
      expect(offset, 6, reason: 'offset units');
      expect(exact + relocated + offset, 34);
    });
  });

  // -------------------------------------------------------------------------
  // AC-7 — every shipped coordinate is byte-exact to its golden literal. This
  // is the core guard: change ANY coordinate in kVietnamUnits2026 and its row
  // here fails until the golden table (and its review) is updated in lockstep.
  // -------------------------------------------------------------------------
  group('AC-7 shipped coordinate == golden literal (tight 1e-9)', () {
    for (final g in _goldenTable) {
      test('AC7 ${g.id}_shippedCoordinate_equalsGoldenLiteral', () {
        final unit = _unit(g.id);
        expect(
          unit.lat,
          closeTo(g.shipLat, _tight),
          reason: '${g.id} latitude drifted from the golden table',
        );
        expect(
          unit.lon,
          closeTo(g.shipLon, _tight),
          reason: '${g.id} longitude drifted from the golden table',
        );
        // The production geography lookup must agree with the source-of-record.
        final coord = vietnamProvinceGeography.coordinateOf(
          Province(id: g.id, name: unit.name),
        );
        expect(coord.latitude, closeTo(g.shipLat, _tight));
        expect(coord.longitude, closeTo(g.shipLon, _tight));
      });
    }
  });

  // -------------------------------------------------------------------------
  // AC-6 — the 7 relocated admin centres are byte-exact to their admin-centre
  // coords: they carry NO coast-alignment offset (shipped == true == golden).
  // -------------------------------------------------------------------------
  group('AC-6 relocated centres are byte-exact (zero offset)', () {
    final relocated = _goldenTable.where((g) => g.kind == _Kind.relocated);

    test('AC6_relocatedCount_isSeven', () {
      expect(relocated, hasLength(7));
    });

    for (final g in relocated) {
      test('AC6 ${g.id}_relocatedCentre_isByteExactWithZeroOffset', () {
        // In the golden table a relocated row's true centre == its shipped coord.
        expect(g.trueLat, closeTo(g.shipLat, _tight));
        expect(g.trueLon, closeTo(g.shipLon, _tight));
        expect(
          g.offsetMagnitude,
          0.0,
          reason: '${g.id} is relocated and must carry NO offset',
        );
        // And the shipped source-of-record matches exactly.
        final unit = _unit(g.id);
        expect(unit.lat, closeTo(g.trueLat, _tight));
        expect(unit.lon, closeTo(g.trueLon, _tight));
      });
    }
  });

  // -------------------------------------------------------------------------
  // AC-3 — the coast-alignment offset cap is machine-enforced:
  //   * every OFFSET unit's |shipped − true admin centre| ≤ 0.1° (and > 0), and
  //   * every EXACT/RELOCATED unit's offset is exactly 0.
  // Hà Tĩnh is EXACT (true 18.343/105.900) — the waived quảng_trị→hà_tĩnh
  // residual means it must assert ZERO offset here, NOT an over-cap nudge.
  // -------------------------------------------------------------------------
  group('AC-3 coast-alignment offset cap (≤ 0.1°) is machine-enforced', () {
    for (final g in _goldenTable) {
      if (g.kind == _Kind.offset) {
        test('AC3 ${g.id}_offset_isWithinCapAndNonZero', () {
          // Deviation is a real (non-zero) nudge...
          expect(
            g.offsetMagnitude,
            greaterThan(0.0),
            reason: '${g.id} is classified OFFSET but has zero deviation',
          );
          // ...bounded by the ratified 0.1° cap (Euclidean magnitude).
          expect(
            g.offsetMagnitude,
            lessThanOrEqualTo(_capDegrees),
            reason:
                '${g.id} offset ${g.offsetMagnitude}° EXCEEDS the 0.1° cap — '
                'this is a real contract violation, not a test to soften',
          );
          // Per-component nudges are also each within the cap (defensive).
          expect((g.shipLat - g.trueLat).abs(), lessThanOrEqualTo(_capDegrees));
          expect((g.shipLon - g.trueLon).abs(), lessThanOrEqualTo(_capDegrees));
        });
      } else {
        test('AC3 ${g.id}_hasZeroOffset', () {
          expect(
            g.offsetMagnitude,
            0.0,
            reason:
                '${g.id} is EXACT/RELOCATED and must carry no offset '
                '(shipped == true admin centre)',
          );
        });
      }
    }

    test('AC3 haTinh_isExactWithZeroOffset_residualWaived', () {
      // Explicit AC-3 pin for the waiver: Hà Tĩnh stays at its true admin
      // centre (18.343/105.900); the over-cap quảng_trị→hà_tĩnh residual was
      // waived rather than silently over-offset.
      final ha = _goldenTable.firstWhere((g) => g.id == 'ha_tinh');
      expect(ha.kind, _Kind.exactCentre);
      expect(ha.offsetMagnitude, 0.0);
      expect(ha.shipLat, closeTo(18.343, _tight));
      expect(ha.shipLon, closeTo(105.900, _tight));
    });
  });
}
