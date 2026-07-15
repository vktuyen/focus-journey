---
verdict: green
total: 1298
passed: 1297
failed: 0
flaky: 0
skipped: 1
run_at: 2026-07-15T20:38:58Z
feature: vietnam-map-fidelity
---

# Test Run Summary — vietnam-map-fidelity

Toolchain: `fvm flutter` (SDK 3.38.10, Dart 3.10.9), run from `src/focus_journey/`. Executable
tests live INSIDE the Flutter package (`test/` unit+widget+golden; `integration_test/` e2e), per the
confirmed project deviation documented in `docs/architecture/overview.md`. Manual / on-device / audit
legs (TC-M*) are carried, not run. Any running `focus_journey` app instance was killed before each
integration leg so it could not interfere.

Scope: EXECUTION + mechanical flake-handling only. No production logic was changed and no assertion
was weakened. No flake was encountered, so no test script was edited.

## Invocation commands

- Full unit/widget suite (feature results + cross-feature regression check), coverage redirected into
  this report folder:
  `fvm flutter test --coverage --coverage-path=<report>/lcov.info`
- Integration (each file run SEPARATELY on macOS, per the known multi-entrypoint `integration_test`
  harness caveat — "Error waiting for a debug connection" / "log reader stopped" when several run in
  one invocation):
  - `fvm flutter test integration_test/vietnam_map_fidelity_wiring_test.dart -d macos`
  - `fvm flutter test integration_test/map_experience_wiring_test.dart -d macos`
  - `fvm flutter test integration_test/route_wiring_smoke_test.dart -d macos`

## Counts

| Layer | Total | Passed | Skipped | Failed |
|---|---|---|---|---|
| Full unit/widget suite (`test/`) — regression + feature coverage | 1287 | 1286 | 1 | 0 |
| Integration: `vietnam_map_fidelity_wiring_test.dart` (macOS) | 6 | 6 | 0 | 0 |
| Integration: `map_experience_wiring_test.dart` (macOS) | 4 | 4 | 0 | 0 |
| Integration: `route_wiring_smoke_test.dart` (macOS) | 1 | 1 | 0 | 0 |
| **Run total (full suite + 3 integration files)** | **1298** | **1297** | **1** | **0** |

- Full-suite final line: `00:28 +1286 ~1: All tests passed!` — 1286 passed, 1 skipped, 0 failed,
  zero `[E]` markers. This is consistent with the prior ~1285-pass baseline (+1 from this slice's new
  cases) — **no cross-feature regression**; the whole package stays green with the vietnam-map-fidelity
  slice included.
- Each integration file ended with `All tests passed!` at its respective `+N`, each on the FIRST
  attempt.

## Per-integration-file outcome

- `vietnam_map_fidelity_wiring_test.dart` (macOS): **6/6 PASS**, first attempt, no retry.
- `map_experience_wiring_test.dart` (macOS): **4/4 PASS**, first attempt, no retry.
- `route_wiring_smoke_test.dart` (macOS): **1/1 PASS**, first attempt, no retry.

The known multi-entrypoint `integration_test` "Error waiting for a debug connection" harness flake did
**not** occur on any file (each was run in its own invocation as instructed). **No retry was needed on
any integration file.**

## The 1 intentionally skipped test (GREEN, not a failure)

- `test/features/route/domain/base_map_geometry_test.dart` ::
  `everyDenselySampledRoutePointIsOnLand` → **SKIPPED**
  - `skip:` reason (verbatim): `'AC-5 sea-crossing carried to province-chain-2026 (route geometry
    hugs coast); tracked on manual TC-M-GEO'`
  - This is the dense-along-segment leg of **TC-808 (AC-5)**. Per the AC-5 amendment (2026-07-15),
    AC-5 now requires only the 13 checkpoint **vertices** on land (asserted, passing) + the route
    reading S→N; the dense along-segment coverage is deferred to the sibling slice
    `province-chain-2026` (the shipped straight-line chain clips four coastal bays —
    `vinh→ninh_binh`, `hue→vinh`, `mui_ca_mau→can_tho`, `nha_trang→quy_nhon` — before the generalized
    bundled coastline). It is deliberately visible as **known-deferred**, not a silent pass. Visual
    verdict carried on **TC-M-GEO**.
  - A skipped test does NOT change the verdict — all non-skipped tests passed, so the verdict is
    **green**.

