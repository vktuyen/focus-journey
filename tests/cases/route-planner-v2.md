# Test cases: route-planner-v2

Spec: [specs/route-planner-v2/spec.md](../../specs/route-planner-v2/spec.md)
Depends on (shipped): [specs/route-progress/spec.md](../../specs/route-progress/spec.md) — the province chain, `routeStartOffset`, `routeDistanceKm` position math, completion/celebration, `totalChainKm ≈ 2000`, decision 3 "block invalid selection in the picker", decision 1 "new start ⇒ new offset, engine never reset" · [specs/map-experience/spec.md](../../specs/map-experience/spec.md) — the single static province-geography model (lat/long + adjacency), `RoutePolylineProjector`, ADR-0004 single canonical-km axis, red idle trace "current route only" · [specs/idle-accounting/spec.md](../../specs/idle-accounting/spec.md) — the per-route distance-keyed active/idle segment record.
Sibling cases: [route-progress.md](route-progress.md) · [map-experience.md](map-experience.md) · [idle-accounting.md](idle-accounting.md)
Manual / on-device companion: [route-planner-v2-manual-checklist.md](route-planner-v2-manual-checklist.md)
Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md)

## Coverage note

`route-planner-v2` is a **pure consumer of engine distance** that owns *route selection + planning +
lifecycle* and adds **zero** activity logic and **zero** new privacy surface. It generalizes
`route-progress`'s "fixed start + N/S direction" into "pick any start + any end → contiguous sub-path,"
adds an auto-insert + **review-before-start** gate with **zero side effect until confirm**, and adds a
**stop-and-restart (abandon)** lifecycle — all by reusing the shipped `routeStartOffset` primitive, the
**unchanged** `RouteProgressResolver` + `RoutePolylineProjector`, and the existing
`shared_preferences`/JSON repository seam. It introduces **no** new geography (consumes `map-experience`'s
static model), **no** engine reset, and **no** network call of its own.

Per `docs/architecture/overview.md`, executable tests live **inside** the Flutter package:
- **Unit** (`src/focus_journey/test/.../domain/`) — the genuinely novel deterministic algorithm: **route
  resolution / auto-insert** (any start + any end → ordered contiguous sub-path; spine-order intermediate
  fill; out-of-span stop **extends** the span; sub-path length `subPathKm`); plus the reuse invariants
  (`RouteProgressResolver` + `RoutePolylineProjector` run **unchanged** over the authored ordered list;
  position = pure fn of `routeDistanceKm` on the single km axis; route % vs country %); plus offset/lifecycle
  math (confirm stamps one offset; abandon stamps a new offset and never resets cumulative `distanceKm`;
  abandoned ≠ completed). These are Flutter-free, timer-free pure functions mirroring `RouteProgressResolver`.
- **Widget** (`src/focus_journey/test/.../presentation/`) — the picker (start==end disabled, 2-checkpoint
  minimum), the review screen (ordered route + total distance + remove/skip editing + re-resolve), the
  abandon confirm guard (shown only with progress; cancel inert), the new route's red idle trace (no bleed),
  and the keyboard/semantics surface.
- **Integration** (`src/focus_journey/integration_test/`) — Bloc↔picker/review wiring, the
  **zero-side-effect-until-confirm** snapshot (offset/segments/position/persisted-state byte-identical
  across a full review+edit+cancel cycle), confirm→travel, abandon→new-route lifecycle, and **restart
  restoration** of the active custom route via the faked repository.
- **Manual / on-device / audit** (see the companion checklist) — NFR-1 no-jank fps on macOS/Windows
  (TC-M-NF1), NFR-3 real screen-reader + keyboard (TC-M-A11Y), and the **gating** NFR-2 privacy audit +
  runtime egress (TC-M-PRIV).

`tests/cases/` (this file) holds only the human-readable Given/When/Then; no executable test is placed under
the top-level `tests/` tree.

Layer → AC mapping:

| AC / NFR | What it asserts | Covering layer(s) | Cases |
| --- | --- | --- | --- |
| **AC-1** | any start + any end → contiguous sub-path in spine order, direction implied; replaces fixed-start+N/S picker | Unit + widget | TC-301, TC-302, TC-304, TC-305 |
| **AC-2** | start==end disabled; 2-adjacent-checkpoint minimum, blocked in picker | Widget + unit | TC-303, TC-312 |
| **AC-3** | auto-insert fills intermediates in spine order, consuming map-experience geography only (pure fn) | Unit | TC-306, TC-307, TC-308 |
| **AC-4** | marked stop outside [start,end] extends the span | Unit + widget | TC-309 |
| **AC-5** | review screen shows ordered route + total distance, editable; remove/skip re-resolves | Widget | TC-310, TC-311, TC-312, TC-313 |
| **AC-6** | ZERO side effect until confirm — snapshot identical across review+edit+cancel (critical) | Integration + unit | TC-314, TC-315, TC-316 |
| **AC-7** | confirm stamps exactly one offset; position = pure fn of routeDistanceKm via unchanged resolver/projector on single km axis | Unit + integration | TC-317, TC-318, TC-319 |
| **AC-8** | route-relative completion at subPathKm; route % = ÷subPathKm, country % = ÷totalChainKm | Unit + widget | TC-320, TC-321, TC-322, TC-323 |
| **AC-9** | abandon confirm guard when progress to lose; cancel is inert | Widget + integration | TC-324, TC-325, TC-326 |
| **AC-10** | confirm abandon stamps a NEW offset, never resets lifetime distance, NOT completion (no celebration) | Unit + integration | TC-327, TC-328, TC-329, TC-330 |
| **AC-11** | new route's red idle trace shows only the new offset's segments — no bleed | Unit + widget | TC-331, TC-332, TC-333 |
| **AC-12** | active custom route (list + offset + lifecycle) survives restart via existing seam | Integration + unit | TC-334, TC-335, TC-336 |
| **NFR-1** | picker/auto-insert/review render + re-render with no visible jank on macOS+Windows | Static guard + **manual/device** | TC-340 + TC-M-NF1 |
| **NFR-2** (CRITICAL gate) | only static map-experience geography; no GPS/location; no new network call; no new identifier/trail; /privacy-audit PASS | Static inspection + **manual audit/egress** | TC-337, TC-338 + TC-M-PRIV |
| **NFR-3** | picker + review (editing + distance readout) + abandon dialog keyboard-reachable + screen-reader labelled | Widget (semantics/keyboard) + **manual screen-reader** | TC-339 + TC-M-A11Y |

