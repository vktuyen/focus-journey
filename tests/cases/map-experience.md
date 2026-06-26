# Test cases: map-experience

Spec: [specs/map-experience/spec.md](../../specs/map-experience/spec.md)
Depends on (shipped): [specs/route-progress/spec.md](../../specs/route-progress/spec.md) — the province chain + position math (`routeDistanceKm`) this feature renders onto · [specs/idle-accounting/spec.md](../../specs/idle-accounting/spec.md) — the distance-keyed active/idle segment record this feature paints red.
Sibling cases: [route-progress.md](route-progress.md) · [idle-accounting.md](idle-accounting.md)
Manual / on-device companion: [map-experience-manual-checklist.md](map-experience-manual-checklist.md)
Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md)

## Coverage note

`map-experience` is a **pure visualizer**: it reads the shipped `idle-accounting` distance-keyed segment
record (`{start, end, classification, cause}`) and the shipped `route-progress` position math
(`position = f(routeDistanceKm)`), and renders them onto a real-Vietnam province polyline with the idle
spans painted red. It introduces **no** new idle judgement, **no** distance accrual, and (the gating
concern) **no** device-location/GPS surface. Per `docs/architecture/overview.md`, executable tests live
**inside** the Flutter package: pure mapping math + chain/geography data integrity → **unit** (`src/test/`);
overlay/full-screen widget behaviour + the red-trace painter + keyboard/semantics → **widget/golden**
(`src/test/`); Bloc↔overlay wiring + restart restoration → **integration** (`src/integration_test/`);
real-OS tile fetch, offline fallback on a real network stack, ≥30fps, screen-reader, and the privacy audit
→ **manual / on-device** (see the companion checklist). `tests/cases/` (this file) holds only the
human-readable Given/When/Then; no executable test is placed under the top-level `tests/` tree.

**Automation status (widget + integration layer — authored by `test-script-author`, 2026-06-24).**
The widget/UI/wiring scenarios are automated and **all pass** under `fvm flutter test`. A fake/offline
`TileProvider` is injected into every map surface, so no test ever reaches the network. Files (all inside
the Flutter package, per `docs/architecture/overview.md`):
- `src/focus_journey/test/features/route/map_test_fixtures.dart` — shared geography fixture + the
  `FakeTileProvider` network seam + helpers (no executable cases itself).
- `src/focus_journey/test/features/route/presentation/map_view_test.dart` — TC-224/TC-213/TC-216/TC-225
  (behavioural, see below)/TC-217/TC-218/TC-219 (AC-6/AC-7/AC-9/AC-10/AC-11/NFR-3).
- `src/focus_journey/test/features/route/presentation/map_surface_test.dart` — TC-220/TC-221/TC-222/TC-223,
  the re-homed picker + celebration, and TC-231 (AC-1/AC-2/AC-3/NFR-2).
- `src/focus_journey/integration_test/map_experience_wiring_test.dart` — TC-215, TC-222 (no-new-window),
  TC-226/TC-228 (AC-8/AC-2/AC-12).
The pure-Dart mapping/geography/cubit math (TC-201..TC-214, TC-227/TC-230) is the `unit-test-writer`'s
layer (`src/test/.../domain/`, `map_cubit_test.dart`) — not duplicated here. **TC-225 golden is DEFERRED**
(project-wide golden deferral precedent: `journey-view` / `local-stats` TC-NF4); the solid-vs-dashed
non-colour cue is asserted **behaviourally** instead in `map_view_test.dart` (TC-216 — same red colour,
distinct `StrokePattern`). All TC-M* legs remain manual / on-device (companion checklist).

The **genuinely novel, deterministic algorithm** flagged in the spec's Open questions is the
**distance-keyed idle segment → polyline geometry mapping** (an idle span `[start, end)` in
route-distance-km → the exact polyline stretch to paint red, correct across province boundaries and road
curves). That mapping is the heart of this suite and is fully **unit-testable** against the rule
(TC-201..TC-208).

Layer → AC mapping:

