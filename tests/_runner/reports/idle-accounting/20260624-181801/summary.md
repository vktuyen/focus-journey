---
verdict: green
total: 602
passed: 602
failed: 0
flaky: 0
skipped: 0
run_at: 2026-06-24T18:18:01Z
feature: idle-accounting
---

# Test Run Summary — idle-accounting (Wave 2 / v2)

All automated tests passed. The whole-package regression run (602 passed, 0 failed)
confirms the idle-accounting Option B slice is green AND introduces no cross-feature
regression in the shipped v1/v2 slices. The focused in-scope subset (102 passed across
the 5 files named for this feature) was run separately to give a clean per-test → case-ID
mapping. No flakes, no functional regressions, no weakened assertions, no mechanical patches.

NFR-1's privacy-audit portion (TC-112 audit leg) and the "no new OS signal" gate remain a
manual `/privacy-audit` ship-gate (privacy-guardian) — the unit-assertable subset (segment
shape is aggregate-only; engine consumes only `getSystemIdleSeconds()` + `isScreenLocked()`)
IS covered by automation (TC-112 / `activity_segment_test.dart`). Coverage is therefore
honest, not silently green.

## Runner

- **Runner:** Flutter test runner (`flutter test`), declared in `docs/architecture/overview.md` (Automation testing → Unit).
- **Invocation:** `fvm flutter` (fvm-pinned Flutter 3.38.10 / Dart 3.10.9 — bare `flutter` is not on PATH).
- All commands run from `src/focus_journey/` (Flutter tests live inside the package per the CONFIRMED layout decision in `overview.md`).

## Commands run (exact)

1. Whole-package regression + coverage:
   `fvm flutter test --coverage`
   → `coverage/lcov.info` moved into this report folder as `lcov.info`.
2. Focused in-scope subset (one combined run for the verdict + 5 per-file runs for counts):
   `fvm flutter test test/features/journey/domain/journey_engine_idle_accounting_test.dart test/features/journey/domain/activity_segment_test.dart test/features/journey/domain/journey_progress_test.dart test/features/journey/presentation/journey_cubit_test.dart test/features/journey/domain/journey_engine_test.dart`

## Pass/fail counts per invocation

| Invocation | Passed | Failed | Flaky | Skipped |
|---|---|---|---|---|
| `journey_engine_idle_accounting_test.dart` (primary suite, TC-100..TC-120) | 29 | 0 | 0 | 0 |
| `activity_segment_test.dart` (ActivitySegment model) | 7 | 0 | 0 | 0 |
| `journey_progress_test.dart` (segment persistence) | 15 | 0 | 0 | 0 |
| `journey_cubit_test.dart` (idle-counter reconciliation / divergence-0) | 7 | 0 | 0 | 0 |
| `journey_engine_test.dart` (shipped engine — regression guard for Option B) | 44 | 0 | 0 | 0 |
| **In-scope idle-accounting total** | **102** | **0** | **0** | **0** |
| Whole-package regression — `fvm flutter test --coverage` (all v1 + v2) | 602 | 0 | 0 | 0 |

The in-scope 102 are a member of the 602. The whole-package green confirms **no regression**
in journey-engine, journey-view, route-progress, local-stats, activity-detection, mini-window, etc.

## Per-test → case mapping

