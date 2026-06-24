---
verdict: green
total: 63
passed: 63
failed: 0
flaky: 0
skipped: 0
run_at: 2026-06-23T18:10:42Z
feature: journey-engine
---

# Test Run Summary — journey-engine

All 63 in-scope tests passed deterministically on the first run. No flakes, no
mechanical patches applied. Verdict: **green**.

## Environment & runner

- Runner: `fvm flutter test` (per `docs/architecture/overview.md` Automation testing — Unit layer).
- Flutter 3.38.10 • Dart 3.10.9 (via fvm; bare `flutter` not on PATH).
- Executed from inside the Flutter package `src/focus_journey/` (project deviation:
  executables live under `src/`, not the top-level `tests/` tree).
- `JourneyEngine` is deterministic via injected clock + mock `ActivityPlugin` — no
  real timers/wall-clock waits, hence sub-second test execution.

## Exact command run

```
# cwd: /Users/tuyenv/WorkingRepos/joblogic-agentic-practices/src/focus_journey
fvm flutter test test/features/journey/ --reporter expanded \
  --coverage \
  --coverage-path /Users/tuyenv/WorkingRepos/joblogic-agentic-practices/tests/_runner/reports/journey-engine/20260623-181042/lcov.info
```

- Exit code: `0`
- Result line: `00:00 +63: All tests passed!`
- Wall-clock duration: ~3 s (package already compiled; dependency resolution dominated).

## Counts

| Metric  | Count |
|---------|-------|
| Total   | 63    |
| Passed  | 63    |
| Failed  | 0     |
| Flaky   | 0     |
| Skipped | 0     |

Per-file breakdown:

| File | Tests | Result |
|------|-------|--------|
| `src/focus_journey/test/features/journey/domain/journey_engine_test.dart` | 44 | all pass |
| `src/focus_journey/test/features/journey/domain/journey_progress_test.dart` | 4 | all pass |
| `src/focus_journey/test/features/journey/data/shared_preferences_journey_repository_test.dart` | 15 | all pass |

> `test/features/journey/` resolves to exactly the three in-scope files.
> `journey_progress_test.dart` is the persisted-snapshot model the engine restores
> from; it sits in the same `domain/` folder as a supporting hardening suite (B-4).

## Per-test → case mapping (TC-001 … TC-022 all covered)

### journey_engine_test.dart
- distance accrual: activeTick_oneHour / activeTick_partialHour → TC-001 ✓
- default-config active travel (B-2) → TC-001 ✓
- journey vs raw separation → TC-002 ✓
- active tick accounting (idleBelowFloor / idleExactlyAtFloor) → TC-003 ✓
- grace tick accounting (idleBetweenFandG / idleExactlyAtG) → TC-004 ✓
- past grace, idle only → TC-005 ✓
- lock overrides grace → TC-006 ✓
- sleep-inferred overrides grace (largeIdle / largeDelta) → TC-007 ✓
- sleep/wake gap is idle → TC-008 ✓
- delta-scaled elapsed (1x60s == 6x10s) → TC-009 ✓
- empty middle band default G=T → TC-010, TC-005 ✓
- idle vs paused G<T (middle band / locked→paused) → TC-011 ✓
- determinism (run twice / wall-clock independent) → TC-012 ✓
- mode is cosmetic → TC-013 ✓
- grace stays travel, no rollback → TC-014 ✓
- raw is streak metric and <= journey → TC-015 ✓
- local-midnight reset (reset / once-only) → TC-016 ✓
- restore across midnight (one-day / multi-day) → TC-017 ✓
- same-day round-trip → TC-018 ✓
- non-positive delta clamped (zero / negative) → TC-019 ✓
- future stored date treated as today → TC-020 ✓
- resume idle/paused to active → TC-021 ✓
- full-day end-to-end invariants → TC-022 ✓
- accrual clamp boundary (B, implementer-flagged, 3 tests) → TC-001/TC-004/TC-008 hardening ✓
- restore × midnight composition (B-3) → TC-011/TC-016 hardening ✓
- non-positive delta vs rollover ordering (S-6, 2 tests) → TC-019/TC-016 hardening ✓
- DST / exact-midnight rollover (S-4, 3 tests) → TC-016 hardening ✓
- construction validation (S-2, 3 tests: kmPerActiveHour / G>T / floor>=G) → config guards for TC-019/TC-010/TC-011/TC-003/TC-004 ✓

### journey_progress_test.dart (persisted snapshot model — supports restore family)
- JSON round-trip preserves all fields → TC-018 (AC-11) ✓
- corrupt input (B-4): missingRequiredNumericKey / malformedStoredDate / missingStoredDate throw FormatException → TC-017/TC-018 hardening ✓

### shared_preferences_journey_repository_test.dart (repository seam)
- load when nothing persisted returns null → TC-018 ✓
- saveThenLoad round-trips → TC-018 ✓
- save overwrites previous → TC-018 ✓
- corrupt blob never crashes (B-4, 5 tests: corruptNonJson / nonObjectTopLevel / missingRequiredKey / wrongTypedNumeric / malformedStoredDate → null) → TC-018 hardening ✓
- additional JourneyProgress validation (7 tests: storedDate normalisation, zero-padding, unknown state/mode fallback, typed-field & out-of-range FormatException) → TC-017/TC-018/TC-020 serialization hardening ✓

## Case coverage check
All 22 cases TC-001…TC-022 have >=1 passing executed test. No coverage gap to
escalate to test-case-designer.

## Failures
None.

## Flake patches applied
None. Deterministic by construction; passed first run with exit code 0.

## Artifacts
- Raw runner stdout/stderr: `output.log`
- Coverage (LCOV): `lcov.info`

## Verdict
**green** — all 63 in-scope tests passed; full TC-001…TC-022 traceability; no flakes; no escalations.