## TC → result mapping

### Integration legs (macOS, `integration_test/`)

`vietnam_map_fidelity_wiring_test.dart` (6/6):
- TC-801 / TC-803 (AC-1/AC-2) offline base on both surfaces (full + ~150px minimap) → PASS
- TC-819 (AC-11) base purely additive — route polyline + markers structurally identical with vs
  without base; base is FIRST FlutterMap child (z-order beneath overlays) → PASS
- TC-812 (AC-7) current-position marker advances northward along the route with the base beneath → PASS
- TC-815 / TC-816 (AC-9 / AC-10) full-screen shows the CC BY-SA credit; no OSM tile/URL request → PASS

`map_experience_wiring_test.dart` (4/4) — upstream regression guard the base sits under:
- TC-215 (AC-8) red idle-trace restored unchanged after restart → PASS
- TC-222 (AC-2) tap opens full-screen in the SAME window (MaterialPageRoute, no window API) → PASS
- TC-226 / TC-228 (AC-12) pure visualizer — zero writes through a distance/segment sweep → PASS

`route_wiring_smoke_test.dart` (1/1):
- TC-wiring: `ticker.tickOnce` flows distanceKm → route cubit → map state → PASS

### Unit/widget legs (`test/`, in-scope files — all green)

- `route/domain/equirectangular_projection_test.dart` → TC-807, TC-809, TC-811 (AC-5/AC-6
  projection core: closed-form `(lat,lon)→normalized (x,y)` within ±1e-6, S→N monotone-y, boundary
  extremes/out-of-bounds contract) → PASS
- `route/domain/base_map_geometry_test.dart` → TC-805 (34-unit count), TC-807, TC-808 (13/13 vertices
  on land), TC-810 (spot-checked cities on landmass), TC-812 → PASS (+ the 1 skipped dense-sampling
  leg noted above)
- `route/data/base_map_repository_test.dart` → TC-820 (NFR-1: base geometry parsed/decoded once,
  cached, not re-allocated per frame) → PASS
- `route/presentation/base_map_layer_test.dart` → TC-801, TC-802 (offline / tiles-fail-or-absent),
  TC-803, TC-804 (decimated minimap non-blob), TC-805, TC-816, TC-821 → PASS
- `route/presentation/map_view_test.dart` → TC-801, TC-802, TC-803, TC-806 (S-shape golden/structure),
  TC-813, TC-814 (overlays legible on base both surfaces; solid vs dashed by non-colour cue), TC-815,
  TC-819, TC-821 (+ upstream TC-213/216/217/224/225 regression) → PASS
- `route/presentation/map_surface_test.dart` → TC-803, TC-815, TC-816 (+ upstream
  TC-220/221/222/223/232 regression) → PASS
- `route/route_separation_static_test.dart` → TC-816, TC-817 (static guard: no location/GPS import,
  no new network surface beyond shipped flutter_map/OSM; static app-shipped bounds/asset) → PASS
- `stats/presentation/onboarding_screen_test.dart` → TC-815 (AC-9 CC BY-SA base-map attribution
  rendered on onboarding) (+ upstream TC-021/022) → PASS

Note on TC-818 (AC-11, ADR-0004(b) canonical-km projection unchanged): not tagged by a dedicated
`TC-818` id, but its guarantee is covered — the canonical-km distance→polyline projector is owned by
`map-experience`/ADR-0004 and its unit tests run green in the full suite (unchanged), and TC-819
asserts the overlay geometry is structurally identical with vs without the base beneath. No
re-projection through the base's equirectangular bounds.

### AC coverage (automatable portions — all satisfied)

AC-1 (TC-801/802), AC-2 (TC-803/804), AC-3 (TC-805 unit count), AC-4 (TC-806 golden/structure),
AC-5 (TC-807 + TC-808 13/13 vertices; dense-sampling deferred/skipped → TC-M-GEO),
AC-6 (TC-809/810/811), AC-7 (TC-812), AC-8 (TC-813/814), AC-9 (TC-815), AC-10 (TC-816/817),
AC-11 (TC-818 via unchanged projector + TC-819), NFR-1 (TC-820), NFR-3 (TC-813/821).

