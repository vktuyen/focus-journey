# Province chain 2026 — journey data model on all 34 current units

**Status:** shipped (2026-07-16)
**Owner:** Kevin (Tuyen Vo)
**Last updated:** 2026-07-15 (approved by Kevin)
**Wave:** refine-app-ui-ux (slice 2 of the Vietnam-2026 pair; sibling: `vietnam-map-fidelity` ✅ shipped)

## Problem
`vietnam-map-fidelity` made the *map* show Vietnam's current 34 provinces (2026), but the journey's
province/route **data model** still encodes the old ~13-checkpoint spine on pre-2025 geography. To "handle all
the provinces of Vietnam (2026)", the `ProvinceChain` / `ProvinceGeography` / distances must be rebuilt onto
the current 34 units — otherwise the map and the journey disagree about what Vietnam is. This slice also owns
the limitation carried from `vietnam-map-fidelity` AC-5: the straight-line route segments that cross coastal
bays on the now-accurate coastline.

## User & outcome
- **Focused individual:** the journey traverses all 34 current provinces in one coherent south→north spine
  (Mũi Cà Mau → the northern border); progress, checkpoints, and distances reflect real 2026 geography, and
  the route stays on land (no segment cutting across the sea).
- **Privacy-skeptical teammate:** unchanged — still local-only, no new reads/egress.
- Observable success: the chain has all 34 units in a valid ordered spine; distances are derived from real
  coordinates; the route renders on land on the shipped 34-province map; a user's in-progress journey survives
  the upgrade (migrated, not lost).

## Scope
### In
- Rebuild `province_geography.dart` + `province_chain.dart` to the **34 current units** using the sourced
  dataset (names + administrative-centre lat/long; relocated centres flagged) — see the dataset inlined in the
  (consumed) backlog item / carried below.
- **One canonical spine through all 34 units**, ordered south→north into a single coherent, **coast-hugging**
  path (no inter-unit segment crosses open sea — resolves the carried `vietnam-map-fidelity` AC-5).
- **Distances auto-computed** as great-circle between consecutive unit-centre coordinates; the sum becomes the
  new `totalChainKm`; `kmPerActiveHour` re-derives from it (≈8 active hours to cross).
- Preserve ADR-0005's derived sub-chain / route-authoring model and ADR-0004(b)'s canonical-km projection —
  migrate, don't reinvent.
- **Forward-migrate persisted `RoutePlan`** referencing old (pre-2025 / 13-node) province ids so an in-progress
  journey isn't lost or corrupted on upgrade.

### Out
- Map rendering / the base-map asset — shipped in `vietnam-map-fidelity`.
- No change to the engine's active/idle accrual mechanism or the distance-vs-raw-stats split (BR-6); only the
  geometry/config it runs over changes (the engine firewall from ADR-0007 holds — a data change, not an
  accrual change).
- No new persistence technology; no new network/egress or location read.

## Constraints & assumptions
- **Engine firewall (BR-6 / ADR-0007):** `kmPerActiveHour` re-derives from the new total, but the accrual
  model is byte-for-byte the same mechanism — this is a geometry/config change, not an accrual change.
- **Coast-hugging ordering:** the 34-unit order must be a coherent land path (inland units — Điện Biên, Sơn
  La, Đắk Lắk, Lâm Đồng, etc. — threaded sensibly), so no segment crosses the sea on the shipped map. Ordering
  approach is an architecture decision (see Open questions / ADR). Per ADR-0009(c), a sea-crossing is cleared
  by (i) re-ordering the 34 units first; (ii) where re-ordering cannot clear a bay because the bundled
  coastline is generalized/decimated, a **bounded coast-alignment offset ≤ 0.1° (~10 km)** on the affected
  **non-relocated** coastal checkpoint — the minimum that clears the bay, documented per-unit and pinned by a
  golden coordinate-table test; (iii) never a synthetic non-unit waypoint (nodes stay exactly the 34 units).
  The offset compensates for map generalization, not geography; relocated centres carry no offset.