| AC / NFR | What it asserts | Covering layer(s) | Cases |
| --- | --- | --- | --- |
| **AC-1** | Inline map overlay on the journey tab; no standalone Map tab | Widget | TC-220, TC-221 |
| **AC-2** | Tap → full-screen in the **same** window (no new OS window) | Widget + integration | TC-222 |
| **AC-3** | Dismiss → back to inline; journey tab still functional | Widget | TC-223 |
| **AC-4** | Provinces at **real lat/long**, road chained in order (country outline, not a straight line) | Unit (geography data) | TC-209, TC-210 |
| **AC-5** | Single geography model; marker placed via reused `routeDistanceKm` math | Unit + integration | TC-211, TC-212 |
| **AC-6** | Idle span painted red on the matching polyline stretch; active not red | Unit (mapping) + widget (paint) | TC-201, TC-202, TC-203, TC-204, TC-224 |
| **AC-7** | Zero-idle route draws no red | Unit + widget | TC-213 |
| **AC-8** | Current route only (offset/day-split); red trace restored unchanged after restart | Unit + integration | TC-214, TC-215 |
| **AC-9** | Voluntary vs lock/sleep both red, distinguished by a non-colour cue | Widget + golden + **manual (colour-blind perception)** | TC-216, TC-225 + TC-M3 |
| **AC-10** | Defined overlay states at start (km=0) / mid-route / completion | Unit + widget | TC-205, TC-206, TC-207, TC-217 |
| **AC-11** | Tiles via flutter_map+OSM **with attribution**; graceful offline fallback; tab never breaks | Widget (fake tile source) + **manual real-network** | TC-218, TC-219 + TC-M1, TC-M2 |
| **AC-12** | Pure visualizer — no re-classification, no accrual; toggle/remove leaves data unchanged | Unit + static + integration | TC-226, TC-227, TC-228 |
| **NFR-1** | ≥30fps, no jank, on macOS + Windows (incl. inline↔full-screen + max idle-segment count) | Static hot-path guards + **manual / device** | TC-229 + TC-M-NF1 |
| **NFR-2** (CRITICAL gate) | Only aggregate idle-duration→distance + static province lat/long; no GPS/location; tiles carry no user data; `/privacy-audit` PASS | Static inspection + **manual audit** | TC-230, TC-231 + TC-M-PRIV |
| **NFR-3** | Idle trace distinguishable beyond colour; toggle/dismiss keyboard-reachable + screen-reader labelled | Widget (semantics/keyboard) + **manual screen-reader** | TC-225, TC-232 + TC-M3, TC-M4 |

**Risky / under-covered areas (flagged for `test-script-author` and reviewers):**

1. **Real-OS tile fetch + offline fallback (AC-11) — the first network call this product has ever made.**
   The whole app has been fully offline to date; a tile fetch is genuinely new behaviour. The
   *fallback-selection logic* (network → tiles+attribution; no-network → cached, else static/blank base on
   which road+markers+red still render) is automatable against a **fake tile provider** that simulates
   success / timeout / error (TC-218, TC-219). But a **real** OSM round-trip, real OS timeout behaviour,
   real tile-cache eviction, and "the journey tab genuinely never blocks/errors on a flaky real network"
   can only be confirmed **on-device with real connectivity toggled** — see TC-M1 / TC-M2 in the manual
   checklist. **Highest-risk area.**
2. **NFR-2 privacy is the gating concern and is only partly automatable.** A static-inspection test can
   assert the slice imports **no** location/GPS API, that province lat/long is an app-shipped static
   constant (not a device read), and that the `flutter_map`/tile request URL template carries no
   identifier/location/idle data (TC-230, TC-231). But "this is the most location-suggestive surface ever
   shipped and adds zero tracking" and "`/privacy-audit` stays PASS" — including a **runtime socket /
   egress inspection** that the only outbound traffic is anonymous tile GETs with no user payload — is a
   **review/audit + on-device gate** (TC-M-PRIV), mirroring how `idle-accounting` TC-112 / `local-stats`
   TC-022 / `route-progress` TC-018 split the privacy promise. A fail here **blocks ship** regardless of
   every other pass.
3. **≥30fps on both desktops (NFR-1) is not deterministically unit-assertable.** We can statically guard
   the paint hot path (no per-frame re-allocation of the static polyline/geography; `shouldRepaint`
   correct; bounded red-trace segment objects) — TC-229 — and load the **maximum expected idle-segment
   count**, but real frame timing during the inline↔full-screen transition with live tiles must be
   measured **on-device per OS** (TC-M-NF1), consistent with the `journey-view` / `journey-scene-v2` fps
   deferrals. Windows on-device legs are **DEFERRED — required before any Windows release**.
4. **Accessibility / colour-blind perception (NFR-3 / AC-9).** The non-colour cue (e.g. solid-vs-hatched
   red) and the keyboard/semantics of the toggle+dismiss are widget-assertable (TC-225, TC-232), but
   whether a colour-blind user can actually *perceive idle stretches and tell causes apart*, and whether a
   **real screen reader** announces the controls usefully, is a **manual perceptual/AT review** (TC-M3,
   TC-M4).

## Conventions used by these cases

- **Deterministic by construction for the automated layer.** The mapping cases are a **pure function**
  `idleSegments × chainGeometry × routeDistanceKm → paintedRedStretches` — no timers, no
  `DateTime.now()`, no I/O, no network. They reuse the `route-progress` deterministic distance source (a
  scriptable stub exposing a settable cumulative `distanceKm`) and a **fixture idle-segment list**
  (distance-keyed `{start, end, classification, cause}`), set directly per case. No case awaits real time
  or real network.
- **Reused upstream contracts (do NOT re-test here).** Active/idle classification, grace/threshold, the
  segment record's contiguity/merge/day-split/persistence, and the position-resolution walk
  (passed/next/%) are owned and tested by `idle-accounting` and `route-progress` respectively. These cases
  treat both as **given inputs** and assert only the *visualization* layered on top. Where a case relies on
  an upstream invariant (e.g. day-split, persisted `idleSince`) it names the upstream case it leans on.
