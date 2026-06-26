# Route Planner v2 (flexible route selection + planning)

**Status:** shipped (2026-06-25, dev build — NFR-1 fps + NFR-3 screen-reader on-device legs carried to the manual checklist)
**Owner:** Kevin (Tuyen Vo)
**Last updated:** 2026-06-25 (shipped — dev build; `/execute-tests` green 877/877, report `tests/_runner/reports/route-planner-v2/20260625-110204/`; `/review-code` ready · `/privacy-audit` PASS; built on ADR-0005 sub-chain model; prior: approved by Kevin — 12 ACs + 3 NFRs, by-proposal AC-2/AC-4/AC-8 confirmed)

## Problem
Shipped `route-progress` models Vietnam as **one fixed ordered province chain** (Mũi Cà Mau ⇄ Hà Giang)
and lets the user pick only a **start province + a single direction** (toward one chain tip). They cannot
say "I want to go from Huế to Đà Lạt," mark the cities they care about along the way, or run anything but
the full N↔S spine. And once a journey is underway there is **no way to abandon it and start a fresh
one** — `route-progress` completion is *terminal until the user chooses*, so mid-route the only path is to
keep going. The journey feels like a fixed treadmill, not a trip the user authored.

This slice gives the user **authorship of the route** while reusing everything `route-progress` and
`map-experience` already shipped. It does three things (Wave 2 requests #8/#9/#10):
1. **Pick any start + any end** (#8) — replace "fixed start + N/S direction" with a free choice of any two
   checkpoints on the spine; the route is the **contiguous sub-path** between them (direction implied by
   which end is the start).
2. **Optional stops + auto-insert + review-before-start** (#9) — the user can mark provinces they care
   about; the app **auto-inserts the intermediate spine checkpoints** between the chosen endpoints (e.g.
   Huế → Đà Lạt auto-adds Đà Nẵng, Nha Trang…) and shows a **review screen** of the resolved, ordered
   route (with total distance) that the user can **edit** (remove/skip intermediates) before confirming
   "start." Reviewing has **zero side effect** until confirm.
3. **Stop & start a new journey** (#10) — abandon the current route mid-journey (with a **confirm guard**
   when there is progress to lose) and start a new one. Abandoning **never resets** the engine's lifetime
   distance and is **distinct from completion** (no arrival celebration fires).

**Why now.** This is Wave 2's tail, and both hard prerequisites just shipped: `route-progress`
(2026-06-24 — the province chain + `routeStartOffset` position math) and `map-experience` (2026-06-25 —
the single static province-geography model: real lat/long + adjacency). #9's auto-insert **consumes** that
geography model (build-once-consume-many); this slice never re-derives or forks geography. Framing this
last unblocks closing Wave 2.

Like its predecessors, this slice is a **pure consumer of engine distance**: it owns *route selection +
planning + lifecycle* but adds **zero** activity logic and **zero** new privacy surface — no OS signal, no
device location/GPS, no network beyond the OSM tiles `map-experience` already introduced.

## User & outcome
- **The focused individual** (developer / student / remote worker) — primary. Success = agency over
  *where* their focus walks them: choose real endpoints, mark the cities they care about, get a sane
  auto-completed route they can review and tweak before committing, and scrap a route to start fresh
  without losing their lifetime total. Observable: opens route selection, picks Huế → Đà Lạt + a stop,
  sees the resolved ordered route on a review screen, edits it, confirms, and travels it; later abandons
  it (after confirming) and starts a new route — lifetime distance unbroken, no false celebration.
- **The privacy-skeptical teammate** — the gating reviewer. Typing/picking real provinces is the most
  location-*suggestive* interaction the product has shipped, so success = the picker + auto-insert
  demonstrably read **only static province reference geography** (lat/long + adjacency from
  `map-experience`) — no device location, no GPS, no new outbound signal. `/privacy-audit` stays PASS.

## Scope
### In
- **Flexible endpoint selection (#8)** — pick **any one start checkpoint and any one end checkpoint** from
  the curated ~10–15 spine (replacing the shipped fixed-start + binary-direction picker). Direction is
  implied by which end is the start. Persisted via the existing `shared_preferences`/JSON repository seam.
- **Optional user stops + auto-insert (#9)** — the user may mark intermediate provinces they care about;
  the app resolves the route by **auto-inserting the spine checkpoints between** the chosen
  endpoints/stops, in spine order, using **only** `map-experience`'s static geography model.
- **Review-before-start screen (#9)** — shows the resolved ordered route (start → … → end) + total route
  distance before any `routeStartOffset` is stamped; the user can **edit** it (remove/skip auto-inserted
  intermediates) and then **confirm "start"** or **cancel** back to the picker. Reviewing/editing/cancel
  have **zero side effect** on the engine, recorded segments, or position until confirm.
- **Stop-and-restart lifecycle (#10)** — abandon the current route mid-journey and start a new one.
  Abandon stamps a **new `routeStartOffset`** at the abandon instant (reusing route-progress decision 1),
  **never resets** the engine's cumulative `distanceKm` (lifetime total preserved), shows a
  **confirm guard** when the current route has progress to lose, and is a **distinct terminal state from
  completion** — an abandoned route does **not** fire the arrival celebration.
- **Custom-route position + progress** — reuse `route-progress`'s position math and `map-experience`'s
  `RoutePolylineProjector` **unchanged** over the authored ordered checkpoint list: position stays a pure
  function of `routeDistanceKm` on the single canonical-km axis. The map overlay + red idle trace render
  the custom route exactly as they render the spine today (current-route-only).
- **Route-relative completion** — a custom route **completes** when `routeDistanceKm` reaches the chosen
  sub-path length (its own end), with the existing celebration/summary; "% complete" of the *route* is
  `routeDistanceKm ÷ subPathKm` (the route's own length).

### Out
- **Re-deriving / forking geography** — the province lat/long + adjacency model is owned by
  `map-experience`; this slice consumes it as-is (build-once-consume-many).
- **Distance accrual / activity logic / idle classification** — owned by the engine + `idle-accounting`;
  unchanged. No engine reset API is added (abandon = new offset, per route-progress decision 1).
- **Branching / non-linear geography or arbitrary nationwide routing** — geography is the curated ~10–15
  linear spine; a route is always a contiguous stretch of it. No off-spine provinces, no road graph.
- **Per-mode speeds / energy** (`journey-energy-model`); the POV reframing (`journey-pov`); map overlay
  rendering itself (owned by shipped `map-experience` — reused, not rebuilt here).
- **Any device-location / GPS read or new network surface.**

## Constraints & assumptions
- **Privacy invariant (hard):** route selection + auto-insert read **only static province reference
  geography**; no device location, no GPS, no new outbound signal beyond `map-experience`'s OSM tiles.
  `/privacy-audit` must stay PASS by construction.
- **Position-invariant preservation (gating):** "position = pure function of `routeDistanceKm`" and
  `map-experience` ADR-0004's **single canonical-km axis** must stay true after generalizing the chain.
  `RouteProgressResolver` + `RoutePolylineProjector` must run **unchanged** over an arbitrary authored
  ordered checkpoint list (not just the hard-coded full spine) with the same determinism + unit-test rigor.
- **Reuse the `routeStartOffset` primitive (route-progress decision 1):** a route is just a
  `routeStartOffset` over the engine's never-reset cumulative `distanceKm`; abandon-and-restart = stamp a
  new offset. No engine change.
- **Geography is the curated linear spine:** every selectable start/end/stop is a checkpoint **on** the
  ~10–15 spine; a custom route is a contiguous sub-path. There is no branching geography to route through.
- **Persistence reuses the existing seam** — the active-route descriptor (authored ordered checkpoint list
  + offset + lifecycle state) saves via the established `shared_preferences`/JSON repository pattern, not
  a new store; the current route survives restart.
- **Pure domain auto-insert:** the auto-insert / route-resolution logic is a **pure, deterministic,
  Flutter-free domain function** (mirroring `RouteProgressResolver`), unit-testable without timers/Flutter.
- **Stack per `docs/architecture/overview.md`** — Flutter desktop, Bloc, Clean Architecture: route model +
  auto-insert + position math are *domain*; persistence is *data*; picker + review screen + abandon flow
  are *presentation*.
- **Supersession to record (ADR):** this supersedes `route-progress`'s single-chain + start+direction
  selection and its terminal-only completion lifecycle (which never contemplated abandonment) — needs an
  ADR + an update to the `route-progress` spec/overview narrative, not a silent override.

## Resolved decisions (Kevin, 2026-06-25 — at spec kickoff)
1. **Route model = contiguous sub-path of the spine (#8).** "Many start, many end provinces" resolves to:
   freely choose **any one start checkpoint and any one end checkpoint** on the spine; the route is the
   contiguous sub-path between them, direction implied by which end is the start. Reuses route-progress
   position math + ADR-0004 projector verbatim. **Rejected:** parallel/branching chains (would break the
   single position axis) — there is no branching geography anyway.
2. **Auto-inserted intermediates are editable on the review screen (#9).** The review screen shows the
   full resolved route (chosen endpoints/stops + auto-filled spine checkpoints between) and lets the user
   **remove/skip** intermediates before confirming "start." Reviewing/editing has **zero side effect**
   until confirm; cancel returns to the picker with nothing recorded.
3. **Abandon requires a confirm guard when there is progress to lose (#10).** Starting a new route while
   the current one has progress shows a "you'll lose progress on this route" confirm. Either way the
   engine's lifetime `distanceKm` is **never reset**, and an abandoned route is **distinct from a
   completed one** — it does **not** fire the arrival celebration.

## Acceptance criteria
Each item is a checkable, observable statement and the ship gate. If it isn't testable, rewrite it.
These ACs ARE the contract — `tests/cases/route-planner-v2.md` references them by ID; there is no separate
acceptance-criteria file.

_Proposed by `product-domain-expert` and **approved by Kevin (2026-06-25)**. The by-proposal resolutions
flagged inline (AC-2 minimum/start≠end · AC-4 extend-the-span · AC-8 show both %s) are **confirmed**._

_**Test status (`/execute-tests`, 2026-06-25, verdict green — 877/877):** `[x]` = verified by automation;
report `tests/_runner/reports/route-planner-v2/20260625-110204/`. AC-1..AC-12 + NFR-2 ticked (incl. gating
AC-6 zero-side-effect snapshot, AC-7 unchanged-cores, AC-10/AC-11 abandon no-bleed; `/privacy-audit` PASS).
**NFR-1 (no-jank fps macOS/Windows) and NFR-3 (real screen-reader) stay `[ ]`** — their deterministic
portions pass but the gating verification is on-device-only and is carried to
`tests/cases/route-planner-v2-manual-checklist.md` (TC-M-NF1, TC-M-A11Y) as pre-public-release legs, plus
TC-M-PRIV runtime-egress capture (NOT a failure)._

**Endpoint selection (#8)**

- [x] AC-1 (any start + any end → contiguous sub-path, direction implied): Given the curated ~10–15
      province spine (Mũi Cà Mau ⇄ Hà Giang), When the user picks **any one start checkpoint** and **any
      one end checkpoint** on the spine, Then the resolved route is the **contiguous sub-path** between
      them taken **in spine order from start toward end** (direction implied by which end is the start),
      containing every spine checkpoint between the two endpoints inclusive — replacing the shipped
      fixed-start + binary N/S-direction picker.
- [x] AC-2 (start == end disallowed; 2-adjacent-checkpoint minimum, blocked in picker): Given the picker,
      When the user has chosen a start checkpoint, Then selecting the **same** checkpoint as the end is
      **disabled/unavailable** (a route can never be zero-length), AND the smallest valid route is **two
      adjacent spine checkpoints** — mirroring `route-progress` decision 3 ("block invalid selection in
      the picker") so the model never enters a zero-checkpoints-ahead state at `routeDistanceKm = 0`.
      _Proposed resolution to Open question "minimum is a 2-checkpoint route, and is start == end
      disallowed?" — reviewer may adjust._

**Auto-insert + review gate (#9)**

- [x] AC-3 (auto-insert fills intermediates in spine order, consuming map-experience geography only):
      Given chosen endpoints (and any marked stops), When the route is resolved, Then the app
      **auto-inserts every spine checkpoint that lies between** the endpoints, in **spine order**, so the
      resolved route is the ordered list `start → …intermediates… → end`, AND the resolution reads
      **only** `map-experience`'s single static province-geography model (lat/long + adjacency) — it
      **never re-derives, forks, or re-orders** geography (build-once-consume-many). The auto-insert is a
      pure, deterministic, Flutter-free domain function (mirroring `RouteProgressResolver`).
- [x] AC-4 (marked stop outside the [start, end] span extends the span): Given a marked stop that lies on
      the spine **outside** the span between the chosen start and end, When the route is resolved, Then
      the span is **extended to the farther of the two endpoints so the stop is included** (the route is
      still a single contiguous sub-path in spine order; the stop becomes the new extreme endpoint in its
      direction), AND the review screen reflects the extended endpoints. _Proposed resolution to Open
      question "what happens if a marked stop lies outside the [start, end] span (reject / extend /
      ignore)?" — **extend the span**; reviewer may instead choose reject-with-message or ignore._
- [x] AC-5 (review screen shows resolved ordered route + total distance, editable): Given a resolved
      route, When the **review-before-start** screen is shown, Then it displays the full **ordered** route
      (`start → … → end`) **and the total route distance** (km), AND the user can **remove/skip
      auto-inserted intermediates** before committing; removing an intermediate re-resolves the displayed
      ordered route and total distance with the remaining checkpoints (endpoints are not removable below
      the AC-2 minimum).
- [x] AC-6 (ZERO side effect until confirm — critical invariant): Given the user is on the review screen
      reviewing, editing, or cancelling, When they do **anything other than confirm "start"**, Then **no**
      `routeStartOffset` is stamped, **no** recorded idle/active segment is created or altered, the
      engine's cumulative `distanceKm` and the current position are **unchanged**, and **no** persisted
      route state is written — **cancel** returns to the picker with **nothing recorded**. Confirm "start"
      is the **only** mutation. (Testable: snapshot offset/segments/position/persisted-state before and
      after a full review+edit+cancel cycle — they are byte-for-byte identical.)
- [x] AC-7 (confirm "start" stamps the route; position stays a pure function of routeDistanceKm on the
      single canonical-km axis): Given a reviewed route, When the user confirms **"start"**, Then exactly
      one `routeStartOffset` is stamped (= engine cumulative `distanceKm` at that instant, per
      `route-progress` decision 1) and travel begins, AND the traveller's position is computed by the
      **unchanged** `RouteProgressResolver` + `map-experience`'s `RoutePolylineProjector` as a **pure
      function of `routeDistanceKm`** (`= engine.distanceKm − routeStartOffset`) over the **authored
      ordered checkpoint list** — preserving ADR-0004's **single canonical-km axis** (no second distance
      axis, no second geography definition is introduced).

**Stop-and-restart lifecycle (#10)**

- [x] AC-8 (route-relative completion + route %): Given an active custom route of length `subPathKm`,
      When `routeDistanceKm` reaches `subPathKm` (the chosen end), Then the route enters **completed** and
      fires the existing `route-progress` celebration/summary, AND **"% complete" of the route** is
      `routeDistanceKm ÷ subPathKm` capped at 100% (the route's own length, distinct from the
      full-chain % which stays `routeDistanceKm ÷ totalChainKm` per `route-progress` decision 5).
      _Proposed resolution to Open question "% of country vs % of route for a sub-path" — **show both**:
      route % against `subPathKm` and country % against `totalChainKm`; reviewer may drop one._
- [x] AC-9 (abandon mid-route requires a confirm guard when there is progress; cancel is inert): Given an
      active route with **progress to lose** (`routeDistanceKm > 0` and not completed), When the user
      starts a new route, Then a **"you'll lose progress on this route" confirm guard** is shown, AND
      **cancelling** the guard leaves the current route, its offset, its segments, and its position
      **completely untouched** (no new offset stamped) — mirroring `route-progress` decision 3 / spec
      decision 3.
- [x] AC-10 (abandon stamps a NEW offset, never resets lifetime distance, is NOT completion): Given the
      user **confirms** the abandon guard, When the new route begins, Then a **new `routeStartOffset`** is
      stamped at the abandon instant, the engine's cumulative lifetime `distanceKm` is **never reset** (no
      engine reset API exists — abandon = new offset), AND the abandoned route enters a **distinct
      terminal state from completion** — it does **NOT** fire the arrival celebration/summary (abandoned ≠
      completed).
- [x] AC-11 (new route's red idle trace shows only the new offset's segments — no bleed): Given a route
      was abandoned and a new one started, When the map overlay renders, Then the red idle trace shows
      **only the new `routeStartOffset`'s** distance-keyed idle segments — **none** of the abandoned
      route's segments bleed onto the new route (consistent with `map-experience` AC-8 "current route
      only"; whether the abandoned route's segments are pruned or kept as inert history is a
      system-architect call, but they must never appear on the new route's trace).

**Persistence + reuse invariant**

- [x] AC-12 (active custom route survives app restart): Given an active custom route (authored ordered
      checkpoint list + `routeStartOffset` + lifecycle state: active / completed / abandoned), When the
      app is restarted, Then the route descriptor is restored **unchanged** via the existing
      `shared_preferences`/JSON repository seam (no new store), the resolved position and route % match
      pre-restart for the same engine `distanceKm`, and the restored route's red idle trace is the same as
      AC-11 (current route only).

### Non-functional
- [ ] NFR-1 Performance: The picker, auto-insert resolution, and review screen render and re-render
      **responsively with no visible jank** on macOS and Windows desktop; for the curated ~10–15-checkpoint
      spine, auto-insert / route re-resolution (including each review-screen edit) completes **effectively
      instantly** (well within one frame) — it is a small in-memory pure-domain computation, never a
      network or disk round-trip.
- [x] NFR-2 Security/Privacy (**CRITICAL — gating**): Endpoint/stop selection and auto-insert read
      **only** `map-experience`'s **static province reference geography** (lat/long + adjacency). The
      feature reads **no** device location / GPS, introduces **no** new outbound network signal beyond the
      OSM tiles `map-experience` already ships (selection/auto-insert/review/abandon make **no** network
      call at all), and emits **no** new identifiers or location trail. Province data is static
      app-supplied reference data, never the user's position. `/privacy-audit` stays **PASS** by
      construction.
- [ ] NFR-3 Accessibility: The endpoint/stop **picker**, the **review screen** (including its
      remove/skip-intermediate editing controls and the total-distance readout), and the **abandon confirm
      dialog** are **keyboard-reachable** (full tab/enter/escape operation, no mouse-only paths) and
      **screen-reader labelled** with meaningful semantics (each checkpoint, each editing control, and the
      confirm/cancel actions expose accessible names) — not relying on visual-only cues.

## Open questions
> Three of the four below now carry a **proposed resolution** in the ACs (flagged inline); Kevin confirms
> or adjusts at approval. The fourth (abandoned-segment storage) is deferred to `system-architect` at
> implement time and does not block approval.
- [ ] Auto-insert **ordering/selection rule** when chosen stops sit between endpoints — strictly spine
      order between the extreme picks (expected), and what happens if a marked stop lies *outside* the
      [start, end] span? **→ proposed in AC-3 (spine order) + AC-4 (extend the span); confirm/adjust.** —
      owner: product-domain-expert
- [ ] Editing the review route down to **just two adjacent checkpoints** (or removing all intermediates) —
      is the minimum a 2-checkpoint route, and is start == end disallowed (mirrors route-progress
      decision 3)? **→ proposed in AC-2 (2-adjacent minimum; start == end blocked); confirm/adjust.** —
      owner: product-domain-expert
- [ ] "% of country" vs "% of route" readout for a **sub-path** route — does the map still show % of full
      chain (`÷ totalChainKm`) alongside route % (`÷ subPathKm`)? **→ proposed in AC-8 (show both);
      confirm/adjust.** — owner: product-domain-expert
- [ ] Abandoned-route **idle/active segments** (per `idle-accounting`, distance-keyed by old offset) —
      kept as history or pruned? Either way the new route's red trace must show **only** the new offset's
      segments (no bleed, gated by AC-11). **Deferred to implement time; non-blocking for approval.** —
      owner: system-architect

## Related
- Backlog framing: [planning/backlog/route-planner-v2.md](../../planning/backlog/route-planner-v2.md)
- Wave 2 batch: [planning/backlog/wave2-feature-requests.md](../../planning/backlog/wave2-feature-requests.md)
- Depends on (shipped): [specs/route-progress/spec.md](../route-progress/spec.md) (chain + `routeStartOffset` + position math) · [specs/map-experience/spec.md](../map-experience/spec.md) (single geography model + `RoutePolylineProjector`, ADR-0004) · [specs/idle-accounting/spec.md](../idle-accounting/spec.md) (per-route segments)
- Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md)
- Architecture: [docs/architecture/](../../docs/architecture/) — ADR-0002 (stack), ADR-0003 (single-window), ADR-0004 (single km axis + projector)
