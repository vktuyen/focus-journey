---
verdict: green
total: 877
passed: 877
failed: 0
flaky: 0
skipped: 0
run_at: 2026-06-25T11:02:04Z
feature: route-planner-v2
---

# Test Run Summary — route-planner-v2

Toolchain: `fvm flutter` (SDK 3.38.10), run from `src/focus_journey/`. Executable tests live
inside the Flutter package (`test/` + `integration_test/`), per the confirmed project deviation
documented in `docs/architecture/overview.md`. Manual / on-device / audit legs are carried, not run.

## Counts

| Layer | Command | Total | Passed | Failed |
|---|---|---|---|---|
| Full unit/widget/integration suite (`test/`) | `fvm flutter test --coverage` | 870 | 870 | 0 |
| route-planner-v2 subset (`test/features/route/`) | `fvm flutter test test/features/route/` | 371 | 371 | 0 |
| E2E flow (macOS) | `fvm flutter test integration_test/route_planner_v2_flow_test.dart -d macos` | 7 | 7 | 0 |
| Run total (full suite + E2E flow) | | 877 | 877 | 0 |

- Full suite final line: `All tests passed!` at `+870`. No `[E]` markers, no `Some tests failed`.
- The route subset (27 test files under `test/features/route/`) was also run on its own for the
  clean 371-test count; `All tests passed!`.
- E2E flow final line: `All tests passed!` at `+7`.
- No cross-feature regression: the whole package suite is green, including upstream
  route-progress / map-experience / idle-accounting / activity / stats tests.

## E2E flow -> TC / AC mapping (integration_test/route_planner_v2_flow_test.dart, -d macos)

- TC-314 -> AC-6 — full review+edit+cancel cycle records NOTHING (gating snapshot) PASS
- TC-315 -> AC-6 — opening review screen stamps no offset, writes nothing PASS
- TC-316 -> AC-6 / NFR-1 — burst of review edits is in-memory only, zero writes PASS
- TC-330 -> AC-10 / AC-7 — confirm->travel->abandon->new-route; one offset, preserved cumulative, correct new-route position PASS
- TC-334 -> AC-12 — active custom route survives restart via the seam PASS
- TC-335 -> AC-12 / AC-11 — restored route red trace is current-route-only after a prior abandon PASS
- TC-336 -> AC-12 — completed lifecycle restores without re-firing arrival celebration PASS

## Unit/widget subset -> TC / AC mapping (test/features/route/, -d host)

The 371 route subset tests realize the automatable cases TC-301..TC-340 across domain/ (resolution,
auto-insert, offset/lifecycle math, single-km-axis reuse), presentation/ (picker, review screen,
abandon guard, red-trace no-bleed, semantics/keyboard), data/ (persistence seam), and the two
static-separation files. AC/NFR coverage realized by this subset:

- AC-1 -> TC-301, TC-302, TC-304, TC-305 PASS (domain resolution + picker widget)
- AC-2 -> TC-303, TC-305, TC-312 PASS (picker disable + review-edit minimum)
- AC-3 -> TC-306, TC-307, TC-308 PASS (auto-insert pure fn + geography-source separation)
- AC-4 -> TC-308, TC-309 PASS (out-of-span stop extends the span)
- AC-5 -> TC-310, TC-311, TC-312, TC-313 PASS (review render + edit/re-resolve + cancel-nav)
- AC-6 -> TC-314, TC-315, TC-316 PASS (gating zero-side-effect — realized in E2E flow above)
- AC-7 -> TC-317, TC-318, TC-319, TC-330, TC-333 PASS (one offset; unchanged resolver/projector; single km axis)
- AC-8 -> TC-320, TC-321, TC-322, TC-323 PASS (route-relative completion; route % vs country %)
- AC-9 -> TC-324, TC-325, TC-326 PASS (abandon guard; cancel inert; no guard at no-progress)
- AC-10 -> TC-327, TC-328, TC-329, TC-330 PASS (new offset; no lifetime reset; abandoned != completed)
- AC-11 -> TC-331, TC-332, TC-333, TC-335 PASS (new route's red trace shows only new offset's segments)
- AC-12 -> TC-334, TC-335, TC-336 PASS (active custom route + lifecycle survive restart)
- NFR-1 (deterministic) -> TC-316, TC-338, TC-340 PASS (re-resolve in-memory, allocation-bounded, no I/O)
- NFR-2 (static, CRITICAL gate) -> TC-307, TC-337, TC-338 PASS (no GPS/location API; static geography only; zero network from planning paths)
- NFR-3 (deterministic) -> TC-339 PASS (Semantics labels + keyboard focus/activation on picker/review/abandon)

Every automatable AC-1..AC-12 and NFR-1..NFR-3 deterministic subset has at least one passing test.

## Manual-only legs carried (not run — by design)

From tests/cases/route-planner-v2-manual-checklist.md; NOT attempted by the executor:

- TC-M-A11Y (NFR-3, [AT]) — real screen reader + full keyboard-only operation of picker/review/abandon. CARRIED / manual.
- TC-M-NF1 (NFR-1, [DEVICE]) — no-jank fps on macOS + Windows. CARRIED / manual.
- TC-M-PRIV (NFR-2, [AUDIT], CRITICAL GATING) — /privacy-audit PASS + runtime egress monitoring (no slice-attributable network call, no GPS/location, no new identifier/trail). CARRIED / manual. Gates ship regardless of the green automated verdict.
- Windows runtime legs of all three are DEFERRED — required before any Windows release.

## Notes — flakes & environment caveats

- No flakes encountered; no retries applied. Both runs were green on the first attempt.
- `Failed to foreground app; open returned 1` appeared ONCE during the macOS app launch for the
  E2E run (documented sandbox foreground/relaunch infra limitation). This is NOT a route-planner-v2
  assertion failure: the test BODY ran in full immediately afterward — all 7 tests executed and the
  run ended with `All tests passed!` at `+7`. The route flow file was run individually on `-d macos`
  as instructed; a single launch warning followed by a clean full-body pass means no retry was needed.
- `Exception: Invalid image data` lines in unit-output.txt are offline tile-decode noise from the
  flutter_map/OSM tile layer under the headless widget tests (those tests assert the offline path
  renders polyline/markers/red-trace WITHOUT tiles and explicitly expect "no throw"). Expected log
  noise, not assertion failures — `[E]` count is 0 and the suite ended green.

## Artifacts (all under this report folder)

- unit-output.txt — full `fvm flutter test --coverage` console output (870 passed).
- integration-output.txt — macOS E2E flow console output (7 passed).
- lcov.info — coverage from the full suite run (redirected via --coverage-path into this folder).

## Verdict

green — all in-scope automated tests pass (877/877); manual legs TC-M-A11Y / TC-M-NF1 / TC-M-PRIV
carried as manual, with TC-M-PRIV flagged as the critical gating audit still owed before ship.