- **Fixture chain & geometry (structure, not literals).** Reuse the `route-progress` fixture chain
  (`Mũi Cà Mau ─60→ Cần Thơ ─170→ Đà Lạt ─300→ Đà Nẵng ─310→ Hà Nội ─600→ Hà Giang`, total 1440 km in the
  fixture; production `totalChainKm ≈ 2000`). For `map-experience` each node additionally carries a
  **static lat/long**; the road polyline is the chain of inter-node geodesic/arc-length segments. Cases key
  off the *structure* — ordered nodes, positive segment lengths, monotone cumulative-km along the
  polyline — NOT the literal numbers, so they survive re-tuning to the curated production chain.
- **The mapping rule (unit under test).** An idle segment with route-distance span `[start, end)` maps to
  the **contiguous polyline stretch** between the point at arc-length `start` and the point at arc-length
  `end` along the road, where arc-length is measured the **same way** `route-progress` measures
  `routeDistanceKm` (so distance→polyline is consistent with distance→marker). A span that crosses a
  checkpoint/province boundary maps to a stretch spanning that boundary; a span on a curved leg follows the
  curve. `[start, end)` is half-open and consistent with the segment record's contiguity (a shared endpoint
  belongs to exactly one stretch — `route-progress` TC-114 / `idle-accounting` TC-114 boundary-ownership).
- **Tolerances.** Distance/arc-length equality within **±1e-6 km**; a painted point's position equality
  within ±1e-6 of the resolved polyline point. Pixel/golden frames tolerate the documented per-OS font/AA
  variance (goldens are pinned for *structure*, not exact pixels).
- **Test layer.** Per `docs/architecture/overview.md`: unit/widget/golden under `src/test/`, integration
  under `src/integration_test/`, run with `flutter test` / `flutter test integration_test/`. A note marks
  any case whose only honest verification is **manual / on-device / audit** and points to the companion
  checklist.

## Cases

### Case: Single idle segment maps to the matching polyline stretch (core mapping happy path)
**ID:** TC-201
**Priority:** P0
**Type:** happy-path
**Covers:** AC-6

Given the fixture chain with lat/long geometry, `routeStartOffset = 0`, and one recorded idle segment with span `[start, end)` lying wholly within a single straight leg (fixture: idle from 80 km to 120 km, inside the Đà Lạt→Đà Nẵng leg)
When the mapping function resolves which polyline stretch to paint red
Then exactly one red stretch is produced, beginning at the polyline point at arc-length `start` and ending at the point at arc-length `end` (within ±1e-6), and **no** other stretch (no active span) is marked red

**Notes:** Pure-function unit test (`src/test/`). Assert the red stretch's endpoints equal the `route-progress` position-resolution for the same arc-lengths (mapping is consistent with the marker math). The worked fixture numbers are illustration; assert against the arc-length rule.

---

### Case: Idle segment spanning a province/checkpoint boundary lands on the correct road stretch (continuous, not clipped)
**ID:** TC-202
**Priority:** P0
**Type:** edge
**Covers:** AC-6

Given an idle segment whose span **crosses a checkpoint boundary** (fixture: idle from 150 km to 260 km, which crosses the Đà Lạt node at cumulative 230 km — i.e. spans the Cần Thơ→Đà Lạt and Đà Lạt→Đà Nẵng legs)
When the mapping resolves the red stretch
Then a **single contiguous** red stretch is drawn that runs across the boundary node — it covers the tail of the first leg AND the head of the next leg, passing through the checkpoint point — with no gap, no clipping at the node, and no duplication of the boundary point

**Notes:** Pure-function unit test (`src/test/`). The genuinely novel case: distance→geometry across a boundary. Assert the stretch's polyline vertex list includes the boundary node's lat/long as an interior point and that arc-length(stretch) == `end − start`.

---

### Case: Idle segment on a curved leg follows the road curve (not a straight chord)
**ID:** TC-203
**Priority:** P0
**Type:** edge
**Covers:** AC-6, AC-4

Given a leg whose polyline has intermediate curve vertices (real-geography legs are not straight chords) and an idle segment whose span lies within that curved leg
When the mapping resolves the red stretch
Then the red stretch **follows the road's curve** — it includes the intermediate curve vertices that fall within `[start, end)` (it traces the same vertices the base road draws over that arc-length window), not a straight chord between the span's endpoints

**Notes:** Pure-function unit test (`src/test/`). Requires a fixture leg with ≥1 interior vertex. Assert the red vertex list is a sub-path of the base road vertex list over the same arc-length window. Guards against a "draw a line from A to B" shortcut that would mis-place red on a curved real-Vietnam leg.

---

### Case: Multiple non-contiguous idle segments produce multiple separate red stretches; active gaps stay unpainted
**ID:** TC-204
**Priority:** P0
**Type:** edge
**Covers:** AC-6

Given a current route with **several non-contiguous** idle segments separated by active spans (fixture: idle [40,60), active [60,200), idle [200,230), active [230,400), idle [400,420))
When the mapping resolves the red stretches
Then it produces **exactly three** disjoint red stretches matching the three idle spans, the intervening active spans are **not** red, and the red stretches do not bleed into or merge across the active gaps

