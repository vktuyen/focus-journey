---
verdict: green
total: 1499
passed: 1499
failed: 0
flaky: 0
skipped: 0
run_at: 2026-07-16T14:54:02Z
resolved_at: 2026-07-16T15:05:00Z
feature: route-real-road
layers:
  unit_widget: { total: 1481, passed: 1481, failed: 0, skipped: 0, status: green }
  e2e:         { total: 18,   passed: 18,   failed: 0, skipped: 0, status: green }
---

> RESOLUTION (2026-07-16, post-run): the 2 e2e failures were **stale assertions**, not a
> route-real-road defect. `test-script-author` corrected the two
> `expect(find.textContaining('OpenStreetMap'), findsNothing)` assertions in
> `integration_test/vietnam_map_fidelity_wiring_test.dart` (lines ~217, ~315, both on the
> FULL-SCREEN surface) to `findsOneWidget('OpenStreetMap contributors')` — reflecting
> route-real-road's now-mandatory ODbL road credit (NFR-4). The no-tiles / no-network privacy
> guards (`TileLayer findsNothing`, CC BY-SA credit) were left untouched. Re-verified:
> `fvm flutter test integration_test/vietnam_map_fidelity_wiring_test.dart -d macos` → **6/6 pass**,
> analyze clean. All in-scope layers now green. FLAGGED to `system-architect`: route-real-road's
> mandatory OSM attribution supersedes vietnam-map-fidelity AC-9/AC-10's "no OSM credit" expectation.

# Test Run Summary — route-real-road

Runner per `docs/architecture/overview.md`: `fvm flutter test` (unit/widget), `integration_test` package via `fvm flutter test integration_test/` (e2e). Flutter 3.38.10 (fvm), Dart 3.10.9.

There is no `tests/cases/route-real-road.md`; the contract is `specs/route-real-road/spec.md` `## Acceptance criteria` (AC-1..AC-9 + NFR-1..4). Mapping below is to those.

## Exact commands run
1. `fvm flutter pub get` — OK (package config fresh).
2. `fvm flutter test` — full unit/widget suite. Result: **All tests passed! +1481** (0 failed, 0 skipped).
3. `fvm flutter test integration_test/` (whole dir, no device flag) — **unusable in this environment**: the macOS app builds (`Built .../focus_journey.app`) but repeatedly fails to launch with `Error waiting for a debug connection: The log reader stopped unexpectedly, or never started.` -> `Unable to start the app on the device.` This is a multi-file orchestration instability of the GUI launcher in this sandbox, NOT a test-code failure. Worked around by running each in-scope e2e file individually with `-d macos` (deterministic, launches cleanly).
4. `fvm flutter test integration_test/<file>.dart -d macos` for each in-scope e2e file:
   - `route_planner_v2_flow_test.dart` -> All tests passed (+7)
   - `route_wiring_smoke_test.dart` -> All tests passed (+1)
   - `map_experience_wiring_test.dart` -> All tests passed (+4)
   - `vietnam_map_fidelity_wiring_test.dart` -> **+4 -2 Some tests failed** (re-run confirmed identical 2 failures — deterministic, not flaky)

## Per-layer counts
- **Unit/widget:** total 1481 · passed 1481 · failed 0 · skipped 0 -> green.
- **E2E (4 in-scope files, per-file `-d macos`):** total 18 · passed 16 · failed 2 · skipped 0 -> failures.

