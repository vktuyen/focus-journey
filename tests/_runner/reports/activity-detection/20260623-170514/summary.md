---
verdict: green
total: 36
passed: 36
failed: 0
flaky: 2
skipped: 0
run_at: 2026-06-23T17:05:14Z
feature: activity-detection
---

# Test Run Summary — activity-detection

In-scope automated tests all passed. The two integration files that initially errored
were a **launch / debug-connection flake** when run back-to-back in one suite invocation;
both passed cleanly on an isolated re-run (see Notes -> Flake). No functional test
assertion failed. Verdict: **green**.

## Toolchain / runner

- SDK: Flutter 3.38.10 (stable) - Dart 3.10.9 - DevTools 2.51.1 (pinned via fvm 4.0.5)
- Package under test: `src/focus_journey/`
- Device for integration: `macOS (desktop) - macos - darwin-arm64` (macOS 26.5.1). Real
  `MethodChannelActivityPlugin` native channel confirmed live (harness logged climbing idle
  seconds, lock=false).
- Windows backend NOT exercised this run (no Windows device available — that half stays manual).

### Invocation commands

```
# from src/focus_journey
fvm flutter --version
fvm flutter test --coverage --coverage-path=<report>/lcov.info        # unit/widget
fvm flutter test integration_test/ -d macos                           # full integration suite (1st pass)
fvm flutter test integration_test/activity_real_backend_smoke_test.dart -d macos   # isolated re-run
fvm flutter test integration_test/activity_logging_harness_test.dart  -d macos     # isolated re-run
```

Raw stdout: `unit-output.txt`, `integration-output.txt`, `integration-retry-smoke.txt`,
`integration-retry-harness.txt`, `devices.txt`. Coverage: `lcov.info` (in this folder).

## Per-file results

| File | Layer | Passed | Failed | Skipped | Notes |
|---|---|:--:|:--:|:--:|---|
| `test/features/activity/domain/activity_plugin_contract_test.dart` | unit | 8 | 0 | 0 | contract-shape, both impls |
| `test/features/activity/data/method_channel_activity_plugin_test.dart` | unit | 16 | 0 | 0 | typed-failure + payload coercion |
| `test/features/activity/data/mock_activity_source_test.dart` | unit | 7 | 0 | 0 | deterministic mock |
| `test/widget_test.dart` | widget | 1 | 0 | 0 | boilerplate counter |
| `integration_test/activity_flag_di_test.dart` | integration | 2 | 0 | 0 | flag->DI wiring (flag OFF -> real backend branch) |
| `integration_test/activity_real_backend_smoke_test.dart` | e2e | 2 | 0 | 0 | **flaky**: launch-errored in suite, passed isolated |
| `integration_test/activity_logging_harness_test.dart` | e2e | 1 | 0 | 0 | **flaky**: launch-errored in suite, passed isolated; real idle readings logged |
| **Total** | | **36** | **0** | **0** | |

Unit/widget: 32 across 4 files (8+16+7+1). Integration/e2e: 5 across 3 files. Grand total 36.

## Per-test -> TC mapping

| Test (file :: case) | TC | Result |
|---|---|:--:|
| `mock_activity_source_test.dart` :: getSystemIdleSeconds caller-set values | TC-012 | PASS |
| `mock_activity_source_test.dart` :: isScreenLocked caller-set values | TC-013 | PASS |
| `mock_activity_source_test.dart` :: seed / independence / stability / queued-error | TC-012, TC-013, TC-016, TC-017 | PASS |
| `activity_plugin_contract_test.dart` :: MockActivitySource reads return driven values | TC-012, TC-013, TC-014 | PASS |
| `activity_plugin_contract_test.dart` :: MockActivitySource unavailable signal -> typed exception | TC-016, TC-017 | PASS |
| `activity_plugin_contract_test.dart` :: isA<ActivityPlugin> (both impls) | TC-011, TC-014 | PASS |
| `activity_plugin_contract_test.dart` :: MethodChannel reads / unavailable signal / isA | TC-011, TC-014, TC-016 | PASS |
| `method_channel_activity_plugin_test.dart` :: getSystemIdleSeconds happy path | TC-014 (contract shape) | PASS |
| `method_channel_activity_plugin_test.dart` :: isScreenLocked happy path | TC-014 (contract shape) | PASS |
| `method_channel_activity_plugin_test.dart` :: getSystemIdleSeconds unavailable/denied/missing/null -> typed | TC-016 | PASS |
| `method_channel_activity_plugin_test.dart` :: isScreenLocked unavailable/denied -> typed | TC-017 | PASS |
| `method_channel_activity_plugin_test.dart` :: payload coercion (double/string -> unavailable) | TC-016, TC-017 | PASS |
| `widget_test.dart` :: counter increments | (none — boilerplate) | PASS |
| `activity_flag_di_test.dart` :: create() resolves selected impl (flag OFF -> MethodChannel) | TC-014, TC-015 | PASS |
| `activity_flag_di_test.dart` :: create(mockSeed:) honoured only when flag on | TC-015 | PASS |
| `activity_real_backend_smoke_test.dart` :: idle non-negative + monotonic (macOS, best-effort) | TC-001, TC-002 (smoke) | PASS |
| `activity_real_backend_smoke_test.dart` :: isScreenLocked returns bool while unlocked | TC-006 (read-shape) | PASS |
| `activity_logging_harness_test.dart` :: logs idle+lock on a timer | TC-001..TC-010 (manual support harness) | PASS |