**Notes:** Pure-function unit test (`src/test/`). Assert count == number of idle segments and that each red stretch's arc-length span equals its source segment's `[start, end)`; assert no red point falls within an active span.

---

### Case: Idle segment at the very start of the route (distance 0)
**ID:** TC-205
**Priority:** P0
**Type:** boundary
**Covers:** AC-6, AC-10

Given an idle segment whose span begins at `start = 0` (the route origin — the user went idle immediately) — fixture: idle [0, 30)
When the mapping resolves the red stretch
Then the red stretch begins exactly at the **start province pin** (the polyline origin) and extends to arc-length 30, with no underflow, no negative arc-length, and no red drawn "before" the origin

**Notes:** Pure-function unit test (`src/test/`). Lower boundary of the mapping. Pairs with the `route-progress` km=0 start state (TC-002 there). Assert the stretch's first point == origin node lat/long.

---

### Case: Idle segment at the route end / destination
**ID:** TC-206
**Priority:** P0
**Type:** boundary
**Covers:** AC-6, AC-10

Given a route at/near completion and an idle segment whose span ends at the destination tip's cumulative distance (fixture: a mid-chain route to Hà Giang at 1380 km, idle [1350, 1380))
When the mapping resolves the red stretch
Then the red stretch ends exactly at the **destination pin** (the resolved completion point), is clamped to the destination (no overshoot past the final pin, consistent with `route-progress` TC-012 clamping), and renders correctly alongside the completion/celebration state

**Notes:** Pure-function unit test (`src/test/`) for the mapping; a widget companion (TC-217) checks it renders with the completion surface. Assert the stretch's last point == destination node position and that arc-length never exceeds distance-to-destination.

---

### Case: Idle segment whose endpoint sits exactly on a checkpoint boundary (boundary ownership)
**ID:** TC-207
**Priority:** P0
**Type:** boundary
**Covers:** AC-6, AC-10

Given an idle segment whose `start` or `end` equals **exactly** a checkpoint's cumulative-from-start distance (fixture: idle [170, 230), where 230 is the Đà Lạt node and 530 the Đà Nẵng node — use end exactly on a node), abutting an adjacent active segment that shares that exact boundary
When the mapping resolves the red stretches for both segments
Then the boundary point belongs to **exactly one** stretch (half-open `[start, end)` ownership — the red stretch and the abutting active stretch do not both claim the node, and neither leaves it unpainted-but-claimed), matching the upstream boundary-ownership rule

**Notes:** Pure-function unit test (`src/test/`). Mirrors `idle-accounting` TC-114 / `route-progress` TC-114 at the *render* layer. Assert no double-painting at the shared node and that the result is deterministic (resolve twice → identical).

---

### Case: All-idle route paints the whole travelled road red
**ID:** TC-208
**Priority:** P1
**Type:** edge
**Covers:** AC-6, AC-7

Given a current route whose **entire** recorded span is idle (one idle segment from 0 to the current `routeDistanceKm`, no active span) — the "I left it locked the whole time" case
When the mapping resolves the red stretches
Then a single red stretch covers the **whole travelled polyline** from origin to the current marker position (and no further — it does not paint road ahead of the marker), and the result is the exact complement of TC-213's zero-idle case

**Notes:** Pure-function unit test (`src/test/`). Upper-extreme complement to AC-7. Assert red arc-length == current `routeDistanceKm` and red end == resolved marker position (not the destination, unless completed).

---

### Case: Province checkpoints sit at their real lat/long and the road chains in order (geography data integrity)
**ID:** TC-209
**Priority:** P0
**Type:** happy-path
**Covers:** AC-4

Given the production province-geography reference data (and the test fixture)
When the geography model is validated and the road polyline is built
Then every checkpoint carries a **real lat/long** within Vietnam's bounding box, the nodes are **strictly ordered** Mũi Cà Mau → Hà Giang, the road polyline connects them in **chain order** (no reordering, no node skipped), adjacent nodes are connected (adjacency holds), and the resulting outline is **not** a single straight line (consecutive legs are not all colinear) — it traces the country

**Notes:** Pure-data unit test (`src/test/`). Mirrors `route-progress` TC-NF4 chain-data integrity, extended with the lat/long + ordering checks this feature adds. Assert lat∈[~8.5,~23.5], long∈[~102,~110] (Vietnam bbox), strict ordering, and a non-colinearity check over consecutive legs. ~10–15 checkpoints.

---

### Case: Polyline arc-length is consistent with route-progress distance (geometry ⇄ distance contract)
**ID:** TC-210
**Priority:** P0
**Type:** edge
**Covers:** AC-4, AC-5

Given the geography polyline and the `route-progress` chain distances
When the cumulative arc-length along the polyline to each checkpoint is computed
Then it is **monotonically increasing** node-to-node and the arc-length to each node equals that node's `route-progress` cumulative-from-origin distance (within ±1e-6, after the documented projection/scaling) — so "arc-length `d` along the road" and "`routeDistanceKm = d`" resolve to the **same** point

