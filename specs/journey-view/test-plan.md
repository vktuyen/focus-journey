# Test plan

## Coverage strategy

Executable tests live INSIDE the Flutter package (per `docs/architecture/overview.md`):
unit/widget under `src/focus_journey/test/`, e2e under `src/focus_journey/integration_test/`.
The human-readable cases are in [tests/cases/journey-view.md](../../tests/cases/journey-view.md)
(TC-001..TC-027). Determinism: the scene is driven via `JourneyGame.applyState(...)` +
`game.update(dt)`; the screen via a scriptable `JourneyCubit` and `pumpWidget` — no real OS, no
real timers, no wall-clock waits.

| AC / NF | Unit (test/) | Integration / E2E (integration_test/) | Static (test/) | Manual |
|---|---|---|---|---|
| AC-1 (active → motion) | TC-001 | TC-021 | | |
| AC-2 (idle → stop+park+overlay) | TC-002 (screen) | TC-021 | | |
| AC-3 (paused ≡ idle) | TC-003 (screen) | | | |
| AC-4 (never moves when stopped) | TC-004 | | | |
| AC-5 (resume within one tick) | TC-005 (cubit/view-state — pre-existing) | TC-021 | | |
| AC-6 / no-jank ease | TC-006, TC-024 | | | TC-016 (device, opt-in) |
| AC-7 (binary speed) | TC-007 | | | |
| AC-8 (mode skin / same speed) | TC-008 | | | |
| AC-9 (no OS/activity surface) | | | TC-009 | TC-026 (privacy-audit) |
| AC-10 (no state mutation) | TC-010 (runtime, screen) | | TC-010 (static) | TC-026 |
| AC-11 (assets CREDITS-recorded) | | | TC-011 | |
| AC-12 (day/night cosmetic tint) | TC-012 | | | |
| AC-13 (first-frame/unknown → parked) | TC-013 (scene + screen) | | | |
| AC-14 (missing asset graceful) | TC-014 | | | |
| NF perf: frame rate | | TC-015 (device, opt-in) | | spot-check |
| NF perf: no jank on toggle | TC-024 (deterministic) | TC-016 (device, opt-in) | | |
| NF perf: bounded pool | TC-017 | | | |
| NF perf: suspended off-screen | TC-018 | | | |
| NF a11y: reduce motion | TC-019 (scene + screen) | | | |
| NF a11y: overlay readability/semantics | TC-020, TC-027 (screen) | | | spot-check (contrast) |

### Executable test files added

- `test/features/journey/presentation/game/journey_game_motion_test.dart` (17 tests) —
  TC-001, TC-004, TC-006/TC-024, TC-007, TC-008, TC-012, TC-013, TC-017, TC-018, TC-019 (motion).
- `test/features/journey/presentation/game/journey_assets_test.dart` (5 tests) —
  TC-011 (CREDITS cross-check), TC-014 (graceful degradation).
- `test/features/journey/presentation/journey_separation_static_test.dart` (4 tests) —
  TC-009, TC-010 (static separation invariant).
- `test/features/journey/presentation/journey_screen_test.dart` (10 tests) —
  TC-002/TC-003, TC-013 (overlay), TC-019 (indicator), TC-020/TC-027 (semantics), TC-010 (runtime).
- `integration_test/journey_scene_smoke_test.dart` (1 test) — TC-021 e2e (green headless + device).
- `integration_test/journey_scene_perf_test.dart` (2 tests) — TC-015/TC-016 skeletons (opt-in).
- Shared harness: `test/features/journey/presentation/game/journey_game_test_harness.dart`.

## Scenarios

- Happy path: TC-001, TC-002, TC-003, TC-005, TC-008 (5)
- Edge / boundary: TC-004, TC-006, TC-007, TC-012, TC-013, TC-015, TC-016, TC-017, TC-018,
  TC-019, TC-020, TC-024, TC-027 (13)
- Negative: TC-014 (1)
- Regression: TC-009, TC-010, TC-011, TC-021, TC-022, TC-023, TC-025, TC-026 (8)

## Deferred / not automated as deterministic assertions

- **TC-022 / TC-023 / TC-025 (goldens) — DEFERRED.** Golden baselines were NOT committed. Rationale:
  the scene composes the Flutter `GameWidget` (Flame) whose frame is produced by a real-time game
  loop; pinning a byte-stable golden in this environment is non-deterministic without an on-device,
  fixed-phase capture, and the intentionally-absent `vehicles/ship.png` makes a clean headless render
  fragile (Flame image-cache quirk, see below). Per the task's golden guidance, the same INTENT is
  covered behaviourally instead:
  - active-frame structure → TC-001 (motion/seam assertions);
  - stopped+overlay frame → TC-002/TC-003 + TC-020/TC-027 (overlay text + semantics);
  - day vs night differ only in tint, geometry/motion identical → TC-012 (behavioural: `currentTint`
    differs by injected hour while per-frame scroll advance is identical ±1e-6).
  No broken/empty golden references were committed. Re-introduce goldens via
  `fvm flutter test --update-goldens` on a device once a fixed-phase render hook is available.
- **TC-015 / TC-016 (performance) — ON-DEVICE, OPT-IN.** Authored as `integration_test` skeletons in
  `journey_scene_perf_test.dart` that SKIP by default and run only with
  `--dart-define=run-perf=true` on a real desktop (`-d macos|windows`), capturing the frame timeline
  via `binding.traceAction`. A strict fps assertion is intentionally NOT forced into the default
  suite (would be flaky in a debug build). The unit-level no-jank property is proven deterministically
  by TC-006/TC-024. Record device + OS + measured fps in `tests/_runner/reports/`.
- **TC-026 (privacy audit) — MANUAL.** Not an automated assertion (mirrors activity-detection
  TC-018/TC-019). Run `/privacy-audit` (`privacy-guardian`). Reinforced by the automated
  static-inspection TC-009/TC-010.

## Risks / notes

- **Flame 1.35.1 missing-asset quirk.** `vehicles/ship.png` is an intentional CREDITS gap (graceful
  placeholder — AC-14). Flame's image cache chains an internal `.then` with no `onError`, so a
  genuinely-missing asset leaks an orphan "Unable to load asset" rejection to the test zone even
  though `JourneySprites._tryLoad` catches it for control flow. Handled in tests WITHOUT touching
  production code: asset/screen tests run the load inside a guarded zone / drain the expected error;
  the e2e + perf tests pre-seed the game's image cache with a 1×1 stub for every manifest path so the
  bundle is never hit. AC-14 itself is asserted UNSTUBBED in `journey_assets_test.dart`.
- **integration_test run convention.** As with the pre-existing activity integration tests, the
  `integration_test/` files must be run ONE FILE PER `flutter test` INVOCATION (batching multiple in
  one run fails with "Unable to start the app"). `/execute-tests` runs them per-file.
- `flutter test` (no path) discovers `test/` only; `integration_test/` is run explicitly.
