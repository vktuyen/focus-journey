# Route real-road visualization — curved road + start/end/stop marker hierarchy

**Status:** shipped (2026-07-16)
**Owner:** Kevin (Tuyen Vo)
**Last updated:** 2026-07-16
**Wave:** refine-app-ui-ux (slice 3; builds on shipped `vietnam-map-fidelity` + staged `province-chain-2026`)

## Problem
province-chain-2026 modelled the journey as **one spine that visits all 34 provinces**, so the drawn route is a
**tour** that detours inland (worst in the north: it zig-zags west to Sơn La / Điện Biên / Lai Châu then back east
to Lạng Sơn / Cao Bằng) with an **equal, oversized pin on every province**. Kevin's correction (2026-07-16, with a
screenshot): that is not a route — a route should be the **shortest sensible path** from start → end **through only
the planned stops**, drawn as a smooth **coastal sweep** that hugs the coast and stays on land, WITHOUT detouring
to visit every province. Provinces the sweep passes are shown as **small grey dots** (fill along the path); inland
provinces off the sweep get nothing. Only the start, end, and user-added stops are big markers. This **supersedes
province-chain-2026's "traverse all 34" route model** — its province *data* (names, coords, 2026 units, map)
stays; the *route derived from it* changes. Separately, the "Factory reset" label reads harshly → rename it.

**Model (confirmed with Kevin 2026-07-16, after 2 wrong iterations):** connecting province centre-points (even
splined) is the wrong model — it draws near-straight legs that cut across the sea and dots every province, which
is NOT how Google/Apple Maps draw a route. Real map apps stitch **actual road geometry** and mark only
start/end/stops. Since the app is offline (zero-network privacy promise), Kevin chose to **bundle Vietnam's real
national highway (QL1A + the connector to the northern terminus) sourced from OpenStreetMap** as a static,
license-clean (ODbL, attributed) polyline. The route follows the REAL road; markers appear ONLY on start, end,
and user-added stops (Google-style) — no per-province dots. Sourcing happens at DEV/BUILD time; runtime stays
100% offline (same posture as the ADR-0008 bundled base map).

## User & outcome
- **Focused individual:** opens the map and sees one **smooth, curved road** tracing up Vietnam through the coast
  provinces (not a straight line, stays on land), with a **big marker on the start and the end** and **small grey
  markers** on the provinces the road passes through. Adding a stop adds a **third big marker** (a via-point).
- Observable success: the route line is visibly curved (not straight segments); exactly the endpoints (+ any
  user-added stops) are big/highlighted; all other on-route provinces are small grey; the road still hugs the
  coast on land (no regression to province-chain-2026 AC-5); the Settings reset action no longer says "Factory
  reset".

## Scope
### In
- **Bundle the real highway (dev-time sourcing):** source Vietnam's national road (QL1A south→north, plus the
  connector to the northern terminus Cao Bằng, e.g. QL3/QL4) from OpenStreetMap as a **license-clean (ODbL)**
  polyline; simplify/decimate it to a reasonable vertex budget; **project it onto the shipped equirectangular
  bounds** (N24/S8 · W101.8/E110.3, same as the base map) and bundle it as a static offline GeoJSON asset under
  `assets/map/`. Record ODbL attribution in `assets/CREDITS.md`. NO runtime network — sourcing is dev-time only.
- **Route follows the real road:** the drawn route line is the **sub-path of the bundled highway** between the
  start and end (and through any user-added stops, in order). Province waypoints (start/end/stops) are **snapped
  to the nearest point on the highway** so the line always lies on the real road — never a straight chord across
  the sea. Applies to both the full map and the minimap.
- **Google-style markers:** **big** markers ONLY on the start, the end, and any user-added stops. **No
  per-province dots** at all (Kevin: "why so many default province points?"). The current-position marker
  (unchanged) rides along the road.
- **Distance/progress along the road:** the route length + progress % follow the real road sub-path length (the
  "km to <end>" readout reflects the actual drawn road).
- **Persist stops:** keep the user's stop ids on `RoutePlan` (additive field) so a restored route keeps its stops.
- **Reset relabel:** rename the destructive full-wipe copy "Factory reset" → **"Reset everything"**, WITHOUT
  colliding with the existing route-only **"Start over"** launch action (keeps stats). Update strings + tests.

### Out
- No RUNTIME routing API / network / tiles — the highway polyline is a static bundled asset; runtime stays
  zero-egress (BR-1/BR-11 / ADR-0008 posture preserved). Sourcing is a one-time dev step.
- province-chain-2026's province DATA (34 units, coords, 2026 map, migration plumbing) is NOT rewritten — this
  slice changes how the ROUTE is drawn (follows the bundled road), and where the default route runs.
