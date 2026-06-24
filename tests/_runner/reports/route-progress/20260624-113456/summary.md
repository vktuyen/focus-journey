---
verdict: green
total: 145
passed: 145
failed: 0
flaky: 0
skipped: 0
deferred_manual: 2
run_at: 2026-06-24T11:34:56Z
feature: route-progress
---

# Test Run Summary — route-progress

Vietnam Focus Journey (Flutter desktop). All in-scope route-progress automation passed,
and the full package regression suite is green. No mechanical flake patches were applied.

## Environment
- Flutter 3.38.10 • channel stable • revision c6f67dede3
- Dart 3.10.9 • DevTools 2.51.1
- Runner: `fvm flutter` (bare `flutter` not on PATH)
- E2E device: macOS (desktop) • darwin-arm64 • macOS 26.5.1
- Working dir for all runs: `src/focus_journey/`

## Runner commands
| Tier | Command | Result |
|------|---------|--------|
| Unit/widget (route only) | `fvm flutter test test/features/route` | 142 passed / 0 failed |
| Unit/widget (full regression + coverage) | `fvm flutter test --coverage` | 308 passed / 0 failed |
| E2E #1 (device) | `fvm flutter test integration_test/route_persistence_test.dart -d macos` | 2 passed / 0 failed |
| E2E #2 (device) | `fvm flutter test integration_test/route_wiring_smoke_test.dart -d macos` | 1 passed / 0 failed |

In-scope route-progress executed total = 142 (route unit/widget) + 3 (route integration) = **145 tests, all passed**.
(The full 308-test run is the regression-safety superset; it re-runs the same 142 route tests plus the
shipped journey/activity slices — all green, so route-progress did not break the shipped slices.)

Note: each integration file was invoked **individually** per the project's known per-file constraint
(two `integration_test` files in one invocation has produced a spurious failure here). The
`Failed to foreground app; open returned 1` line is a benign macOS windowing log from the headless
integration harness, not a test failure — both runs reported `All tests passed!`.

## Per-test → case mapping

### E2E / integration (device, macOS)
- `integration_test/route_persistence_test.dart::TC-009 start + direction persist across restart` → **TC-009** ✓
- `integration_test/route_persistence_test.dart::TC-010 completed route stays completed and does not auto-advance` → **TC-010** ✓ (also reinforces **TC-013** terminal-no-auto-advance)
  - B-1 fix verified: asserts honest full-chain completion `dest / chain.totalChainKm * 100` (≈95.83% for the mid-chain `can_tho→ha_giang` route), frozen across a +1000 km cumulative climb — NOT 100%. Passes on-device.
- `integration_test/route_wiring_smoke_test.dart::TC-wiring ticker.tickOnce flows distanceKm → route cubit → map readout` → **TC-NF3** ✓ (live wiring smoke: engine distance → cubit → map readout renders without tiles/network)

### Unit / widget (route slice)
- `domain/route_progress_resolver_test.dart` → **TC-001, TC-002, TC-003, TC-004, TC-005, TC-006, TC-007, TC-008, TC-011, TC-013, TC-014b, TC-NF1** ✓ (position math, boundary triplet, monotonicity, south-mirror, full-chain %, determinism)
- `domain/route_progress_resolver_sanity_test.dart` → **TC-001, TC-NF1, TC-NF4** ✓ (+ TC-018 reinforcement)
- `domain/route_selection_test.dart` → **TC-015** ✓ (valid-start / tip-off-direction guard)
- `domain/province_chain_test.dart` → **TC-NF4** ✓ (chain integrity / fixture distances)
- `data/shared_preferences_route_repository_test.dart` → **TC-009, TC-010** ✓ (unit-level persist/restore seam)
- `presentation/route_progress_cubit_test.dart` → **TC-001, TC-002, TC-003, TC-004, TC-005, TC-006, TC-007, TC-008, TC-011, TC-012, TC-013, TC-014, TC-014b** ✓ (cubit state mapping incl. explicit-new-start offset capture, clamp-to-destination, terminal completion)
- `presentation/route_progress_cubit_persistence_test.dart` → **TC-001, TC-014b** ✓ (offset subtraction across persistence)
- `presentation/route_map_screen_test.dart` → **TC-002, TC-011, TC-013** ✓ (marker-on-start-pin, celebration/summary surface, frozen terminal frame)
- `presentation/start_picker_test.dart` → **TC-015** ✓ (start picker / valid-start UI)
- `route_separation_static_test.dart` → **TC-016, TC-017, TC-NF3** ✓ (no OS/activity surface, no engine mutation, no tile/network import) — also documents TC-NF2 and TC-018 as out-of-band

## Deferred-to-manual (NOT counted as failures, by design)
- **TC-018** — manual `/privacy-audit`. Already PASSED in Phase 4. Re-run on any source/dependency change to the slice. Status: **PASS (manual)**.
- **TC-NF2** — on-device frame-timing / golden (smooth on-marker paint). Project golden infra is deferred (same posture as `journey-view`). Status: **DEFERRED**. Static-inspection portion is referenced by `route_separation_static_test.dart`; the runtime frame-timing assertion is not yet automatable here.

## Coverage
- `--coverage` generated `coverage/lcov.info`; copied to this report folder: `lcov.info` (11,464 bytes).

## Flake / mechanical patches
- **None.** No tests were quarantined, retried, or edited. Zero flakes observed across all four runner invocations.

## Verdict
**green** — all 145 in-scope tests passed (142 unit/widget + 3 integration on macOS), full regression suite (308) green, B-1 honest-completion fix verified on-device, TC-018 manual PASS, TC-NF2 deferred by design.
