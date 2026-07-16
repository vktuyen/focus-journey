# ADR-0009: Journey province/route data model on Vietnam's current 34 units — great-circle distances, curated coast-hugging spine, plan-migration-by-reset

- Status: accepted
- Date: 2026-07-15
- Deciders: Kevin (Tuyen Vo) / system-architect

## Context

> This ADR **amends ADR-0004(b)** — it changes the *source* of the canonical-km chain (derived
> great-circle distances instead of hand-authored stylized literals) while **preserving that decision's
> single canonical-km projection axis unchanged**. It also **amends ADR-0005's migration clause** — the
> legacy-`RouteSelection`→`RoutePlan` "reconstruct the same sub-path" rule is replaced by
> **migrate-by-reset** for this wholesale topology change. It **builds on** ADR-0008 (the bundled,
> georeferenced 34-province GeoJSON base map + `BaseMapGeometry.containsLandmass`, which the no-sea-crossing
> test samples) and does **not** touch ADR-0007's engine firewall / BR-6 (this is a geometry/config change,
> not an accrual change). ADR-0004 should be tagged **amended-by-0009** (b); ADR-0005's migration clause
> **amended-by-0009**.

The `province-chain-2026` slice (slice 2 of the Vietnam-2026 pair; sibling `vietnam-map-fidelity` ✅ shipped)
rebuilds the journey's province/route **data model**. `vietnam-map-fidelity` already made the *map* show
Vietnam's current 34 administrative units (2026), but the `ProvinceChain` / `ProvinceGeography` / distances
still encode the pre-2025 ~13-checkpoint stylized spine — so the map and the journey disagree about what
Vietnam is. This slice also owns the limitation carried from `vietnam-map-fidelity` AC-5: straight-line route
segments that clip coastal bays on the now-accurate coastline.

The spec (AC-1..AC-11, NFR-1..3; Open questions all RESOLVED 2026-07-15 at framing) fixes the shape. The
gating forces:

- **Real 2026 geography (AC-1/AC-2/AC-6/AC-7).** The model must carry exactly the **34 current units**
  (6 municipalities + 28 provinces, effective 1 July 2025) at their **administrative-centre** WGS84
  coordinates. **7 units have relocated centres** (the admin centre now sits in a former partner province):
  Lào Cai→Yên Bái, Bắc Ninh→Bắc Giang, Quảng Trị→Đồng Hới, Gia Lai→Quy Nhơn (coastal), Tây Ninh→Tân An,
  Đồng Tháp→Mỹ Tho, An Giang→Rạch Giá — these must be honoured because they change **both** the coast-hugging
  order and the segment distances.
- **Route stays on land (AC-5).** No inter-unit segment may cross open sea on the shipped 34-province map —
  resolving the carried `vietnam-map-fidelity` AC-5.
- **Engine firewall (AC-4/AC-10, BR-6, ADR-0007).** `kmPerActiveHour` re-derives from the new total, but the
  accrual mechanism stays byte-for-byte the same — a full traversal still takes ≈8 active hours.
- **No lost progress on upgrade (AC-9, BR-8).** A persisted route referencing retired pre-2025/13-node ids
  must never crash and must not silently drop the user's lifetime distance.
- **No new egress / location read (NFR-2, BR-1).** Names + coordinates are static app-shipped reference data.

All five decisions below were **settled at framing** (spec Open questions, RESOLVED 2026-07-15); this ADR
records them as the rules an implementer follows — it does not re-open them.

## Decision

**Rebuild the journey data model onto Vietnam's current 34 units at their administrative-centre coordinates,
derive segment distances as great-circle (haversine) lengths, bake a single hand-curated coast-hugging
south→north spine proven correct by an automated no-sea-crossing test, and forward-migrate any persisted
legacy plan by reset onto the new spine — all while ADR-0004(b)'s canonical-km axis and ADR-0007/BR-6's
accrual firewall stay intact.**

### (a) 34-unit dataset (2026) as static app-shipped reference data — RATIFIED.