- **Relocated centres** (admin centre sits in a former partner province) must be honoured when seeding
  coordinates/distances: Gia Lai→Quy Nhơn, An Giang→Rạch Giá, Bắc Ninh→Bắc Giang, Quảng Trị→Đồng Hới,
  Tây Ninh→Tân An, Đồng Tháp→Mỹ Tho, Lào Cai→Yên Bái.
- **Migration:** old persisted `RoutePlan.orderedNodeIds` use retired ids; define a forward-migration (map to
  nearest current unit, or reset to a fresh full-spine plan) that never crashes or silently drops progress.
- Georeferenced overlays must still land on the shipped 34-province map (same equirectangular bounds).

## Acceptance criteria

- [x] AC-1: Given the rebuilt `province_geography.dart` + `province_chain.dart`, When the canonical `vietnamProvinceChain` is constructed at startup, Then it contains exactly **34 checkpoints** — one per current unit in the sourced dataset — with unique ids and no missing or extra units.
- [x] AC-2: Given the canonical chain, When its invariants are asserted, Then nodes are strictly ordered south→north (index 0 = Cà Mau / Tân Thành at lat ≈ 9.177, last = the northernmost unit at maximum latitude — note Hà Giang is now within Tuyên Quang), there are exactly **33 segments**, every segment is strictly positive, and their sum equals `totalChainKm` within `_sumTolerance`.
- [x] AC-3: Given each consecutive pair of unit centres, When a segment distance is computed, Then it equals the **great-circle (haversine) distance** between the two **shipped checkpoint coordinates** within ±1% (or ≤1 km), and `totalChainKm` equals the sum of those 33 great-circle segments. A shipped coordinate is the administrative-centre coordinate, except that a **non-relocated coastal checkpoint MAY carry a documented coast-alignment offset ≤ 0.1° (~10 km)** to keep its chords landward of the generalized coastline (see AC-5 / ADR-0009(c)); the **7 relocated centres are seeded exactly** (AC-6).
- [x] AC-4: Given the new `totalChainKm`, When `kmPerActiveHour` is derived, Then it re-derives as `totalChainKm ÷ ~8 active hours` (no hardcoded 2000 km / 250 km-per-hour literal remains), so a full traversal still takes ≈8 active hours.
- [x] AC-5: Given the shipped 34-province map and its equirectangular projection, When the full spine polyline is densely sampled between every consecutive pair of checkpoints (≥20 interpolated points per segment) against `BaseMapGeometry.containsLandmass`, Then **every sampled point falls on land** — no inter-unit segment crosses open sea — resolving the carried `vietnam-map-fidelity` AC-5, **except one documented bounded residual** on `quảng_trị → hà_tĩnh` (Đồng Hới → Hà Tĩnh): the chord clips a generalized-coastline notch at ~(17.75, 106.39) that cannot be cleared within the 0.1° coast-alignment cap (Quảng Trị is a relocated centre, exact; Hà Tĩnh would need ~0.114°). **Kevin waived it 2026-07-15** — Hà Tĩnh is kept at its true admin centre and the residual is pinned to **≤3 samples** on that one segment (a map-decimation artifact, not a real sea crossing — the real land is continuous there); every other segment is 100% on land.
- [x] AC-6: Given the relocated-centre flags in the dataset, When coordinate seeding is checked, Then each relocated unit's checkpoint sits at its administrative-centre coordinate, not its nominal territory (Gia Lai at coastal Quy Nhơn ≈ 13.782/109.219, An Giang at Rạch Giá ≈ 10.012/105.081, Bắc Ninh at Bắc Giang, Quảng Trị at Đồng Hới, Tây Ninh at Tân An, Đồng Tháp at Mỹ Tho, Lào Cai at Yên Bái).
- [x] AC-7: Given the 34-unit spine, When each checkpoint is projected onto the shipped 34-province base map, Then it lands on land (same equirectangular bounds as `vietnam-map-fidelity`), with no checkpoint in the sea or off-canvas. Each checkpoint sits at its true georeferenced administrative-centre coordinate, **except** any non-relocated coastal checkpoint carrying a documented coast-alignment offset ≤ 0.1° (~10 km) that shifts it just inland to stay landward of the generalized coastline (ADR-0009(c)); the 7 relocated centres are exact. A **golden coordinate-table test pins all 34 shipped coordinates** so every offset is explicit and diff-reviewable.
- [x] AC-8: Given ADR-0005 sub-chain route authoring over the 34-unit spine, When a user picks a start, an end, and intermediate stops, Then the derived sub-chain is a valid `ProvinceChain` (ordered, no duplicate ids, n−1 positive segments summing to its own total) and its lifecycle (active/completed/abandoned per BR-10) behaves as before.
- [x] AC-9: Given a `RoutePlan` / legacy `RouteSelection` persisted under retired pre-2025 / 13-node province ids, When the app loads it after the upgrade, Then it never crashes and forward-migrates **by reset** — a clean fresh full-spine active plan stamped at the current engine cumulative distance (not an id-remap) — and the user's cumulative/lifetime distance is preserved intact (BR-8, separate engine store).
- [x] AC-10: Given the route-owns-total / engine-takes-injected-rate boundary (BR-6), When the same active-time and idle-time inputs are replayed against the rebuilt geometry, Then distance-from-journey-time and stats-from-raw-active-time accrue by the identical mechanism as before (only `kmPerActiveHour` differs, as injected config) — a regression guard confirms no accrual-logic change.
- [x] AC-11: Given the canonical-km projection (ADR-0004b), When a position at canonical distance `d` km is projected onto the 34-unit spine, Then it maps to the correct segment and interpolated coordinate, and round-trips (checkpoint → cumulative km → coordinate) to the seeded centre within tolerance.

