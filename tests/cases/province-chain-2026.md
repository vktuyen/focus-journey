# Test cases: province-chain-2026

Spec: [specs/province-chain-2026/spec.md](../../specs/province-chain-2026/spec.md) — its `## Acceptance criteria`
section (AC-1..AC-11 + NFR-1..3) is the contract.
Sibling (shipped): [specs/vietnam-map-fidelity/spec.md](../../specs/vietnam-map-fidelity/spec.md) — the 34-province
base map + the carried AC-5 "route hugs coast" limitation this slice **resolves**. Case-file style matched from
[tests/cases/vietnam-map-fidelity.md](vietnam-map-fidelity.md).
Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md) — BR-1 (privacy), BR-6
(distance/stats split), BR-8 (never-reset cumulative), BR-10 (route lifecycle), BR-11 (network egress).
Reused geometry: `src/focus_journey/lib/features/route/domain/` — `equirectangular_projection.dart` (the fixed
N24/S8·W101.8/E110.3 projection), `base_map_geometry.dart` (`containsLandmass` ray-cast — the AC-5 engine),
`province_chain.dart` (`ProvinceChain(nodes, segmentsKm)`, `totalChainKm`, `_sumTolerance`),
`province_geography.dart`, `route_plan.dart` (`RoutePlan`, legacy `RouteSelection`),
`route_polyline_projector.dart` (canonical-km axis).

## Coverage note

This slice is a **journey DATA MODEL rebuild** — `province_geography.dart` + `province_chain.dart` re-authored onto
Vietnam's current **34 units (2026)** with **great-circle (haversine) auto-distances**, a **hand-curated
coast-hugging south→north spine** verified to never cross the sea, and **plan-migration-by-reset** for in-progress
journeys. The **map asset is shipped and unchanged** (`vietnam-map-fidelity`); this slice changes the *geometry/config
the model runs over*, not the accrual engine (ADR-0007 firewall) and not the base-map render.

**The strong automatable core is pure Dart** and needs no widget/device leg:
- **Chain-data integrity** (AC-1/AC-2): count, unique ids, endpoints, 33 positive segments, sum-equals-total — pure
  unit tests over the production `vietnamProvinceChain` constant.
- **Great-circle distances** (AC-3): a deterministic closed-form haversine over the seeded centre coordinates —
  hand-computable, no I/O.
- **No-sea-crossing dense spine** (AC-5): the flagship — dense sampling of all 33 segments against the *real shipped*
  `BaseMapGeometry.containsLandmass` (the same ray-cast + real GeoJSON parsed from disk that `vietnam-map-fidelity`'s
  `base_map_geometry_test.dart` uses). This **re-arms the currently-skipped guard** (see regression list below).
- **Relocated-centre seeding** (AC-6), **on-land + on-canvas projection** (AC-7), **canonical-km round-trip** (AC-11),
  **sub-chain authoring validity** (AC-8) — all pure domain math.
- **kmPerActiveHour re-derivation** (AC-4) and **accrual-mechanism regression** (AC-10) — a wiring/static guard plus a
  replay test over the injected rate.

**Weak / manual-only legs** (cannot be honestly settled by a Dart test): the *visual* verdict that the spine reads as
one continuous coast-hugging S→N line on the drawn coastline (TC-M-GEO, carried from the sibling), on-device frame
parity (NFR-1 device leg), real screen-reader/keyboard operation of any changed authoring picker (NFR-3 AT leg), and
the gating **privacy audit** (NFR-2 / TC-M-PRIV) — a data-only change *should* add zero egress and zero location read.

Layer → AC/NFR mapping:

| AC / NFR | Assertion (paraphrased) | Covering layer(s) | Cases |
| --- | --- | --- | --- |
| **AC-1** | exactly 34 checkpoints, unique ids, one per dataset unit | Unit (pure) | PC-901, PC-902 |
| **AC-2** | endpoints = lat extremes, 33 strictly-positive segments summing to `totalChainKm` | Unit (pure) | PC-903, PC-904 |
| **AC-3** | each segment = haversine within ±1% / ≤1 km; total = sum of 33 | Unit (pure) | PC-905, PC-906 |
| **AC-4** | `kmPerActiveHour = totalChainKm/8`, no hardcoded 2000/250 literal | Unit + static guard | PC-907, PC-908 |
| **AC-5** | dense spine (≥20 pts/seg) all on land vs shipped `containsLandmass` | Unit (real geometry) + **visual** | PC-909, PC-910, PC-911, TC-M-GEO |
| **AC-6** | 7 relocated units at admin-centre coord, not nominal territory | Unit (pure) | PC-912, PC-913 |
| **AC-7** | all 34 project on land + on-canvas under fixed bounds | Unit (projection + landmass) + **visual** | PC-914, PC-915, TC-M-GEO |
| **AC-8** | sub-chain authoring valid + lifecycle per BR-10 | Unit (pure) | PC-916, PC-917, PC-918 |
| **AC-9** | legacy retired-id RoutePlan → migrate-by-reset, no crash, cumulative preserved | Unit + integration | PC-919, PC-920, PC-921, PC-922 |
| **AC-10** | replay → identical accrual mechanism; only injected rate differs (BR-6/ADR-0007) | Unit (regression) | PC-923, PC-924 |
| **AC-11** | canonical-km `d` → correct segment/coord; checkpoint round-trips within tol | Unit (pure) | PC-925, PC-926, PC-927 |
| **NFR-1** | chain build + projection memoized/once; no per-frame cost; render parity | Static/hot-path guard + **device** | PC-928, TC-M-NF1 |
| **NFR-2** (gating) | no new file/network read, no egress, no location; local-only (BR-1) | Static inspection + **audit** | PC-929, TC-M-PRIV |
| **NFR-3** | changed authoring picker keyboard + screen-reader; no regression | Widget (semantics/keyboard) + **AT** | PC-930, TC-M-A11Y |

