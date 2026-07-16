# Route real-road visualization — curved road + start/end/stop marker hierarchy

**Created:** 2026-07-16 (Kevin's request, mid-`province-chain-2026`)
**Spec:** [specs/route-real-road/](../../specs/route-real-road/)
**Wave:** refine-app-ui-ux (slice 3; builds on `vietnam-map-fidelity` ✅ + `province-chain-2026` staged/ready-to-ship)

## Goal
Draw the journey route as a smooth curved road (spline) through the on-route provinces — big markers only on
start + end (+ user-added stops), small grey markers on pass-through provinces — and rename "Factory reset" to a
friendlier full-wipe label. Presentation-only; route data (province-chain-2026) unchanged; offline invariant kept.

## Phase ledger
| ✓ | Phase | Command | Date | Verdict / note |
|---|-------|---------|------|----------------|
| [x] | 2 · Spec | (spec-first; Kevin specified intent precisely) | 2026-07-16 | 6 ACs + 3 NFRs; `Status: approved`. |
| [x] | 3 · Build | `/implement` (includes self-review pass) | 2026-07-16 | **v3 done — route follows the REAL bundled highway.** After v1 (centre-point spline) + v2 (coastal-corridor spline) were rejected ("not how Google/Apple Maps work"), Kevin chose the real road: sourced QL1A+QL4A from OSM (ODbL, offline, `ui-asset-curator`), then integrated (`flutter-app-developer`) — new `RoadPath`/`RoadRoute`/`RouteGeometry` domain + `AssetRoadPathRepository`; route line = road sub-path between snapped waypoints; **markers only on start/end/stops, no per-province dots**; km/progress along the road; ODbL attribution in-app. Default Cà Mau→Cao Bằng = 2497.6 km / kmPerActiveHour ≈312. analyze clean, full suite green, macOS build ✓. **Follow-ups:** (a) `integration_test/` harness may need the new `roadPath` param threaded (not run by `flutter test`; verify at review/execute); (b) Cao Bằng snaps ~19 km short (OSM QL4A data limit); (c) far-south ~46 km inherent to snapping Cà Mau's inland centre vs Đất Mũi cape. |
| [x] | 3b · Build (authoring UI) | `/implement` (self-review) | 2026-07-16 | **Review/authoring now matches the real-road model (AC-7).** After Kevin's live feedback ("pass-through provinces should be implicit, not stops"), `flutter-app-developer` reworked `route_review_screen.dart` to list ONLY anchors (start/end/marked stops, all locked) — removed the ⊖ skip-intermediate feature + "Skipped" section; distance readout now shows the real road length (RoadRoute over anchors) with `subPathKm` fallback; `RoadPath?` threaded main→flow→review; picker copy updated. Supersedes route-planner-v2 AC-5 / ADR-0005 remove-intermediate (flag: `system-architect` ADR amendment; pure `RoutePlanner` domain untouched). analyze clean, `fvm flutter test` 1468 green, macOS build ✓. Prior stale-state diagnosis: the earlier "marker south of Cà Mau" report was a stale `flutter run` session (hot-reload doesn't refresh top-level geography/asset consts) over a leftover persisted plan (`ca_mau→hue→…→cao_bang`, stop=hue); current code places the 0% marker exactly on the start pin (verified). |
| [x] | 3c · Build (detour + start gate) | `/implement` (self-review) | 2026-07-16 | **AC-8 + AC-9.** Kevin: line must go through off-highway stops, and the odometer/game must not run before an explicit start. (1) `RoadRoute.build` rewritten to a DETOUR model — the drawn line touches every REAL waypoint via a highway spur (out-and-back for off-road stops like An Giang ~71km); `waypointCoordinates` now the true province coords (markers at real locations); length includes detours + the ~19km real-Cao-Bằng end connector. (2) New `JourneyGateCubit` (starts paused) + `JourneyGateControl` Start/Pause toggle; `main.dart` no longer auto-starts the ticker — gate stream drives `_ticker.start/stop`; `confirmRoute` fires `onRouteStarted`→gate opens; engine untouched (ADR-0007); Flame scene stays parked (no self-animation). analyze clean, `fvm flutter test` 1475 green, macOS build ✓. |
| [x] | 4 · Review | `/review-code` | 2026-07-16 | verdict: **approved** (flutter-code-reviewer) + privacy **pass** (privacy-guardian). 0 Blocking; 6 Suggestions (S1 authoring hooks need try/finally — stuck-paused blast radius; S2 accrues on completed route / welcome prompt — product Q; S3 no on-land test for AC-8 stop spur; S4/S5 per-tick LatLng/RoadRoute re-alloc; S6 emit-after-close edge). analyzer clean, 629 in-scope tests pass. No `tests/cases/route-real-road.md` (spec-first, inline ACs). **Post-review (user-approved): all S1–S6 applied + S2 arrival-freeze behaviour change** — gate now runs iff active, NOT-completed route & not authoring; try/finally + isClosed guards; AC-8 on-land spur test added; LatLng/review-distance memoized. `fvm flutter test` 1481 green, macOS build ✓. |
| [x] | 5 · Test | `/execute-tests` | 2026-07-16 | verdict: **green** — unit/widget 1481/1481 + e2e 18/18. Initial run had 2 e2e `failures`: stale `findsNothing('OpenStreetMap')` assertions in `vietnam_map_fidelity_wiring_test.dart` that route-real-road's now-required ODbL road credit (NFR-4) correctly contradicts → `test-script-author` reconciled them (→ `findsOneWidget('OpenStreetMap contributors')`, privacy guards untouched), file re-ran 6/6. All AC-1..9 + NFR-1..4 exercised & passing. Report: `tests/_runner/reports/route-real-road/20260716-145402/summary.md`. **FLAG → system-architect:** route-real-road's mandatory OSM/ODbL attribution supersedes vietnam-map-fidelity AC-9/AC-10 "no OSM credit". (e2e run per-file with `-d macos`; whole-dir run unreliable in sandbox — env quirk, not a defect.) |
| [x] | 6 · Ship | `/ship` | 2026-07-16 | **Shipped.** All AC-1..9 + NFR-1..4 ✓; green report `tests/_runner/reports/route-real-road/20260716-145402/summary.md` (1481 unit/widget + 18 e2e). Status→shipped; moved active→done. |