### Non-functional
- [x] NFR-1 Performance: The 34-unit chain build and canonical-km→coordinate projection are computed once (or memoized) and add no measurable per-frame cost — render stays at parity with `vietnam-map-fidelity` frame timings.
- [x] NFR-2 Security/Privacy: No new file/network reads, no new egress, and no location access are introduced; the model stays local-only within BR-1's aggregate-idle-only boundary.
- [x] NFR-3 Accessibility: Any changed route-authoring UI (start/end/stop pickers over the 34 units) remains fully keyboard-navigable and screen-reader-labelled, with no regression from the shipped authoring flow.

## Open questions — RESOLVED 2026-07-15 (system-architect framing → ADR-0009 to be written at build time)
- [x] **Spine ordering:** a **hand-curated canonical order** baked into `province_chain.dart`, verified by an automated no-sea-crossing test that samples `BaseMapGeometry.containsLandmass` (ADR-0008) along every segment. No synthetic non-unit waypoints — `nodes` stays exactly the 34 units; fix a sea-crossing by re-ordering.
- [x] **Migration:** forward-migrate **by reset** (fresh full-spine plan stamped at the current engine cumulative), never id-remap — the topology + total km changed wholesale so a remap would misplace the traveller. Existing decoders already catch retired-id `ArgumentError`s → degrade safely (no crash); lifetime distance is a separate store (untouched).
- [x] **Pacing:** `kmPerActiveHour = totalChainKm / 8` (already injected at `main.dart:597`), so end-to-end stays ≈8 active hours even though the great-circle total grows (~2500–3500 km vs the old stylized 2000). Only displayed km grow; a playtest note on relative leg-length feel, not a correctness item.
- [x] **Enum stability:** keep `JourneyDirection.towardHaGiang`/`towardMuiCaMau` + `southTip`/`northTip` as stable **symbolic** labels (persisted-by-name; north terminus identity changed but the label stays) — update doc comments/UI labels only, no persisted-enum migration.
- Candidate **ADR-0009** (write via `/add-adr` at build time): great-circle auto-distances (amends ADR-0004(b)'s stylized-2000km premise) · hand-curated 34-unit ordering + no-sea-crossing test · plan-migration-by-reset (amends ADR-0005's migration clause) · enum-name stability.