### Regression risk — shipped tests that HARDCODE the old model (top ledger risk; MUST be updated)

These pin the pre-2025 / 13-node / stylized-2000 km model and **will fail** (or silently mask the new contract) until
updated. The `test-script-author` must update them **in lockstep** with the data rebuild; leaving any of them asserting
the old numbers is the single biggest regression trap.

1. `src/focus_journey/test/features/route/domain/province_chain_test.dart` —
   - `hasAround10To15Checkpoints` asserts `inInclusiveRange(10, 15)` → must become **34**.
   - `segmentSumEqualsTotalChainKm_exactly2000` asserts `closeTo(2000, kTol)` → must become the new
     great-circle total (~2500–3500 km), and the "12 segments" comment/`segmentCountIsNodesMinusOne` becomes **33**.
   - `isStrictlyOrdered_muiCaMauToHaGiang` asserts `southTip.id == 'mui_ca_mau'` and `northTip.id == 'ha_giang'` →
     the north-terminus **identity changed** (Hà Giang is now within Tuyên Quang; north tip is the max-latitude
     current unit) and the south-tip id/centre is now Cà Mau / Tân Thành (9.177). The *symbolic* enum labels
     `towardHaGiang`/`towardMuiCaMau` + `southTip`/`northTip` stay (persist-by-name), but the node ids/coords change.
     _(The `_fixtureChain()` synthetic chain in this file — total 1440 — is a hand-worked fixture and MAY stay as-is;
     only the **production-constant** assertions are load-bearing.)_
2. `src/focus_journey/test/features/route/domain/province_geography_test.dart` —
   - `coversAllThirteenProvinces` asserts `hasLength(13)` (chain + `canonicalCoordinates`) → must become **34**.
   - `everyCoordinateSitsInsideTheVietnamBbox` and `canonicalCoordinates_traceSouthTipToNorthTip` still hold but run
     over the new 34-unit data (verify the new south/north tip lat bounds).
3. `src/focus_journey/test/features/route/domain/base_map_geometry_test.dart` —
   - `allThirteenCheckpointsOnLand` (TC-812) asserts **13/13** and encodes the `mui_ca_mau` display **nudge**
     (8.613/104.725). This slice re-derives the **authoritative** centre (Cà Mau / Tân Thành 9.177/105.152), so this
     becomes **34/34** and the nudge is retired.
   - **`everyDenselySampledRoutePointIsOnLand` is currently `skip:`'d** ("AC-5 sea-crossing carried to
     province-chain-2026"). This slice's PC-909/PC-910 is exactly that guard **re-armed** (skip removed) over the new
     coast-hugging spine — the four legs it names (`vinh→ninh_binh`, `hue→vinh`, `mui_ca_mau→can_tho`,
     `nha_trang→quy_nhon`) must now pass. `parsedProvinceRingsCountIs37` is about the **asset** (unchanged) — leave it.
4. `src/focus_journey/lib/features/journey/domain/journey_engine.dart` — `defaultKmPerActiveHour = 250` is the
   pre-2025 literal (2000÷8). AC-4 requires the *production* rate re-derives from `totalChainKm/8` (already wired at
   `main.dart:597`). The engine **default constant** is a fallback, not the production path — but the static guard
   (PC-908) must confirm no `2000`/`250` literal is the chain total or the shipped pacing; flag whether the fallback
   default should be documented as "test-only default, production injects from the chain".
5. Fixtures using `kmPerActiveHour: 250` as an **injected** rate in engine/route/cubit tests
   (`journey_engine_test.dart`, `activity_ticker_test.dart`, `route_progress_resolver_test.dart`,
   `journey_cubit_test.dart`, the `journey_scene_v2` / `journey_dynamic_curve` suites, etc.) are testing the
   **mechanism** with an arbitrary rate and are AC-10-legitimate — they do **not** need the production number and
   should **stay** (changing them would dilute the accrual-regression guard). Do not blanket-replace 250.