## Manual / on-device / audit legs carried (not run — by design)

From `tests/cases/vietnam-map-fidelity.md` (TC-M*); NOT attempted by the executor:
- **TC-M-OFFLINE** (AC-1/AC-2, [DEVICE], P0) — real WiFi-off render of full map + ~150px minimap, base
  never a blank/grey canvas. CARRIED / manual. macOS pending; Windows DEFERRED.
- **TC-M-GEO** (AC-4/5/6/7, [VISUAL], P0) — S-shape coastline recognisability + georeferenced pin
  placement spot-check (incl. the deferred dense along-segment sea-crossing check for the four
  coastal-bay legs). CARRIED / manual. macOS pending; Windows DEFERRED.
- **TC-M-GEOM** (AC-3, [ASSET], P1) — asset inspection: 34 merged units, no pre-2025 internal borders
  inside Gia Lai / Đắk Lắk / Lâm Đồng. CARRIED / manual (asset-level, no per-OS split).
- **TC-M-NF1** (NFR-1, [DEVICE], P1) — real on-device fps / no visible jank on full map + minimap.
  CARRIED / manual. macOS pending; Windows DEFERRED.
- **TC-M-A11Y** (AC-8/NFR-3, [AT], P1) — real screen-reader + keyboard-only + colour-blind perception
  of solid vs dashed idle-trace against the base. CARRIED / manual. macOS pending; Windows DEFERRED.
- **TC-M-PRIV** (AC-10/NFR-2, [AUDIT], P0, **CRITICAL / GATING**) — `/privacy-audit` PASS + runtime
  egress monitoring: bundled static base adds no egress and no location read. **Already PASSED at the
  review phase with zero egress** (source-level audit; the base is a bundled asset, no new network
  dependency, no location/GPS API). Runtime egress on macOS carried; Windows DEFERRED. The static
  reinforcement TC-816/TC-817 passed automatically in this run.

Windows runtime legs of all of the above are **DEFERRED — required before any Windows release**
(precedent: `map-experience`, `route-planner-v2`, `mini-window`).

## Notes — flakes & environment caveats

- **No flakes encountered; no retries applied.** All four runs (full suite + 3 integration files) were
  green on the first attempt.
- `Failed to foreground app; open returned 1` appeared during the macOS launch of
  `route_wiring_smoke_test.dart` (documented sandbox foreground/relaunch infra limitation, same as
  prior `journey-reset` / `map-experience` / `route-planner-v2` reports). This is NOT an assertion
  failure: the test body ran in full immediately afterward and the run ended with `All tests passed!`
  at `+1`. A single launch warning followed by a clean full-body pass means no retry needed.
- Any `Exception: Invalid image data` lines in the console are offline OSM tile-decode noise from the
  `flutter_map` tile layer under headless widget tests (those tests assert the offline path renders
  the base + overlays WITHOUT tiles and expect no throw). Expected log noise, not assertion failures —
  `[E]` count is 0 and the suite ended green.
- No production logic changed and no assertions weakened (execution + flake-handling scope only); no
  flake patches were needed, so no test scripts were edited.

## Artifacts (all under this report folder)

- `unit-output.txt` — full `fvm flutter test --coverage` console output (1286 passed, 1 skipped).
- `integration-vietnam-map-fidelity-wiring.txt` — macOS integration output (6 passed).
- `integration-map-experience-wiring.txt` — macOS integration output (4 passed).
- `integration-route-wiring-smoke.txt` — macOS integration output (1 passed).
- `lcov.info` — coverage from the full-suite run (redirected via `--coverage-path` into this folder).

## Verdict

green — every in-scope automated test passed (1297/1297 executed: full suite 1286 + 11 integration),
with 1 intentionally-skipped known-deferred test (dense along-segment sea-crossing, carried to
`province-chain-2026` / TC-M-GEO). No cross-feature regression against the ~1285 baseline, no flakes,
no retries. Manual legs TC-M-OFFLINE / TC-M-GEO / TC-M-GEOM / TC-M-NF1 / TC-M-A11Y carried as manual;
the CRITICAL gating privacy leg **TC-M-PRIV already PASSED at review with zero egress** (static
reinforcement TC-816/TC-817 green here).
