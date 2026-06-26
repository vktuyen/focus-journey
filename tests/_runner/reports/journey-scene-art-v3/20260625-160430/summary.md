---
verdict: green
total: 465
passed: 465
failed: 0
flaky: 0
skipped: 0
manual_carried: 4
run_at: 2026-06-25T16:04:30Z
feature: journey-scene-art-v3
---

# Test Run Summary — journey-scene-art-v3

Execution + mechanical flake-patching only. No functional fixes applied. All in-scope automated
tests passed across three invocations. One mechanical infra flake was hit on the integration smoke
(default device = unsigned iOS) and corrected by targeting the macOS desktop device (see Notes).

## Environment
- Runner: `fvm flutter test` — Flutter 3.38.10 (stable, Dart 3.10.9), revision c6f67dede3.
- Host: macOS 26.5.1 (darwin-arm64), headless (no on-device run).
- Package dir: `src/focus_journey/`.
- Unit/widget invocations ran on the default Dart VM; the `integration_test` smoke ran on the
  `macOS (desktop)` device (`-d macos`) per `docs/architecture/overview.md` (desktop project).

## Invocation results

| # | Command | Total | Passed | Failed | Skipped | Log |
|---|---------|------:|-------:|-------:|--------:|-----|
| 1 | `fvm flutter test test/features/journey/presentation/game/` | 154 | 154 | 0 | 0 | `unit.log` |
| 2 | `fvm flutter test test/features/journey/` | 309 | 309 | 0 | 0 | `journey-feature.log` |
| 3 | `fvm flutter test -d macos integration_test/journey_scene_art_v3_smoke_test.dart` | 2 | 2 | 0 | 0 | `smoke.log` |
| | **Overall** | **465** | **465** | **0** | **0** | |

Invocations 1 and 2 overlap (the game dir is a subset of the journey feature dir); the overall
total is the sum of distinct invocation runs as executed, all green. The 6 in-scope unit/widget
files individually report: art_v3 `+20`, credits `+7`, separation `+6`, spike `+5`,
journey_assets `+11`, no_orphan `+1`.

## Per-test (file) -> case-ID / AC-ID mapping (in-scope slice)

Per the cases-file Automation coverage table. Each file's TC tags were verified present in source and
the suite passed.

- `test/.../game/journey_scene_art_v3_spike_artifact_test.dart` (5 tests) -> TC-301 (AC-1 artifact gate), TC-302 (AC-2 fallback ladder) PASS
- `test/.../game/journey_scene_art_v3_test.dart` (20 tests) -> TC-303 (AC-3), TC-305 (AC-5), TC-306 (AC-6), TC-307 (AC-7), TC-308 (AC-8/NFR-1), TC-310 (AC-10), TC-313 (AC-17/3/5/7), TC-314 (AC-17/6), TC-316 (AC-14), TC-317 (AC-15/NFR-3), TC-318 (AC-16/NFR-3) PASS
- `test/.../game/journey_scene_art_v3_credits_test.dart` (7 tests) -> TC-309 (AC-9 dims), TC-311 (AC-11 CREDITS) + new `bundledJourneyPng_isSubsetOf_manifest` guard PASS
- `test/.../game/journey_scene_art_v3_separation_test.dart` (6 tests) -> TC-312 (AC-12 engine byte-for-byte), TC-315 (AC-13 separation) PASS
- `test/.../game/journey_assets_test.dart` (11 tests) -> repaired membership, TC-303 / AC-10 / AC-11 family PASS
- `test/.../game/journey_sprites_no_orphan_test.dart` (1 test) -> repaired AC-14 never-throws PASS
- `integration_test/journey_scene_art_v3_smoke_test.dart` (2 tests, standalone, -d macos) -> TC-304 (AC-4 both surfaces), TC-319 (e2e long-journey smoke; AC-3/4/5/6/7) PASS

Regression context (invocation 2 superset): the full `test/features/journey/` suite (309 tests,
including journey-scene-v2, journey-pov, cockpit, road-geometry, motion siblings) is green — the art
re-source did not regress sibling journey tests.

## Manual / carried legs (NOT automatable — not run)

From the cases file + manual checklist; listed for traceability, not executed:
- TC-M-SPIKE [REVIEW] — stylized-flat cohesion + craft sign-off (AC-1 hard gate; look legs of AC-3/4/5/6). Recorded done.
- TC-M-FALLBACK [REVIEW] — fallback-ladder rightness sign-off (AC-2). Recorded done.
- TC-M-NF1 [DEVICE] — sustained >=30fps on both surfaces under the higher-res set (NFR-1). Carried (on-device only; automated proxy TC-308 passed).
- TC-M-PRIV [AUDIT] — `/privacy-audit` PASS, runtime egress gate (NFR-2). Carried (gating ship-blocker; reinforced by TC-315 separation + TC-312 cosmetic-only counters, both green).

## Notes
- Mechanical flake patched (no script edit): invocation 3 first failed with EXIT=1 because
  `flutter test` on the `integration_test` file defaulted to the connected iOS device, which the
  build environment cannot code-sign (`Error (Xcode): No Accounts ... No profiles for
  'com.example.focusJourney'`). This is an infra/device-target issue, NOT a test or functional
  failure — the Dart test body never loaded. Per `docs/architecture/overview.md` (Flutter desktop
  project; dev runs `-d macos|windows`), the same file was re-run standalone with `-d macos`; it
  passed 2/2. No test source was modified. The known multi-`main` "loading [E]" integration conflict
  was avoided by running the art-v3 smoke file in isolation as instructed.
- Raw stdout/stderr saved alongside this file: `unit.log`, `journey-feature.log`, `smoke.log`
  (`smoke.log` reflects the successful `-d macos` re-run).
- No goldens are committed PNG baselines on this project; TC-313/TC-314 are deterministic
  frame-structure assertions (per the cases-file automation note) — no golden churn to review.

## Verdict
green