6. `src/focus_journey/lib/features/route/domain/route_polyline_projector.dart` doc comment ("the engine's locked
   2000 km total") and `province_chain.dart` header comment ("~2000 km total") describe the old premise — update the
   prose to the great-circle model per candidate ADR-0009 (doc-only, not a test, but reviewers should catch it).

### Risky / under-covered areas (flagged for `test-script-author` and reviewers)

1. **AC-2 "strictly ordered south→north" vs coast-hugging.** The spine is a *hand-curated* coast-hugging order that
   threads inland units (Điện Biên, Sơn La, Đắk Lắk, Lâm Đồng) — it is **not** a pure latitude sort, so a naive
   "assert each node's latitude ≥ the previous" would be WRONG and contradict AC-5. The safe automatable assertion is:
   `nodes.first` is the southernmost unit (Cà Mau/Tân Thành ≈9.177), `nodes.last` is the northernmost (max-latitude)
   unit, 33 strictly-positive segments, sum == total — and the *ordering correctness* is proven by the no-sea-crossing
   test (AC-5), not by monotonic latitude. If product intends strict per-index latitude monotonicity, that conflicts
   with the resolved coast-hugging decision — **escalate to `product-domain-expert` before asserting it** (PC-904).
2. **AC-5 is the flagship and its automatability depends on the real vector geometry.** The guard is only meaningful
   against the **shipped GeoJSON parsed from disk** (as `base_map_geometry_test.dart` already does) — a synthetic
   rectangle land ring would pass trivially. PC-909/PC-910 MUST load the real asset. The *visual* "reads as one
   coast-hugging line" verdict remains manual (TC-M-GEO). If a re-ordering still can't clear a bay, the fix is
   **re-ordering the 34 units** (no synthetic non-unit waypoints — Open-question resolution), which may ripple into
   AC-2/AC-3 numbers.
3. **AC-9 migration-by-reset changes today's behaviour.** The shipped decoder (`shared_preferences_route_repository`
   `_tryDecodePlan`) catches the retired-id `ArgumentError` and returns **null** ("no saved route") — i.e. it currently
   **drops** the plan silently (no crash, but progress lost). AC-9 requires an *active* **fresh full-spine plan stamped
   at the current engine cumulative** (reset, not drop, not id-remap), with lifetime distance preserved. So PC-919/920
   assert **new** behaviour, not the shipped null-return — the implementer must add the reset path. Confirm where the
   "current engine cumulative" is read from at load (the separate never-reset store, BR-8).
4. **Great-circle total is only bounded, not fixed (AC-3/AC-4).** The spec says ~2500–3500 km — do NOT hardcode an
   exact total in the test; assert `total == sum(haversine segments)` and a sane range, and let the pacing derive as
   `total/8`. A single wrong coordinate would shift the total; PC-906 pins one hand-worked segment so a systematic
   haversine bug is caught.
5. **NFR-2 privacy stays gating even for a data-only change.** New coordinate tables are static app-shipped reference
   data — the audit must confirm no coordinate/bound is ever a **device** read and no new egress/import sneaks in
   (TC-M-PRIV). A fail blocks ship regardless of every other pass.

## Conventions used by these cases

