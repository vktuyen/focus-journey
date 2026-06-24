---
verdict: green
total: 167
passed: 167
failed: 0
flaky: 0
skipped: 5
run_at: 2026-06-24T09:27:32Z
feature: journey-view
---

# Test Run Summary — journey-view

Execution + mechanical-flake-patching only. No functional fixes or test-logic
rewrites were applied. Every in-scope deterministic test passed on first run; no
flakes were observed, so no patches were needed.

`total`/`passed` count the executed tests (166 unit/widget + 1 integration smoke).
`skipped` = 2 opt-in perf tests (TC-015, TC-016) + 3 golden cases (TC-022/023/025)
that have **no committed golden test files and no stable headless golden infra** —
all five are documented deferrals, not failures (see Case coverage check).

## Environment & runner

- Runner: `fvm flutter test` — Flutter 3.38.10 (stable, rev c6f67dede3) / Dart 3.10.9 / DevTools 2.51.1 via **fvm** (`/Users/tuyenv/fvm/bin/fvm`). Bare `flutter` is not on PATH.
- Declared in `docs/architecture/overview.md` §"Automation testing": unit/widget + integration via `flutter test`; e2e via the `integration_test` package run with `flutter test integration_test/`.
- Project deviation (per overview.md): executable tests live INSIDE the package at `src/focus_journey/` — unit/widget under `test/`, e2e under `integration_test/`. All commands run with cwd = `/Users/tuyenv/WorkingRepos/joblogic-agentic-practices/src/focus_journey`.
- Integration harness constraint honoured: each `integration_test/` file was run in its OWN invocation (batching fails with "Unable to start the app").
- Platform: macOS (darwin 25.5.0). Headless/CI-style — no dedicated on-device perf desktop session.

## Exact command(s) run

All with cwd = `/Users/tuyenv/WorkingRepos/joblogic-agentic-practices/src/focus_journey`.

1. **Journey-view presentation suite** (the in-scope unit/widget files)
   `fvm flutter test test/features/journey/presentation/`
   -> exit code **0** — result line `00:04 +70: All tests passed!` (70 tests).

2. **Full unit/widget suite + coverage** (regression sweep — nothing else broke)
   `fvm flutter test --coverage`
   -> exit code **0** — result line `00:05 +166: All tests passed!` (166 tests; superset of run 1).
   Coverage moved into this report folder as `lcov.info`; repo-root `coverage/` removed (no litter).

3. **Integration smoke — TC-021** (own invocation per harness constraint)
   `fvm flutter test integration_test/journey_scene_smoke_test.dart`
   -> exit code **0** — result line `00:18 +1: All tests passed!` (1 test).

4. **Integration perf — TC-015/TC-016** (own invocation; opt-in, skipped by default)
   `fvm flutter test integration_test/journey_scene_perf_test.dart`
   -> exit code **0** — result line `00:16 +0 ~2: All tests skipped.` (2 tests skipped — correct gated behaviour).
   To execute on-device, re-run with `--dart-define=run-perf=true` on a real perf desktop session.

## Counts

| Metric  | Count | Notes |
|---|---|---|
| total   | 167 | 166 unit/widget (run 2, superset of the 70 in run 1) + 1 integration smoke |
| passed  | 167 | all executed tests green |
| failed  | 0   | — |
| flaky   | 0   | no retries needed; no flakes observed |
| skipped | 5   | 2 perf (TC-015/016, opt-in) + 3 golden cases (TC-022/023/025, no infra) — all documented deferrals |

## Per-file breakdown (in-scope files)