**Risky / under-covered areas (flagged for `test-script-author` and reviewers):**

1. **The reuse invariant — `RouteProgressResolver` + `RoutePolylineProjector` running UNCHANGED over an
   arbitrary authored ordered checkpoint list (AC-7).** The whole correctness of custom-route position rests
   on these shipped components behaving identically when fed an *authored sub-path list* instead of the
   hard-coded full spine, on the **single canonical-km axis** (ADR-0004). TC-317/TC-318/TC-319 assert the
   position is computed *by the same function* and that **no second distance axis / second geography
   definition** is introduced. A regression here silently breaks every downstream render. **Highest-logic-risk
   area** — keep the unit rigor at `route-progress`'s level.
2. **The zero-side-effect-until-confirm invariant (AC-6) is gating and must be a true before/after snapshot.**
   TC-314 snapshots `routeStartOffset`, the idle/active segment record, the engine `distanceKm` + position,
   and the persisted route blob **before** entering review, drives a full review+edit+cancel cycle, and
   asserts **byte-for-byte identical** state after. This is easy to get subtly wrong (e.g. an offset stamped
   on review-screen open, a "draft" written to prefs on edit). Confirm "start" must be the *only* mutation.
3. **No idle-trace bleed after abandon (AC-11).** Whether the abandoned route's distance-keyed segments are
   pruned or kept as inert history is a `system-architect` call (deferred open question), but they must
   **never** appear on the new route's red trace. TC-331/TC-332 cover both possible storage decisions by
   asserting the *rendered* new-route trace shows only the new offset's window regardless. Flag the chosen
   storage to the reviewer so the test asserts the right thing.
4. **NFR-2 privacy is the gating concern and only partly automatable.** Static inspection (TC-337/TC-338) can
   assert no location/GPS API, that geography is the static `map-experience` model, and that
   selection/auto-insert/review/abandon make **zero** network calls. But "this is the most location-suggestive
   surface ever shipped and adds zero tracking," runtime egress, and `/privacy-audit` PASS are a
   **review/audit + on-device gate** (TC-M-PRIV). A fail here **blocks ship** regardless of every other pass.
5. **On-device NFR legs (NFR-1 fps, NFR-3 real screen-reader/keyboard).** The deterministic part is
   automatable (TC-340 hot-path / allocation guard; TC-339 Semantics + keyboard focus), but real no-jank
   frame timing on each OS and a real AT user operating the picker/review/abandon are manual (TC-M-NF1,
   TC-M-A11Y). Windows runtime legs are **DEFERRED — required before any Windows release**.

## Conventions used by these cases

- **Deterministic by construction for the automated layer.** Route resolution / auto-insert is a **pure
  function** `(spine geography, start, end, marked stops) → ordered checkpoint list + subPathKm` — no
  timers, no `DateTime.now()`, no I/O, no network. Lifecycle math is a pure function of (engine cumulative
  `distanceKm`, `routeStartOffset`, the authored list). Cases reuse the `route-progress`/`map-experience`
  deterministic distance source (a scriptable stub exposing a **settable** cumulative `distanceKm`), a
  **fixture idle-segment list** (distance-keyed `{start, end, classification, cause}`), and the existing
  in-memory `shared_preferences`/JSON repository fake. No case awaits real time or real network.
- **Reused upstream contracts (do NOT re-test here).** Active/idle classification + grace/threshold, the
  segment record's contiguity/merge/day-split/persistence, distance accrual, the distance→marker position
  walk, the distance→polyline (`RoutePolylineProjector`) red-trace mapping, and the celebration/summary
  surface are owned and tested by `idle-accounting`, `route-progress`, and `map-experience`. These cases
  treat them as **given** and assert only what `route-planner-v2` adds: route authorship, the review gate,
  the abandon lifecycle, and that the reused components run **unchanged** over an *authored* list. Where a
  case leans on an upstream invariant it names it rather than re-testing it.
- **Fixture spine (structure, not literals).** Reuse the `route-progress`/`map-experience` fixture chain
  (`Mũi Cà Mau ─60→ Cần Thơ ─170→ Đà Lạt ─300→ Đà Nẵng ─310→ Hà Nội ─600→ Hà Giang`, ordered, each node
  carrying a static lat/long; fixture total 1440 km; production `totalChainKm ≈ 2000`, curated ~10–15
  checkpoints). Cases key off the *structure* — ordered nodes, positive inter-node distances, contiguity —
  NOT the literal numbers, so they survive re-tuning to the production chain. "Worked numbers" in a Given are
  illustration; assert against the rule.
- **Route model.** A custom route is the **contiguous sub-path** of the spine between the chosen start and
  end, taken **in spine order from start toward end** (direction implied by which end is the start). It is
  the ordered list `start → …intermediates… → end` containing every spine checkpoint between the endpoints
  inclusive. `subPathKm` = sum of inter-node distances over that list. `routeDistanceKm = engine.distanceKm
  − routeStartOffset`.
- **Tolerances.** Distance / arc-length / `subPathKm` equality within **±1e-6 km**; a resolved position's
  equality within ±1e-6 of the projector's point; percentages within ±1e-6 (after the documented cap at
  100%). Persisted-state / snapshot comparisons are **byte-for-byte / structural equality** (AC-6 / AC-12).
- **Test layer.** Per `docs/architecture/overview.md`: unit/widget/golden under `src/focus_journey/test/`,
  integration under `src/focus_journey/integration_test/`, run with `fvm flutter test` /
  `fvm flutter test integration_test/ -d <os>`. A note marks any case whose only honest verification is
  **manual / on-device / audit** and points to the companion checklist.