### Amended post-approval 2026-07-15 (Kevin's ruling — bounded coast-alignment offset)
A self-review found the shipped implementation used a small inland offset on a coastal checkpoint that the
approved contract's absolute "true administrative-centre coordinate" wording did not permit. Root cause: the
bundled base-map coastline (ADR-0008) is **generalized/decimated** — it omits real peninsulas and bay detail
(e.g. Hạ Long bay), so a straight great-circle chord between two true coastal admin-centre coordinates can dip
into the simplified "sea" even where the real land is continuous, and pure re-ordering (Open-questions "fix by
re-ordering" premise) cannot always clear it for adjacent coastal units. Kevin's ruling — **minimize + ratify +
golden test** — is now recorded in **ADR-0009(c)** as a precedence order (re-order → bounded ≤0.1° (~10 km)
coast-alignment offset on a **non-relocated** coastal checkpoint, documented per-unit and pinned by a golden
coordinate-table test → never a synthetic waypoint). AC-3, AC-7 and the coast-hugging ordering constraint above
were updated to match; relocated centres remain exact and nothing else is loosened.

After minimizing, 7 of the 8 offsets fell well under the cap (Hà Tĩnh and Quảng Ninh's original ~25 km shifts
are gone). **One residual could not be cleared within the cap** — `quảng_trị → hà_tĩnh` needs ~0.114° (~12 km,
over cap) because Quảng Trị is a relocated exact centre and only Hà Tĩnh can move. **Kevin waived it 2026-07-15
(keep Hà Tĩnh exact, document the residual):** it is a coastline-decimation artifact (the real land is
continuous), so the true admin centre is preserved and the residual is bounded to ≤3 samples on that one segment
by the dense guard (see AC-5). A future asset-densification follow-up could close it fully.

## Related
- Backlog framing + the sourced 34-unit dataset: [planning/backlog/province-chain-2026.md](../../planning/backlog/province-chain-2026.md) _(consumed on promotion — dataset carried below)_
- Sibling (shipped): [specs/vietnam-map-fidelity/](../vietnam-map-fidelity/) — the 34-province base map + the carried AC-5 route-hugs-coast limitation this slice resolves.
- Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md) — BR-1, BR-6, BR-8, BR-10
- Architecture: [docs/architecture/](../../docs/architecture/) — ADR-0004 (canonical-km projection), ADR-0005 (sub-chain routes), ADR-0007 (engine firewall)

## Sourced 34-unit dataset (2026) — the geography source for this slice
From `ui-asset-curator` (map: *Vietnam administrative divisions 2025*, Wikimedia CC BY-SA; names via Wikipedia's
current table). Coordinates are city-level representative WGS84 points for each administrative centre; `approx`
= lower-confidence / relocated. **Relocated centres** (admin centre sits in a former partner province — matters
for the coast-hugging order + distances): Lào Cai→Yên Bái, Bắc Ninh→Bắc Giang, Quảng Trị→Đồng Hới,
Gia Lai→Quy Nhơn, Tây Ninh→Tân An, Đồng Tháp→Mỹ Tho, An Giang→Rạch Giá. Count: 6 municipalities + 28
provinces = **34**. (Coordinates ≥1 to re-verify at build.)