### Primary idle-accounting suite — `test/features/journey/domain/journey_engine_idle_accounting_test.dart` (TC-100..TC-120)
- `TC-100 pre-fix repro baseline (AC-2 regression anchor)::*` → TC-100 / AC-2 (regression baseline) ✓ — documented pre-fix snapshot, not a perpetual red test
- `TC-101 voluntaryIdle_idleTimeTodayEqualsWallTimeSinceOnset` → TC-101 / AC-1 ✓
- `TC-102 active_neverIncreasesAfterIdleTransition (honesty)` → TC-102 / AC-1 ✓
- `TC-103 lock_anchorsIdleAtLockInstant_overridesGrace` → TC-103 / AC-1 ✓
- `TC-103 sleepVariant_anchorsIdleAtSleepInstant` → TC-103 / AC-1 (sleep variant) ✓
- `TC-104 insideTickTransition_divergence0_atEveryBoundary` → TC-104 / AC-2 ✓
- `TC-105 manyTransitions_noCumulativeDrift` → TC-105 / AC-2 ✓
- `TC-106 onBoundaryTransition_divergence0` → TC-106 / AC-2 ✓
- `TC-107 segments_coverRunEndToEnd_contiguous_noOverlap` → TC-107 / AC-3 ✓
- `TC-108 summedSegmentDurations_equalTotalElapsed` → TC-108 / AC-3 ✓
- `TC-114 sharedBoundaryPosition_resolvesToExactlyOneSegment` → TC-114 / AC-3 ✓
- `TC-109 lockSegment_startsAtLockInstant_notNextBoundary` → TC-109 / AC-4 ✓
- `TC-110 voluntaryRamp_activeThenIdle_causeVoluntary` → TC-110 / AC-4 ✓
- `TC-111 mixedRun_everySegmentMatchesItsBand` → TC-111 / AC-4 ✓
- `TC-112 segments_onlyAggregateFields_engineUsesOnlyIdleAndLock` → TC-112 / NFR-1 (unit-assertable subset) ✓ — audit leg deferred (see Notes)
- `TC-113 nonPositiveDelta_clampedToZero_noSegmentMutation` → TC-113 / NFR-2 ✓
- `TC-115 futureStoredDate_restoresSegmentsIntact_noSpuriousSplit` → TC-115 / NFR-2 ✓
- `TC-115 pastStoredDate_dailyResetDropsSegments_preservesDistance` → TC-115 / NFR-2 (complementary past-date leg) ✓
- `Decision (d) grace-stays-travel (TC-116)::*` → TC-116 / AC-1, AC-3 ✓
- `Decision (c) midnight split (TC-117)::*` → TC-117 / AC-3 ✓
- `Decision (c) growth bound by merge (TC-118)::*` → TC-118 / AC-3 ✓
- `Decision (c) persistence across restart (TC-119)::*` → TC-119 / AC-3 ✓
- `TC-120 mixed full-day end-to-end (AC-1..AC-4)::*` → TC-120 / AC-1..AC-4 ✓

(29 test bodies in this file: the TC-100 baseline group, TC-116..TC-119 decision groups, and
the TC-120 group each contribute >1 test body; every TC-100..TC-120 case is covered.)

### ActivitySegment model — `test/features/journey/domain/activity_segment_test.dart`
- `jsonKeys_areOnlyAggregateFields_noInputContent` → TC-112 / NFR-1 (aggregate-only shape) ✓
- `sameClassificationAndCause_areMergeable` / `differentClassification_orCause_areNotMergeable` → TC-118 / AC-3 (merge eligibility) ✓
- `extendedTo_movesEnd_addsElapsed_keepsStartClassificationCause` → TC-118 / AC-3 (growth bound) ✓
- `toJson_then_fromJson_isLossless` / `fromJson_unknownEnumNames_degradeToSafeDefaults` / `fromJson_missingNumericField_throwsFormatException` → TC-119 / AC-3 (persistence round-trip + robustness) ✓

### Segment persistence — `test/features/journey/domain/journey_progress_test.dart`
- `segments_roundTripLosslessly` → TC-119 / AC-3 (segment record persistence) ✓
- `absentSegmentsKey_legacyBlob_restoresEmptyList` / `nonListSegments_throwsFormatException` / `listWithNonObjectElement_throwsFormatException` → TC-119 / NFR-2 (forward/backward-compatible restore robustness) ✓
- `storedDateWithClockTime_isNormalisedToDateOnly` / `storedDateIso_isZeroPaddedYyyyMmDd` / `outOfRangeStoredDate_throwsFormatException` → supports TC-115 / NFR-2 (date normalisation on restore) ✓
- remaining cases (`toJsonThenFromJson_preservesAllFields`, unknown-enum fallbacks, malformed-blob FormatExceptions) → upstream journey-engine persistence (AC-9/AC-10/AC-11), re-run here as the segment-bearing carrier model — green regression guard ✓

