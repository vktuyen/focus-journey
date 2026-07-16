---
verdict: green
total: 285
passed: 285
failed: 0
flaky: 0
skipped: 0
run_at: 2026-07-16T09:28:50Z
feature: province-chain-2026
---

# Test Run Summary — province-chain-2026

Toolchain: `fvm flutter` (SDK 3.38.10, Dart 3.10.9), run from `src/focus_journey/`. Executable tests
live INSIDE the Flutter package (`test/` unit+widget; `integration_test/` e2e) per the confirmed project
deviation documented in `docs/architecture/overview.md`. Manual / on-device / audit legs (TC-M*) are
carried, not run. Any running `focus_journey` app instance was killed before each integration leg.

Scope: EXECUTION + mechanical flake-handling only. No production logic was changed and no assertion was
weakened. No flake was encountered, so no test script was edited.

## Invocation commands

- In-scope unit/widget suite (16 files), coverage redirected into this report folder:
  `COVERAGE_FILE=<report>/.coverage fvm flutter test --coverage --coverage-path=<report>/lcov.info <the 16 test/ paths>`
- Integration (each file run SEPARATELY on macOS, per the sibling `vietnam-map-fidelity` precedent — the
  known multi-entrypoint `integration_test` harness caveat when several entrypoints run in one invocation):
  - `fvm flutter test integration_test/route_wiring_smoke_test.dart -d macos`
  - `fvm flutter test integration_test/map_experience_wiring_test.dart -d macos`
  - `fvm flutter test integration_test/vietnam_map_fidelity_wiring_test.dart -d macos`
  - `fvm flutter test integration_test/route_planner_v2_flow_test.dart -d macos`

## Counts

| Layer | Total | Passed | Skipped | Failed |
|---|---|---|---|---|
| In-scope unit/widget suite (`test/`, 16 files) | 267 | 267 | 0 | 0 |
| Integration: `route_wiring_smoke_test.dart` (macOS) | 1 | 1 | 0 | 0 |
| Integration: `map_experience_wiring_test.dart` (macOS) | 4 | 4 | 0 | 0 |
| Integration: `vietnam_map_fidelity_wiring_test.dart` (macOS) | 6 | 6 | 0 | 0 |
| Integration: `route_planner_v2_flow_test.dart` (macOS) | 7 | 7 | 0 | 0 |
| **Run total (unit/widget + 4 integration files)** | **285** | **285** | **0** | **0** |

- Unit/widget final line: `00:06 +267: All tests passed!` — 267 passed, 0 skipped, 0 failed, zero `[E]`.
- Each integration file ended with `All tests passed!` on the FIRST attempt, no retry.

## Re-armed guard (the flagship regression — no longer skipped)

The sibling `vietnam-map-fidelity` run left ONE test intentionally skipped:
`base_map_geometry_test.dart :: everyDenselySampledRoutePointIsOnLand` (dense along-segment sea-crossing,
carried with `skip: 'AC-5 sea-crossing carried to province-chain-2026'`). In THIS run that guard is
**re-armed and GREEN** over the rebuilt 34-unit coast-hugging spine (PC-909 / PC-910). The run has **0
skipped** tests — the deferred guard ends armed, not skipped, exactly as PC-910 requires. The four legs the
old 13-node route clipped (`vinh→ninh_binh`, `hue→vinh`, `mui_ca_mau→can_tho`, `nha_trang→quy_nhon`) now
have no sample in the sea.

## Per-test-file → case-ID mapping (traceability)

### Unit / widget (`test/`, all PASS)

- `route/domain/province_chain_2026_haversine_test.dart` → AC-3: PC-905, PC-906 → PASS
- `route/domain/province_chain_2026_pacing_test.dart` → AC-4: PC-907, PC-908 → PASS
- `route/domain/province_chain_2026_authoring_test.dart` → AC-8: PC-916, PC-917, PC-918 → PASS
- `route/domain/province_chain_2026_projection_roundtrip_test.dart` → AC-11: PC-925, PC-926, PC-927 → PASS
- `route/domain/province_chain_2026_relocated_centres_test.dart` → AC-6: PC-912, PC-913 → PASS
- `route/domain/province_chain_2026_nfr_test.dart` → NFR-1 PC-928, NFR-2 PC-929 → PASS
- `route/domain/province_chain_2026_golden_coords_test.dart` → AC-1/AC-6/AC-7 (golden 34-coord table) → PASS
- `route/domain/base_map_geometry_test.dart` → AC-5 PC-909/PC-910 (dense guard RE-ARMED), PC-911 (mis-order
  rejected), AC-6/AC-5 PC-913, AC-7 PC-914 (34/34 on land) → PASS
- `route/domain/equirectangular_projection_test.dart` → AC-7 PC-915 (34 checkpoints inside [0,1], no clamp) → PASS
- `route/domain/province_chain_test.dart` → AC-1 PC-901 (34 unique nodes, 33 segments), AC-2 PC-903 (tips +
  33 positive segments sum), PC-904 (broadly northward, not strict latitude sort) → PASS
