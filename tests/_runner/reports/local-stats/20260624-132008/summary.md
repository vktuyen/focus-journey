---
verdict: green
total: 191
passed: 191
failed: 0
flaky: 0
skipped: 0
deferred: 8
run_at: 2026-06-24T13:20:08Z
feature: local-stats
---

# Test Run Summary — local-stats

Vietnam Focus Journey (Flutter desktop, macOS). Runner per
`docs/architecture/overview.md` "Automation testing": `fvm flutter test` for
unit/widget, `fvm flutter test integration_test/` (run per-file) for e2e.
Working dir: `src/focus_journey/`.

## Verdict

**green** — every in-scope automated test passed. Static analysis clean. The
deferred/manual cases (golden TC-NF4, privacy-audit ship-gate TC-022, real-OS
device legs TC-NF5a–d) are carried, not run, and per the cases file do not block
green.

## Totals (automated, in-scope to this run)

| Layer | Command | Passed | Failed | Skipped |
|---|---|---|---|---|
| Static analysis | `fvm flutter analyze` | clean (No issues found) | — | — |
| Stats unit/widget | `fvm flutter test test/features/stats` | 176 | 0 | 0 |
| Integration — persistence | `fvm flutter test integration_test/stats_persistence_test.dart` | 4 | 0 | 0 |
| Integration — wiring | `fvm flutter test integration_test/stats_wiring_test.dart` | 11 | 0 | 0 |
| **In-scope total** | | **191** | **0** | **0** |

> Whole-package sanity run (`fvm flutter test`, all features) also passed:
> **484 / 484**, "All tests passed!" — confirms the stats suite is green inside
> the full suite and introduced no cross-feature regression. The 191 above is the
> stats-scoped slice of that.

Coverage (stats suite, `--coverage`): 685 / 774 lines = **88.5%** over the 20
`lib/features/stats/**` source files. Raw `lcov.info` saved in this folder.

## Individual-vs-batch integration note (required)

Per the documented macOS desktop harness limitation, the two integration files
were run **individually**, NOT as a single `fvm flutter test integration_test/`
batch. Batch invocation is known to emit spurious `[E]` "Unable to start the app
on the device" launch failures that also hit untouched files
(`route_persistence`, `journey_scene_smoke`). Each per-file run is the
authoritative result:

- `stats_persistence_test.dart` → 4 passed (`+4: All tests passed!`)
- `stats_wiring_test.dart` → 11 passed (`+11: All tests passed!`)

No batch run was performed for this report, so there is no batch launch-noise to
record this time; both files pass cleanly in isolation.

## Per-test → case mapping

### Unit / widget (`test/features/stats/**`, 176 tests)
- domain/daily_stats_test.dart → TC-001, TC-002 (honesty invariant raw ≤ journey) ✓
- domain/best_focus_tracker_test.dart → TC-003 ✓
- domain/calendar_week_test.dart → TC-004 (Mon–Sun edges) ✓
- domain/weekly_stats_test.dart → TC-004 (weekly aggregate) ✓
- domain/focus_streak_test.dart → TC-016 (raw-active ≥ 25 min/day, 25 qualifies / 24 breaks) ✓
- domain/badge_evaluator_test.dart → TC-013, TC-014, TC-015, TC-017, TC-018 (four families, thresholds, permanent vs windowed) ✓
- domain/json_round_trip_test.dart → TC-007, TC-027 (blob schema = AC-5 field set, nothing more) ✓
- domain/stats_domain_smoke_test.dart → TC-NF1 (determinism — pure functions) ✓
- presentation/stats_cubit_test.dart → TC-001, TC-002 (projection) ✓
- presentation/stats_screen_test.dart → TC-001, TC-002, TC-003 (two distinct labelled values) ✓
- presentation/badges_screen_test.dart → TC-013..TC-018 (earned/locked list) ✓
- presentation/settings_cubit_test.dart → TC-008, TC-009 (threshold knob/persist) ✓
- presentation/settings_screen_test.dart → TC-008, TC-010, TC-011, TC-012, TC-021 (re-open) ✓
- presentation/onboarding_screen_test.dart → TC-021 (claim copy renders) ✓
- presentation/onboarding_gate_test.dart → TC-021 (first-run flag / not re-shown) ✓
- stats_separation_static_test.dart → TC-026, TC-027, TC-NF2, TC-NF3 (static: no ActivityPlugin/MethodChannel/network; layering; write-free consumer) ✓