**Notes:** Pure-function unit test (`src/test/`). This is the contract the whole red-trace mapping depends on (TC-201..TC-208 assume it). If lat/long geodesic length and the curated chain km differ, the model must define the reconciliation (e.g. arc-length parameterised by chain km); assert that definition holds. Flag to architect if the spec's mapping rule leaves this unspecified — escalate to `product-domain-expert`/`system-architect`, do not invent.

---

### Case: Current marker placed via reused route-progress routeDistanceKm math (no second geography model)
**ID:** TC-211
**Priority:** P0
**Type:** happy-path
**Covers:** AC-5

Given the geography model and the distance source reporting a cumulative `distanceKm` (so `routeDistanceKm = distanceKm − routeStartOffset`)
When the overlay places the current-position marker
Then the marker's position is derived by passing `routeDistanceKm` through the **existing** `route-progress` position math (the same function `route-progress` cases exercise), placed on the road polyline — `map-experience` introduces **no** second position function and **no** second geography definition (the model under test is the single source `route-planner-v2` will consume)

**Notes:** Unit + static (`src/test/`). Assert the marker position equals `route-progress`'s resolved position for the same `routeDistanceKm`, and statically assert `map-experience` does not define its own chain/position constants (it imports the single model).

---

### Case: Marker and red trace stay consistent under a non-zero routeStartOffset
**ID:** TC-212
**Priority:** P1
**Type:** edge
**Covers:** AC-5, AC-8

Given two runs producing the same `routeDistanceKm = R` — run A (`offset=0`, cumulative=R) and run B (`offset=1100`, cumulative=R+1100) — with the same current-route idle segments
When the overlay resolves the marker and red stretches in each
Then both runs produce **identical** marker position and identical red stretches (within ±1e-6) — the visualization keys off `routeDistanceKm`, never raw cumulative

**Notes:** Pure-function unit test (`src/test/`). Render-layer complement to `route-progress` TC-014b. Guards against any path reading raw cumulative for marker or red-trace placement.

---

### Case: Zero-idle route draws no red anywhere
**ID:** TC-213
**Priority:** P0
**Type:** happy-path
**Covers:** AC-7

Given a current route with **no** recorded idle segments (all-active)
When the overlay renders
Then the road, checkpoint pins, and current marker are drawn but **no red trace** appears anywhere on the polyline

**Notes:** Pure-function unit test for the mapping (`src/test/`, red-stretch list empty) plus a widget assertion that the painter emits zero red paint ops. Exact complement of TC-208.

---

### Case: Only the current route is traced — lifetime/other-route idle is excluded
**ID:** TC-214
**Priority:** P0
**Type:** edge
**Covers:** AC-8

Given the idle-accounting record contains segments spanning **more than the current route** (segments before `routeStartOffset`, and/or from a previous day per the settled day-key — leaning on `idle-accounting` day-split TC-117 and `route-progress` offset TC-014)
When the overlay renders
Then **only** the current route's idle segments are painted (those whose distance span falls within the current route's `[routeStartOffset, routeStartOffset + routeDistanceKm)` window, re-based to route arc-length) — the lifetime total and prior routes/days are **not** shown

**Notes:** Pure-function unit test (`src/test/`). Feed a record with out-of-window segments and assert they are filtered out; assert in-window segments are re-based correctly to route arc-length. Names the day-split / offset upstream invariants it relies on rather than re-testing them.

---

### Case: Red trace is restored unchanged after an app restart (current route)
**ID:** TC-215
**Priority:** P0
**Type:** edge
**Covers:** AC-8

Given a current route with recorded idle segments and the carry-forwards settled here persisted (the `idle-accounting` `idleSince` (S-3) and the segment day-key (S-1)), saved via the in-memory `shared_preferences`/JSON repository seam
When the app is relaunched (a fresh Bloc/model restores from the saved blob) and the overlay re-renders
Then the **same** current-route red trace is restored unchanged — same red stretches, same marker — with no loss, no spurious extra/missing idle, and no re-classification on restore

**Notes:** Integration test (`src/integration_test/`) with the faked repository; restore path also unit-testable. Mirrors `idle-accounting` TC-119 / `route-progress` TC-009 persistence at the visualization layer. Assert restored red stretches equal pre-restart stretches.

---

### Case: Voluntary vs lock/sleep idle both render red but differ by a non-colour cue
**ID:** TC-216
**Priority:** P0
**Type:** edge
**Covers:** AC-9, NFR-3

Given current-route idle segments of both causes — one `cause = voluntary`, one `cause = lockSleep` (as tagged by `idle-accounting` AC-4)
When the overlay renders the red trace
Then **both** stretches are drawn in the **same red colour** (single "drifted off" message), AND they are **visually distinguished by a secondary non-colour cue** (e.g. solid red for voluntary vs hatched/dashed red for lock/sleep) — the cause is recoverable from the cue without relying on colour

**Notes:** Widget test on the painter (`src/test/`) plus a golden (TC-225) pinning the two stroke styles. Assert both stretches use the same red colour value AND that the stroke style (dash/pattern flag) differs by cause. The *human colour-blind perception* judgement is manual — TC-M3. Encodes the AC-9 proposed decision (a reviewer may collapse to identical or split into two hues — re-confirm before automating the exact cue).