### Idle-counter reconciliation — `test/features/journey/presentation/journey_cubit_test.dart`
- `emittedIdleTimeToday_equalsEngineAccumulator_divergence0` → TC-104 / AC-2 (Bloc-layer divergence-0 check — closes the "what the UI shows" flag raised in cases on TC-104) ✓
- remaining cases (initial parked state, motion mapping TC-005/TC-021, resume mapping, redundant-emit skip) → upstream journey-view; green regression guard confirming the idle-counter wiring did not disturb the Bloc ✓

### Shipped engine regression guard — `test/features/journey/domain/journey_engine_test.dart`
- All 44 tests (JourneyEngine S-series / TC-0xx band, grace, honesty, daily-reset, persistence, DST/midnight) → upstream `journey-engine` cases — **green**, confirming Option B left the whole-tick accounting and honesty invariant intact (the regression guard the task called out). ✓

## In-scope AC / NFR coverage (covered-by-automation vs deferred-manual)

Covered by automation (deterministic scripted clock + mock ActivityPlugin, headless):
- **AC-1** (idle onset within one tick; active never increases after T) → TC-101, TC-102, TC-103, TC-116 ✓
- **AC-2** (UI idle counter vs accumulator, divergence 0; no cumulative drift) → TC-100 (baseline), TC-104, TC-105, TC-106 + Bloc-layer `journey_cubit_test` divergence-0 ✓
- **AC-3** (lossless + contiguous segment reconstruction; durations sum to elapsed; day-split; merge; persistence) → TC-107, TC-108, TC-114, TC-116, TC-117, TC-118, TC-119 ✓
- **AC-4** (segment labels + cause tagging; lock/sleep starts at lock instant) → TC-109, TC-110, TC-111 ✓
- **NFR-1** (aggregate-only segment record; no new OS signal — unit-assertable subset) → TC-112 + `activity_segment_test` shape assertions ✓
- **NFR-2** (delta ≤ 0 / clock step-back / future stored date clamped, no accrual, no segment corruption) → TC-113, TC-115 + `journey_progress_test` restore robustness ✓

Deferred-manual (NOT failures — carried to the ship gate):
- **NFR-1 audit gate** — "no new OS signal introduced" and `/privacy-audit` PASS are a review/audit gate handled by `privacy-guardian` via `/privacy-audit`, not fully expressible as a unit assertion (TC-112 audit portion, flagged "Manual / audit" in the cases file). The unit-assertable subset above is green; the audit verdict is a ship-blocker recorded for `/privacy-audit`.

## Flakes
None. No test was re-run to chase green; every invocation passed on the first run.
No mechanical patch (selector / timing / wait-condition / ordering) was applied, and no
production logic or assertion was touched.

## Notes for the reviewer
- Coverage data captured: `tests/_runner/reports/idle-accounting/20260624-181801/lcov.info`
  (whole-package lcov from invocation 1; the package-root `coverage/` dir was emptied and removed).
- TC-100 is intentionally a documented pre-fix-behaviour snapshot / regression anchor, not a
  perpetually-failing red test — it passes by asserting the baseline it captured, and TC-104 drives
  the displayed-vs-accumulator divergence to 0 on the fixed Option B engine. Both are green.
- The "what the UI would show" risk flagged on TC-104 in the cases file (Bloc-layer independent
  rounding) IS now covered: `journey_cubit_test.dart::emittedIdleTimeToday_equalsEngineAccumulator_divergence0`
  asserts the Bloc emits the engine accumulator with divergence 0 — no independent rounding before display.
- No new scenarios were authored and no assertions were changed; this run is execution-only.

## Verdict
green
