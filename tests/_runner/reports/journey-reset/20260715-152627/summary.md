---
verdict: green
total: 1235
passed: 1235
failed: 0
flaky: 0
skipped: 0
run_at: 2026-07-15T15:26:27Z
feature: journey-reset
---

# Test Run Summary — journey-reset

Toolchain: `fvm flutter` (SDK 3.38.10, Dart 3.10.9), run from `src/focus_journey/`. Executable
tests live inside the Flutter package (`test/` + `integration_test/`), per the confirmed project
deviation documented in `docs/architecture/overview.md`. Manual / on-device / audit legs (TC-M*)
are carried, not run. Any running `focus_journey` app instance was killed before the integration
legs so it could not interfere.

## Invocation commands

- Full unit/widget suite (regression + journey-reset coverage):
  `fvm flutter test --coverage --coverage-path=<report>/lcov.info`
- journey-reset in-scope unit/widget subset (10 files, clean per-feature count):
  `fvm flutter test test/features/reset/... test/features/{journey,route,stats,mini_window}/data/..._reset_test.dart`
- Integration (each file run SEPARATELY on macOS, per the known multi-entrypoint harness caveat):
  - `fvm flutter test integration_test/journey_reset_factory_reset_test.dart -d macos`
  - `fvm flutter test integration_test/journey_reset_launch_gate_test.dart -d macos`
  - `fvm flutter test integration_test/journey_reset_start_over_test.dart -d macos`

## Counts

| Layer | Total | Passed | Failed |
|---|---|---|---|
| Full unit/widget suite (`test/`) — regression check | 1221 | 1221 | 0 |
| journey-reset in-scope unit/widget subset (10 files) | 60 | 60 | 0 |
| Integration: `journey_reset_factory_reset_test.dart` (macOS) | 4 | 4 | 0 |
| Integration: `journey_reset_launch_gate_test.dart` (macOS) | 6 | 6 | 0 |
| Integration: `journey_reset_start_over_test.dart` (macOS) | 4 | 4 | 0 |
| **Run total (full suite + 3 integration files)** | **1235** | **1235** | **0** |

- Full suite final line: `All tests passed!` at `+1221`. No `[E]` markers, no `Some tests failed`.
  This matches the prior ~1221 baseline — **no cross-feature regression**; the whole package
  (journey-engine / route-planner-v2 / route-progress / map-experience / idle-accounting / activity /
  stats / mini-window) stays green with the journey-reset slice included.
- The 60 in-scope subset tests are a subset of the 1221 full-suite tests (not double-counted in the
  run total); run standalone to give a clean per-feature figure.
- Each integration file ended with `All tests passed!` at its respective `+N`.

## Per-integration-file outcome

- `journey_reset_factory_reset_test.dart` (macOS): **4/4 PASS**, first attempt, no retry.
- `journey_reset_launch_gate_test.dart` (macOS): **6/6 PASS**, first attempt, no retry.
- `journey_reset_start_over_test.dart` (macOS): **4/4 PASS**, first attempt, no retry.

The known multi-entrypoint `integration_test` "Error waiting for a debug connection" harness flake
did **not** occur on any file (each was run in its own invocation as instructed). **No retry was
needed on any integration file.**

## TC → result mapping

### Integration legs (macOS, `integration_test/`)

Factory reset — `journey_reset_factory_reset_test.dart`:
- integration_test/journey_reset_factory_reset_test.dart::TC-704 → AC-3 (confirm clears EVERY key incl. both mini_window + legacy route_selection_v1) PASS
- integration_test/journey_reset_factory_reset_test.dart::TC-706 → AC-4 (next autosave after wipe writes zero-state, not pre-reset distance) PASS
- integration_test/journey_reset_factory_reset_test.dart::TC-706b → AC-4 (rebuilt engine + route cubit report zero, nothing rehydrates) PASS
- integration_test/journey_reset_factory_reset_test.dart::"AC-5 relaunch after reset = onboarding" → AC-5, AC-7 (onboarding, zero stats, default window/tray, prompt suppressed) → realizes TC-707 / TC-708 / TC-709 PASS

Launch gate — `journey_reset_launch_gate_test.dart`:
- integration_test/journey_reset_launch_gate_test.dart::TC-710 → AC-6 (active route → prompt shown) PASS
- integration_test/journey_reset_launch_gate_test.dart::TC-711 → AC-7 (fresh install → no prompt) PASS
- integration_test/journey_reset_launch_gate_test.dart::TC-712 → AC-7 (completed → no prompt) PASS
- integration_test/journey_reset_launch_gate_test.dart::TC-713 → AC-7 (abandoned → no prompt) PASS
- integration_test/journey_reset_launch_gate_test.dart::TC-714 → AC-8 (Resume reaches identical prior position) PASS
- integration_test/journey_reset_launch_gate_test.dart::TC-715 → AC-8 (Resume keys off persisted distance, no sleep/wake jump) PASS

Start over — `journey_reset_start_over_test.dart`:
- integration_test/journey_reset_start_over_test.dart::TC-716/TC-717 → AC-9 (fresh offset == cumulative D, engine cumulative untouched) PASS
- integration_test/journey_reset_start_over_test.dart::TC-718 → AC-10 (only route keys change; lifetime keys retained byte-for-byte) → also realizes TC-719 (no lifetime key deleted) PASS
- integration_test/journey_reset_start_over_test.dart::TC-720 → AC-11, AC-6 (relaunch offers Resume on the NEW route) PASS
- integration_test/journey_reset_start_over_test.dart::TC-721 → AC-12 (from identical seed, Start over keeps cumulative; Factory reset clears — BR-8 carve-out) PASS