---

### Case: Overlay state at km=0 / mid-route / completion is well-defined
**ID:** TC-217
**Priority:** P0
**Type:** happy-path
**Covers:** AC-10

Given three resolved states — (a) `routeDistanceKm = 0`, (b) a mid-route distance with idle behind the marker, (c) the route completed at the destination tip
When the overlay renders each
Then (a) the **start province marker** is shown at the chain origin with **no** red trace and no progress drawn; (b) the current marker sits at its `routeDistanceKm` position with red covering **only** recorded idle spans **behind** the marker (none ahead); (c) the full road is shown with the destination reached and the complete-route idle trace, **consistent with `route-progress`'s completion/celebration state** — the overlay does **not** block or alter completion

**Notes:** Widget test (`src/test/`) for the three states (mapping legs covered by TC-205/TC-206). Assert no red is drawn ahead of the marker in (b). Assert the completion surface (celebration/summary from `route-progress` TC-011) is not suppressed or modified by the overlay in (c).

---

### Case: Tiles load via flutter_map+OSM with visible OSM attribution (network available)
**ID:** TC-218
**Priority:** P0
**Type:** happy-path
**Covers:** AC-11

Given network connectivity (simulated by a **fake tile provider** returning tiles successfully) and the overlay rendering
When the map renders
Then map tiles load via the `flutter_map` + OSM tile layer AND the **OSM attribution is visibly shown** on the map surface (inline and full-screen), with the province road, checkpoint markers, and red trace drawn on top of the tiles

**Notes:** Widget test (`src/test/`) against an injected fake/stub tile provider — no real network. Assert the attribution widget/string is present and visible. The **real** OSM round-trip + real attribution rendering is the on-device leg TC-M1.

---

### Case: No network → graceful fallback; road + markers + red trace still render; journey tab never breaks
**ID:** TC-219
**Priority:** P0
**Type:** negative
**Covers:** AC-11

Given **no** network (fake tile provider returns timeout/error, and the cache is empty)
When the overlay renders
Then the map degrades to the **defined fallback** — last-cached tiles if available, otherwise a **static/blank base** — on which the province road, checkpoint markers, and the red idle trace **still render**; the failed tile fetch produces **no** thrown error, **no** blocking spinner that hangs, and the **journey tab remains fully functional** (other journey UI keeps working)

**Notes:** Widget test (`src/test/`) with the fake provider scripted to fail. Cover both fallback branches: (1) empty cache → static/blank base + road/markers/red still drawn; (2) populated cache → last-cached tiles shown. Assert no unhandled exception surfaces and the journey tab's other widgets still build. The **real** offline/airplane-mode behaviour on a real network stack is TC-M2.

---

### Case: Inline map overlay renders on the journey tab and the standalone Map tab is gone
**ID:** TC-220
**Priority:** P0
**Type:** happy-path
**Covers:** AC-1

Given the app running on the journey tab
When the journey tab builds
Then a map overlay is rendered **inline** on that tab AND the navigation contains **no** standalone "Map" tab (the shipped `route-progress` Map tab is removed from the nav)

**Notes:** Widget test (`src/test/`). Assert the inline overlay widget is present on the journey tab and that the nav/tab bar has no "Map" destination. Regression-watch: removing the Map tab must not break navigation to other tabs.

---

### Case: Removing the standalone Map tab does not break other navigation (regression)
**ID:** TC-221
**Priority:** P1
**Type:** regression
**Covers:** AC-1

Given the navigation after the standalone Map tab has been removed
When the user navigates between the remaining tabs (journey, stats, settings, etc.)
Then every remaining tab still reachable and functional, no dangling route to the old Map tab, and no crash/blank screen from the removed destination

**Notes:** Widget/integration test (`src/test/` or `src/integration_test/`). Guards the AC-1 removal against a broken nav graph. Assert no leftover named route resolves to the removed tab.

---

### Case: Tapping the inline overlay opens full-screen in the SAME window (no new OS window)
**ID:** TC-222
**Priority:** P0
**Type:** happy-path
**Covers:** AC-2

Given the inline map overlay shown on the journey tab (single-window, per ADR-0003)
When the user taps the overlay
Then the map opens **full-screen within the same window** — the full-screen map surface replaces/covers the inline view in the existing window, and **no new OS window is spawned** (window count unchanged)

**Notes:** Widget test for the tap→full-screen transition (`src/test/`) plus an integration assertion (`src/integration_test/`) that no new window/`WindowController` is created (mock-window path, mirroring `mini-window` single-window discipline). Encodes ADR-0003 same-window navigation.

---

### Case: Dismissing full-screen returns to the inline overlay and the journey tab stays functional
**ID:** TC-223
**Priority:** P0
**Type:** happy-path
**Covers:** AC-3

Given the map is full-screen
When the user dismisses it via the close affordance, back gesture, **or** the Esc key
Then the map returns to the **inline overlay** on the journey tab and the journey tab is fully functional (other journey controls respond) — for all three dismiss paths