## Per-AC coverage (route-real-road spec, AC-1..AC-9 + NFR-1..4)
- **AC-1** bundled highway GeoJSON via asset seam, projected, ODbL credit -> `road_path_test`, `route_curve_test`, `coastal_corridor_test`, data/`road_path_repository_test`, presentation/`map_view_test`, `map_cubit_test` — PASS
- **AC-2** line follows real road geometry (no sea chord), full map + minimap -> domain/`road_route_test`, `road_route_on_land_test`, presentation/`route_picker_review_widget_test`, `map_view_test`, `road_route_map_cubit_test`; e2e `map_experience_wiring_test` — PASS
- **AC-3** big markers ONLY on start/end/stops, no per-province dots -> `route_plan_test`, presentation/`map_view_test`, `map_cubit_test`, `road_route_map_cubit_test` — PASS
- **AC-4** default 2 markers / +1 stop -> 3 + sub-path through it; stop ids survive RoutePlan round-trip -> `road_route_test`, `road_route_on_land_test`, `route_plan_test`, presentation/`map_view_test`, `map_cubit_test`, `road_route_map_cubit_test` — PASS
- **AC-5** road-following line stays on land (containsLandmass) -> `road_route_test`, `road_route_on_land_test`, `route_curve_test`, `coastal_corridor_test`, presentation/`route_picker_review_widget_test`, `map_cubit_test` — PASS
- **AC-6** reset relabel "Factory reset" -> "Reset everything", distinct from "Start over" -> `reset_copy_test`; e2e via `route_planner_v2_flow_test` reset paths — PASS
- **AC-7** review flow lists only anchors (start/end/user stops), no remove-intermediate affordance, real-road distance -> `route_plan_test`, presentation/`map_cubit_test`, `route_progress_cubit_test`; e2e `route_planner_v2_flow_test` — PASS
- **AC-8** off-highway stop detours out-and-back, marker at true location, length includes detour -> `road_route_on_land_test`, presentation/`map_view_test`, `map_cubit_test`, `route_progress_cubit_test` — PASS
- **AC-9** journey gate = `hasActiveRoute && !authoring`, no manual button -> `journey/presentation/journey_gate_test`, data/`shared_preferences_route_repository_plan_unit_test`, presentation/`map_view_test`, `map_cubit_test`; e2e `route_planner_v2_flow_test` — PASS
- **NFR-1** spline/road precomputed once per route/layout (memoized) -> data/`road_path_repository_test`, presentation/`map_cubit_test` — PASS
- **NFR-2** no new file/network/location read; zero-egress -> data/`road_path_repository_test` — PASS
- **NFR-3** big/small markers keep semantic labels; no a11y regression -> presentation/`route_picker_review_widget_test`, `map_view_test` — PASS
- **NFR-4** bundled highway is license-clean (ODbL) with attribution; no proprietary geometry -> presentation/`map_view_test` (unit/widget) — PASS. NOTE: the e2e failure below is the flip side of NFR-4 — the new OSM/ODbL attribution string now renders at runtime, which contradicts a stale prior-slice assertion.

## Failing tests (e2e) — route to test-script-author
File: `src/focus_journey/integration_test/vietnam_map_fidelity_wiring_test.dart` (listed in-scope; touched by this slice). Both failures deterministic across 2 runs.

1. `AC-1/AC-2 / TC-801, TC-803 offline base on both surfaces > full map renders the bundled base — no network, no TileLayer` (line 217)
2. `AC-9 / TC-815 + AC-10 / TC-816 attribution + no OSM > full-screen shows the CC BY-SA credit; no OSM tile/URL` (line 315)

Both fail on the same assertion:

    expect(find.textContaining('OpenStreetMap'), findsNothing);
    Expected: no matching candidates
      Actual: Found 1 widget with text containing OpenStreetMap
      Which: means one was found but none were expected

**Diagnosis (NOT a functional regression, NOT a flake):** these assertions belong to the *prior* `vietnam-map-fidelity` slice, whose base map was not OSM-derived, so it asserted "OpenStreetMap" never appears. `route-real-road` now bundles Vietnam's national highway sourced from OpenStreetMap under ODbL, and its NFR-4/AC-1 REQUIRE the ODbL attribution (which includes "OpenStreetMap") to be recorded/shown. So the app now legitimately renders an OpenStreetMap credit. Privacy posture intact — in the same tests `find.byType(TileLayer)` is still `findsNothing` and `find.textContaining('CC BY-SA')` is still `findsOneWidget` (both PASS): no OSM tiles, no network, just an attribution string. The stale `findsNothing('OpenStreetMap')` assertions are contradicted by correct new behaviour.

**Routing:** wrong/outdated assertions -> **test-script-author**. The `findsNothing('OpenStreetMap')` expectations (lines 217 and 315) must be reconciled with route-real-road NFR-4 (the OSM/ODbL credit is now mandatory). Likely also warrants a **system-architect** note that route-real-road's OSM attribution supersedes vietnam-map-fidelity AC-9/AC-10's "no OSM credit". NOT edited here — behavioral/assertion change, out of scope for mechanical flake handling; underlying code-generator behaviour is correct.

## Notes
- No mechanical flake patches were applied; no production or test code was edited.
- The full-suite `fvm flutter test integration_test/` run is unreliable in this sandbox (GUI app repeatedly fails the debug-connection handshake when many files launch in sequence). Per-file `-d macos` invocation is stable and authoritative; that is how the 4 in-scope e2e files were executed. Environment/runner-orchestration quirk, not a test defect.
- Devices available: macos, chrome (web), plus a wireless iOS device (irrelevant — desktop app).

## Verdict
**green** (after resolution) — unit/widget 1481/1481 + e2e 18/18. The initial run was `failures` due to 2 stale `findsNothing('OpenStreetMap')` assertions in `vietnam_map_fidelity_wiring_test.dart` that route-real-road's now-required ODbL attribution correctly contradicts; `test-script-author` reconciled them (→ `findsOneWidget('OpenStreetMap contributors')`, privacy guards untouched) and the file re-ran 6/6. All in-scope ACs (AC-1..9, NFR-1..4) exercised and passing.