## Cases

### Endpoint selection (#8)

### Case: Any start + any end resolves to the contiguous sub-path in spine order (direction implied)
**ID:** TC-301
**Priority:** P0
**Type:** happy-path
**Covers:** AC-1, AC-3

Given the curated spine and a chosen start = an interior checkpoint and end = a different interior checkpoint farther toward one tip (fixture: start = Cần Thơ, end = Đà Nẵng), no marked stops
When the route is resolved
Then the resolved route is the **ordered list** `start → …every spine checkpoint strictly between… → end` taken in spine order from start toward end (fixture: `Cần Thơ → Đà Lạt → Đà Nẵng`), it contains every spine checkpoint between the endpoints **inclusive**, and the direction is implied by which endpoint is the start (no separate N/S direction input is required)

**Notes:** Pure-function unit test (`src/focus_journey/test/.../domain/`). Assert the list is a contiguous slice of the spine in order, endpoints inclusive, no node skipped, no node reordered. The structural complement (reverse direction) is TC-302.

---

### Case: Choosing the start at the higher-index tip resolves the reverse-direction sub-path
**ID:** TC-302
**Priority:** P0
**Type:** edge
**Covers:** AC-1

Given start = a checkpoint nearer the Hà Giang tip and end = a checkpoint nearer the Mũi Cà Mau tip (fixture: start = Hà Nội, end = Đà Lạt)
When the route is resolved
Then the resolved ordered list runs **from the chosen start toward the chosen end** (fixture: `Hà Nội → Đà Nẵng → Đà Lạt`) — i.e. the same contiguous spine stretch but ordered start→end (reverse of TC-301's direction), confirming direction is purely "which endpoint is start," with no N/S toggle

**Notes:** Pure-function unit test. Guards that resolution is direction-agnostic on input and orders strictly by which end is start. Pairs with TC-301 (same stretch, opposite order).

---

### Case: Picker replaces the shipped fixed-start + binary N/S-direction control
**ID:** TC-304
**Priority:** P1
**Type:** regression
**Covers:** AC-1

Given the route-selection picker
When the picker is shown
Then it offers **two free checkpoint choices** (any one start + any one end on the curated spine) and **no** "direction (toward Hà Giang / toward Mũi Cà Mau)" toggle remains — the shipped `route-progress` fixed-start + binary-direction control is gone, and selecting two checkpoints fully determines the route

**Notes:** Widget test (`src/focus_journey/test/.../presentation/`). Regression-watch: removing the direction toggle must not break the picker's confirm path or leave a dangling control. Assert no direction-toggle widget is present and that a start+end selection is sufficient to enable "review."

---

### Case: Adjacent-only endpoints resolve to a two-checkpoint route with no intermediates
**ID:** TC-305
**Priority:** P1
**Type:** boundary
**Covers:** AC-1, AC-2

Given start and end that are **adjacent** spine checkpoints (fixture: start = Mũi Cà Mau, end = Cần Thơ), no marked stops
When the route is resolved
Then the resolved ordered list is exactly the **two endpoints** with **no** auto-inserted intermediate (nothing lies strictly between adjacent checkpoints), `subPathKm` equals the single inter-node distance, and the route is valid (the minimum non-zero route)

**Notes:** Pure-function unit test. Lower boundary of AC-1 resolution and the floor referenced by AC-2. Assert list length == 2 and `subPathKm` == the one inter-node distance.

---

### Case: start == end is disabled in the picker; 2-adjacent-checkpoint minimum enforced
**ID:** TC-303
**Priority:** P0
**Type:** negative
**Covers:** AC-2

Given the picker with a start checkpoint already chosen
When the user attempts to choose the **same** checkpoint as the end
Then that option is **disabled/unavailable** (a zero-length route can never be selected), AND the smallest selectable route is **two adjacent spine checkpoints** — so the model never enters a zero-checkpoints-ahead state at `routeDistanceKm = 0` (mirroring `route-progress` decision 3 "block invalid selection in the picker")

**Notes:** Widget test (`src/focus_journey/test/.../presentation/`). Assert the start==end end-option is non-selectable/disabled (not merely rejected after the fact), and that "review/confirm" cannot be reached with start==end. Mirrors `route-progress` picker-blocking precedent.

---

### Auto-insert + review gate (#9)

### Case: Auto-insert fills every intermediate spine checkpoint in spine order (pure, deterministic)
**ID:** TC-306
**Priority:** P0
**Type:** happy-path
**Covers:** AC-3

Given chosen endpoints with ≥1 spine checkpoint strictly between them and no marked stops (fixture: start = Cần Thơ, end = Hà Nội)
When the route is resolved
Then the app **auto-inserts every spine checkpoint that lies between** the endpoints in **spine order**, producing the ordered list `start → …intermediates… → end` (fixture: `Cần Thơ → Đà Lạt → Đà Nẵng → Hà Nội`), and resolving twice produces an **identical** list (deterministic)

**Notes:** Pure-function unit test (`src/focus_journey/test/.../domain/`). The novel algorithm; mirrors `RouteProgressResolver`'s determinism. Assert idempotent/deterministic resolve and exact spine-order fill.

---

### Case: Auto-insert reads ONLY map-experience's static geography — never re-derives, forks, or re-orders it
**ID:** TC-307
**Priority:** P0
**Type:** edge
**Covers:** AC-3, NFR-2

Given the `route-planner-v2` auto-insert / route-resolution source
When inspected statically and exercised
Then it consumes **only** `map-experience`'s single static province-geography model (lat/long + adjacency) — it **never re-derives, forks, or re-orders** geography, defines **no** second checkpoint/ordering/distance constant of its own, and the resolution is a **pure, Flutter-free, timer-free** domain function (build-once-consume-many)

**Notes:** Static-inspection + pure-function unit test (`src/focus_journey/test/.../domain/`). Mirrors `map-experience` TC-227 separation rigor. Assert the resolver imports the single geography model and declares no rival geography constant; assert it is Flutter-free (no `package:flutter` import in the domain function).

---

### Case: Stops between the endpoints do not change the resolved list (intermediates already auto-filled)
**ID:** TC-308
**Priority:** P1
**Type:** edge
**Covers:** AC-3, AC-4

Given chosen endpoints and a marked stop that lies **inside** the [start, end] span (fixture: start = Cần Thơ, end = Hà Nội, stop = Đà Nẵng)
When the route is resolved
Then the resolved ordered list is the **same** contiguous spine sub-path it would be without the stop (the stop is already among the auto-inserted intermediates), and the span/endpoints are **unchanged** — an in-span stop neither extends nor truncates the route

**Notes:** Pure-function unit test. Pairs with TC-309 (out-of-span stop *does* extend). Confirms a stop only matters when it sits outside the endpoint span.

---

### Case: A marked stop OUTSIDE the [start, end] span extends the span to include it
**ID:** TC-309
**Priority:** P0
**Type:** edge
**Covers:** AC-4

Given chosen endpoints and a marked stop that lies on the spine **outside** the span between them (fixture: start = Cần Thơ, end = Đà Lạt, stop = Hà Nội — beyond Đà Lạt toward the Hà Giang tip)
When the route is resolved
Then the span is **extended to the farther of the two endpoints so the stop is included** (the stop becomes the new extreme endpoint in its direction), the route is still a **single contiguous sub-path in spine order** (fixture: `Cần Thơ → Đà Lạt → Đà Nẵng → Hà Nội`), and the **review screen reflects the extended endpoints**

**Notes:** Pure-function unit test for resolution + a widget assertion that the review screen shows the extended endpoints. Encodes the AC-4 proposed decision (**extend**, not reject/ignore) — a reviewer may switch to reject-with-message or ignore; re-confirm before automating the exact behaviour. Assert the new extreme endpoint and contiguity.

---

### Case: Review screen shows the resolved ordered route and the total route distance
**ID:** TC-310
**Priority:** P0
**Type:** happy-path
**Covers:** AC-5

Given a resolved route (fixture: `Cần Thơ → Đà Lạt → Đà Nẵng → Hà Nội`)
When the review-before-start screen is shown
Then it displays the **full ordered route** `start → … → end` in spine order AND the **total route distance** (`subPathKm`, km) — the sum of the inter-node distances over the resolved list

**Notes:** Widget test (`src/focus_journey/test/.../presentation/`). Assert the ordered checkpoint list is rendered in order and a total-distance readout equals `subPathKm` for the fixture (within display rounding).

---

### Case: Removing an auto-inserted intermediate re-resolves the displayed route and total distance
**ID:** TC-311
**Priority:** P0
**Type:** happy-path
**Covers:** AC-5

Given the review screen showing a route with ≥1 removable intermediate (fixture: `Cần Thơ → Đà Lạt → Đà Nẵng → Hà Nội`)
When the user removes/skips an auto-inserted intermediate (fixture: remove Đà Nẵng)
Then the displayed **ordered route re-resolves** with the remaining checkpoints and the **total distance updates** to reflect the change — the review screen reflects the edit immediately

**Notes:** Widget test. Assert the removed checkpoint disappears from the displayed list and the total-distance readout changes consistently with the remaining list. Re-resolution is the same pure function (TC-306) driven from the UI.

---

### Case: Endpoints are not removable below the 2-checkpoint minimum
**ID:** TC-312
**Priority:** P1
**Type:** boundary
**Covers:** AC-2, AC-5

Given the review screen with all intermediates already removed down to **two** checkpoints (fixture: route now just `Cần Thơ → Đà Lạt`, adjacent in the resolved sub-path)
When the user attempts to remove a further checkpoint (an endpoint)
Then removal is **blocked at the two-checkpoint minimum** — endpoints cannot be removed below it, so the review route can never collapse to a single point or empty route (consistent with AC-2)

**Notes:** Widget test. Assert that with exactly two checkpoints remaining, the remove controls for the endpoints are disabled/no-op. Boundary complement to TC-303 (picker-side) — this is the *review-edit* side of the same minimum.

---

### Case: Cancelling the review returns to the picker (UI navigation; data-side covered by AC-6)
**ID:** TC-313
**Priority:** P1
**Type:** happy-path
**Covers:** AC-5

Given the review screen with a resolved (and possibly edited) route
When the user chooses **cancel**
Then the UI returns to the **picker** so the user can re-choose endpoints/stops, and the review route is discarded from the UI

**Notes:** Widget test for the navigation only. The crucial *data* assertion that cancel records **nothing** is AC-6 / TC-314. Keep this case strictly about the screen transition; do not duplicate the snapshot here.

---

### ZERO side effect until confirm (#9 — critical invariant)

### Case: A full review + edit + cancel cycle leaves offset, segments, position, and persisted state byte-identical
**ID:** TC-314
**Priority:** P0
**Type:** edge
**Covers:** AC-6

Given a known starting state — a snapshot of `routeStartOffset`, the idle/active segment record, the engine cumulative `distanceKm` + current position, and the persisted route blob — captured **before** entering review
When the user enters the review screen, edits the route (remove/skip ≥1 intermediate), and then **cancels** back to the picker (no confirm)
Then **every** snapshotted value is **byte-for-byte / structurally identical** afterward — **no** `routeStartOffset` is stamped, **no** idle/active segment is created or altered, the engine `distanceKm` and current position are unchanged, **no** persisted route state is written, and cancel recorded **nothing**

**Notes:** Integration test (`src/focus_journey/integration_test/`) with the fake distance source + faked `shared_preferences`/JSON repository recording every write attempt. **The gating AC-6 snapshot.** Assert **zero** writes to the repository across the whole cycle and equality of the before/after snapshot. Mirrors `map-experience` TC-226 / `route-progress` TC-017 no-write rigor, raised to a full review+edit+cancel cycle.

---

### Case: Opening the review screen alone stamps no offset and writes nothing (no eager mutation)
**ID:** TC-315
**Priority:** P0
**Type:** edge
**Covers:** AC-6

Given a resolved route and the pre-review snapshot (as TC-314)
When the user merely **opens** the review screen and looks at it (no edit, no confirm, no cancel yet)
Then **no** `routeStartOffset` has been stamped, **no** segment created/altered, position/`distanceKm` unchanged, and **no** persisted write has occurred — the act of reviewing is purely read-only

**Notes:** Integration/widget test. Guards against the easy bug of stamping an offset or persisting a "draft route" on review-screen open. Assert zero repository writes the moment the review screen builds. Sub-case isolation from the edit/cancel of TC-314.

---

### Case: Re-resolution on each review edit is in-memory only — no segment, offset, or persisted write
**ID:** TC-316
**Priority:** P1
**Type:** edge
**Covers:** AC-6, NFR-1

Given the review screen and a fake repository/segment store recording any write
When the user performs a **burst of edits** (remove then re-add / skip several intermediates), each triggering a re-resolve
Then every re-resolution updates **only in-memory** review state — **zero** writes to the repository, **zero** segment mutations, **zero** offsets stamped — and (NFR-1 deterministic part) the re-resolve is a small pure-domain computation with no network/disk round-trip

**Notes:** Integration/widget runtime guard. Runtime complement to TC-314. Assert zero writes across the edit burst; also feeds the NFR-1 "re-resolution never touches network/disk" claim (the on-device no-jank measurement is TC-M-NF1).

---

### Confirm "start" (#9)

### Case: Confirm "start" stamps exactly one routeStartOffset equal to the engine's cumulative distance at that instant
**ID:** TC-317
**Priority:** P0
**Type:** happy-path
**Covers:** AC-7

Given a reviewed route and the engine reporting a cumulative `distanceKm = D` at the confirm instant (fixture: D = 740, a non-zero lifetime total from prior travel)
When the user confirms **"start"**
Then **exactly one** `routeStartOffset` is stamped equal to `D` (per `route-progress` decision 1), travel begins, and from then on `routeDistanceKm = engine.distanceKm − routeStartOffset` (= 0 at the confirm instant) — confirm is the only state mutation in the whole flow (the inverse of AC-6)

**Notes:** Unit + integration test. Assert exactly one offset write with value == cumulative `distanceKm` at confirm, and that `routeDistanceKm` starts at 0. Pairs with TC-314 (everything *before* confirm wrote nothing).

---

### Case: Custom-route position is computed by the UNCHANGED RouteProgressResolver + RoutePolylineProjector over the authored list
**ID:** TC-318
**Priority:** P0
**Type:** edge
**Covers:** AC-7

Given a confirmed custom route whose **authored ordered checkpoint list** is a sub-path (not the full spine) and a sequence of increasing `routeDistanceKm` values
When the traveller's position is resolved
Then it is produced by the **existing** `RouteProgressResolver` + `map-experience`'s `RoutePolylineProjector` run **unchanged** over the authored list — position is a **pure function of `routeDistanceKm`** (same `route-progress` cases exercise), and `route-planner-v2` introduces **no** second position function and **no** second geography definition

**Notes:** Unit test (`src/focus_journey/test/.../domain/`). **The highest-logic-risk reuse invariant.** Assert the resolved position equals what `RouteProgressResolver`/`RoutePolylineProjector` produce for the same `routeDistanceKm` over the same authored list, and statically assert `route-planner-v2` defines no rival resolver/projector. Mirrors `map-experience` TC-211.

---

### Case: Single canonical-km axis is preserved — same routeDistanceKm yields same position regardless of cumulative/offset (ADR-0004)
**ID:** TC-319
**Priority:** P0
**Type:** edge
**Covers:** AC-7

Given two runs of the **same** authored route producing the same `routeDistanceKm = R` — run A (`offset = 0`, cumulative = R) and run B (`offset = 740`, cumulative = R + 740)
When the position is resolved in each
Then both runs produce an **identical** resolved position (within ±1e-6) — the position keys off `routeDistanceKm` on the **single canonical-km axis** (ADR-0004), never raw cumulative, and no second distance axis is introduced

**Notes:** Pure-function unit test. Mirrors `map-experience` TC-212 / `route-progress` TC-014b at the custom-route layer. Guards against any path reading raw cumulative or introducing a parallel axis when the chain is generalized.

---

### Stop-and-restart lifecycle (#10)

### Case: A custom route completes when routeDistanceKm reaches subPathKm and fires the existing celebration
**ID:** TC-320
**Priority:** P0
**Type:** happy-path
**Covers:** AC-8

Given an active custom route of length `subPathKm` (fixture: `Cần Thơ → Đà Lạt → Đà Nẵng`, `subPathKm` = sum of its inter-node distances)
When `routeDistanceKm` reaches `subPathKm` (the chosen end)
Then the route enters **completed** and fires the existing `route-progress` celebration/summary unchanged — completion is **route-relative** (the chosen sub-path's own end), not the full-chain end

**Notes:** Unit (state transition) + widget (celebration surface) test. Assert the transition to completed at `routeDistanceKm == subPathKm` and that the `route-progress` celebration fires (reuse, not rebuild). The celebration content itself is `route-progress`'s (TC-011 there) — assert it is reached, not re-tested.

---

### Case: Route % is routeDistanceKm ÷ subPathKm, capped at 100%
**ID:** TC-321
**Priority:** P0
**Type:** edge
**Covers:** AC-8

Given an active custom route with length `subPathKm` and several `routeDistanceKm` values (0, mid, == subPathKm, and an over-shoot beyond subPathKm)
When the route % is computed
Then it equals `routeDistanceKm ÷ subPathKm` — **0% at start, monotonically increasing, and capped at 100%** at/after `subPathKm` (never exceeds 100%)

**Notes:** Pure-function unit test. Assert the cap and the denominator is the **route's own** length, not the full chain. Encodes the AC-8 route-% half of the proposed "show both" decision.

---

### Case: Country % is routeDistanceKm ÷ totalChainKm, distinct from route %
**ID:** TC-322
**Priority:** P0
**Type:** edge
**Covers:** AC-8

Given an active custom route where `subPathKm < totalChainKm` and a `routeDistanceKm` value
When both percentages are computed
Then **country %** = `routeDistanceKm ÷ totalChainKm` (per `route-progress` decision 5, full-chain denominator) and **route %** = `routeDistanceKm ÷ subPathKm`, and the two are **different** numbers for a sub-path (country % < route % when `subPathKm < totalChainKm`) — both are shown

**Notes:** Pure-function unit test. Encodes the AC-8 proposed "show both" decision; a reviewer may drop one — re-confirm before pinning the UI to both. Assert both formulae and that they diverge for a strict sub-path.

---

### Case: Review screen / readout shows both route % and country %
**ID:** TC-323
**Priority:** P1
**Type:** happy-path
**Covers:** AC-8

Given an active custom route at a known `routeDistanceKm`
When the progress readout renders
Then it displays **both** the route % (`÷ subPathKm`) and the country % (`÷ totalChainKm`), each labelled so the user can tell them apart

**Notes:** Widget test. The render-layer companion to TC-321/TC-322. If the reviewer drops one % per AC-8, update this case to the single retained readout. Assert both labelled values are present.

---

### Case: Starting a new route while the current one has progress shows the abandon confirm guard
**ID:** TC-324
**Priority:** P0
**Type:** happy-path
**Covers:** AC-9

Given an active route with **progress to lose** (`routeDistanceKm > 0` and not completed)
When the user starts a new route
Then a **"you'll lose progress on this route" confirm guard** is shown before anything is abandoned

**Notes:** Widget test (`src/focus_journey/test/.../presentation/`). Assert the guard dialog appears when `routeDistanceKm > 0` and not completed. Pairs with TC-326 (no guard when there is nothing to lose) for the boundary.

---

### Case: Cancelling the abandon guard leaves the current route, offset, segments, and position completely untouched
**ID:** TC-325
**Priority:** P0
**Type:** edge
**Covers:** AC-9

Given the abandon confirm guard is shown for an active route with progress
When the user **cancels** the guard
Then the current route is unchanged — its `routeStartOffset`, its recorded idle/active segments, and its resolved position are **completely untouched**, **no** new offset is stamped, and the user remains on the current route (mirroring `route-progress` decision 3 / this spec's decision 3)

**Notes:** Widget + integration test. Assert zero writes and an unchanged offset/segments/position after cancelling the guard. The cancel-is-inert complement to AC-6's cancel.

---

### Case: No abandon guard appears when there is no progress to lose (boundary)
**ID:** TC-326
**Priority:** P1
**Type:** boundary
**Covers:** AC-9

Given the current route has **no progress to lose** — either `routeDistanceKm = 0` (just started, never moved) or the route is already **completed**
When the user starts a new route
Then **no** confirm guard is shown (there is nothing to lose) and the new-route flow proceeds directly to the picker/review — the guard is gated strictly on `routeDistanceKm > 0 && !completed`

**Notes:** Widget test. The lower boundary of AC-9 — guards against showing a needless warning at km=0 or after a completion. Cover both no-progress branches (km=0 and completed) as sub-cases.

---

### Case: Confirming abandon stamps a NEW routeStartOffset at the abandon instant
**ID:** TC-327
**Priority:** P0
**Type:** happy-path
**Covers:** AC-10

Given the user **confirms** the abandon guard with the engine at cumulative `distanceKm = D2` (fixture: D2 = 1180, after travelling the old route)
When the new route begins
Then a **new `routeStartOffset` = D2** is stamped at the abandon instant (reusing `route-progress` decision 1 — abandon = new offset), so the new route's `routeDistanceKm` starts at 0 from `D2`

**Notes:** Unit + integration test. Assert the new offset equals cumulative `distanceKm` at the abandon instant and that the new route's `routeDistanceKm` resets to 0 (offset-relative), while cumulative is preserved (TC-328).

---

### Case: Abandon never resets the engine's lifetime cumulative distanceKm (no engine reset API)
**ID:** TC-328
**Priority:** P0
**Type:** edge
**Covers:** AC-10

Given the engine at cumulative `distanceKm = D2` when the user confirms abandon
When the new route begins (new offset stamped per TC-327)
Then the engine's cumulative lifetime `distanceKm` is **still D2** immediately after — abandon **never resets** it (no engine reset API exists), so the lifetime total is unbroken across abandon-and-restart

**Notes:** Unit + integration test. **A gating reuse invariant** (mirrors `route-progress` decision 1 / `map-experience` TC-228 engine-untouched). Assert cumulative `distanceKm` is identical before and after abandon; assert no reset call path exists. Drive a fake distance source and confirm only an offset write, never a cumulative mutation.

---

### Case: An abandoned route is a distinct terminal state from completion — NO arrival celebration fires
**ID:** TC-329
**Priority:** P0
**Type:** edge
**Covers:** AC-10

Given an active route abandoned mid-way (confirmed) **before** `routeDistanceKm` reached `subPathKm`
When the abandon completes and the new route begins
Then the abandoned route enters a **distinct terminal state from completion** and does **NOT** fire the `route-progress` arrival celebration/summary (abandoned ≠ completed) — no false "you arrived"

**Notes:** Unit (state) + widget (no celebration surface) test. Assert the abandoned route's terminal state != completed and that the celebration/summary widget is **not** shown for an abandon. Contrast with TC-320 (real completion *does* celebrate).

---

### Case: Abandon-then-start is the only path to a fresh route; lifecycle survives the round-trip
**ID:** TC-330
**Priority:** P1
**Type:** happy-path
**Covers:** AC-10, AC-7

Given an active route with progress
When the user abandons it (confirm) and then reviews + confirms a **new** route
Then the new route stamps its own single offset (TC-317/TC-327), the lifetime cumulative `distanceKm` is preserved across the whole round-trip (TC-328), and the new route's position resolves via the unchanged resolver/projector over its own authored list (AC-7) — the user has a clean fresh route with no engine damage

**Notes:** Integration test (`src/focus_journey/integration_test/`) end-to-end through abandon→new-route. Ties AC-10 + AC-7 together; assert offset sequence (old → new), preserved cumulative, and correct new-route position.

---

### Case: New route's red idle trace shows ONLY the new offset's segments — no bleed from the abandoned route
**ID:** TC-331
**Priority:** P0
**Type:** edge
**Covers:** AC-11

Given a route was abandoned (its idle segments recorded against the **old** offset) and a new route started with a **new** offset
When the map overlay renders the new route
Then the red idle trace shows **only** the new `routeStartOffset`'s distance-keyed idle segments (those in the new route's `[newOffset, newOffset + routeDistanceKm)` window, re-based to the new route's arc-length) — **none** of the abandoned route's segments bleed onto the new route's trace (consistent with `map-experience` AC-8 "current route only")

**Notes:** Unit (segment-window filter) + widget (rendered trace) test. **Flagged risky area.** Whether the old segments are pruned or kept as inert history is a `system-architect` call — assert the *rendered* new-route trace excludes old-offset segments **either way**. Feed a record containing both old and new segments and assert only the new window is painted. Mirrors `map-experience` TC-214.

---

### Case: At the instant a new route starts (km=0), its red trace is empty regardless of abandoned-route history
**ID:** TC-332
**Priority:** P1
**Type:** boundary
**Covers:** AC-11

Given a freshly started new route at `routeDistanceKm = 0`, with the abandoned route's idle segments still present in the record
When the overlay renders
Then the new route's red trace is **empty** (no idle yet for the new offset) — no abandoned-route segment appears at or before the new route's origin

**Notes:** Unit + widget test. Lower boundary of the no-bleed invariant (TC-331). Assert zero red stretches at the new route's km=0 even though the record is non-empty.

---

### Case: The map overlay renders the custom route exactly as it renders the spine (current-route-only reuse)
**ID:** TC-333
**Priority:** P1
**Type:** edge
**Covers:** AC-11, AC-7

Given an active custom route (a sub-path) with recorded idle segments
When the map overlay + red idle trace render
Then they render the custom route via the **same** `map-experience` overlay + red-trace path used for the spine today — current-route-only, no new rendering path introduced — so an authored sub-path looks/behaves exactly like a spine route on the map

**Notes:** Widget test reusing the `map-experience` overlay against an authored sub-path. Assert the same overlay/painter path is used (no `route-planner-v2`-specific overlay) and the trace honours the current-route window. Reinforces AC-7's "reuse unchanged."

---

### Persistence + reuse invariant

### Case: An active custom route (authored list + offset + lifecycle state) survives an app restart unchanged
**ID:** TC-334
**Priority:** P0
**Type:** edge
**Covers:** AC-12

Given an active custom route persisted via the existing `shared_preferences`/JSON repository seam — the **authored ordered checkpoint list + `routeStartOffset` + lifecycle state** (active) — and a known engine cumulative `distanceKm`
When the app is restarted (a fresh Bloc/model restores from the saved blob)
Then the route descriptor is restored **unchanged** (same authored list, same offset, same lifecycle state) via the **existing** seam (no new store), and the resolved position and route % **match pre-restart** for the same engine `distanceKm`

**Notes:** Integration test (`src/focus_journey/integration_test/`) with the faked repository; the restore mapping is also unit-testable. Mirrors `route-progress` TC-009 / `map-experience` TC-215 persistence. Assert restored descriptor structurally equals the pre-restart one and that position/% recompute identically.

---

### Case: Restored route's red idle trace matches AC-11 (current route only) after restart
**ID:** TC-335
**Priority:** P1
**Type:** edge
**Covers:** AC-12, AC-11

Given an active custom route (possibly after a prior abandon, so the record may contain old-offset segments) persisted and then restored on restart
When the overlay re-renders post-restart
Then the restored route's red idle trace shows **only** the current offset's segments — identical to AC-11 (current route only) — with **no** bleed from any abandoned/prior route surviving the restart

**Notes:** Integration test. Combines persistence (AC-12) with the no-bleed invariant (AC-11) across a restart. Assert the post-restart trace equals the pre-restart current-route trace and excludes old-offset segments.

---

### Case: Lifecycle state (active / completed / abandoned) is persisted and restored, not recomputed wrongly
**ID:** TC-336
**Priority:** P1
**Type:** edge
**Covers:** AC-12

Given three persisted routes — one **active**, one **completed**, one **abandoned**
When each is restored on restart
Then each comes back in its **correct lifecycle state** — the completed route still shows completion (no re-celebration spuriously re-fired on restore), the abandoned route is still distinct-from-completion (no false celebration on restore), and the active route resumes travelling

**Notes:** Integration test. Guards the lifecycle-state half of AC-12. Assert restore does not re-fire the celebration for a completed/abandoned route and does not misclassify abandoned as completed. Leans on `route-progress` completion-persistence; asserts the new abandoned state persists distinctly.

---

### Non-functional

### Case: No device-location / GPS API; selection + auto-insert read only the static map-experience geography (static privacy)
**ID:** TC-337
**Priority:** P0
**Type:** edge
**Covers:** NFR-2

Given all `route-planner-v2` source (route model, auto-insert resolver, picker, review screen, abandon flow, persistence) and its dependency set
When inspected statically
Then the slice imports/calls **no** device-location / GPS / geolocation API (no `geolocator`/`location`/CoreLocation/geocoding/location platform channel), reads province lat/long + adjacency **only** from `map-experience`'s static app-shipped geography model (never a device read), and emits **no** new identifier or location trail — the persisted route descriptor is static reference IDs + a distance offset, not the user's position

**Notes:** Static-inspection case (`src/focus_journey/test/`, grep over imports + manifest). The automatable subset of the gating NFR-2. Mirrors `map-experience` TC-230. Assert the geography source is the shared static model and that the route descriptor carries no device-position field. The full promise (`/privacy-audit` PASS, runtime egress, "zero tracking on the most location-suggestive surface") is the audit gate TC-M-PRIV.

---

### Case: Selection / auto-insert / review / abandon make NO network call at all
**ID:** TC-338
**Priority:** P0
**Type:** edge
**Covers:** NFR-2, NFR-1

Given the picker, the auto-insert resolver, the review screen, and the abandon flow
When each is exercised (open picker, pick start+end, mark a stop, resolve, review+edit, confirm, abandon+restart) under a network seam that records any outbound request
Then **zero** outbound network requests originate from this slice — selection/auto-insert/review/abandon are pure in-memory + local-persistence operations introducing **no** new network surface beyond `map-experience`'s OSM tiles (which belong to the map overlay, not this slice)

**Notes:** Static + fake-network-seam test (`src/focus_journey/test/`). Mirrors `map-experience` TC-231 intent (data-free), here proving **no** request at all from the planning paths. Also reinforces NFR-1 ("never a network or disk round-trip" for auto-insert). The runtime egress confirmation is TC-M-PRIV.

---

### Case: Picker + review screen (editing + total-distance readout) + abandon dialog are keyboard-reachable and screen-reader labelled
**ID:** TC-339
**Priority:** P1
**Type:** edge
**Covers:** NFR-3

Given the endpoint/stop **picker**, the **review screen** (its remove/skip-intermediate controls and the total-distance readout), and the **abandon confirm dialog**
When the widget tree's semantics and keyboard focus traversal are inspected
Then every interactive element is **keyboard-reachable** (focusable + activatable via Tab/Enter, with Esc/cancel where applicable — no mouse-only path) and carries **meaningful semantic labels** (each selectable checkpoint, each editing control, the distance readout, and the confirm/cancel actions expose accessible names) — not relying on visual-only cues

**Notes:** Widget test (`src/focus_journey/test/.../presentation/`) asserting `Semantics` labels + keyboard focusability/activation across all three surfaces. The deterministic part of NFR-3. The **real screen-reader announcement quality + full keyboard-only operation** is the manual AT leg TC-M-A11Y. Mirrors `map-experience` TC-232.

---

### Case: Auto-insert / re-resolution is allocation-bounded and sub-frame; no per-edit network or disk round-trip
**ID:** TC-340
**Priority:** P1
**Type:** nfr
**Covers:** NFR-1

Given the auto-insert / route-resolution function and a review-screen edit sweep over the ~10–15-checkpoint spine
When resolution and each re-resolve are inspected and run
Then resolution is a small **in-memory pure-domain** computation (bounded by the checkpoint count, no per-resolve re-load of geography, **no** network/disk round-trip) and a re-resolve sweep completes effectively instantly — the deterministic guard behind NFR-1's "responsive, no visible jank"

**Notes:** Static inspection + micro-benchmark/redraw test (`src/focus_journey/test/`). The deterministic part of NFR-1; mirrors `map-experience` TC-229 hot-path guard. Assert no geography re-derivation per resolve and no I/O on the resolve path. The actual **no-jank fps on macOS/Windows** is on-device only — TC-M-NF1.

---

## Coverage table (AC / NFR → covering case IDs)

| Item | Description | Covered by |
|---|---|---|
| AC-1 | any start + any end → contiguous sub-path in spine order, direction implied; replaces fixed-start+N/S | TC-301, TC-302, TC-304, TC-305 |
| AC-2 | start==end disabled; 2-adjacent-checkpoint minimum (picker + review-edit) | TC-303, TC-305, TC-312 |
| AC-3 | auto-insert fills intermediates in spine order, consuming map-experience geography only (pure fn) | TC-306, TC-307, TC-308 |
| AC-4 | marked stop outside [start,end] extends the span | TC-308, TC-309 |
| AC-5 | review screen: ordered route + total distance, editable; remove/skip re-resolves | TC-310, TC-311, TC-312, TC-313 |
| AC-6 | ZERO side effect until confirm — snapshot identical across review+edit+cancel (critical) | TC-314, TC-315, TC-316 |
| AC-7 | confirm stamps one offset; position = pure fn of routeDistanceKm via unchanged resolver/projector, single km axis | TC-317, TC-318, TC-319, TC-330, TC-333 |
| AC-8 | route-relative completion at subPathKm; route % ÷subPathKm, country % ÷totalChainKm (both shown) | TC-320, TC-321, TC-322, TC-323 |
| AC-9 | abandon confirm guard when progress to lose; cancel inert; no guard at no-progress boundary | TC-324, TC-325, TC-326 |
| AC-10 | confirm abandon stamps NEW offset, never resets lifetime distance, NOT completion (no celebration) | TC-327, TC-328, TC-329, TC-330 |
| AC-11 | new route's red idle trace shows only the new offset's segments — no bleed | TC-331, TC-332, TC-333, TC-335 |
| AC-12 | active custom route (list + offset + lifecycle) survives restart via existing seam | TC-334, TC-335, TC-336 |
| NFR-1 | picker/auto-insert/review render + re-render with no visible jank on macOS+Windows | TC-316, TC-338, TC-340 (deterministic), TC-M-NF1 (on-device) |
| NFR-2 (CRITICAL gate) | only static map-experience geography; no GPS/location; no new network call; no new identifier/trail; /privacy-audit PASS | TC-307, TC-337, TC-338 (static), TC-M-PRIV (audit + runtime egress) |
| NFR-3 | picker + review (editing + distance) + abandon dialog keyboard-reachable + screen-reader labelled | TC-339 (deterministic), TC-M-A11Y (manual screen-reader + keyboard-only) |

Every AC (AC-1..AC-12) and every NFR (NFR-1..NFR-3) maps to at least one case. No AC is orphaned. The
TC-M* manual / on-device / audit legs live in
[route-planner-v2-manual-checklist.md](route-planner-v2-manual-checklist.md).