**Notes:** Widget test (`src/test/`). Cover all three dismiss affordances (close button, back, Esc) as separate sub-cases. Keyboard reachability of Esc/close ties to NFR-3 (TC-232). Assert the inline overlay is shown again and journey controls are interactive.

---

### Case: Red trace renders on top of the road on the matching stretch (painter integration)
**ID:** TC-224
**Priority:** P1
**Type:** happy-path
**Covers:** AC-6

Given the overlay with a known fixture idle segment and resolved red stretch (from TC-201)
When the painter draws the overlay
Then the red stroke is painted **over** the base road polyline along exactly the resolved stretch (correct z-order — red visible above the road, below the markers as designed), and active road segments retain the base (non-red) colour

**Notes:** Widget/golden test (`src/test/`). The render-layer companion to the TC-201 mapping math. A golden pins one frame for visual-structure regression (tolerant of per-OS AA). Asserts the mapping result actually reaches the canvas in the right z-order.

---

### Case: Golden — voluntary (solid) vs lock/sleep (hatched) red stroke styles are visually distinct
**ID:** TC-225
**Priority:** P1
**Type:** edge
**Covers:** AC-9, NFR-3

Given a fixture route with one voluntary and one lock/sleep idle segment
When the overlay is painted to a golden frame
Then the golden shows the two stretches in the same red but with **distinct stroke patterns** (solid vs hatched/dashed), pinning the non-colour cue for regression

**Notes:** Golden test (`src/test/`), tolerant of per-OS font/AA variance — pins *structure* (two distinct patterns), not exact pixels. If goldens are deferred project-wide (precedent: `local-stats` TC-NF4, `journey-view`), assert the two distinct stroke styles **behaviourally** instead (TC-216) and record the golden as deferred in the manual checklist. The colour-blind *perception* judgement remains manual (TC-M3).

---

### Case: Pure visualizer — toggling/removing the overlay leaves recorded segments and distance unchanged
**ID:** TC-226
**Priority:** P0
**Type:** edge
**Covers:** AC-12

Given recorded idle segments and a cumulative `distanceKm` value, with the overlay active
When the overlay is **toggled off / removed** and then re-added (and exercised through any render sequence)
Then the `idle-accounting` segment record and the engine's `distanceKm` / `routeStartOffset` are **byte-identical** before and after — the visualizer writes **nothing** back; the overlay is a read-only consumer

**Notes:** Integration test (`src/integration_test/`) with a fake distance source + fake segment store recording any write attempt; assert **zero** writes from the map slice. Mirrors `route-progress` TC-017. Render-then-snapshot the upstream data and assert no mutation.

---

### Case: No re-classification, no distance accrual — engine/ticker/ActivityPlugin untouched (static separation)
**ID:** TC-227
**Priority:** P0
**Type:** edge
**Covers:** AC-12

Given all `map-experience` source (geography model, mapping function, overlay/full-screen widgets, red-trace painter, tile layer wiring)
When inspected statically
Then it contains **none** of: active-vs-idle decision logic, idle re-classification, distance-accrual logic, `JourneyEngine`/ticker mutation, or `ActivityPlugin`/`getSystemIdleSeconds`/`isScreenLocked`/platform-channel calls — it **reads** the `idle-accounting` segments and `route-progress` position as-is

**Notes:** Static-inspection case (`src/test/`, grep/source review). Mirrors `route-progress` TC-016 / `idle-accounting` TC-112. Re-run on any change to the slice's files. Allowed: reading the segment record + `distanceKm`; forbidden: any classification/accrual/OS-idle call.

---

### Case: Driving the visualizer through any sequence never alters JourneyEngine state (runtime guard)
**ID:** TC-228
**Priority:** P1
**Type:** edge
**Covers:** AC-12

Given a fake distance source and segment store exposing settable values and recording writes
When the overlay is driven through a sweep of distances and segment sets (start, mid, completion, all-idle, zero-idle)
Then no `tick`, no accrual, and no segment mutation originate from `map-experience`; the source's exposed `distanceKm`, `state`, and the segment list are unchanged after every step (zero recorded writes)

**Notes:** Integration/widget runtime guard (`src/integration_test/`). Runtime complement to TC-227's static check; reused by TC-226. Assert zero writes across the whole sweep.

---

### Case: Paint hot path does not re-allocate static geometry per frame; red-trace segments bounded; shouldRepaint correct
**ID:** TC-229
**Priority:** P1
**Type:** nfr
**Covers:** NFR-1

Given the overlay painter (province polyline, pins, markers, red trace) and a route with the **maximum expected idle-segment count**
When the painter's `paint`/`shouldRepaint` are inspected and a redraw sweep is run
Then the **static** geography (polyline + pins) is **not** re-allocated per frame in the paint hot path (built once / cached), the red-trace stretch objects are bounded by the idle-segment count (not rebuilt per frame from scratch unnecessarily), and `shouldRepaint` returns **false** when nothing relevant changed