- **Deterministic pure-Dart core.** Chain/geography/haversine/projection/round-trip cases are pure functions over the
  static `vietnamProvinceChain` / `vietnamProvinceGeography` constants — no timers, no `DateTime.now()`, no I/O, no
  network, no `latlong2` (domain is framework-free). AC-5 loads the **real shipped GeoJSON from disk** and parses it
  with the production pure parser (as the sibling's `base_map_geometry_test.dart` does) — deterministic, offline.
- **Fixed georeferencing bounds.** Projection cases use exactly `EquirectangularBounds` North 24° / South 8° · West
  101.8° / East 110.3° (same as `vietnam-map-fidelity`): `x = (lon−101.8)/(110.3−101.8)`, `y = (24−lat)/(24−8)`.
- **Haversine reference.** Great-circle uses mean Earth radius 6371 km; `d = 2R·asin(√(sin²(Δφ/2) +
  cosφ₁·cosφ₂·sin²(Δλ/2)))`. AC-3 tolerance is **±1% or ≤1 km**, whichever is looser per segment.
- **Tolerances.** Segment-sum vs `totalChainKm` within `_sumTolerance` (1e-6 km); round-trip coordinate within ~1e-6°
  (linear-lerp exactness) unless a segment note says otherwise; a projected point is "on land" iff `containsLandmass`
  returns true (never in a sea/ocean polygon).
- **Test layer.** Per `docs/architecture/overview.md`: unit/widget under `src/focus_journey/test/`, integration under
  `src/focus_journey/integration_test/`, run with `fvm flutter test`. TC-M* legs are manual / on-device / audit, run
  during `/execute-tests` and recorded per OS where applicable (Windows runtime legs DEFERRED — precedent:
  `vietnam-map-fidelity`, `map-experience`).

## Cases

### Chain composition — exactly 34 checkpoints (AC-1)

### Case: The canonical chain is built with exactly 34 unique checkpoints — one per current unit
**ID:** PC-901
**Priority:** P0
**Type:** happy-path
**Covers:** AC-1

Given the rebuilt `province_geography.dart` + `province_chain.dart`
When the canonical `vietnamProvinceChain` is constructed at startup
Then it holds exactly **34** checkpoint nodes, every node id is unique, and there is one node per unit in the sourced 2026 dataset — no missing and no extra unit

**Notes:** Pure unit test over the production constant (`src/focus_journey/test/features/route/domain/province_chain_test.dart`). Directly updates the shipped `hasAround10To15Checkpoints` assertion (regression list #1). Also assert `segmentCountIsNodesMinusOne` now reads 33.

---

### Case: Every dataset unit is represented — 6 municipalities + 28 provinces, none dropped
**ID:** PC-902
**Priority:** P1
**Type:** edge
**Covers:** AC-1

Given the sourced 34-unit dataset (6 municipalities + 28 provinces) and the built geography
When the chain's node ids are compared against the dataset's units
Then each of the 34 units maps to exactly one node id, the geography has a coordinate for every node (constructor guard passes), and no dataset unit is absent and no non-dataset id is present

**Notes:** Unit test over `vietnamProvinceGeography` (updates `coversAllThirteenProvinces` → 34, regression list #2). The `ProvinceGeography` constructor already fails loudly on a missing coordinate — assert it constructs `returnsNormally` for all 34.

---

### Ordering + segments (AC-2)

### Case: Endpoints are the latitude extremes with 33 strictly-positive segments summing to the total
**ID:** PC-903
**Priority:** P0
**Type:** happy-path
**Covers:** AC-2

Given the canonical 34-unit chain
When its invariants are asserted
Then `nodes.first`/`southTip` is Cà Mau / Tân Thành at lat ≈ 9.177 (the southernmost centre), `nodes.last`/`northTip` is the northernmost current unit (maximum-latitude admin centre), there are exactly **33** segments, every segment is strictly positive (`> 0`), and their sum equals `totalChainKm` within `_sumTolerance`

**Notes:** Pure unit test. The `ProvinceChain` constructor already enforces positive segments + `nodes.length−1` count + sum; assert them over the production constant. `totalChainKm` is derived from segments so the sum invariant holds by construction — assert it explicitly for the reader. North terminus identity changed (Hà Giang now within Tuyên Quang) — assert against the max-latitude unit, not a hardcoded `ha_giang` id.

---

### Case: The spine progresses south→north overall without asserting a pure latitude sort
**ID:** PC-904
**Priority:** P1
**Type:** edge
**Covers:** AC-2

Given the hand-curated coast-hugging order (which threads inland units — Điện Biên, Sơn La, Đắk Lắk, Lâm Đồng — so it is deliberately NOT a strict per-node latitude sort)
When the overall spine direction is checked
Then the south tip latitude is strictly less than the north tip latitude and the spine reads broadly northward, while per-index latitude monotonicity is **not** asserted (the ordering's correctness is proven by the no-sea-crossing test PC-909, not by a latitude sort)

**Notes:** Pure unit test. **Guards the AC-2/coast-hugging tension flagged in the coverage note.** Do NOT assert `nodes[i+1].lat >= nodes[i].lat` — that would contradict the resolved coast-hugging decision. If product actually wants strict monotonic latitude, escalate to `product-domain-expert` before writing that assertion.

---

### Great-circle distances (AC-3)

### Case: Each segment equals the haversine distance between the two admin-centre coordinates
**ID:** PC-905
**Priority:** P0
**Type:** happy-path
**Covers:** AC-3

Given each consecutive pair of the 34 unit-centre coordinates
When a segment distance is computed and compared to the great-circle (haversine) distance between the pair
Then every one of the 33 segments equals its haversine distance within ±1% (or ≤1 km), and `totalChainKm` equals the sum of those 33 great-circle segments

**Notes:** Pure unit test (mean Earth radius 6371 km, formula in Conventions). Iterate `canonicalCoordinates` pairwise, compute haversine independently, compare to `segmentsKm[i]`. Do NOT hardcode the exact total — assert it against the summed haversine legs plus a sane range (~2500–3500 km per the spec).

---

### Case: A hand-worked haversine value pins the formula for one named leg
**ID:** PC-906
**Priority:** P1
**Type:** edge
**Covers:** AC-3

Given one specific consecutive pair (e.g. Đà Nẵng 16.060/108.221 → Huế 16.463/107.590) with an independently hand-computed great-circle distance
When that leg's `segmentsKm` value is compared to the hand-computed reference
Then it matches within ≤1 km — pinning the radius + formula so a systematic haversine bug (wrong radius, degrees-vs-radians, swapped lat/lon) is caught rather than hidden inside the aggregate sum

**Notes:** Pure unit test with a literal expected value computed offline. Complements PC-905's aggregate check with one exact spot value. Pick a short leg with well-separated coordinates.

---

### Pacing re-derivation (AC-4)

### Case: kmPerActiveHour re-derives from the new total so a full traversal still takes ~8 active hours
**ID:** PC-907
**Priority:** P0
**Type:** happy-path
**Covers:** AC-4

Given the rebuilt `totalChainKm` (the summed 33 great-circle segments)
When `kmPerActiveHour` is derived for the engine
Then it equals `totalChainKm ÷ 8`, and dividing `totalChainKm` by that rate yields ≈8 active hours end-to-end — the displayed km grow with the great-circle total while the time-to-cross stays ~8 h

**Notes:** Assert the wiring at `main.dart:597` (`vietnamProvinceChain.totalChainKm / 8`) already re-derives rather than hardcoding. Unit-assertable: `(totalChainKm / (totalChainKm/8))` == 8. Confirm the production path injects the derived rate, not the engine's fallback default.

---

### Case: No hardcoded 2000 km total or 250 km/active-hour literal remains on the production path
**ID:** PC-908
**Priority:** P1
**Type:** regression
**Covers:** AC-4

Given all `province-chain-2026` source (the chain/geography constants, the km-per-active-hour wiring, the projector doc premise)
When it is inspected statically for the retired stylized literals
Then no `2000` appears as the chain total and no `250` appears as the shipped pacing rate — the total is derived from the 33 great-circle segments and the rate is `totalChainKm/8`; the `JourneyEngine.defaultKmPerActiveHour = 250` fallback is confirmed as a documented test-only default that the production wiring overrides (not the shipped rate)

**Notes:** Static-inspection case (grep over the route/chain source + the engine wiring). Ties regression-list #4/#6. Flag to the reviewer whether the engine fallback constant should be re-commented. Do NOT touch injected `kmPerActiveHour: 250` in mechanism fixtures (regression-list #5) — those are AC-10-legitimate.

---

### No-sea-crossing spine — the resolved carried limitation (AC-5)

### Case: The full 34-unit spine, densely sampled, never leaves the shipped landmass
**ID:** PC-909
**Priority:** P0
**Type:** happy-path
**Covers:** AC-5

Given the shipped 34-province base geometry (real GeoJSON parsed from disk) and its `BaseMapGeometry.containsLandmass`
When the spine polyline is densely sampled between every consecutive pair of the 34 checkpoints (≥20 interpolated points per segment) and each sample is tested against `containsLandmass`
Then **every** sampled point on all 33 segments falls on land — no inter-unit segment crosses open sea — resolving the carried `vietnam-map-fidelity` AC-5

**Notes:** Unit test loading the real asset (mirror `base_map_geometry_test.dart` `_loadRealGeometry`). This is the flagship. Sample ≥20 (the sibling used 50) per segment. Report which segment (labelled by node ids) leaves the landmass so a re-ordering fix is targeted. Visual verdict is TC-M-GEO.

---

### Case: The previously-skipped dense-sampling guard is re-armed and green for the coast-hugging spine
**ID:** PC-910
**Priority:** P0
**Type:** regression
**Covers:** AC-5

Given the sibling's `everyDenselySampledRoutePointIsOnLand` test, currently `skip:`'d with "AC-5 sea-crossing carried to province-chain-2026"
When the skip is removed and the guard runs over the rebuilt coast-hugging spine
Then it passes — specifically the four legs the sibling flagged as clipping bays on the old 13-node straight-line route (`vinh→ninh_binh`, `hue→vinh`, `mui_ca_mau→can_tho`, `nha_trang→quy_nhon`) no longer have any sample in the sea

**Notes:** Regression against the exact carried limitation. Either drop the `skip:` on the existing test or supersede it with PC-909 over the 34-unit data — but the deferred guard must end **armed**, not skipped. Confirm no `skip:` string mentioning province-chain-2026 survives.

---

### Case: A re-ordering that re-introduces a sea-crossing is detected (the guard has teeth)
**ID:** PC-911
**Priority:** P1
**Type:** negative
**Covers:** AC-5

Given a deliberately mis-ordered variant of the 34-unit spine that forces a segment across a known bay/open-sea span
When the dense-sampling landmass check runs over that variant
Then it fails (reports the offending segment) — proving the test would catch a regression rather than passing vacuously against a too-generous geometry

**Notes:** Unit test with a locally-constructed bad-order `ProvinceChain`/coordinate pair (not the production constant). Guards against a synthetic/over-generous land ring masking real sea-crossings — the check must run against the real shipped geometry.

---

### Relocated administrative centres (AC-6)

### Case: Each relocated unit is seeded at its administrative-centre coordinate, not its nominal territory
**ID:** PC-912
**Priority:** P0
**Type:** happy-path
**Covers:** AC-6

Given the 7 relocated-centre flags in the dataset
When each relocated unit's seeded coordinate is checked
Then it sits at its administrative centre: Gia Lai at coastal Quy Nhơn ≈ 13.782/109.219, An Giang at Rạch Giá ≈ 10.012/105.081, Bắc Ninh at Bắc Giang, Quảng Trị at Đồng Hới, Tây Ninh at Tân An, Đồng Tháp at Mỹ Tho, and Lào Cai at Yên Bái — never at the nominal province territory

**Notes:** Pure unit test asserting the seeded `GeoCoordinate` for each of the 7 relocated ids against the dataset centre values. These drive both the coast-hugging order and the distances (AC-3/AC-5), so a mis-seed here would ripple.

---

### Case: Gia Lai's coastal relocated centre keeps its neighbouring segments on land
**ID:** PC-913
**Priority:** P1
**Type:** edge
**Covers:** AC-6, AC-5

Given Gia Lai seeded at coastal Quy Nhơn (13.782/109.219) rather than its inland highland territory
When its two neighbouring spine segments are dense-sampled against the landmass
Then they stay on land — the coastal centre is what makes the coast-hugging order coherent through the south-central coast (a highland-centre seed would pull the segment inland and change both the distance and the sea-crossing outcome)

**Notes:** Unit test tying the relocated-centre seed to the AC-5 outcome for the specific case the spec calls out as "coastal relocated centre". Uses the real geometry.

---

### On-land georeferenced projection (AC-7)

### Case: All 34 checkpoints project onto the drawn landmass under the fixed bounds
**ID:** PC-914
**Priority:** P0
**Type:** happy-path
**Covers:** AC-7

Given the 34-unit spine and the shipped base geometry under the equirectangular bounds N24/S8 · W101.8/E110.3
When each checkpoint coordinate is tested against `containsLandmass`
Then all 34 return true — every checkpoint sits on land, none in the sea — updating the shipped 13/13 guard to **34/34** and retiring the old `mui_ca_mau` display nudge (the authoritative Cà Mau/Tân Thành centre 9.177/105.152 lands on the drawn coastline directly)

**Notes:** Unit test over the real geometry (updates `allThirteenCheckpointsOnLand`, regression list #3). Same bounds as `vietnam-map-fidelity` — no new georeferencing.

---

### Case: Every checkpoint projects on-canvas (normalized 0..1) with no clamping firing
**ID:** PC-915
**Priority:** P1
**Type:** edge
**Covers:** AC-7

Given `EquirectangularBounds.project` (the shipped closed-form projection) and the 34 checkpoint lat/longs
When each checkpoint is projected to the normalized frame
Then every normalized `(x, y)` falls strictly within `[0, 1]` (on-canvas, never off-frame) and the projection's out-of-bounds clamp never fires for any real checkpoint — the 34 units sit well inside the map frame

**Notes:** Pure unit test on the projection (`equirectangular_projection.dart`). Reuses the shipped bounds; asserts the new 34 coords are all inside the frame (a coordinate outside would clamp to an edge and land wrong).

---

### Sub-chain route authoring over the 34-unit spine (AC-8)

### Case: A user-authored start/end/stop sub-chain derives a valid ProvinceChain
**ID:** PC-916
**Priority:** P0
**Type:** happy-path
**Covers:** AC-8

Given ADR-0005 sub-chain route authoring over the 34-unit spine
When a user picks a start, an end, and intermediate stops
Then the derived sub-chain is a valid `ProvinceChain` — ordered, no duplicate ids, exactly n−1 strictly-positive segments whose sum equals the sub-chain's own total — built by the unchanged `RoutePlanner` over the new full chain/geography

**Notes:** Pure unit test via `RoutePlanner.resolve` / `fromOrderedIds` over `vietnamProvinceChain`/`vietnamProvinceGeography`. Asserts the authoring model migrates onto the 34-unit spine unchanged (no reinvention).

---

### Case: Sub-chain lifecycle active/completed/abandoned behaves as before (BR-10)
**ID:** PC-917
**Priority:** P1
**Type:** edge
**Covers:** AC-8

Given a derived sub-chain over the 34-unit spine and a `RoutePlan` with each lifecycle value
When the plan transitions active → completed (reaches its end, fires celebration) and active → abandoned (silent restart over the never-reset cumulative)
Then the lifecycle behaves per BR-10 exactly as on the shipped spine — completion latches and retains progress; abandon is a distinct terminal state with no celebration — and the enum round-trips by name

**Notes:** Unit test reusing `route_plan_test.dart` patterns over the new production chain. BR-10 mechanism is unchanged — assert it still holds with the new geometry.

---

### Case: Authoring rejects invalid picks over the new spine (start==end, unknown id)
**ID:** PC-918
**Priority:** P1
**Type:** negative
**Covers:** AC-8

Given the route planner over the 34-unit chain
When a pick violates a guard — start equals end, or an id not in the chain, or fewer than two ids
Then it throws `ArgumentError` (authoring guards unchanged), so a malformed sub-chain fails loudly at authoring, not silently at paint

**Notes:** Pure unit test. Confirms the shipped `RoutePlanner`/`ProvinceChain` guards still fire against the rebuilt chain (no regression in the loud-failure contract).

---

### Migration by reset (AC-9)

### Case: A legacy retired-id RoutePlan forward-migrates by reset to a fresh full-spine active plan
**ID:** PC-919
**Priority:** P0
**Type:** happy-path
**Covers:** AC-9

Given a persisted `RoutePlan` (or legacy `RouteSelection`) whose `orderedNodeIds` use retired pre-2025 / 13-node province ids (e.g. `mui_ca_mau`, `sa_pa`, `ha_giang`)
When the app loads it after the upgrade to the 34-unit chain
Then it never crashes and forward-migrates **by reset** — a clean fresh **full-spine active** plan over all 34 units, stamped at the current engine cumulative distance — rather than an id-remap

**Notes:** Integration/unit test over `SharedPreferencesRouteRepository.loadPlan`. **This asserts NEW behaviour:** the shipped `_tryDecodePlan` currently catches the retired-id `ArgumentError` and returns `null` (drops the plan). AC-9 requires an active reset plan stamped at the current cumulative — the implementer must add this path. Confirm where "current engine cumulative" is read at load.

---

### Case: The user's cumulative/lifetime distance survives the migration intact
**ID:** PC-920
**Priority:** P0
**Type:** edge
**Covers:** AC-9

Given an in-progress journey with a known engine cumulative/lifetime distance and a legacy retired-id plan
When the upgrade migrates the plan by reset
Then the cumulative/lifetime distance is preserved intact (the engine's separate never-reset store is untouched — BR-8), and the fresh plan's `routeStartOffsetKm` is stamped at that current cumulative so the traveller resumes at the same lifetime distance, only re-based onto the new spine

**Notes:** Integration test asserting the engine's cumulative store is not reset/zeroed by the plan migration. Ties BR-8 (separate store). The plan's offset = current cumulative at reset.

---

### Case: A retired-id or corrupt blob never crashes startup
**ID:** PC-921
**Priority:** P1
**Type:** negative
**Covers:** AC-9

Given a persisted blob that is a retired-id plan, a malformed/corrupt plan, or an off-direction-tip legacy selection
When `loadPlan` runs at startup
Then it never throws to the app boot path — retired ids resolve to the reset full-spine plan, and a genuinely unreadable/corrupt blob degrades to "no saved route" (null) — startup always proceeds

**Notes:** Unit test over `loadPlan` decode paths. Distinguishes "retired but recognisable → reset" from "corrupt/undecodable → null". Existing `FormatException`/`ArgumentError`/`TypeError` catches must still prevent a boot crash.

---

### Case: Migration is a reset, not an id-remap — the traveller is never misplaced onto a wrong current unit
**ID:** PC-922
**Priority:** P1
**Type:** regression
**Covers:** AC-9

Given a legacy plan whose retired ids have no clean 1:1 mapping to the new 34 units (topology + total km changed wholesale)
When migration runs
Then the result is a fresh full-spine plan (start at the south tip, whole 34-unit spine) stamped at the current cumulative — NOT a nearest-unit id-remap that would drop the traveller at an arbitrary wrong province — so no silent misplacement occurs

**Notes:** Unit test asserting the migrated plan's `orderedNodeIds` are the full new spine (not a subset derived from remapped old ids). Guards the resolved Open-question ("never id-remap").

---

### Accrual-mechanism regression guard (AC-10)

### Case: Replaying the same active/idle inputs accrues distance and stats by the identical mechanism
**ID:** PC-923
**Priority:** P0
**Type:** regression
**Covers:** AC-10

Given the same recorded active-time and idle-time inputs replayed against the engine, once with the old rate and once with the rebuilt geometry's injected `kmPerActiveHour`
When distance-from-journey-time and stats-from-raw-active-time are accrued
Then they accrue by the byte-for-byte identical mechanism (BR-6 split preserved) — the only difference is the injected `kmPerActiveHour` value; distance scales linearly with the new rate while the active/idle classification and the raw-active-time stats are unchanged

**Notes:** Unit test over `JourneyEngine` injecting two different rates against the same input trace; assert distance scales exactly by the rate ratio and stats/streak (raw active time) are rate-independent. Confirms this is a config change, not an accrual change (ADR-0007 firewall).

---

### Case: The data change does not touch the active/idle classification or the distance/stats firewall
**ID:** PC-924
**Priority:** P1
**Type:** regression
**Covers:** AC-10

Given the engine firewall (ADR-0007 / BR-6) and the rebuilt geometry
When the engine's active-condition, idle threshold, grace, and distance-vs-raw-active-time split are exercised
Then they are unchanged — the geometry/config rebuild introduces no new active/idle decision, reads no new signal, and leaves the distance/stats boundary intact

**Notes:** Unit + static guard. Reuses the shipped engine/idle-accounting suites; assert they still pass unchanged against the new config. The firewall separation static test should not need edits (flag if it does).

---

### Canonical-km projection round-trip (AC-11)

### Case: A canonical distance d maps to the correct segment and interpolated coordinate on the 34-unit spine
**ID:** PC-925
**Priority:** P0
**Type:** happy-path
**Covers:** AC-11

Given the canonical-km projection (ADR-0004b) over the 34-unit spine
When a position at canonical distance `d` km is projected
Then it resolves to the correct chain leg (the one whose `[cumStart, cumEnd)` contains `d`) and the coordinate linearly interpolated between that leg's two checkpoint centres by the km-fraction — consistent with `RoutePolylineProjector.coordinateAt`

**Notes:** Pure unit test over `RoutePolylineProjector` with the new geography. Pick a `d` mid-leg and assert the leg index + interpolated coordinate. The projector's canonical-km axis is reused unchanged; assert it works over the 34-unit data.

---

### Case: Each of the 34 checkpoints round-trips checkpoint → cumulative km → coordinate to its seeded centre
**ID:** PC-926
**Priority:** P0
**Type:** edge
**Covers:** AC-11

Given each of the 34 checkpoints and its cumulative canonical km from the south tip
When that cumulative km is projected back to a coordinate
Then the result equals the checkpoint's seeded administrative-centre coordinate within tolerance for all 34 — the projection round-trips exactly at every node boundary

**Notes:** Pure unit test iterating all 34 nodes: `coordinateAt(cumulative(node)) == coordinateOf(node)`. Node boundaries are exact (fraction 0/1), so tolerance is tight (~1e-6°).

---

### Case: Canonical-km boundaries — d=0 is the south tip, d=total is the north tip, overshoot clamps
**ID:** PC-927
**Priority:** P1
**Type:** boundary
**Covers:** AC-11

Given the projection over the 34-unit spine
When `d = 0`, `d = totalChainKm`, `d < 0`, and `d > totalChainKm` are projected
Then `d=0` resolves to the south-tip centre, `d=totalChainKm` to the north-tip centre, and out-of-range values clamp to the nearest tip (no overshoot, no NaN, no wrap)

**Notes:** Pure unit test — the projector already clamps to `[0, routeLengthKm]`; assert it over the new total. Lower/upper boundary of the canonical-km axis.

---

### Non-functional

### Case: Chain build and canonical-km projection are computed once/memoized with no per-frame cost
**ID:** PC-928
**Priority:** P1
**Type:** nfr
**Covers:** NFR-1

Given the 34-unit chain build and the canonical-km→coordinate projection
When the build/projection paths are inspected and a redraw sweep is run
Then the chain + geography are built once (static constants) / the projector precomputes its cumulative-km + coordinate arrays once, nothing is re-parsed or re-allocated per frame, and render stays at parity with `vietnam-map-fidelity` frame timings

**Notes:** Static inspection + widget redraw guard (mirror `vietnam-map-fidelity` TC-820). The chain/geography are `final` top-level constants; the projector precomputes in its constructor. Real on-device fps is TC-M-NF1.

---

### Case: The rebuild introduces no new file/network read, no egress, and no location access
**ID:** PC-929
**Priority:** P0
**Type:** negative
**Covers:** NFR-2

Given the rebuilt chain/geography constants, the great-circle distance computation, and the migration path
When the slice's source and dependency set are inspected statically
Then it reads no new file or network, adds no new egress, and calls no geolocation/GPS/location API — every coordinate and bound is a static app-shipped constant (never a device read), keeping the model local-only within BR-1's aggregate-idle-only boundary

**Notes:** Static-inspection case (grep over the route/chain source + `pubspec`). The distances are computed from static coordinates (or precomputed constants), never a device position. The `/privacy-audit` PASS is the gate TC-M-PRIV — a fail blocks ship.

---

### Case: Any changed route-authoring picker over the 34 units stays keyboard + screen-reader accessible
**ID:** PC-930
**Priority:** P1
**Type:** nfr
**Covers:** NFR-3

Given any start/end/stop route-authoring UI adjusted to list the 34 units
When the widget tree's semantics and keyboard focus traversal are inspected
Then every picker control is keyboard-reachable (focusable + activatable) and carries meaningful semantic labels, with no regression from the shipped authoring flow — and if this slice changes no authoring UI, assert the existing pickers still expose semantics with the 34-unit data present

**Notes:** Widget test asserting `Semantics` labels + keyboard focusability over the expanded 34-unit list (a longer list must stay navigable). Real screen-reader/keyboard operation is TC-M-A11Y.

---

## Manual / on-device / audit legs (TC-M*)

These cannot be honest Dart tests. Run during `/execute-tests`, record per OS where applicable. Windows runtime legs
are **DEFERRED — required before any Windows release** (precedent: `vietnam-map-fidelity`, `map-experience`).

### TC-M-GEO — Visual: the 34-unit spine reads as one coast-hugging S→N line on land (P0, visual)
Covers AC-5, AC-7 (the exact-placement verdict the landmass ray-cast cannot fully settle). Automated companions:
PC-909, PC-910, PC-914. This is the carried `vietnam-map-fidelity` TC-M-GEO leg, now over the resolved spine.

Steps (rendered base, full map + minimap): confirm the spine draws as one continuous coast-hugging line from the
southern tip (Cà Mau) to the northern terminus with **no leg cutting across a bay or open sea** — pay special
attention to the four legs the old route clipped (near Vinh↔Ninh Bình, Huế↔Vinh, the Mekong-delta south, and the
south-central coast). Confirm all 34 checkpoints sit visually on their true admin centres, never offshore.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M-NF1 — No frame regression with the 34-unit spine (P1, device)
Covers NFR-1. Deterministic guard: PC-928. Open the map + minimap on a real build; confirm no visible jank and no
per-frame regression vs the `vietnam-map-fidelity` baseline with the larger 34-unit spine present.

- macOS: Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (DEFERRED): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M-A11Y — Route-authoring picker over 34 units is AT-operable (P1, AT)
Covers NFR-3. Automated leg: PC-930. With VoiceOver (macOS) / Narrator (Windows) then keyboard-only, confirm the
start/end/stop pickers over the 34 units are announced with meaningful names, reachable by Tab, activatable by Enter,
and the longer list stays navigable.

- macOS (VoiceOver + keyboard): Pass [ ]  Fail [ ]  Blocked [ ]
- Windows (Narrator + keyboard, DEFERRED): Pass [ ]  Fail [ ]  Blocked [ ]

### TC-M-PRIV — Privacy audit: data-only rebuild adds no egress, no location read (P0, audit) — **GATING**
Covers NFR-2. **Ship-blocker.** Static reinforcement: PC-929. Run `/privacy-audit` over the slice: confirm the new
coordinate tables / distance computation / migration add no new location/GPS read and no new network dependency (the
coordinates are static app-shipped reference data), and runtime egress is unchanged from the shipped baseline
(BR-1 / BR-11). A contradiction fails NFR-2 and blocks ship regardless of every other pass.

- Audit verdict (source-level): Pass [ ]  Fail [ ]  Blocked [ ]
- Runtime egress verdict: macOS Pass [ ]  Fail [ ]  Blocked [ ]   Windows Pass [ ]  Fail [ ]  Blocked [ ] (DEFERRED)
- Auditor / date: `__________`

---

## Coverage table (AC / NFR → covering case IDs)

| Item | Description (paraphrased) | Covered by |
|---|---|---|
| AC-1 | Exactly 34 unique checkpoints, one per dataset unit | PC-901, PC-902 |
| AC-2 | Endpoints = lat extremes; 33 strictly-positive segments summing to total | PC-903, PC-904 |
| AC-3 | Each segment = haversine within ±1%/≤1 km; total = sum of 33 | PC-905, PC-906 |
| AC-4 | `kmPerActiveHour = totalChainKm/8`; no hardcoded 2000/250 literal | PC-907, PC-908 |
| AC-5 | Dense spine (≥20 pts/seg) all on land — carried limitation resolved | PC-909, PC-910, PC-911, TC-M-GEO |
| AC-6 | 7 relocated units at admin-centre coord, not nominal territory | PC-912, PC-913 |
| AC-7 | All 34 project on land + on-canvas under fixed bounds | PC-914, PC-915, TC-M-GEO |
| AC-8 | Sub-chain authoring valid + lifecycle per BR-10 | PC-916, PC-917, PC-918 |
| AC-9 | Legacy retired-id plan → migrate-by-reset, no crash, cumulative preserved | PC-919, PC-920, PC-921, PC-922 |
| AC-10 | Replay → identical accrual mechanism; only injected rate differs | PC-923, PC-924 |
| AC-11 | Canonical-km `d` → correct segment/coord; checkpoint round-trips | PC-925, PC-926, PC-927 |
| NFR-1 | Build + projection once/memoized; no per-frame cost; render parity | PC-928, TC-M-NF1 |
| NFR-2 (gating) | No new file/network read, no egress, no location; local-only | PC-929, TC-M-PRIV |
| NFR-3 | Changed authoring picker keyboard + screen-reader; no regression | PC-930, TC-M-A11Y |

Every AC (AC-1..AC-11) and every NFR (NFR-1..NFR-3) maps to at least one case. No AC is orphaned. The `test-script-author`
must update the shipped old-model tests listed in the **Regression risk** section in lockstep — that is the top ledger
risk for this slice.