- No change to the route-only "Start over" behaviour or the full-wipe SCOPE (only its label).
- No new native surface. New bundled DATA asset (the highway polyline) — flagged for an ADR note (extends
  ADR-0008's bundled-offline-geodata decision).

## Constraints & assumptions
- **Offline curve:** "like Google Maps" is approximated by a spline through the province centres (they already
  hug the coast → reads like a real road, stays on land). NOT literal surveyed roads (impossible offline).
- **On-land preserved:** the smoothed curve must not bow off the landmass — sampling the spline against
  `BaseMapGeometry.containsLandmass` stays on land to the same standard as province-chain-2026 AC-5 (the ≤3-sample
  `quảng_trị→hà_tĩnh` residual carries over; a spline must not INTRODUCE new sea excursions beyond it).
- **Label collision:** "Start over" already means the route-only restart (keeps stats). The renamed full-wipe
  action must stay clearly distinct from it.
- Presentation-layer change: pure-domain route model stays framework-free; privacy invariant untouched.

## Acceptance criteria
- [x] AC-1: Given the bundled highway asset, When the app loads it, Then it is a static offline GeoJSON polyline
  of Vietnam's real national road (QL1A + northern connector), projected onto the shipped equirectangular bounds,
  with ODbL attribution recorded in `assets/CREDITS.md` — and it is read via the bundled-asset seam only (no
  runtime network).
- [x] AC-2: Given an active route, When the line is drawn on the full-screen map and the minimap, Then it follows
  the **real road geometry** (the bundled highway sub-path between the endpoints) — it visibly curves along the
  coast/road, and no leg is a straight chord across open sea.
- [x] AC-3: Given any route, When markers are drawn, Then **big** markers appear ONLY on the start, the end, and
  any user-added stops — there is **no per-province dot** for provinces the road merely passes (regression fix for
  "many default province points" + "grey marker too big").
- [x] AC-4: Given the default route (no stops), When it is drawn, Then exactly **two** big markers show
  (start, end) joined by the real road; When the user adds one stop, Then a **third** big marker appears at that
  stop and the road sub-path routes through it (start → stop → end along the highway); the stop ids survive a
  `RoutePlan` save/load round-trip (additive field; an old plan without the field decodes with no stops, no crash).
- [x] AC-5: Given the road-following line, When it is densely sampled against `BaseMapGeometry.containsLandmass`,
  Then it stays on land (the real road is on land by construction; snapping endpoints to the road introduces no
  open-sea excursion) — verified against the real bundled geometry.
- [x] AC-6: Given the Settings reset action, When it is displayed, Then its label is the friendlier full-wipe
  wording (no longer "Factory reset") and remains clearly distinct from the route-only "Start over" action; the
  wipe SCOPE (erases everything incl. lifetime distance/streaks/badges) is unchanged.
- [x] AC-7: Given the route authoring/review flow, When the "Review your route" screen is shown, Then it lists
  ONLY the anchors that are journey stops — the start, the end, and any user-marked stops (in travel order, all
  locked) — and NEVER the pass-through provinces the road merely traverses (Kevin: "they should be implicit,
  always exist to draw the road but not a stop"). The old route-planner-v2 "skip an auto-inserted intermediate"
  affordance (⊖ remove + "Skipped (tap to add back)") is REMOVED. The distance readout reflects the **real road
  length** between the anchors (same axis the map draws), not the chain sub-path km. **This supersedes
  route-planner-v2 AC-5 / ADR-0005's remove-intermediate decision** — flagged for a `system-architect` ADR
  amendment (the pure `RoutePlanner.resolve(removedStops:)` domain is untouched; only the presentation stopped
  offering removal).

- [x] AC-8: Given a route with a stop that is NOT on the bundled highway (e.g. An Giang, ~71 km west of QL1A),
  When the route is drawn, Then the black line **detours off the highway out to the stop's real location and
  back** so the line genuinely passes through every start / stop / end; the stop marker sits at the province's
  TRUE location (not snapped onto the highway); the route length includes the round-trip detour distance. (User
  decision 2026-07-16: "the black line should go through all the stops.")
- [x] AC-9: Given the odometer/game must not run before a journey is under way, When the app decides whether to
  accrue, Then the journey runs iff there is a **committed active route AND the user is not currently authoring**
  one — there is NO manual Start/Pause button. Concretely: a restored active route runs on launch; first-run /
  no-route stays paused (odometer frozen, game parked); confirming a route ("Start journey") begins it; while
  RE-authoring an existing route (abandon / "Start over") travel is paused until the dialog closes (cancel keeps
  the old route → resumes; confirm → new route runs). The gate lives at the ticker/app layer (a
  `JourneyGateCubit` driven by `hasActiveRoute && !authoring`); the pure `JourneyEngine` is untouched (ADR-0007).
  (User decisions 2026-07-16: "odometer only counts when we start the journey"; then "remove that button — just
  pause while the route is setting up, start after we confirm the route.")

### Non-functional (updated)
- [x] NFR-4 Provenance/licensing: the bundled highway data is license-clean (ODbL) with attribution recorded;
  no proprietary (Google/Apple/HERE) geometry is used.

### Non-functional
- [x] NFR-1 Performance: the spline is precomputed once per route/layout (not per frame) — render stays at parity
  with the shipped map frame timings (memoized like the existing base geometry).
- [x] NFR-2 Privacy: no new file/network/location read; the curve is derived purely from static province
  coordinates — offline/zero-egress invariant preserved (BR-1/BR-11 / ADR-0008).
- [x] NFR-3 Accessibility: big vs small markers keep meaningful semantic labels (start/end/stop named; pass-through
  reachable/labelled); no keyboard/screen-reader regression.

## Related
- Builds on: [specs/vietnam-map-fidelity/](../vietnam-map-fidelity/) (base map), [specs/province-chain-2026/](../province-chain-2026/) (34-unit on-land spine + route data), route-planner-v2 (marked-stop authoring / ADR-0005).
- Domain: [docs/domain/business-rules.md](../../docs/domain/business-rules.md) — BR-1/BR-11 (privacy/egress).
- Reset copy: `src/focus_journey/lib/features/reset/presentation/reset_copy.dart` (`FactoryResetCopy` vs `LaunchPromptCopy.startOverLabel`).