```json
[
  {"name":"Hà Nội","type":"municipality","centre":"Hoàn Kiếm","lat":21.028,"lon":105.854},
  {"name":"Hồ Chí Minh","type":"municipality","centre":"Sài Gòn","lat":10.776,"lon":106.701},
  {"name":"Hải Phòng","type":"municipality","centre":"Thủy Nguyên","lat":20.97,"lon":106.62,"approx":true},
  {"name":"Đà Nẵng","type":"municipality","centre":"Hải Châu","lat":16.060,"lon":108.221},
  {"name":"Huế","type":"municipality","centre":"Thuận Hóa","lat":16.463,"lon":107.590},
  {"name":"Cần Thơ","type":"municipality","centre":"Ninh Kiều","lat":10.033,"lon":105.784},
  {"name":"Cao Bằng","type":"province","centre":"Thục Phán (Cao Bằng)","lat":22.666,"lon":106.258},
  {"name":"Lạng Sơn","type":"province","centre":"Lương Văn Tri (Lạng Sơn)","lat":21.853,"lon":106.761},
  {"name":"Phú Thọ","type":"province","centre":"Việt Trì","lat":21.322,"lon":105.402},
  {"name":"Quảng Ninh","type":"province","centre":"Hạ Long","lat":20.951,"lon":107.076},
  {"name":"Thái Nguyên","type":"province","centre":"Phan Đình Phùng (Thái Nguyên)","lat":21.593,"lon":105.844},
  {"name":"Tuyên Quang","type":"province","centre":"Minh Xuân (Tuyên Quang)","lat":21.823,"lon":105.214},
  {"name":"Lào Cai","type":"province","centre":"Yên Bái (relocated centre)","lat":21.705,"lon":104.870,"approx":true},
  {"name":"Điện Biên","type":"province","centre":"Điện Biên Phủ","lat":21.386,"lon":103.017},
  {"name":"Lai Châu","type":"province","centre":"Tân Phong (Lai Châu)","lat":22.386,"lon":103.458},
  {"name":"Sơn La","type":"province","centre":"Chiềng Cơi (Sơn La)","lat":21.327,"lon":103.914},
  {"name":"Bắc Ninh","type":"province","centre":"Bắc Giang (relocated centre)","lat":21.281,"lon":106.197},
  {"name":"Hưng Yên","type":"province","centre":"Phố Hiến (Hưng Yên)","lat":20.646,"lon":106.051},
  {"name":"Ninh Bình","type":"province","centre":"Hoa Lư","lat":20.251,"lon":105.975},
  {"name":"Thanh Hóa","type":"province","centre":"Hạc Thành (Thanh Hóa)","lat":19.807,"lon":105.776},
  {"name":"Nghệ An","type":"province","centre":"Trường Vinh (Vinh)","lat":18.679,"lon":105.681},
  {"name":"Hà Tĩnh","type":"province","centre":"Thành Sen (Hà Tĩnh)","lat":18.343,"lon":105.900},
  {"name":"Quảng Trị","type":"province","centre":"Đồng Hới (relocated centre)","lat":17.468,"lon":106.622},
  {"name":"Quảng Ngãi","type":"province","centre":"Cẩm Thành (Quảng Ngãi)","lat":15.120,"lon":108.800},
  {"name":"Gia Lai","type":"province","centre":"Quy Nhơn (coastal relocated centre)","lat":13.782,"lon":109.219},
  {"name":"Đắk Lắk","type":"province","centre":"Buôn Ma Thuột","lat":12.688,"lon":108.050},
  {"name":"Khánh Hòa","type":"province","centre":"Nha Trang","lat":12.238,"lon":109.196},
  {"name":"Lâm Đồng","type":"province","centre":"Xuân Hương–Đà Lạt","lat":11.940,"lon":108.458},
  {"name":"Đồng Nai","type":"province","centre":"Trấn Biên (Biên Hòa)","lat":10.957,"lon":106.842},
  {"name":"Tây Ninh","type":"province","centre":"Tân An (relocated centre, former Long An)","lat":10.535,"lon":106.413,"approx":true},
  {"name":"Đồng Tháp","type":"province","centre":"Mỹ Tho (relocated centre, former Tiền Giang)","lat":10.360,"lon":106.359},
  {"name":"Vĩnh Long","type":"province","centre":"Long Châu (Vĩnh Long)","lat":10.253,"lon":105.972},
  {"name":"An Giang","type":"province","centre":"Rạch Giá (relocated centre, former Kiên Giang)","lat":10.012,"lon":105.081},
  {"name":"Cà Mau","type":"province","centre":"Tân Thành (Cà Mau)","lat":9.177,"lon":105.152}
]
```
