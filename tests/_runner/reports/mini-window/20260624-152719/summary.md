---
verdict: green
total: 92
passed: 92
failed: 0
flaky: 0
skipped: 0
run_at: 2026-06-24T15:27:19Z
feature: mini-window
---

# Test Run Summary — mini-window (Wave 2 / v2)

All in-scope automated tests passed across four invocations: the mini-window
unit/widget subset, the two macOS integration files (run one-at-a-time per the
local-stats batch-relaunch limitation), and the whole-package regression run.
No flakes, no functional regressions, no weakened assertions. The deferred
real-OS / on-device / privacy-audit legs are carried as ship-gate manual work
(see "Carried manual ship-gate legs"), so coverage is honest — not silently green.

## Commands run (exact)

All from `src/focus_journey/` (fvm-pinned Flutter 3.38.10 -> always `fvm flutter`).

1. Mini-window unit/widget subset:
   `fvm flutter test test/features/mini_window/`
2. Whole-package regression + coverage:
   `fvm flutter test --coverage`  (coverage/lcov.info moved into this report folder)
3. Integration — wiring (mock seams, macOS):
   `fvm flutter test integration_test/mini_window_wiring_test.dart -d macos --dart-define=mock-window=true --dart-define=mock-activity=true`
4. Integration — smoke (mock seams, macOS):
   `fvm flutter test integration_test/mini_window_smoke_test.dart -d macos --dart-define=mock-window=true --dart-define=mock-activity=true`

## Pass/fail counts per invocation

| Invocation | Passed | Failed | Flaky | Skipped |
|---|---|---|---|---|
| Unit/widget — `test/features/mini_window/` | 75 | 0 | 0 | 0 |
| Integration — `mini_window_wiring_test.dart` (macos, mock) | 14 | 0 | 0 | 0 |
| Integration — `mini_window_smoke_test.dart` (macos, mock) | 3 | 0 | 0 | 0 |
| **Mini-window in-scope total** | **92** | **0** | **0** | **0** |
| Whole-package regression — `fvm flutter test` (all v1 + v2) | 559 | 0 | 0 | 0 |

The whole-package run (559 pass, matching the expected ~559) confirms **no regression**
in the shipped v1 slices (journey-engine, journey-view, route-progress, local-stats,
activity-detection); the mini-window subset (75) is a member of that 559.

> Note: both integration runs emitted a cosmetic harness line `Failed to foreground
> app; open returned 1` while building the macOS app. This is the headless
> integration_test harness not bringing the window to the foreground; the tests still
> loaded and all assertions passed. Not a failure, not a flake — no re-run needed.

## Per-test -> case mapping (PASS)