| File | Layer | Result |
|---|---|---|
| `test/features/journey/presentation/journey_view_state_test.dart` | unit | pass |
| `test/features/journey/presentation/journey_cubit_test.dart` | unit | pass |
| `test/features/journey/presentation/activity_ticker_test.dart` | unit | pass |
| `test/features/journey/presentation/journey_separation_static_test.dart` | static-inspection (unit) | pass |
| `test/features/journey/presentation/journey_screen_test.dart` | widget | pass |
| `test/features/journey/presentation/game/journey_game_motion_test.dart` | widget (Flame harness) | pass |
| `test/features/journey/presentation/game/journey_assets_test.dart` | static + harness | pass |
| `test/features/journey/presentation/game/journey_sprites_no_orphan_test.dart` | static/harness | pass |
| `integration_test/journey_scene_smoke_test.dart` | e2e | pass (TC-021) |
| `integration_test/journey_scene_perf_test.dart` | e2e perf | skipped (opt-in; TC-015/016) |

(`game/journey_game_test_harness.dart` is a shared helper, not a test file — not counted.)
The full sweep (run 2, 166 tests) also exercised journey-engine + activity-detection suites with no regressions.

## Per-test -> case mapping (TC-001…TC-027)

| TC | Covered by executed test | Status |
|---|---|---|
| TC-001 | `game/journey_game_motion_test.dart` -> "TC-001 active -> road/lanes/side-objects/vehicle advance monotonically" | pass |
| TC-002 | `journey_screen_test.dart` -> "TC-002 / TC-003 idle and paused both show overlay" | pass |
| TC-003 | `journey_screen_test.dart` -> "idleAndPaused_produceIdenticalOverlayPresentation" | pass |
| TC-004 | `game/journey_game_motion_test.dart` -> "TC-004 scene never moves while last state is idle/paused" | pass |
| TC-005 | `journey_view_state_test.dart` + `journey_cubit_test.dart` -> "updateFromEngine motion mapping (TC-005/TC-021)" | pass |
| TC-006 | `game/journey_game_motion_test.dart` -> "TC-006 / TC-024 bounded ease — no jank, shrinking deltas to zero" | pass |
| TC-007 | `game/journey_game_motion_test.dart` -> "TC-007 binary speed — constant while active, zero while stopped" | pass |
| TC-008 | `game/journey_game_motion_test.dart` -> "TC-008 vehicle sprite reflects mode; same speed across skins" | pass |
| TC-009 | `journey_separation_static_test.dart` -> "TC-009 scene source reads no OS/activity surface" | pass |
| TC-010 | `journey_separation_static_test.dart` (static half) + `journey_screen_test.dart` "TC-010 (runtime half)" | pass |
| TC-011 | `game/journey_assets_test.dart` -> "TC-011 every shipped asset is CREDITS-recorded" | pass |
| TC-012 | `game/journey_game_motion_test.dart` -> "TC-012 day/night tint cosmetic — motion identical across clocks" | pass |
| TC-013 | `journey_view_state_test.dart` (AC-13) + `journey_screen_test.dart` (overlay half) + `game/journey_game_motion_test.dart` "TC-013 first-frame / pre-state" | pass |
| TC-014 | `game/journey_assets_test.dart` + `game/journey_sprites_no_orphan_test.dart` -> "missing/failed asset degrades gracefully (no crash)" | pass |
| TC-015 | `integration_test/journey_scene_perf_test.dart` -> "TC-015 sustained frame rate while active" | **deferred (skipped)** — opt-in on-device perf run |
| TC-016 | `integration_test/journey_scene_perf_test.dart` -> "TC-016 no jank/dropped-frame spike on toggle" | **deferred (skipped)** — opt-in on-device perf run |
| TC-017 | `game/journey_game_motion_test.dart` -> "TC-017 bounded side-object pool — live count plateaus" | pass |
| TC-018 | `game/journey_game_motion_test.dart` -> "TC-018 suspend when not visible — pauseEngine stops motion advance" | pass |
| TC-019 | `game/journey_game_motion_test.dart` (motion-suppression half) + `journey_screen_test.dart` (indicator half) | pass |
| TC-020 | `journey_screen_test.dart` -> "TC-020 / TC-027 overlay is real text in the semantics tree" | pass |
| TC-021 | `integration_test/journey_scene_smoke_test.dart` -> "TC-021 mock-driven active->idle->active scrolls, stops+overlay, resumes" | pass |
| TC-022 | (golden — active frame) | **deferred** — no golden infra (see below) |
| TC-023 | (golden — stopped/overlay frame) | **deferred** — no golden infra (see below) |
| TC-024 | `game/journey_game_motion_test.dart` -> "TC-006 / TC-024 bounded ease — no jank, shrinking deltas to zero" | pass |
| TC-025 | (golden — day vs night) | **deferred** — no golden infra (see below) |
| TC-026 | Privacy audit — executed in Phase 4 via `/privacy-audit` -> PASS | covered elsewhere (not re-run here) |
| TC-027 | `journey_screen_test.dart` -> "activeVsStopped_areDistinguishableViaSemantics" | pass |

