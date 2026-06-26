# Test run — dev-mode-switcher (quick-change)

verdict: green

**Date:** 2026-06-26 10:27:03
**Slug:** dev-mode-switcher
**Lane:** quick-change
**Runner:** `fvm flutter test` (per docs/architecture/overview.md)

## Totals
- **16 passed / 0 failed / 0 skipped / 0 flaky**
  - `test/features/journey/presentation/dev_mode_switcher_test.dart` — **6 passed** (the feature's AC tests)
  - `test/features/journey/presentation/journey_screen_test.dart` — **10 passed** (regression: the screen the switcher overlays)

## Command
```
fvm flutter test \
  test/features/journey/presentation/dev_mode_switcher_test.dart \
  test/features/journey/presentation/journey_screen_test.dart
```
(run from `src/focus_journey`)

## AC → test mapping (all green)
- **AC-1** (debug dropdown lists all six modes, current selected) → `debugBuildWithCallback_rendersDropdown_listingAllSixModes_currentSelected`
- **AC-2** (selecting a mode swaps the scene) → `tappingDropdownAndPickingMode_invokesCallbackWithSelectedMode` (screen fires callback) + `mainStyleCallback_writesEngineModeThenUpdatesCubit_emitsNewMode` (engine.mode write + cubit re-emit)
- **AC-3** (no production surface — gated) → `noCallback_dropdownAbsentFromTree` (null-callback half; the `kDebugMode` half is a compile-time const-false → tree-shaken in release, documented in-test)
- **AC-4** (cosmetic-only — accrual untouched) → `switchedMode_identicalTickSequence_yieldsIdenticalAccrualVsDefaultMode` + `switchingModeMidJourney_doesNotRetroactivelyChangeAccrual`

## Pre-run gates
- `/quick-change` review (flutter-code-reviewer): **approved-with-suggestions**, 0 Blocking.
- `dart format` applied to the test file (the one actionable suggestion); `fvm flutter analyze` on the 3 in-scope files: clean.
- `/privacy-audit` not required — the change reads no OS/system signal (it only sets the existing cosmetic `JourneyEngine.mode` field and re-publishes via the cubit).

## Notes
- No production code modified during test/ship (mechanical `dart format` only).
- Raw output: `in-scope.txt` in this folder.