**Current phase:** SHIPPED (2026-07-16)   **Next command:** — (slice complete)

## What shipped
The journey route now follows the **real bundled national highway** (QL1A + QL4A, OSM/ODbL, offline): a curved on-land road, big markers ONLY on start/end/user stops (no per-province dots), the line **detours out to off-highway stops** (e.g. An Giang) and back, distance/progress measured along the real road. The authoring **review lists only anchors** (start/stops/end) with the road distance — the old remove-intermediate affordance is gone. The journey is **paused until a route is confirmed** and **freezes on arrival** (no manual button; gate = active-not-completed-route ∧ ¬authoring). "Factory reset" relabelled **"Reset everything"**. Privacy invariant preserved (zero egress, asset-only reads). Green: 1481 unit/widget + 18 e2e.

## What we'd do differently
- The bundled road is a **single spine (QL1A+QL4A)** — off-highway stops are reached by a straight out-and-back **spur**, not real secondary roads. A future slice could bundle provincial connectors (the "add smaller roads" option) for true Maps-like routing to every province; NW-mountain stops (200–300 km off) produce long spurs today.
- Two iterations were spent on centre-point splines before pivoting to real road geometry — should have started from "stitch actual road data" given the "like Google Maps" requirement.
- `_resetPlan` still seeds `coastalCorridorNodeIds` (a v2-corridor holdover); harmless (markers reduce to anchors) but worth simplifying to the two tips for the pure start+end default.
- Cross-slice: route-real-road's mandatory OSM/ODbL attribution **supersedes vietnam-map-fidelity AC-9/AC-10** ("no OSM credit") — flagged for a `system-architect` ADR/spec amendment.
- Report link: [tests/_runner/reports/route-real-road/20260716-145402/summary.md](../../tests/_runner/reports/route-real-road/20260716-145402/summary.md)

## Road data sourced (2026-07-16, `ui-asset-curator`)
`assets/map/vietnam_national_route.geojson` — real OSM geometry (ODbL, © OpenStreetMap contributors): QL1A
(Cà Mau→Lạng Sơn, 346 pts) + QL4A connector (Lạng Sơn→toward Cao Bằng, 54 pts), 400 vertices, WGS84 lon/lat,
within the base-map bounds. Attribution in `assets/CREDITS.md`; wired in `pubspec.yaml`. Reproducible via
`tool/build_national_route.py`. **Gap:** QL4A ends ~19 km short of Cao Bằng centre — integration snaps the north
waypoint to the connector end.

## Notes
- Sibling `province-chain-2026` is at Phase 6 (ready to `/ship`) — this slice's diff is in the same working tree;
  commits can be structured per-slice. province-chain-2026's route DATA is unchanged by this slice.
- Honest constraint: offline (no routing API) → curved road = spline through province centres, not surveyed roads.
- Reset relabel avoids colliding with the existing route-only "Start over" (keeps stats) launch action.