## ACs demonstrated green by automation vs manual-only

Demonstrated green by automation this run:
- **AC-6** (mock injectable + deterministic) — TC-012/TC-013/TC-014/TC-015 (unit + DI wiring).
- **AC-10** (typed failure on unavailable/denied) — TC-016/TC-017 (unit, incl. payload coercion).
- **AC-11** (contract is implementation-independent) — TC-011/TC-014 (both impls satisfy interface).
- **AC-1 / AC-2** (idle climbs) — best-effort macOS smoke only (TC-001/TC-002 smoke half).
  Deterministic +/-2s per-OS proof remains Manual. macOS smoke PASS; Windows not run.
- **AC-4** (lock state — macOS) — read-shape only (returns bool, false while unlocked).
  Full lock->unlock transition is Manual. macOS read-shape PASS.

Remain manual-only / not executed here (real-OS, two-platform, or audit):
- **AC-1..AC-5, AC-9** full per-OS verification — TC-001..TC-011 Manual checklist
  (`tests/cases/activity-detection-manual-checklist.md`). Not executed.
- **AC-3** (idle resets on input) — TC-003/TC-004/TC-005 — Manual, not executed.
- **AC-5** (lock state — Windows) — TC-007 — Manual, no Windows device, not executed.
- **AC-7 / AC-8** (privacy promise) — TC-018/TC-019/TC-020 — privacy-guardian **audit**, not an
  automated assertion. Not executed here; run via `/privacy-audit`.

## Raw failure output

No assertion failures. For traceability, the first-pass suite run produced these transient
launch errors (both files passed on isolated re-run):

```
00:28 +2 -1: ...activity_real_backend_smoke_test.dart [E]
  Failed to load "...activity_real_backend_smoke_test.dart": Unable to start the app on the device.
  (preceded by: Error waiting for a debug connection: The log reader stopped unexpectedly, or never started.)

00:40 +2 -2: ...activity_logging_harness_test.dart [E]
  Failed to load "...activity_logging_harness_test.dart": Unable to start the app on the device.
  (preceded by: Error waiting for a debug connection: The log reader stopped unexpectedly, or never started.)
```

## Notes

- **Flake (not patched in code).** Running all three integration files in a single
  `flutter test integration_test/` invocation causes the 2nd and 3rd app launches to lose the
  Flutter debug-VM connection ("log reader stopped unexpectedly / Unable to start the app"). This
  is a runner/launch race on this macOS session, NOT a test-code defect, so no script was edited.
  Mitigation used: re-ran each affected file in its own invocation; both passed. CI recommendation:
  run desktop integration files one-per-invocation (or add an inter-file launch delay) rather than
  as one batched suite. No mechanical flake patch was applied to any .dart file.
- The recurring `Failed to foreground app; open returned 1` line is non-fatal — it appears on
  passing runs too and does not affect the debug connection or assertions.
- **No functional code changes and no test-script edits were made.** This run is read-only on src/.
- **Review findings NOT yet fixed as of this run:**
  - **m1 — Windows cold-start lock parity:** NOT fixed. Windows isScreenLocked() cold-start
    behaviour is unverified here (no Windows device; TC-007/TC-008 remain manual).
  - **m3 — negative idle coercion:** NOT fixed. The plugin does not yet coerce/guard a negative
    idle value from the native side; current unit tests assert non-negative on the happy path but
    do not cover a native-returned negative. Route to code-generator (fix) and
    test-script-author (add the negative-idle assertion).
- Manual real-OS cases (TC-001..TC-011) and privacy audit cases (TC-018..TC-020) are listed as
  manual / not executed, not as passed.
