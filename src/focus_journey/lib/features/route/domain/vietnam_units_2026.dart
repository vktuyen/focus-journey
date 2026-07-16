/// Domain layer — pure Dart. No Flutter, no platform channels, no `latlong2`,
/// no I/O, no network. The ORDERED source-of-record for Vietnam's 34 current
/// administrative units (2026), consumed by BOTH `province_chain.dart` (nodes +
/// great-circle segments) and `province_geography.dart` (id → coordinate), so
/// there is exactly ONE ordering of the spine (province-chain-2026 / AC-1/AC-2).
///
/// ## Ordering (candidate ADR-0009 — hand-curated coast-hugging spine)
/// The list order IS the canonical south→north spine order. Index 0 is the
/// southernmost centre (Cà Mau / Tân Thành, lat ≈ 9.177); the last is the
/// northernmost current unit (Cao Bằng, the max-latitude admin centre — note
/// the old north terminus "Hà Giang" is now within Tuyên Quang). The order is a
/// coherent, coast-hugging progression that threads inland units (Điện Biên,
/// Sơn La, Đắk Lắk, Lâm Đồng, …) so NO inter-unit great-circle segment crosses
/// open sea on the shipped 34-province base map — it is verified by the
/// dense-sampling no-sea-crossing test (AC-5), NOT by a pure latitude sort, so
/// the order is deliberately not strictly latitude-monotonic.
///
/// ## Relocated centres (honoured EXACTLY here — spec §Constraints / AC-6)
/// Seven units' administrative centres sit in a former partner province; each
/// is seeded at its ADMIN CENTRE coordinate unchanged (never a display-nudge, so
/// AC-6 holds tightly): Gia Lai → coastal Quy Nhơn, An Giang → Rạch Giá,
/// Bắc Ninh → Bắc Giang, Quảng Trị → Đồng Hới, Tây Ninh → Tân An,
/// Đồng Tháp → Mỹ Tho, Lào Cai → Yên Bái.
///
/// ## Coast-alignment offset (a handful of NON-relocated coastal cities) — B1
/// The bundled base map's coastline is a GENERALIZED/simplified outline, so a
/// straight great-circle chord between two coastal city centres can dip into a
/// "sea" polygon at a deep bay (Hạ Long) or a lagoon-fronted cape (the
/// north-central coast). The precedent shipped in `vietnam-map-fidelity` (the
/// sub-km `mui_ca_mau` nudge) is generalized here: a MINIMAL offset is applied to
/// each affected non-relocated coastal unit so the spine stays landward of the
/// generalized coastline (AC-5/AC-7). Each offset is BOUNDED (hard cap ≤ 0.1° ≈
/// 10 km from the true admin centre) and MINIMIZED (the smallest magnitude that
/// still keeps its neighbouring segments on land under the dense no-sea-crossing
/// check @50 samples — B1). Every offset unit documents inline its true admin
/// centre, the applied offset (° and ~km), and the bay/generalization it clears,
/// so the golden coordinate-table test and reviewers see each deviation.
///
/// Final offsets (all ≤ 0.1°): Đà Nẵng 0.004°, Huế 0.020°, Nghệ An 0.098°,
/// Thanh Hóa 0.063°, Hải Phòng 0.016°, Quảng Ninh 0.097°. Quảng Ngãi and Cà Mau
/// use their authoritative centres directly (no offset). No relocated centre is
/// offset.
///
/// ## Over-cap residual (Đồng Hới → Hà Tĩnh — WAIVED by Kevin 2026-07-15)
/// One segment cannot be cleared within the cap: quang_tri (Đồng Hới, a FIXED
/// relocated centre) → ha_tinh clips a generalized-coastline notch at ~(17.75,
/// 106.39) near Đồng Hới's own departure. Only Hà Tĩnh can move, and full
/// clearance needs ≈0.114° (~12 km, OVER the 0.1° cap). Kevin's ruling: keep Hà
/// Tĩnh EXACT (it is a coastline-decimation artifact — the real land is
/// continuous — not a true sea crossing) rather than lift the cap. The dense
/// no-sea-crossing test pins this residual to ≤3 samples on this one segment;
/// every other segment stays fully on land. A future asset-densification
/// follow-up could close it fully.
///
/// PRIVACY (NFR-2 — gating): every coordinate is STATIC app-shipped reference
/// data (public administrative-centre points) — never a device-location read.
/// This file imports no geolocation/GPS/platform API.
library;