`province_geography.dart` + `province_chain.dart` are rebuilt from the sourced dataset (spec "Sourced 34-unit
dataset"): the **34 current units** (6 municipalities + 28 provinces), each with a unique id, its name, and its
**administrative-centre** WGS84 coordinate (AC-1). The **7 relocated centres** are seeded at their admin-centre
coordinate, **not** their nominal territory centroid (AC-6): Lào Cai→Yên Bái, Bắc Ninh→Bắc Giang,
Quảng Trị→Đồng Hới, Gia Lai→Quy Nhơn (coastal ≈13.782/109.219), Tây Ninh→Tân An, Đồng Tháp→Mỹ Tho,
An Giang→Rạch Giá (≈10.012/105.081). This is static reference data (no device location, no network — NFR-2 /
BR-1), and it replaces the pre-2025 ~13-checkpoint dataset wholesale.

### (b) Great-circle (haversine) auto-distances — AMENDS ADR-0004(b).

Segment distances are computed as the **great-circle (haversine, mean Earth radius 6371 km) distance** between
consecutive administrative-centre coordinates (AC-3), **not** hand-authored stylized literals. `totalChainKm`
becomes the sum of the 33 great-circle segments (~2500–3500 km vs the old locked ~2000). This **amends
ADR-0004(b)**: only the *source* of the canonical-km chain changes (derived great-circle instead of literal);
ADR-0004(b)'s **single canonical-km projection axis is preserved unchanged** — `RoutePolylineProjector`,
`RouteProgressResolver`, and `IdleTraceMapper` still run over one distance axis and one geography model
(AC-11). `kmPerActiveHour = totalChainKm / 8` **re-derives** from the new total (already wired at
`main.dart:597`; no hardcoded 2000 km / 250 km-per-hour literal remains — AC-4), so a full traversal still
takes ≈8 active hours. The engine's accrual mechanism is **byte-for-byte unchanged** — the ADR-0007 firewall /
BR-6 holds: this is a geometry/config change delivered as injected rate, not an accrual change (AC-10).

### (c) Hand-curated coast-hugging spine + automated no-sea-crossing test — RATIFIED.

The 34 units are ordered south→north into **one canonical coast-hugging spine baked into
`province_chain.dart`**. There are **no synthetic non-unit waypoints** — the chain's `nodes` stay **exactly**
the 34 units. Correctness is enforced by an **automated test** that densely samples every segment (≥20
interpolated points per segment) against `BaseMapGeometry.containsLandmass` (ADR-0008's real bundled 34-province
geometry): every sampled point must fall on land (AC-5). This **resolves** the limitation carried from
`vietnam-map-fidelity` AC-5 (straight-line segments clipping coastal bays).

A discovered sea-crossing is cleared by the following **precedence order**:

1. **Prefer re-ordering the 34 units.** Thread an inland unit between the two coastal units so the chords stay
   landward. This is always the first move.
2. **Bounded coast-alignment offset — permitted where re-ordering cannot clear the bay.** ADR-0008's bundled
   coastline is a **generalized / decimated** outline: it omits real peninsulas and bay detail (e.g. Hạ Long
   bay), so a straight great-circle chord between two **true** coastal administrative-centre coordinates can
   dip into the simplified "sea" even though the real land is continuous. For adjacent coastal units with no
   inland unit to thread between them, re-ordering cannot fix this. In that case a **coast-alignment offset
   ≤ 0.1° (~10 km)** applied to the affected **non-relocated** coastal checkpoint is permitted to keep its
   chords landward of the generalized coastline, provided it is (a) the **minimum** offset that clears the
   bay, (b) **documented per-unit in `vietnam_units_2026.dart`** with the reason, and (c) **guarded by a
   golden coordinate-table test** so every shipped coordinate is explicit and diff-reviewable. This is the
   same device as the already-shipped sub-km `mui_ca_mau` nudge, now generalized and bounded. The offset
   compensates for **map generalization, not geography** — the seeded value is deliberately moved off the true
   admin centre only to stay on the simplified land polygon. The **7 relocated administrative centres carry
   NO offset** — they are seeded exactly at their admin-centre coordinate (decision (a)/AC-6).
3. **Synthetic non-unit waypoints remain forbidden.** The chain's `nodes` stay **exactly** the 34 units; a bay
   is never cleared by inserting a node that is not one of the 34 units.

**Known limitation / accepted residual — `quảng_trị → hà_tĩnh` (Kevin's ruling 2026-07-15).** After
minimizing, 7 of 8 offsets fell under the 0.1° cap; one did not. The Đồng Hới→Hà Tĩnh chord clips a
generalized-coastline notch at ~(17.75, 106.39) right at Đồng Hới's northward departure. Quảng Trị is a
relocated centre (exact, cannot move — decision (a)/AC-6), and Hà Tĩnh would need ~0.114° (~12 km) to fully
clear it — **over the cap**. The ruling: **Hà Tĩnh stays exact at its true admin centre and the residual is
accepted — the 0.1° cap is a hard rule and is NOT lifted, even to reach a full AC-5 pass.** Rationale: this is
a coastline-decimation artifact (the real land is continuous there), not a genuine sea crossing. The dense
no-sea-crossing guard **pins this one segment's residual to ≤3 sampled points**; every other segment is 100%
on land. A future base-map asset-densification follow-up could close it fully.

The order is deliberately **not a pure latitude sort** — it threads inland units (Điện Biên, Sơn La, Đắk Lắk,
Lâm Đồng, …) sensibly so the path stays a coherent landline. The invariants asserted structurally are therefore
the **endpoints + segment shape** (AC-2): index 0 = the south tip (Cà Mau / Tân Thành at lat ≈9.177), last =
the max-latitude northern unit, exactly **33 strictly-positive segments** summing to `totalChainKm` within
`_sumTolerance`. **Ordering-correctness itself is proven by the no-sea-crossing test**, not by a monotonic-lat
assertion (which the inland threading would violate).

### (d) Plan-migration-by-reset — AMENDS ADR-0005's migration clause.

A persisted `RoutePlan` (or legacy `RouteSelection`) referencing retired pre-2025 / 13-node province ids
forward-migrates **by reset**: on load it becomes a **fresh full-spine active plan over all 34 units**, stamped
at the **current engine cumulative distance** (`routeStartOffsetKm = current cumulative`) — **never** an
id-remap (AC-9). This **amends ADR-0005's migration clause** (whose "reconstruct the same sub-path from the
legacy start/direction" rule assumed a stable topology): here the topology **and** the total km changed
wholesale, so any id-remap or sub-path reconstruction would misplace the traveller. The engine's separate
**never-reset cumulative/lifetime store (BR-8) is untouched**, so the traveller resumes at the **same lifetime
distance re-based onto the new spine** — no crash, no lost progress. Existing corrupt-safe decoders already
catch retired-id `ArgumentError`s and degrade to "no saved route"; the reset path sits on top of that
never-crash contract.

### (e) Enum-name stability — RATIFIED.

`JourneyDirection.towardHaGiang` / `towardMuiCaMau` and `southTip` / `northTip` are kept as stable **symbolic**
labels (persisted-by-name). The north-terminus *identity* changed — Hà Giang is now within Tuyên Quang — but
the **enum label stays**, so there is **no persisted-enum migration**; this is a doc-comment / UI-label update
only. Keeping the names avoids a needless serialization break for a value whose role (the "toward the northern
tip" direction) is unchanged.

## Consequences

- **Easier / gained.** The map and the journey finally agree on what Vietnam is — one 34-unit model behind
  both. Distances are now real geography (auto-derived, no hand-tuned literals to drift), and every checkpoint
  lands on its true georeferenced coordinate on the shipped base map (AC-7) — except the small, bounded,
  documented set of coastal checkpoints carrying a coast-alignment offset (decision (c)). The route provably
  hugs the coast
  (the no-sea-crossing test makes AC-5 a regression guard, resolving the carried limitation). ADR-0005's
  sub-chain route authoring keeps working over the new spine (AC-8) because the sub-chain still derives
  structurally from `(chain, geography, start, direction)`.
- **Preserved.** ADR-0004(b)'s single canonical-km projection axis, `RoutePolylineProjector`,
  `RouteProgressResolver`, and `IdleTraceMapper` are untouched (only the chain's *values* change — AC-11). The
  ADR-0007 / BR-6 engine firewall holds: accrual is byte-for-byte identical, only injected `kmPerActiveHour`
  differs (AC-4/AC-10). Privacy/offline posture is unchanged — static reference coordinates only, no new
  reads/egress/location (NFR-2 / BR-1). The user's lifetime distance survives the upgrade (BR-8).
- **Harder / new obligations.**
  - The **hand-curated spine order** is now an artifact to maintain, guarded by the no-sea-crossing test — any
    future dataset/coordinate change must re-run and re-satisfy that test (a sea-crossing is cleared by the
    decision (c) precedence: re-order first, else a bounded ≤0.1° coast-alignment offset on a non-relocated
    coastal checkpoint, never a synthetic waypoint).
  - **Coast-alignment offsets are shipped coordinate state.** Each offset must be the minimum that clears its
    bay, documented per-unit in `vietnam_units_2026.dart`, and pinned by the golden coordinate-table test — so
    every offset is explicit and diff-reviewable rather than an unexplained magic number.
  - **Coordinate accuracy** (esp. the 7 relocated centres and the `approx` points) directly determines both the
    spine order and the total km; the seeded values must be verified at build.
  - **Displayed distances grow** (~2500–3500 km vs 2000). This is intentional and correctness-neutral (pacing
    stays ≈8 active hours via the re-derived rate); only a playtest note on relative leg-length *feel* remains.
  - **Migrate-by-reset is lossy for the authored sub-chain** (see trade-off) — the implementer must reset to the
    full spine, not attempt an id-remap.
- **Trade-off accepted (coast-alignment offset).** An offset checkpoint renders and measures from a point up to
  ~10 km (≤0.1°) inland of its true administrative centre. This is an accepted, bounded, tested deviation: it is
  the minimum needed to keep the chords on the *generalized* land polygon, it is documented per-unit, and the
  golden coordinate-table test makes every shipped coordinate explicit. The 7 relocated centres carry no offset.
- **Trade-off accepted.** On upgrade, an in-flight **authored sub-chain** (a custom start/end/stops route) is
  **not preserved as a route** — it resets to a fresh full-spine plan. This is deliberate: the topology + total
  km changed wholesale, so remapping retired ids onto the new 34-unit spine would misplace the traveller. The
  thing that actually matters — the user's **cumulative/lifetime distance** — is preserved intact (BR-8), and the
  full-spine reset is stamped at that current cumulative, so the traveller resumes coherently on the new model.

## Alternatives considered

### Keep the stylized ~2000 km hand-authored `segmentsKm` literals
Rejected. Now that checkpoints carry real 2026 administrative-centre coordinates (ADR-0008's georeferenced
base), keeping stylized literals would leave the on-map leg lengths and the chain km arbitrarily disconnected
across 34 units and 33 legs — impossible to author consistently by hand and drift-prone. Great-circle derivation
gives one self-consistent source; the ≈8-hour pacing is preserved by re-deriving `kmPerActiveHour` from the new
total, so nothing about the engine contract is lost (only the chain's *source*, not its axis, changes).

### Re-derive distances from GeoJSON polygon geometry (polygon perimeters / centroids)
Rejected — same reasoning as ADR-0004(b)/ADR-0008. The base map's polygons are a **visual** layer and must not
become a second source of "where am I on the route." Great-circle between the seeded administrative-centre
points is the single, deterministic, framework-free distance source; the polygons only host the
land/sea-crossing check.

### Order the spine by pure latitude sort
Rejected. A pure south→north latitude sort would zig-zag between the coast and the inland highlands (Điện Biên,
Sơn La, Đắk Lắk, Lâm Đồng), producing segments that cut across the sea or across the country — failing AC-5.
The hand-curated coast-hugging order threads the inland units into a coherent landline; its correctness is
proven by the no-sea-crossing test, which a lat sort could not pass.

### Add synthetic non-unit waypoints to bend segments around bays
Rejected. Injecting non-unit waypoints would make `nodes` no longer "exactly the 34 units," breaking AC-1's
"one per current unit, no extra" invariant and polluting the checkpoint set that route authoring (ADR-0005)
and the map pins consume. Where re-ordering the 34 real units cannot clear a bay (because the generalized
coastline omits real land), the sanctioned fix is a bounded ≤0.1° coast-alignment offset on the affected
non-relocated coastal checkpoint (decision (c)), which keeps `nodes` exactly the 34 units — not a synthetic
node.

### Forward-migrate a persisted plan by id-remap (map each retired id to the nearest current unit)
Rejected. The 2025 reorganization merged/renamed units and moved administrative centres, and the total km
changed wholesale — a nearest-unit remap would place the traveller on segments that no longer exist and at a
route fraction that no longer means what it did. Reset-to-full-spine (stamped at the current engine cumulative)
is the only migration that never misplaces the traveller, and it preserves the one durable quantity that
matters — lifetime distance (BR-8).

### Rename the direction/tip enums to the new north-terminus identity
Rejected. `JourneyDirection` / tip enums persist **by name**; renaming them would force a persisted-enum
migration for zero behavioural gain — the "toward the northern tip" role is unchanged even though Hà Giang now
sits within Tuyên Quang. Keeping the symbolic labels (doc-comment/UI-label refresh only) avoids a gratuitous
serialization break.

## References

- Spec: `specs/province-chain-2026/spec.md` — AC-1..AC-11, NFR-1..3, and the RESOLVED Open questions (the
  four candidate decisions this ADR ratifies) + the sourced 34-unit dataset.
- ADR-0004(b) — canonical-km distance→polyline projection (**amended by this ADR**: derived great-circle
  source, axis preserved).
- ADR-0005 — custom routes via derived sub-chains; its migration clause is **amended by this ADR**
  (migrate-by-reset).
- ADR-0007 — engine firewall / cosmetic-only boundary (BR-6): accrual mechanism unchanged.
- ADR-0008 — bundled 34-province GeoJSON base map + `BaseMapGeometry.containsLandmass` (the no-sea-crossing
  test's land oracle).
- Domain rules: `docs/domain/business-rules.md` — BR-1 (privacy boundary), BR-6 (distance vs stats split),
  BR-8 (daily reset / cumulative persists), BR-10 (route lifecycle).
