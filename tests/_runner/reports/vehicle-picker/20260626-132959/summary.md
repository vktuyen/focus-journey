---
verdict: green
total: 1205
passed: 1205
failed: 0
flaky: 0
skipped: 0
in_scope_total: 84
in_scope_passed: 84
regression_total: 1121
regression_passed: 1121
run_at: 2026-06-26T13:29:59Z
feature: vehicle-picker
---

# Test Run Summary — vehicle-picker

Runner: `fvm flutter test` (Flutter 3.38.10 / Dart 3.10.9), per `docs/architecture/overview.md`.
Package root: `/Users/tuyenv/WorkingRepos/joblogic-agentic-practices/src/focus_journey`.
Raw output saved alongside this file: `unit.txt`, `integration.txt`, `regression.txt`.

## Commands run (exact)

1. Unit/widget/static (11 files, one invocation):
   ```
   fvm flutter test \
     test/features/stats/domain/app_settings_vehicle_preference_test.dart \
     test/features/stats/presentation/settings_cubit_vehicle_test.dart \
     test/features/stats/presentation/vehicle_picker_test.dart \
     test/features/stats/presentation/vehicle_picker_widget_test.dart \
     test/features/stats/presentation/vehicle_picker_credits_test.dart \
     test/features/journey/presentation/journey_screen_vehicle_precedence_test.dart \
     test/features/journey/presentation/vehicle_picker_display_test.dart \
     test/features/journey/domain/vehicle_picker_cosmetic_engine_test.dart \
     test/features/journey/domain/vehicle_picker_firewall_static_test.dart \
     test/features/mini_window/presentation/app_shell_vehicle_precedence_test.dart \
     test/features/route/presentation/vehicle_picker_route_start_test.dart
   ```
   Result: `+83: All tests passed!` (83 passed, 0 failed).

2. Integration (own invocation, on macOS device):
   ```
   fvm flutter test integration_test/vehicle_picker_two_surface_test.dart -d macos
   ```
   Result: `+1: All tests passed!` — EXIT_CODE=0.

3. Regression sweep (one invocation, sibling suites the change touched):
   ```
   fvm flutter test test/features/stats/ test/features/journey/ test/features/route/ test/features/mini_window/
   ```
   Result: `+1121: All tests passed!` — EXIT_CODE=0. Includes the touched scene-manifest guard
   `journey_scene_art_v3_credits_test.dart` and `map_surface_test.dart` — both green.

## Totals

| Scope | Passed | Failed | Flaky | Skipped |
|---|---|---|---|---|
| In-scope unit/widget/static (11 files) | 83 | 0 | 0 | 0 |
| In-scope integration (1 file) | 1 | 0 | 0 | 0 |
| In-scope subtotal | 84 | 0 | 0 | 0 |
| Regression sweep | 1121 | 0 | 0 | 0 |
| Grand total | 1205 | 0 | 0 | 0 |

## Per-test (file) → case / AC mapping

- `test/features/stats/domain/app_settings_vehicle_preference_test.dart` → TC-607 (AC-7 absent/corrupt → null, no crash) + AppSettings vehiclePreference JSON round-trip (AC-5) PASS
- `test/features/stats/presentation/settings_cubit_vehicle_test.dart` → TC-605 (AC-5 setVehicle emit + repository save), TC-606p (AC-6 restore-before-first-apply) PASS
- `test/features/stats/presentation/vehicle_picker_test.dart` → TC-614 (AC-14 icon-based, not a text dropdown), VehiclePicker selection + tap callback (AC-14) PASS
- `test/features/stats/presentation/vehicle_picker_widget_test.dart` → TC-614 (AC-14 distinct icon per all six modes), TC-617 (NFR-3 per-mode semantics label + focus reach + no focus trap) PASS
- `test/features/stats/presentation/vehicle_picker_credits_test.dart` → TC-615 (AC-15 every icon CREDITS-attributed; no uncredited icon loaded) PASS
- `test/features/journey/presentation/journey_screen_vehicle_precedence_test.dart` → TC-601 (AC-1), TC-602 (AC-2), TC-603 (AC-3), TC-604 (AC-4) PASS
- `test/features/journey/presentation/vehicle_picker_display_test.dart` → TC-601 (AC-1 sprite + branch swap), TC-603 (AC-3), TC-604 (AC-4) PASS
- `test/features/journey/domain/vehicle_picker_cosmetic_engine_test.dart` → TC-608 (AC-8 engine truth byte-for-byte across all six picks), TC-609 (AC-9 JourneyCubit pure reader, engine unchanged) PASS
- `test/features/journey/domain/vehicle_picker_firewall_static_test.dart` → TC-610 (AC-10 FIREWALL), TC-610b (AC-10 negative twin), TC-616 (NFR-1 O(1) composition / no new per-frame cost) PASS
- `test/features/mini_window/presentation/app_shell_vehicle_precedence_test.dart` → TC-618 / B2 production shared-game path: AC-2/AC-3 (override on full window + PiP), AC-4, AC-1 (live pick ≤1 frame), AC-6 (restore seeds before first apply) PASS
- `test/features/route/presentation/vehicle_picker_route_start_test.dart` → TC-611 (AC-11), TC-612 (AC-12), TC-613 (AC-13 skippable picker write-back + skip leg) PASS
- `integration_test/vehicle_picker_two_surface_test.dart::TC-618 ...` → TC-618 (AC-1, AC-6, AC-11, AC-13) PASS

AC-1..AC-15 and NFR-1, NFR-3 each have at least one green automated case this run. NFR-2 (privacy) has no
automated assert — it is the `/privacy-audit` ship gate (TC-M-PRIV), reinforced by the green AC-10 firewall
(TC-610/TC-610b) and AC-9 separation (TC-609).

## Manual carries — DEFERRED (not automated; out of scope)

- TC-M-ART [VISUAL][REVIEW] — icon cohesion + not-colour-alone read (AC-14 gate + NFR-3 visual leg).
- TC-M-A11Y [REAL-OS] — real keyboard-only + VoiceOver/Narrator per-mode announcement (NFR-3 real leg).
- TC-M-NF1 [DEVICE] — sustained >=30fps on both surfaces with override resolved (NFR-1 device leg).
- TC-M-PRIV [AUDIT] — `/privacy-audit` PASS, ship-blocker (NFR-2).
Their automated proxies (TC-614/TC-615/TC-617, TC-616, TC-610/TC-609) all passed.

## Notes

- No flakes encountered; no scripts edited; no retries. Single clean pass per layer.
- Integration ran in its own invocation with `-d macos` per the architecture doc — avoided the iOS-routing build
  failure and the multi-file debug-connection flake by construction.
- One grep false positive while scanning regression.txt: the substring "fail" inside the test name
  `JourneyGame.failedCockpitAssetPaths` — not an actual failure. Zero `-N:` failing markers; every layer ended
  with `All tests passed!` and EXIT_CODE=0.
- Regression sweep confirms vehicle-picker changes did not break siblings, including the touched
  `journey_scene_art_v3_credits_test.dart` and `map_surface_test.dart`.

## Verdict

green
