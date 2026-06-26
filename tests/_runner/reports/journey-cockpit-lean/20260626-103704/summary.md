# Test run — journey-cockpit-lean (re-run after wheel/minimap tweaks, ship gate)

verdict: green

**Date:** 2026-06-26 10:37:04
**Slug:** journey-cockpit-lean
**Runner:** `fvm flutter test` (unit on host; integration `-d macos`)
**Why re-run:** `cockpit_painter.dart` was tweaked after the prior green run (car steering wheel now sized to the dash band so the whole wheel is visible; `map_surface.dart` minimap moved bottom-right → centre-right). This run re-verifies the gate reflects the current code.

## Totals
- **In-scope: 69 / 69 passed, 0 failed, 0 flaky**
  - unit/widget/golden/static/perf (5 files): **66 passed** — incl. TC-516 leaning-car-cockpit golden + TC-517 draw-count goldens (wheel resize did NOT change draw structure), TC-509/TC-510 AC-9 scene-byte-identical.
  - integration two-surface (`-d macos`, own invocation): **2 passed** (TC-514 + the non-vacuity guard).
  - integration smoke (`-d macos`, own invocation): **1 passed** (TC-518).
- **Regression — full journey-game suite (`test/features/journey/presentation/game/`): 247 passed, 0 failed.** Confirms the wheel change did not regress the journey-pov cockpit or sibling scene tests.

## Commands
```
fvm flutter test test/features/journey/presentation/game/journey_cockpit_lean_{test,behaviour,golden,separation_static,perf}_test.dart
fvm flutter test integration_test/journey_cockpit_lean_two_surface_test.dart -d macos
fvm flutter test integration_test/journey_cockpit_lean_smoke_test.dart -d macos
fvm flutter test test/features/journey/presentation/game/    # regression
```

## AC coverage (all green)
AC-1..AC-14 + NFR-1/NFR-3 via TC-501..518; NFR-2 via the `/privacy-audit` PASS (2026-06-26).

## Notes
- Raw output: `unit.txt`, `integration-two-surface.txt`, `integration-smoke.txt`, `regression.txt` in this folder.
- Live-tuning tweaks folded in at ship (car wheel fully visible; minimap centre-right). These are cosmetic and covered by the existing draw-structure goldens + the green regression.
