# Test run — vehicle-picker (ship gate; re-run after dev-mode-switcher removal)

verdict: green

**Date:** 2026-06-26 13:58:58
**Slug:** vehicle-picker
**Runner:** `fvm flutter test` (full suite)
**Why re-run:** the debug-only `dev-mode-switcher` was removed (Kevin's request, superseded by this production picker), editing `journey_screen.dart` + `main.dart` and deleting `dev_mode_switcher_test.dart`. This run re-verifies the ship gate reflects the current tree.

## Totals
- **Full package suite: 1161 passed / 0 failed / 0 flaky.** (`fvm flutter test`, EXIT 0 — "All tests passed!")
  - Count is 1 file fewer than the prior 1162-pass run because `dev_mode_switcher_test.dart` was deleted with the feature.
- `fvm flutter analyze lib` — **clean, no issues** (confirms the removed `kDebugMode`/`travel_mode` imports left nothing dangling).
- Integration `vehicle_picker_two_surface_test.dart` runs on `-d macos` (separate invocation per the macOS chaining-flake guidance); covered green in the prior in-scope run `20260626-132959`.

## Coverage (unchanged from the approved run)
AC-1..15 + NFR-1/NFR-3 each have ≥1 green automated case (TC-601..618 incl. twins TC-606p/TC-610b); NFR-2 via the `/privacy-audit` PASS. The B2 production shared-game-path tests (`app_shell_vehicle_precedence_test.dart`) are green — the picked vehicle renders on both surfaces.

## Command
```
fvm flutter analyze lib
fvm flutter test          # full package suite, from src/focus_journey
```

## Notes
- The OpenStreetMap line in the log is flutter_map's standard advisory, not a failure.
- Raw output: `full-suite.txt` in this folder.
- Gates: `/review-code` **approved** (after fixes), `/privacy-audit` **PASS**. Manual carries remain: TC-M-ART, TC-M-A11Y, TC-M-NF1.