/// A single current administrative unit (2026): its stable [id], display
/// [name], and administrative-centre coordinate ([lat] / [lon], WGS-84 degrees).
///
/// A plain value holder (not `Equatable`) — the chain/geography build their own
/// `Province` / `GeoCoordinate` value objects from these fields. The [id] is a
/// fresh stable kebab-case identifier for the current unit (old pre-2025 ids are
/// retired; persisted plans referencing them migrate by reset — AC-9).
class VietnamUnit {
  /// Creates a unit record with its centre coordinate.
  const VietnamUnit({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
  });

  /// Stable kebab-case identifier for the current unit (persisted in plans).
  final String id;

  /// Human-facing unit name (Vietnamese diacritics).
  final String name;

  /// Administrative-centre latitude (degrees, north-positive).
  final double lat;

  /// Administrative-centre longitude (degrees, east-positive).
  final double lon;
}

/// The 34 current units in canonical coast-hugging SOUTH→NORTH spine order.
/// The order is verified by the AC-5 dense no-sea-crossing test — do not
/// re-order without re-running it.
const List<VietnamUnit> kVietnamUnits2026 = <VietnamUnit>[
  // --- South (Mekong delta) — hug the delta from the Cà Mau cape northward ---
  // Cà Mau / Tân Thành: authoritative centre, lands on the drawn coastline
  // directly (the shipped display-nudge is retired — AC-6/AC-7/PC-914).
  VietnamUnit(id: 'ca_mau', name: 'Cà Mau', lat: 9.177, lon: 105.152),
  VietnamUnit(id: 'can_tho', name: 'Cần Thơ', lat: 10.033, lon: 105.784),
  // An Giang @ Rạch Giá — relocated centre, EXACT (no offset).
  VietnamUnit(id: 'an_giang', name: 'An Giang', lat: 10.012, lon: 105.081),
  VietnamUnit(id: 'vinh_long', name: 'Vĩnh Long', lat: 10.253, lon: 105.972),
  // Đồng Tháp @ Mỹ Tho — relocated centre, EXACT.
  VietnamUnit(id: 'dong_thap', name: 'Đồng Tháp', lat: 10.360, lon: 106.359),
  // Tây Ninh @ Tân An — relocated centre, EXACT.
  VietnamUnit(id: 'tay_ninh', name: 'Tây Ninh', lat: 10.535, lon: 106.413),
  VietnamUnit(
    id: 'ho_chi_minh',
    name: 'Hồ Chí Minh',
    lat: 10.776,
    lon: 106.701,
  ),
  VietnamUnit(id: 'dong_nai', name: 'Đồng Nai', lat: 10.957, lon: 106.842),
  // --- South-central — thread the highlands (inland) between coastal centres ---
  VietnamUnit(id: 'lam_dong', name: 'Lâm Đồng', lat: 11.940, lon: 108.458),
  VietnamUnit(id: 'khanh_hoa', name: 'Khánh Hòa', lat: 12.238, lon: 109.196),
  VietnamUnit(id: 'dak_lak', name: 'Đắk Lắk', lat: 12.688, lon: 108.050),
  // Gia Lai @ coastal Quy Nhơn — relocated centre, EXACT (keeps the south-central
  // coast leg coherent — AC-6/PC-913).
  VietnamUnit(id: 'gia_lai', name: 'Gia Lai', lat: 13.782, lon: 109.219),
  // Quảng Ngãi — EXACT admin centre (true 15.120/108.800). No offset needed: both
  // its chords already stay landward on the generalized coast. (The old −0.02° lon
  // nudge is retired — it was not the minimum.)
  VietnamUnit(id: 'quang_ngai', name: 'Quảng Ngãi', lat: 15.120, lon: 108.800),
  // --- Central coast — no inland unit to thread; MINIMAL coast-alignment offsets
  //     (each the smallest that keeps its chords landward under the dense
  //     no-sea-crossing check @50 samples — B1 minimize; every offset ≤ 0.1°) ---
  // Đà Nẵng — true admin centre (16.060/108.221). Offset lat −0.004° (~0.44 km):
  // a sub-km nudge so the Quảng Ngãi↔Đà Nẵng↔Huế chords clear the generalized
  // central coast. (Longitude restored to true — the old −0.02° lon was not the
  // minimum.)
  VietnamUnit(id: 'da_nang', name: 'Đà Nẵng', lat: 16.056, lon: 108.221),
  // Huế — true admin centre (16.463/107.590). Offset lat −0.020°/lon +0.004°
  // (~2.3 km, mag 0.020°): shifts off the Tam Giang lagoon-fronted coast, which
  // the generalized outline renders as sea. (Was −0.024°/−0.080°; minimized.)
  VietnamUnit(id: 'hue', name: 'Huế', lat: 16.443, lon: 107.594),
  // Quảng Trị @ Đồng Hới — relocated centre, EXACT.
  VietnamUnit(id: 'quang_tri', name: 'Quảng Trị', lat: 17.468, lon: 106.622),
  // Hà Tĩnh — EXACT admin centre (true 18.343/105.900). NO offset applied: the
  // Đồng Hới→Hà Tĩnh chord clips a generalized-coastline notch at ~(17.75,106.39)
  // near the FIXED Quảng Trị (Đồng Hới) departure end; fully clearing it needs
  // ≈0.114° (~12 km, over the 0.1° cap). Kevin WAIVED it (2026-07-15): keep Hà
  // Tĩnh exact and accept the bounded ≤3-sample residual on quang_tri→ha_tinh
  // rather than lift the cap. (Was −0.24° lon = ~25 km — the B1 breach.)
  VietnamUnit(id: 'ha_tinh', name: 'Hà Tĩnh', lat: 18.343, lon: 105.900),
  // Nghệ An @ Vinh — true admin centre (18.679/105.681). Offset lon −0.098°/lat
  // +0.002° (~10.3 km, mag 0.098° < cap): west onto the mainland, off the
  // generalized coast near the Lam-river mouth. Absorbs the full ha_tinh→nghe_an
  // clearance (Hà Tĩnh is held exact), hence near the cap.
  VietnamUnit(id: 'nghe_an', name: 'Nghệ An', lat: 18.681, lon: 105.583),
  // Thanh Hóa — true admin centre (19.807/105.776). Offset lon −0.062°/lat +0.012°
  // (~6.6 km, mag 0.063°): west onto the mainland, off the generalized coast.
  // (Was −0.10° lon; minimized.)
  VietnamUnit(id: 'thanh_hoa', name: 'Thanh Hóa', lat: 19.819, lon: 105.714),
  VietnamUnit(id: 'ninh_binh', name: 'Ninh Bình', lat: 20.251, lon: 105.975),
  // --- Red River delta + north-east coast loop ---
  VietnamUnit(id: 'hung_yen', name: 'Hưng Yên', lat: 20.646, lon: 106.051),
  // Hải Phòng — true admin centre (Thủy Nguyên, 20.970/106.620). Offset lat
  // +0.016°/lon −0.002° (~1.8 km, mag 0.016°): a small nudge onto the generalized
  // Red-River-delta coast. (Was +0.018°/−0.060°; minimized.)
  VietnamUnit(id: 'hai_phong', name: 'Hải Phòng', lat: 20.986, lon: 106.618),
  // Quảng Ninh @ Hạ Long — true admin centre (20.951/107.076). Offset lat
  // +0.096°/lon −0.012° (~10.7 km, mag 0.097° < cap): off deeply-indented Hạ Long
  // Bay onto the Quảng Ninh mainland (the generalized coast omits the bay's
  // peninsulas). Still within Quảng Ninh territory. (Was +0.067°/−0.236° = ~25 km
  // — the B1 breach; minimized to a mainly-northward nudge under the cap.)
  VietnamUnit(id: 'quang_ninh', name: 'Quảng Ninh', lat: 21.047, lon: 107.064),
  VietnamUnit(id: 'ha_noi', name: 'Hà Nội', lat: 21.028, lon: 105.854),
  // Bắc Ninh @ Bắc Giang — relocated centre, EXACT.
  VietnamUnit(id: 'bac_ninh', name: 'Bắc Ninh', lat: 21.281, lon: 106.197),
  VietnamUnit(
    id: 'thai_nguyen',
    name: 'Thái Nguyên',
    lat: 21.593,
    lon: 105.844,
  ),
  // --- North-west mountains (all inland — no sea) then swing north-east ---
  VietnamUnit(id: 'phu_tho', name: 'Phú Thọ', lat: 21.322, lon: 105.402),
  VietnamUnit(
    id: 'tuyen_quang',
    name: 'Tuyên Quang',
    lat: 21.823,
    lon: 105.214,
  ),
  // Lào Cai @ Yên Bái — relocated centre, EXACT.
  VietnamUnit(id: 'lao_cai', name: 'Lào Cai', lat: 21.705, lon: 104.870),
  VietnamUnit(id: 'son_la', name: 'Sơn La', lat: 21.327, lon: 103.914),
  VietnamUnit(id: 'dien_bien', name: 'Điện Biên', lat: 21.386, lon: 103.017),
  VietnamUnit(id: 'lai_chau', name: 'Lai Châu', lat: 22.386, lon: 103.458),
  VietnamUnit(id: 'lang_son', name: 'Lạng Sơn', lat: 21.853, lon: 106.761),
  // Cao Bằng — the northernmost current unit (max latitude): the north tip.
  VietnamUnit(id: 'cao_bang', name: 'Cao Bằng', lat: 22.666, lon: 106.258),
];