## Case coverage check (covered vs deferred)

**Covered by an executed passing test (22 cases):** TC-001, TC-002, TC-003, TC-004,
TC-005, TC-006, TC-007, TC-008, TC-009, TC-010, TC-011, TC-012, TC-013, TC-014,
TC-017, TC-018, TC-019, TC-020, TC-021, TC-024, TC-027 — plus **TC-026** covered
elsewhere (Phase 4 `/privacy-audit` PASS, referenced not re-run).

**Deferred (5 cases) — documented, NOT failures:**

- **TC-022 / TC-023 / TC-025 (goldens) — deferred: golden infra not stable headless.**
  Path taken: searched `test/` for `matchesGoldenFile` / a `goldens/` dir / any
  committed `.png` baseline — **none exist**. No golden test files were authored
  (build/self-review/review phases deferred goldens to this phase). Per the task
  guard and the test-script-author's finding, Flame's real-time render loop plus the
  intentionally-absent `ship.png` make headless byte-stable goldens non-deterministic
  on this machine, so I did **not** author tests or generate/commit unstable baselines
  (`--update-goldens` was NOT run — there are no golden tests to update). Their
  **behavioural counterparts all passed**: active-frame structure/motion via TC-001;
  stopped/parked + "Paused — idle" overlay via TC-002/TC-003; idle≡paused equivalence
  via TC-003; day/night cosmetic tint with identical motion via TC-012. AC-1/AC-2/AC-3/AC-12
  are behaviourally verified; only the pixel-level visual pins remain deferred until
  stable headless golden infra exists.
- **TC-015 / TC-016 (perf) — deferred to an on-device perf run.** The perf suite ran
  and correctly **skipped** (gated behind `--dart-define=run-perf=true`; headless/CI-style
  run, no dedicated perf desktop session). To execute:
  `fvm flutter test integration_test/journey_scene_perf_test.dart --dart-define=run-perf=true`
  on a real macOS/Windows desktop, recording device + OS. The no-jank ease property is
  already proven **deterministically** at the unit level by TC-006 and TC-024 (bounded,
  monotonically-shrinking per-frame deltas to zero, no spike).

Every AC (AC-1..AC-14) and every non-functional item has at least one covering test
that either passed or has a documented deferral with a passing behavioural counterpart.

## Failures

None. No reproducible functional failure, no weak/wrong assertion surfaced, no
missing-case gap requiring escalation. Nothing routed to flutter-app-developer /
flame-game-developer / test-script-author / test-case-designer.

## Flake patches applied

None. All deterministic tests passed on the first run with exit code 0; no retries
were performed and no test scripts were edited.

## Artifacts

All under `tests/_runner/reports/journey-view/20260624-092732/`:
- `summary.md` — this file.
- `output.log` — consolidated raw stdout of all four runs (RUN 1–4).
- `unit-output.log` — raw stdout, presentation suite (run 1).
- `full-unit-output.log` — raw stdout, full suite + coverage (run 2).
- `integration-smoke-output.log` — raw stdout, TC-021 smoke (run 3).
- `integration-perf-output.log` — raw stdout, TC-015/016 perf, skipped (run 4).
- `lcov.info` — coverage from run 2 (moved out of repo-root `coverage/`).

## Verdict

green
