# Map experience

**Status:** shipped (2026-06-25, dev build — AC-11/NFR-1/NFR-3 on-device legs carried to the manual checklist)
**Owner:** Kevin (Tuyen Vo)
**Last updated:** 2026-06-25 (shipped — dev build; prior: AC-5 reconciled to ADR-0004 — single `routeDistanceKm` axis projected via `RoutePolylineProjector`; OSM/network supersession recorded; prior: approved by Kevin, AC-9 idle-cause + AC-10 lifecycle states accepted as proposed)

## Problem
Geography in the app lives in two disconnected places. The shipped `route-progress` map is a **separate
tab** drawing a stylized, custom-painted province polyline (no real coordinates; "no live tiles in v1"),
while the just-shipped `idle-accounting` feature silently records ordered **active-vs-idle route
segments** keyed by distance-along-route — data nobody can yet *see*. The result: the map feels like a
side panel rather than part of the journey, and the freshly-captured idle data has no visual home.

This feature folds the map into the journey itself and gives the idle data a home:
1. **Map overlay on the journey tab, full-screen on tap** (request #4) — replace the standalone Map tab so
   place is always glanceable from where the user already is.
2. **Idle painted red on the map road** (request #7) — turn the invisible idle segments from
   `idle-accounting` into a felt "where I drifted off" trace.
3. **Real Vietnam geography** (absorbs the retired `map-geographic` candidate) — province lat/long +
   adjacency so the road follows the actual country, not a stylized line.

**Why now.** Both hard prerequisites shipped today (2026-06-24): `route-progress` (province-chain +
position model) and `idle-accounting` (the distance-keyed active/idle segment record, explicitly designed
as "the contract for `map-experience` #7"). This feature is also the **provider** of the real-geography
province model that `route-planner-v2` (#9 waypoint auto-insert) will consume next.

## User & outcome
- **The focused individual** (developer / student / remote worker) — primary. Success = a map that is part
  of the journey (not a detour), with their focus-vs-drift honestly traced in red along a real Vietnam
  route. Observable: opens the journey tab, sees the map inline + the red idle trace; taps to go
  full-screen; no separate Map tab to hunt for.
- **The privacy-skeptical teammate** — the gating reviewer. Success = the most location-suggestive surface
  the product has ever shipped (real lat/long + a "where idle" trace) demonstrably adds **zero** tracking
  surface: only aggregate idle *duration* mapped to route *distance*, no device location, no GPS, no
  timestamp trail. `/privacy-audit` stays PASS.

## Scope
### In
- Map **overlay** embedded on the journey tab; **tap → full-screen** (same window, per ADR-0003), dismiss
  back to inline. Standalone **Map tab removed**.
- **Real Vietnam province geography** — static lat/long + chain ordering/adjacency reference data for the
  existing ~10–15 province chain (Mũi Cà Mau ⇄ Hà Giang). The **single geography model**, owned here,
  that `route-planner-v2` will later consume.
- **Red idle trace**: render `idle-accounting`'s distance-keyed idle segments for the **current route**
  onto the map road geometry (a defined distance→polyline mapping). Active segments not red.
- Map tiles via `flutter_map` + OSM (the dependency ADR-0002 deferred to v2), with **offline/no-network
  fallback** and OSM attribution.
- Reuse the existing `route-progress` position math (position = pure function of `routeDistanceKm`) and the
  `idle-accounting` segment record as-is — this feature is a **pure visualizer**.

### Out
- Re-deriving or re-classifying idle (owned by `idle-accounting`); accruing distance (owned by the engine).
- Flexible route selection / multi-stop / waypoint auto-insert — that's `route-planner-v2` (consumes this
  feature's geography model; not built here).
- Per-mode speeds / energy model (`journey-energy-model`); the POV reframing (`journey-pov`).
- Any device-location / GPS read. Province lat/long is **static reference data**, never the user's position.
- Arbitrary nationwide routing — the chain stays the curated ~10–15 checkpoints.

## Constraints & assumptions
- **Privacy invariant (hard):** only aggregate idle duration mapped to route distance is visualized — no
  GPS, no device location, no timestamped per-event trail. Tile requests carry no user data.
  `/privacy-audit` must stay PASS by construction.
- **Network is new to this product.** The app has been fully offline to date; a tile fetch is the first
  outbound call. Must degrade gracefully with no connectivity and respect OSM tile-usage policy.
- **Supersession to record:** the "no live tiles / no network, custom-painted map" stance lives in
  `docs/architecture/overview.md` + the `route-progress` spec (not a standalone ADR; ADR-0002 already
  deferred `flutter_map`+OSM to v2). Shipping this needs an ADR recording the supersession + an overview update.
- **Same-window navigation** (ADR-0003 single-window two-mode): the full-screen map is a same-window
  surface, not a new window.
- **Carry-forwards from `idle-accounting` must be settled here** (see Open questions): persist `idleSince`
  (S-3) and decide the segment **day-key** (S-1), so the trace survives restart and shows the current route only.
- **Desktop targets:** macOS + Windows; `flutter_map` tile rendering/caching/perf must hold on both.
- **State:** existing Bloc state drives the surface; no change to `JourneyEngine`, the ticker, or `ActivityPlugin`.

## Acceptance criteria
Each item is a checkable, observable statement and the ship gate. If it isn't testable, rewrite it.
These ACs ARE the contract — `tests/cases/map-experience.md` references them by ID; there is no separate
acceptance-criteria file.

_Approved by Kevin (2026-06-24). **Test status (`/execute-tests`, 2026-06-25, verdict green — 730/730):**
`[x]` = verified by automation; report `tests/_runner/reports/map-experience/20260625-004844/`. AC-11,
NFR-1, NFR-3 stay `[ ]` — their automatable portions passed but the gating verification (real OSM
round-trip TC-M1/2; ≥30fps TC-M-NF1; colour-blind TC-M3 + screen-reader TC-M4) is on-device-only and is
carried to `tests/cases/map-experience-manual-checklist.md` as a pre-public-release leg (NOT a failure)._

**Overlay + full-screen (request #4)**

- [x] AC-1 (overlay is inline on the journey tab; no Map tab): Given the app is running, When the user
      is on the journey tab, Then a map overlay is rendered inline on that tab, AND the navigation
      contains **no standalone "Map" tab** (the shipped `route-progress` Map tab is removed).
- [x] AC-2 (tap opens full-screen in the same window): Given the inline map overlay is shown on the
      journey tab, When the user taps the overlay, Then the map opens **full-screen within the same
      window** (per ADR-0003 single-window two-mode — no new OS window is spawned).
- [x] AC-3 (dismiss returns to inline): Given the map is full-screen, When the user dismisses it (close
      affordance / back / Esc), Then the map returns to the inline overlay on the journey tab and the
      journey tab remains functional.

**Real Vietnam geography**

- [x] AC-4 (provinces at real lat/long, chained in order): Given the curated ~10–15 province chain
      (Mũi Cà Mau ⇄ Hà Giang), When the map road is drawn, Then each province checkpoint is placed at
      its **real lat/long** and the road polyline connects checkpoints in **chain order**, tracing the
      actual country outline — not a stylized straight line.
- [x] AC-5 (single distance axis + single geography model): Given the province-geography reference data,
      When the current marker is placed on the road, Then it is placed from the **same `routeDistanceKm`
      value** the `route-progress` `RouteProgressResolver` computes — the single shared distance axis —
      projected onto the polyline by `RoutePolylineProjector.coordinateAt` (a new distance→coordinate
      function; the resolver itself produces no coordinate), AND the geography model is the single source
      consumed by the overlay (the same model `route-planner-v2` will later consume) — this feature
      introduces **no second distance axis and no second geography definition**.
      _(Reconciliation of the earlier "no new projection function" phrasing recorded in ADR-0004(b).)_

**Red idle trace (request #7)**

- [x] AC-6 (idle renders red on the matching road stretch): Given the current route has recorded idle
      segments from `idle-accounting` (distance-keyed `{start, end, classification, cause}`), When the
      overlay renders, Then each idle segment is drawn **red** along the road on the polyline stretch
      whose distance-along-route span matches the segment's `[start, end)`, AND active segments are
      **not** drawn red.
- [x] AC-7 (zero-idle route draws no red): Given the current route has no idle segments, When the
      overlay renders, Then **no red trace** is drawn anywhere on the road.
- [x] AC-8 (current route only, survives restart): Given idle segments span more than the current route
      (per `routeStartOffset` and day-split), When the overlay renders, Then it shows **only the current
      route's** trace — not the lifetime total — AND after an app restart the current route's red trace
      is restored unchanged (carry-forward: `idleSince` persisted, segment day-key settled per
      `idle-accounting` S-3/S-1).
- [x] AC-9 (voluntary vs lock/sleep both render red, distinguished by pattern): **(decision confirmed —
      solid vs dashed red, non-colour cue)** Given idle segments tagged `voluntary` and `lock/sleep` from `idle-accounting`, When the
      overlay renders, Then **both render as red** (a single "drifted off" colour, so the felt message
      stays simple), but they are **visually distinguished by a secondary non-colour cue** (e.g.
      solid red for voluntary vs hatched/dashed red for lock/sleep) so the cause is recoverable without
      relying on colour alone. _Proposed resolution to Open question "voluntary vs lock/sleep: same red
      or distinguished?" — reviewer may collapse to identical red or split into two hues._

**Overlay states across the route lifecycle**

- [x] AC-10 (defined states at start / mid-route / completion): Given `routeDistanceKm = 0` (route
      start), When the overlay renders, Then the start province marker is shown at the chain origin with
      no red trace and no progress drawn; AND given mid-route, the current marker sits at its
      `routeDistanceKm` position with the red trace covering only recorded idle spans behind it; AND
      given the route is **completed** (distance reached the chain end), the overlay shows the full road
      with the destination reached and the complete-route idle trace, consistent with the
      `route-progress` completion/celebration state (the overlay does not block or alter completion).

**Tiles + offline + pure-visualizer invariant**

- [ ] AC-11 (tiles via flutter_map+OSM with attribution; graceful offline fallback): Given network
      connectivity, When the map renders, Then map tiles load via `flutter_map` + OSM **with OSM
      attribution visibly shown**; AND given **no network**, the map degrades to a **defined fallback**
      (last-cached tiles if available, otherwise a static/blank base on which the province road, markers,
      and red trace still render) — the journey tab never breaks, errors, or blocks on a failed tile
      fetch.
- [x] AC-12 (pure visualizer — no re-classification, no accrual): Given the overlay is active, When it
      renders the road and red trace, Then it **reads existing `idle-accounting` segment data and
      `route-progress` position as-is** and performs **no** idle re-classification and **no** distance
      accrual — `JourneyEngine`, the ticker, and `ActivityPlugin` are unchanged, and toggling/removing the
      overlay does not alter any recorded segment or distance value.

### Non-functional
- [ ] NFR-1 Performance: The map overlay, road polyline, and red idle trace render and re-render within
      a smooth frame budget (**≥ 30 fps, no visible jank**) on both macOS and Windows desktop, including
      the inline↔full-screen transition and a route with the maximum expected idle-segment count.
- [x] NFR-2 Security/Privacy (**CRITICAL — gating**): The feature visualizes **only** aggregate idle
      *duration* mapped to route *distance* plus **static province reference lat/long**. It reads **no**
      device location / GPS, emits **no** timestamped per-event or per-location trail, and tile requests
      carry **no** user data (no identifiers, no location, no idle data in the request). Province lat/long
      is static app-supplied reference data, never the user's position. `/privacy-audit` stays **PASS**.
- [ ] NFR-3 Accessibility: The red idle trace is distinguishable **beyond colour alone** (per AC-9's
      non-colour cue) so colour-blind users can perceive idle stretches and tell causes apart; the
      inline↔full-screen toggle and dismiss affordance are **keyboard-reachable and screen-reader
      labelled**; map controls expose meaningful semantics rather than relying on visual-only cues.

## Open questions
- [ ] Real lat/long geography vs a curated province-adjacency list — which backs the model? — owner: system-architect
- [ ] Distance-keyed idle segment → map polyline geometry mapping rule (across province boundaries/curves) — owner: system-architect
- [ ] Voluntary vs lock/sleep idle cause: same red, or distinguished on the overlay? — owner: product-domain-expert
- [ ] Carry-forward: persist `idleSince` (idle-accounting S-3) + segment **day-key** (S-1) — owner: code-generator
- [ ] Offline / no-network tile behaviour + tile-cache strategy + OSM attribution — owner: system-architect
- [ ] Overlay states at `routeDistanceKm` = 0 / mid-route / completed (celebration) — owner: product-domain-expert

## Related
- Backlog framing: [planning/backlog/map-experience.md](../../planning/backlog/map-experience.md)
- Wave 2 batch: [planning/backlog/wave2-feature-requests.md](../../planning/backlog/wave2-feature-requests.md)
- Depends on (shipped): [specs/route-progress/spec.md](../route-progress/spec.md) · [specs/idle-accounting/spec.md](../idle-accounting/spec.md)
- Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md)
- Architecture: [docs/architecture/](../../docs/architecture/)