### Integration — `integration_test/stats_persistence_test.dart` (4 tests)
- → TC-005 (record day before counters zero) ✓
- → TC-007 (history persists/reloads across restart, no new store) ✓
- → TC-019 (daily reset at midnight while running; cumulative persists) ✓
- → TC-020 (daily reset across midnight when app was closed; restore on D+1) ✓

### Integration — `integration_test/stats_wiring_test.dart` (11 tests)
- → TC-008 (idle threshold applied on engine's next tick) ✓
- → TC-010 (launch-at-startup read-on-open / write-on-flip, injected fake) ✓
- → TC-011 (notifications local toasts only; master toggle gates all types) ✓
- → TC-012 (badge-earned once; gated streak reminder — no-nag, not-while-active) ✓
- → TC-NF3 (no network / offline end-to-end) ✓

## Deferred / manual / not-run (carried — do not block green)

| Case | Status | Reason |
|---|---|---|
| TC-022 | NOT RUN (manual ship-gate) | `/privacy-audit` copy ⇄ code release gate — manual audit by `privacy-guardian`, not an automated assertion. Statically reinforced (not replaced) by TC-026/TC-027 which passed. A fail here blocks ship regardless of this run. |
| TC-NF4 | DEFERRED | Goldens not introduced in this repo (no stable per-OS-tolerant golden harness), consistent with the journey-view decision. The visual structure those goldens would pin (TC-002 two-value honesty layout, TC-013 earned/locked list, TC-021 onboarding copy) is asserted behaviourally in the widget tests, which passed. |
| TC-NF5a | NOT RUN (manual / device) | Real launch-at-startup OS registration, per-OS. Automated fake leg TC-010 passed. |
| TC-NF5b | NOT RUN (manual / device) | Real badge-earned OS toast delivery, per-OS. Automated fake leg TC-011/TC-012 passed. |
| TC-NF5c | NOT RUN (manual / device) | Real gated streak-reminder OS toast, per-OS. Automated fake leg TC-012 passed. |
| TC-NF5d | NOT RUN (manual / device) | Real-OS no-network-egress verification, per-OS. Static leg TC-NF3 passed. |

(TC-022, TC-NF4, and TC-NF5a–d = 6 distinct checklist entries; TC-NF5 spans 4
per-OS legs. Manual checklist: `tests/cases/local-stats-manual-checklist.md`.)

## AC coverage status (automated)

AC-1..AC-20 all have at least one passing automated case this run. AC-21 (TC-022)
is the manual `/privacy-audit` gate — automated reinforcement (TC-026/TC-027)
passed; the audit itself is still owed before ship. AC-10 / AC-11 real-OS legs
(TC-NF5) are the manual device checks; their automated fake legs passed.

## Failures routed

None. No functional regression (→ `flutter-app-developer`), no weak/wrong
assertion (→ `test-script-author`), no missing case (→ `test-case-designer`).

## Flake patches applied

None. No mechanical flake observed; no test file was edited. All runs passed on
first invocation.

## Notes for a reviewer

- Before ship, the manual `/privacy-audit` (TC-022) and the per-OS device checks
  (TC-NF5a–d) on a real macOS and Windows build still need running and recording
  in `tests/cases/local-stats-manual-checklist.md`. They are outside automated
  scope and were not attempted here.
- Coverage `lcov.info` was moved out of the repo-root `coverage/` directory into
  this report folder per the architecture doc's "do not leave coverage at repo
  root" rule; the temporary `coverage/` dir was removed.

## Raw artifacts (this folder)
- `analyze.txt` — `fvm flutter analyze` output (clean)
- `unit.txt` — full-package `fvm flutter test` (484/484)
- `unit-stats-only.txt` — `fvm flutter test test/features/stats` (176/176)
- `integration-persistence.txt` — per-file e2e (4/4)
- `integration-wiring.txt` — per-file e2e (11/11)
- `lcov.info` — stats-suite coverage (88.5% lines)