### Unit/widget legs (`test/`, 60-test subset — realized, all green)

The 60 subset tests across the 10 in-scope files realize the deterministic automatable cases:
- TC-701, TC-703, TC-722 → AC-1 / NFR-3 (destructive confirmation shown, irreversible + distinct-from-Start-over labelling, asymmetry warning) — `presentation/factory_reset_dialog_test.dart`, `factory_reset_cubit_test.dart` PASS
- TC-702, TC-702b → AC-2 (cancel and Esc/scrim dismiss both inert, zero writes) — `factory_reset_dialog_test.dart` PASS
- TC-705 → AC-3 (key-list drift guard against the canonical registry) — `domain/local_data_reset_service_test.dart` PASS
- TC-704 (per-repo half) + TC-707 → AC-3 / AC-5 (each repo's reset seam clears its keys incl. both mini_window keys) — `journey/route/stats/mini_window .../data/..._reset_test.dart` PASS
- TC-706b → AC-4 (in-memory zero-state re-init) — `presentation/factory_reset_cubit_test.dart` PASS
- TC-709, TC-710, TC-711, TC-712, TC-713 → AC-5/6/7 (launch-gate decision function per lifecycle state) — `domain/launch_gate_test.dart`, `presentation/launch_gate_cubit_test.dart`, `launch_prompt_test.dart` PASS
- TC-714 → AC-8 (restore mapping unit side) — `launch_gate` / restore tests PASS
- TC-716, TC-717 → AC-9 (offset/lifecycle math + reuse-not-reinvent static check) — `presentation/factory_reset_cubit_test.dart` / reset service PASS
- TC-719 → AC-10 / AC-12 (Start over clears no lifetime key) PASS
- TC-721, TC-722 → AC-12 (asymmetry math + in-product surfacing copy) PASS
- TC-723 → NFR-1 (bounded in-memory wipe/re-init/gate, no network/disk on hot path) PASS
- TC-724 → NFR-2 (static import/manifest guard: only deletes, no new read/network/dependency) PASS
- TC-725 → NFR-3 (Semantics labels + keyboard focus/activation on both dialogs, destructive action distinguished) PASS

Every automatable case TC-701..TC-725 has at least one passing test across the two layers.

## Manual / on-device / audit legs carried (not run — by design)

From `tests/cases/journey-reset.md` (TC-M*); NOT attempted by the executor:
- TC-M-BOOT (AC-5/6/7/8/11, [DEVICE]) — launch-gate bootstrap across a real kill/reopen. CARRIED / manual.
- TC-M-NF1 (NFR-1, [DEVICE]) — reset + reopen feel instant, no perceptible stall. CARRIED / manual.
- TC-M-A11Y (NFR-3, [AT]) — real screen-reader + full keyboard-only operation of both dialogs. CARRIED / manual.
- TC-M-PRIV (NFR-2, [AUDIT], **CRITICAL / GATING**) — `/privacy-audit` PASS + runtime egress monitoring (feature only deletes, adds no read/network/dependency, genuinely erases). CARRIED / manual. **Gates ship regardless of the green automated verdict.**
- Windows runtime legs of all of the above are **DEFERRED — required before any Windows release**.

## Notes — flakes & environment caveats

- **No flakes encountered; no retries applied.** All five runs were green on the first attempt.
- `Failed to foreground app; open returned 1` appeared **once per integration file** during the
  macOS app launch (documented sandbox foreground/relaunch infra limitation, same as prior
  route-planner-v2 / map-experience reports). This is NOT an assertion failure: in each case the
  test body ran in full immediately afterward and the run ended with `All tests passed!` at its
  respective `+N`. A single launch warning followed by a clean full-body pass means no retry needed.
- `Exception: Invalid image data` lines in `unit-output.txt` are offline OSM tile-decode noise from
  the `flutter_map` tile layer under headless widget tests (those tests assert the offline path
  renders polyline/markers/red-trace WITHOUT tiles and explicitly expect "no throw"). Expected log
  noise, not assertion failures — `[E]` count is 0 and the suite ended green.
- No production logic changed and no assertions weakened (execution + flake-handling scope only);
  no flake patches were needed, so no test scripts were edited.

## Artifacts (all under this report folder)

- `unit-output.txt` — full `fvm flutter test --coverage` console output (1221 passed).
- `unit-subset-output.txt` — journey-reset 10-file subset console output (60 passed).
- `integration-factory-reset.txt` — macOS integration output (4 passed).
- `integration-launch-gate.txt` — macOS integration output (6 passed).
- `integration-start-over.txt` — macOS integration output (4 passed).
- `lcov.info` — coverage from the full-suite run (redirected via `--coverage-path` into this folder).

## Verdict

green — all in-scope automated tests pass (1235/1235: full suite 1221 + 14 integration), no
regression against the ~1221 baseline, no flakes, no retries. Manual legs TC-M-BOOT / TC-M-NF1 /
TC-M-A11Y / TC-M-PRIV carried as manual, with **TC-M-PRIV flagged as the critical gating privacy
audit still owed before ship**.