### Unit/widget (`test/features/mini_window/`)
- `mini_window_separation_test.dart::noOsUserSignalApiAnywhereInTheSlice` -> TC-010 / TC-019-PRIV (static) PASS
- `mini_window_separation_test.dart::mutatesNoJourneyStateFields` -> TC-010 PASS
- `mini_window_separation_test.dart::presentationLayerDoesNotImportWindowOrTrayManager` -> TC-010 / NFR-7 (one-interface structural part, also reinforces TC-023) PASS
- `mini_window_separation_test.dart::modeCubitAndShellConstructNoSecondEngineOrGame` -> TC-009 (static) PASS
- `mini_window_separation_test.dart::compactViewReadsOnlyViewStateForRendering` -> TC-010 PASS
- `data/mock_window_mode_controller_test.dart::*` -> TC-024 / NFR-8 (mock window model: start full, enterCompact sets compact+AOT+emits) PASS
- `data/mock_tray_controller_test.dart::*` -> TC-024 / NFR-8 + TC-011/TC-013-STATUS (tray model: init, setState, actions, setMode, setStatusLine) PASS
- `data/shared_preferences_compact_window_position_repository_test.dart::*` -> TC-019-POS (position-only persistence round-trip) PASS
- `data/shared_preferences_hide_to_tray_hint_repository_test.dart::*` -> TC-015 / AC-17 (one-time hint flag round-trip) PASS
- `domain/compact_geometry_test.dart::clampOntoVisible *` (15 cases) -> TC-019-CLAMP / AC-8 (off-screen clamp, in-bounds unchanged, multi-display, fixed-size invariant) PASS
- `presentation/app_shell_cubit_test.dart::enterCompact_drivesControllerAndMirrorsMode` -> TC-006 PASS
- `presentation/app_shell_cubit_test.dart::showApp_fromCompact_returnsToFull` -> TC-007 PASS
- `presentation/app_shell_cubit_test.dart::onHiddenToTray_firstTime/whenAlreadyShown/isOneTimeWithinSession` -> TC-015 / AC-17 PASS
- `presentation/app_shell_cubit_test.dart::fullToCompactToFull_mirrorsControllerModeChangesInOrder / showApp_whileAlreadyFull_doesNotEmitARedundantModeChange / hint_isOrthogonalToMode_modeMirrorPreservesHintFlag` -> TC-006/TC-007 + TC-022 (mode mirroring) PASS
- `presentation/app_shell_test.dart::sharesOneGameAcrossModesAndDrivesIt` -> TC-009 (runtime identity) PASS
- `presentation/app_shell_shared_game_test.dart::TC-013 fullToCompactToFull_reusesSameGame_withoutReInit` -> TC-013 PASS
- `presentation/app_shell_shared_game_test.dart::TC-009 bothModes_consumeSameCubit_andSameGame_noSecondInstance` -> TC-009 PASS
- `presentation/app_shell_shared_game_test.dart::TC-020 NFR-1: idle_pausesUpdateLoop_resumesOnActive` -> TC-020 / NFR-1 PASS
- `presentation/compact_view_test.dart::rendersBlocDistanceReadout` -> TC-004 PASS
- `presentation/compact_view_scene_test.dart::TC-001 active_compactSceneScrolls_andReadoutShowsDistance` -> TC-001 PASS
- `presentation/compact_view_scene_test.dart::TC-002 *` -> TC-002 (parks on idle/paused) PASS
- `presentation/compact_view_scene_test.dart::TC-003 *` -> TC-003 (start/stop within one pump, no jump) PASS
- `presentation/compact_view_scene_test.dart::TC-005 *` -> TC-005 (pre-state / unknown -> parked) PASS
- `presentation/compact_view_scene_test.dart::TC-021-RM *` -> TC-021-RM / NFR-3 (reduce-motion) PASS
- `presentation/(compact_view / compact_view_scene)::TC-021 *` -> TC-021 / NFR-6 leg (a) (readout text in semantics tree) PASS
- `presentation/journey_tray_mapper_test.dart::TC-011 *` -> TC-011 (tray icon variant/tooltip reflects state) PASS
- `presentation/journey_tray_mapper_test.dart::TC-013-STATUS *` -> TC-013-STATUS / AC-13 (tray status line) PASS

### Integration — wiring (`mini_window_wiring_test.dart`, macos, mock)
- `TC-024 / NFR-8 mock backends ... drives the whole flow against the mock model` -> TC-024 PASS
- `TC-006 enterCompact() -> compact, pip visible, main hidden` -> TC-006 PASS
- `TC-007 showApp() from compact -> full, main visible, pip dismissed` -> TC-007 PASS
- `TC-008 never (mainVisible && pipVisible) at any observed step` -> TC-008 PASS
- `TC-011 active vs idle/paused distinguishable + update on emit` -> TC-011 PASS
- `TC-013-STATUS status line equals the projected Bloc state/distance` -> TC-013-STATUS PASS
- `TC-012 Show app / Enter compact / Quit each produce their effect` -> TC-012 / AC-12, AC-16 PASS
- `TC-014 hideToTray() -> hidden/alive/closed-to-tray; distance accrues` -> TC-014 PASS
- `TC-018 pipVisible stays false after a close-to-tray` -> TC-018 PASS
- `TC-016 post-restore distance continuous + same engine; Quit-only exit` -> TC-016 PASS
- `TC-017 first close fires + persists the hint; a second close does not` -> TC-015 + TC-017 PASS
- `TC-017 the persisted-flag path suppresses the hint on first close` -> TC-015 PASS
- `TC-017 Quit flushes the latest journey state BEFORE the process exits` -> TC-017 PASS
- `TC-019-POS drag -> persist -> relaunch restores position (size never)` -> TC-019-POS PASS

### Integration — smoke (`mini_window_smoke_test.dart`, macos, mock)
- `TC-009 the same game instance is passed to full AND compact subtrees` -> TC-009 PASS
- `TC-013 identity preserved + onLoad not re-run across re-parenting` -> TC-013 PASS
- `TC-026 active->compact->idle->active->show app->close holds end to end` -> TC-026 PASS

## In-scope AC / NFR coverage (covered-by-automation vs deferred-manual)