- `route/domain/province_geography_test.dart` → AC-1 PC-902 (geography covers all 34 units) → PASS
- `route/domain/route_polyline_projector_test.dart` → AC-11 PC-925/PC-926/PC-927 (canonical-km axis unchanged) → PASS
- `route/domain/route_progress_resolver_sanity_test.dart` → AC-11 (progress resolver sanity over 34-unit spine) → PASS
- `route/data/shared_preferences_route_repository_plan_unit_test.dart` → AC-9 PC-919, PC-920, PC-921, PC-922
  (migrate-by-reset to full-spine active at current cumulative; corrupt→null; not a nearest-unit remap) → PASS
- `journey/domain/journey_engine_rate_regression_test.dart` → AC-10 PC-923, PC-924 (accrual byte-identical
  across rates; only injected rate differs — ADR-0007 firewall intact) → PASS
- `route/presentation/province_chain_2026_picker_a11y_test.dart` → NFR-3 PC-930 (picker keyboard-focusable +
  semantic labels over 34 units) → PASS

### Integration (macOS, `integration_test/`, all PASS)

- `route_wiring_smoke_test.dart` (1/1) → wiring smoke: ticker → route cubit → map state over 34-unit chain → PASS
- `map_experience_wiring_test.dart` (4/4) → upstream `map-experience` regression guard → PASS
- `vietnam_map_fidelity_wiring_test.dart` (6/6) → sibling base-map fidelity regression guard → PASS
- `route_planner_v2_flow_test.dart` (7/7) → AC-8/AC-9 route-authoring + migration flow over the 34-unit spine → PASS

### AC / NFR coverage (automatable portions — all satisfied)

AC-1 (PC-901/902), AC-2 (PC-903/904), AC-3 (PC-905/906), AC-4 (PC-907/908), AC-5 (PC-909/910/911 — re-armed;
visual→TC-M-GEO), AC-6 (PC-912/913), AC-7 (PC-914/915; visual→TC-M-GEO), AC-8 (PC-916/917/918), AC-9
(PC-919/920/921/922), AC-10 (PC-923/924), AC-11 (PC-925/926/927), NFR-1 (PC-928; device→TC-M-NF1), NFR-2
(PC-929; gating audit→TC-M-PRIV), NFR-3 (PC-930; AT→TC-M-A11Y). Every AC-1..11 and NFR-1..3 has a green
automated leg.

## Manual / on-device / audit legs (TC-M*) — carried, not run by the executor

Windows runtime legs DEFERRED — required before any Windows release (precedent: `vietnam-map-fidelity`,
`map-experience`, `route-planner-v2`).

- **TC-M-GEO** (AC-5/AC-7, [VISUAL], P0) — spine reads as one coast-hugging S→N line, no bay clipped.
  Companions PC-909/910/914 GREEN. CARRIED / manual. macOS pending; Windows DEFERRED.
- **TC-M-NF1** (NFR-1, [DEVICE], P1) — real fps/no-jank with 34-unit spine. Companion PC-928 green.
  CARRIED / manual. macOS pending; Windows DEFERRED.
- **TC-M-A11Y** (NFR-3, [AT], P1) — VoiceOver/Narrator + keyboard over 34-unit picker. Companion PC-930 green.
  CARRIED / manual. macOS pending; Windows DEFERRED.
- **TC-M-PRIV** (NFR-2, [AUDIT], P0, **CRITICAL / GATING**) — `/privacy-audit` over the data-only rebuild.
  **Already PASS at the `/review-code` phase** (source-level audit). Static reinforcement PC-929 passed
  automatically here. Runtime egress on macOS carried; Windows DEFERRED.

## Notes — flakes & environment caveats

- No flakes encountered; no retries applied. All five runs green on the first attempt. No test script edited.
- Any `Failed to foreground app; open returned 1` / offline-tile `Invalid image data` lines in integration
  logs are documented sandbox foreground + offline OSM tile-decode noise (same as prior reports), NOT
  assertion failures: each run ended `All tests passed!`, `[E]` count is 0.

## Artifacts (all under this report folder)

- `unit-output.txt` — full in-scope unit/widget console output (267 passed, 0 skipped, 0 failed).
- `integration-route-wiring-smoke.txt` — macOS integration output (1 passed).
- `integration-map-experience-wiring.txt` — macOS integration output (4 passed).
- `integration-vietnam-map-fidelity-wiring.txt` — macOS integration output (6 passed).
- `integration-route-planner-v2-flow.txt` — macOS integration output (7 passed).
- `lcov.info` — coverage from the in-scope unit/widget run (redirected via `--coverage-path`).

## Verdict

green — every in-scope automated test passed (285/285: 267 unit/widget + 18 integration), 0 skipped, 0
failed, 0 flaky. The previously-skipped dense along-segment sea-crossing guard is re-armed and green over the
rebuilt 34-unit coast-hugging spine (PC-909/910). No cross-feature regression. Manual legs TC-M-GEO /
TC-M-NF1 / TC-M-A11Y carried; the CRITICAL gating privacy leg TC-M-PRIV already PASSED at review (static
reinforcement PC-929 green here).