**Notes:** Static inspection + widget redraw test (`src/test/`). The deterministic part of NFR-1; mirrors `route-progress` TC-NF2 / `journey-view` TC-017/TC-018. The actual **≥30fps on macOS/Windows incl. the inline↔full-screen transition with live tiles** is on-device only — TC-M-NF1.

---

### Case: No device-location / GPS API anywhere; province lat/long is static app-supplied reference data (static privacy)
**ID:** TC-230
**Priority:** P0
**Type:** edge
**Covers:** NFR-2

Given all `map-experience` source and its dependency set (including `flutter_map` and the geography data asset)
When inspected statically
Then the slice imports/calls **no** device-location / GPS / geolocation API (no `geolocator`/`location`/CoreLocation/`Geocoding`/platform location channel), the province lat/long is a **static app-shipped constant/asset** (never a device read), and `flutter_map` is used **only** for static tile display + the static province overlay — not to read the device's position

**Notes:** Static-inspection case (`src/test/`, grep over imports + dependency manifest). The automatable subset of the gating NFR-2. Assert the geography source is a const/asset, not a runtime location read. The full promise ("zero tracking surface", `/privacy-audit` PASS, runtime egress) is the audit gate TC-M-PRIV.

---

### Case: Tile requests carry no user data (no identifier, no location, no idle data in the request)
**ID:** TC-231
**Priority:** P0
**Type:** edge
**Covers:** NFR-2

Given the configured `flutter_map` OSM tile layer and its URL template / request construction
When the tile request URLs and headers are inspected (statically, and via a request-capturing fake tile provider)
Then each tile request is a **standard anonymous tile GET** keyed only by `{z}/{x}/{y}` (and a static OSM user-agent per OSM policy) — it contains **no** user identifier, **no** device/user location, **no** idle/segment data, and **no** account/session token

**Notes:** Static + fake-provider widget test (`src/test/`). Capture the outbound URL/headers the tile layer would emit and assert the payload is data-free beyond tile coordinates + required UA. The **real socket / egress inspection** (only anonymous tile GETs leave the machine, nothing else) is the on-device runtime leg of TC-M-PRIV — framed there.

---

### Case: Toggle/dismiss affordances are keyboard-reachable and screen-reader labelled; map controls expose semantics
**ID:** TC-232
**Priority:** P1
**Type:** edge
**Covers:** NFR-3

Given the inline overlay, the tap-to-fullscreen affordance, and the full-screen dismiss affordance
When the widget tree's semantics and keyboard focus traversal are inspected
Then the open-full-screen and dismiss controls are **keyboard-reachable** (focusable, activatable via keyboard incl. Esc-to-dismiss) and carry **meaningful semantic labels** (screen-reader announceable), and the map controls expose semantics rather than relying on visual-only cues

**Notes:** Widget test (`src/test/`) asserting `Semantics` labels and keyboard focusability/activation. The deterministic part of NFR-3. The **real screen-reader** announcement quality (VoiceOver / Narrator) is a manual AT check — TC-M4.

---

## Coverage table (AC / NFR → covering case IDs)

| Item | Description | Covered by |
|---|---|---|
| AC-1 | inline overlay on journey tab; no standalone Map tab | TC-220, TC-221 |
| AC-2 | tap → full-screen in same window (no new OS window) | TC-222 |
| AC-3 | dismiss → back to inline; journey tab functional | TC-223 |
| AC-4 | provinces at real lat/long, road chained in order | TC-209, TC-210, TC-203 |
| AC-5 | single geography model; marker via reused routeDistanceKm math | TC-211, TC-212, TC-210 |
| AC-6 | idle red on matching stretch; active not red | TC-201, TC-202, TC-203, TC-204, TC-205, TC-206, TC-207, TC-208, TC-224 |
| AC-7 | zero-idle route draws no red | TC-213, TC-208 |
| AC-8 | current route only; survives restart | TC-214, TC-215, TC-212 |
| AC-9 | voluntary vs lock/sleep both red, non-colour cue | TC-216, TC-225, TC-M3 |
| AC-10 | defined states at start / mid / completion | TC-205, TC-206, TC-207, TC-217 |
| AC-11 | tiles via flutter_map+OSM + attribution; graceful offline fallback | TC-218, TC-219, TC-M1, TC-M2 |
| AC-12 | pure visualizer — no re-classification, no accrual; toggle leaves data unchanged | TC-226, TC-227, TC-228 |
| NFR-1 | ≥30fps no jank on macOS+Windows incl. transition + max segments | TC-229 (deterministic guard), TC-M-NF1 (on-device) |
| NFR-2 | aggregate-only; no GPS/location; tiles carry no user data; /privacy-audit PASS | TC-230, TC-231 (static), TC-M-PRIV (audit + runtime egress) |
| NFR-3 | distinguishable beyond colour; keyboard + screen-reader reachable | TC-216, TC-225, TC-232 (deterministic), TC-M3/TC-M4 (manual perception/AT) |

Every AC (AC-1..AC-12) and every NFR (NFR-1..NFR-3) maps to at least one case. No AC is orphaned. The
TC-M* manual/on-device legs live in [map-experience-manual-checklist.md](map-experience-manual-checklist.md).
