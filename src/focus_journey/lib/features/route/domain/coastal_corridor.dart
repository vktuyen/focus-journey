/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O, no
/// `latlong2`. Only the pure chain / geography / planner value objects.
///
/// THE DEFAULT COASTAL CORRIDOR (route-real-road / AC-1/AC-5). province-chain-2026
/// modelled the journey as ONE spine that visits all 34 units, so the drawn route
/// was a *tour* that detoured deep inland (worst in the north: a west-then-east
/// zig-zag through the NW mountains). Kevin's correction: the default route should
/// be a clean south→north **coastal sweep** that hugs the coast and does NOT
/// detour to visit every province.
///
/// This module does NOT touch province-chain-2026's DATA (the 34 units, their
/// coordinates, the map). It defines a curated ROUTE-SHAPING SUBSET over the
/// unchanged chain: the deep-inland units the sweep skips ([kInlandExcludedFromCorridor]).
/// Removing them (via the planner's existing segment-merge — ADR-0005 decision 1,
/// which preserves the canonical km axis) leaves a monotonically-northward,
/// coast-hugging corridor from the south tip (Cà Mau) to the north end (Cao Bằng).
/// The excluded units are reachable only as user-added stops.
///
/// The excluded set + resulting corridor are VERIFIED against the real bundled
/// geometry by `coastal_corridor_test.dart`: the sweep stays on land (no new
/// open-sea excursion beyond the ≤3-sample residual class) AND reads as a clean
/// sweep (no south-going backtracking / west-then-east reversal). Do not change
/// the set without re-running that guard.
///
/// PRIVACY (NFR-2): reads ONLY static reference data; no I/O, no network.
library;

import 'province_chain.dart';
import 'province_geography.dart';
import 'route_planner.dart';

/// The deep-inland provinces EXCLUDED from the default coastal corridor.
///
/// Three clusters, each an inland detour off the coastal sweep:
///  - **NW mountains** — the west-then-east zig-zag Kevin flagged: the route dived
///    west to Sơn La / Điện Biên / Lai Châu (lon ≈ 103) then jumped back east to
///    Lạng Sơn (lon ≈ 106.8). Lào Cai / Tuyên Quang / Phú Thọ sit on that same
///    inland loop and are dropped with it.
///  - **Central highlands** — Lâm Đồng pulls the line inland off the south-central
///    coast. Gia Lai is KEPT (its centre is coastal Quy Nhơn). Đắk Lắk is ALSO
///    KEPT even though its centre (Buôn Ma Thuột) is inland: it is the only unit
///    between Khánh Hòa and Gia Lai, and dropping it makes the smoothed Khánh
///    Hòa→Gia Lai leg bow ~20 km into the sea off Quy Nhơn (verified) — a worse
///    AC-5 violation than the mild inland notch keeping it produces. On-land wins.
///  - **Red-River delta interior** — Hà Nội / Bắc Ninh / Thái Nguyên form the
///    inland loop between the NE coast (Hạ Long) and the NE tip (Lạng Sơn /
///    Cao Bằng); skipping them lets the sweep arc cleanly up the coast to the tip
///    instead of darting inland to Hà Nội and back.
///
/// Endpoints (Cà Mau, Cao Bằng) are intentionally absent — they are always kept.
const Set<String> kInlandExcludedFromCorridor = <String>{
  // NW mountains (the west-then-east zig-zag)
  'son_la',
  'dien_bien',
  'lai_chau',
  'lao_cai',
  'tuyen_quang',
  'phu_tho',
  // Central highlands (Gia Lai + Đắk Lắk kept — see the doc above)
  'lam_dong',
  // Red-River delta interior loop
  'ha_noi',
  'bac_ninh',
  'thai_nguyen',
};

/// The default coastal-corridor node ids over [chain], in canonical south→north
/// order, with the deep-inland provinces ([kInlandExcludedFromCorridor]) removed.
/// The tips (south / north) are always retained. This is the DEFAULT route —
/// the migration-reset target and the full-country default plan (route-real-road
/// / AC-1), replacing the all-34 spine tour.
List<String> coastalCorridorNodeIds(ProvinceChain chain) => List<String>.unmodifiable(
  <String>[
    for (final node in chain.nodes)
      if (!kInlandExcludedFromCorridor.contains(node.id)) node.id,
  ],
);

/// The canonical km length of the default coastal corridor over [chain] /
/// [geography] — the resolved sub-path total. Used to derive `kmPerActiveHour`
/// from the DEFAULT ROUTE (route-real-road pacing) so a full corridor traversal
/// still ≈ 8 active hours.
///
/// NOTE: because the planner MERGES a removed unit's segments into its survivors
/// (ADR-0005 decision 1 — the canonical km axis is preserved), the corridor total
/// equals the full spine total (the endpoints are unchanged tips). So this returns
/// the same value as `chain.totalChainKm`; it is derived from the corridor for
/// semantic correctness (and to track any future corridor whose endpoints change).
double coastalCorridorTotalKm(
  ProvinceChain chain,
  ProvinceGeography geography,
) {
  final resolved = RoutePlanner.fromOrderedIds(
    fullChain: chain,
    fullGeography: geography,
    orderedNodeIds: coastalCorridorNodeIds(chain),
  );
  return resolved.subPathKm;
}