Covered by automation (mock window/tray + scriptable Bloc, headless):
- AC-1..AC-5 (compact scene mirror) -> TC-001..TC-005, TC-026
- AC-6 (PiP collapse + mutual exclusion, mock leg) -> TC-006/007/008, TC-026
- AC-8 (position persist + clamp) -> TC-019-POS, TC-019-CLAMP
- AC-9 (single shared engine/game) -> TC-009, TC-013 (static + runtime identity)
- AC-10 (PiP reads only state/mode/distanceKm, mutates nothing) -> TC-010
- AC-11/AC-12/AC-13 (tray icon/menu/status, mock leg) -> TC-011, TC-012, TC-013-STATUS
- AC-15/AC-16/AC-17/AC-18 (close-to-tray, restore, hint, no auto-PiP) -> TC-014, TC-015, TC-016, TC-017, TC-018
- AC-14 mode-aware mirroring (P2) -> reinforced by app_shell_cubit mode-mirror tests (TC-022)
- NFR-1 (loop paused when idle/not-visible) -> TC-020
- NFR-3 (reduce-motion) -> TC-021-RM
- NFR-6 leg (a) (readout text in semantics) -> TC-021 (a)
- NFR-7 structural one-interface / no-leak -> separation static test (reinforces TC-023)
- NFR-8 (mock path -> deterministic headless) -> TC-024

Deferred-manual (NOT failures — carried to the ship gate; see below):
- AC-6/AC-7/AC-8(drag): real OS always-on-top stacking, frameless drag, dock hide -> TC-M1, TC-M2, TC-M2-AOT [REAL-OS, macOS]
- AC-11/AC-12/AC-15/AC-16/AC-18 real legs: real close-intercept + real tray icon/menu rendering & clicking -> TC-M3 [REAL-OS, macOS]
- NFR-6 leg (b): real tray-menu keyboard / screen-reader reachability -> TC-M4 [REAL-OS, macOS]
- NFR-2: sustained ~60 fps / no added jank on device -> TC-M-NF2 [DEFERRED, device] (unit-level no-jank-on-toggle is within TC-003)
- NFR-4 (headline) + NFR-5: zero-new-user-data-surface privacy audit -> TC-019-PRIV / TC-M-PRIV [MANUAL AUDIT, ship-blocker] (statically reinforced by TC-010 + separation test; TC-023 / TC-025 fold into this audit — they do NOT replace it)
- NFR-9: Windows on-device runtime legs (always-on-top, drag, tray, hide-to-tray, geometry restore) -> DEFERRED — required before any Windows release (Windows rows of TC-M1/M2/M2-AOT/M3/M4/M-NF2)

## Flakes
None. No test was re-run; no mechanical patch (selector/timing/wait/ordering) was
applied. The integration files were each run exactly once and passed. No production
logic or assertions were touched.

## Carried manual ship-gate legs (must be performed/recorded before /ship completes)
From `tests/cases/mini-window-manual-checklist.md`:
- TC-M1 (macOS) — frameless body drag + position restore [REAL-OS]
- TC-M2 (macOS) — PiP stays above a different focused app [REAL-OS]
- TC-M2-AOT (macOS, P2) — always-on-top toggle real stacking [REAL-OS]
- TC-M3 (macOS) — real close-intercept hides to tray, tray icon updates, menu actions work [REAL-OS]
- TC-M4 (macOS, P1) — tray menu keyboard/screen-reader reachable [REAL-OS]
- TC-M-NF2 (device, P1) — sustained fps / no jank [DEFERRED]
- TC-M-PRIV — /privacy-audit zero-new-surface (NFR-4/NFR-5) [MANUAL AUDIT, ship-blocker]
- Windows runtime legs (NFR-9) — all of the above on Windows [DEFERRED — required before any Windows release]

## Notes for the reviewer
- Coverage data captured: `tests/_runner/reports/mini-window/20260624-152719/lcov.info` (whole-package lcov from invocation 2).
- TC-022 (P2, mode-aware menu) and TC-023 / TC-025 (P0 static parity & dependency-capability) are not encoded as standalone named automated tests; TC-022 mode mirroring is exercised by the app_shell_cubit mode tests, and TC-023/TC-025 are static-inspection cases that land in the /privacy-audit (TC-M-PRIV) — the separation static test reinforces the no-leak / one-interface structural part. The full TC-023/TC-025/TC-M-PRIV verdict is a manual ship-gate, recorded above as deferred-manual, not as automation failures.

## Verdict
green
