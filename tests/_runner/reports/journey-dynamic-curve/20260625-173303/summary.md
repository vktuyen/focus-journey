---
verdict: green
total: 182
passed: 182
failed: 0
flaky: 0
skipped: 0
manual_carried: 4
run_at: 2026-06-25T17:33:03Z
feature: journey-dynamic-curve
---

# Test Run Summary — journey-dynamic-curve

Execution + mechanical flake-patching only. No functional fixes applied. All in-scope automated
tests passed: the unit/widget game-dir suite (181 tests, covering the 4 dynamic-curve files plus the
slice's `road_geometry_test` / `journey_scene_v2_test` regressions) and the desktop integration smoke
(1 test). No mechanical flake was hit this run — the integration smoke was targeted at `-d macos` from
the outset, sidestepping the known unsigned-iOS device flake that prior slices corrected reactively.

## Environment
- Runner: `fvm flutter test` — Flutter 3.38.10 (stable, Dart 3.x), revision c6f67dede3.
- Host: macOS 26.5.1 (darwin-arm64), headless (no on-device performance run).
- Package dir: `src/focus_journey/`.
- Unit/widget invocation ran on the default Dart VM; the `integration_test` smoke ran on the
  `macOS (desktop)` device (`-d macos`) per `docs/architecture/overview.md` (Flutter desktop project;
  the default unsigned-iOS device is a known INFRA flake for `integration_test`, not a test failure).

## Invocation results

| # | Command | Total | Passed | Failed | Skipped | Log |
|---|---------|------:|-------:|-------:|--------:|-----|
| 1 | `fvm flutter test test/features/journey/presentation/game/` | 181 | 181 | 0 | 0 | `unit.log` |
| 2 | `fvm flutter test -d macos integration_test/journey_dynamic_curve_smoke_test.dart` | 1 | 1 | 0 | 0 | `smoke.log` |
| | **Overall** | **182** | **182** | **0** | **0** | |

Invocation 1 runs the whole `test/features/journey/presentation/game/` directory (181 tests) — this
contains the 4 in-scope dynamic-curve files AND the slice's edited regression files (`road_geometry_test`,
`journey_scene_v2_test`) plus the sibling cockpit / scene-art / assets game tests, so the regressions are
covered in the same green run. Per-file counts for the in-scope slice (run individually for the mapping):
dynamic_curve `+10`, dynamic_curve_behaviour `+10`, dynamic_curve_separation_static `+5`,
dynamic_curve_cosmetic_engine `+2`; edited regressions: road_geometry `+4`, journey_scene_v2 `+13`.

## Per-test (file) -> case-ID / AC-ID mapping (in-scope slice)

TC tags verified present in source and the suite passed. Mapping per the cases-file Coverage table
(`tests/cases/journey-dynamic-curve.md` TC-401..415).

- `test/.../game/journey_dynamic_curve_test.dart` (10 tests) -> TC-401 (AC-1 model curvature >=~2x baseline), TC-405 (AC-5/AC-6 arc-length spacing +/-20% over `liveCentreLinePoints`), and an in-file TC-415 model leg PASS
- `test/.../game/journey_dynamic_curve_behaviour_test.dart` (10 tests) -> TC-401 (AC-1), TC-403 (AC-3/AC-4 sweep+determinism), TC-404 (AC-4 single phase / frozen), TC-406 (AC-6/NFR-1 cadence cost), TC-411 (AC-10/NFR-3 reduce-motion freeze), TC-412 (AC-11/NFR-3 on-screen bound), TC-413 (AC-1/2/3/7 swept frame), TC-414 (AC-10 held frame) PASS
- `test/.../game/journey_dynamic_curve_separation_static_test.dart` (5 tests) -> TC-403 (AC-4 static leg), TC-404 (AC-4 static), TC-410 (AC-8 pure-view imports) PASS
- `test/.../game/journey_dynamic_curve_cosmetic_engine_test.dart` (2 tests) -> TC-409 (AC-9 engine byte-for-byte unchanged vs baseline) PASS
- `integration_test/journey_dynamic_curve_smoke_test.dart` (1 test, standalone, -d macos) -> TC-415 (AC-3/AC-10/AC-11 e2e: sharper curve on both surfaces, sweep -> freeze -> resume) PASS

Note: TC-402 (AC-2 near-camera painter excursion), TC-407 (NFR-1 O(1) integral) and TC-408 (AC-7
ceiling + per-frame cap) are realized within the above game-dir suite (TC-407 extends the
`road_geometry_test` closed-form-integral group; TC-402/TC-408 are painter-excursion assertions in the
dynamic-curve files). The headline binding case TC-405 measures over `JourneyGame.liveCentreLinePoints`
(not `liveSpawnDistances`) per the cases-file Headline Risk 1 and passed — i.e. even arc-length spacing
holds at the sharper curvature under whichever cadence fork the implementer took.

Regression context (invocation 1 superset): the full `test/features/journey/presentation/game/`
directory (181 tests, including journey-scene-v2, road-geometry, cockpit, scene-art and assets siblings)
is green — the dynamic-curve intensification and the edits to `road_geometry_test` /
`journey_scene_v2_test` did not regress sibling journey-game tests.

## Manual / carried legs (NOT automatable — not run)

From the cases file + manual checklist; listed for traceability, not executed. Counted in `manual_carried`.
- TC-M-FEEL [VISUAL] — "reads as a genuine sweeping F1-like drive yet stays a calm companion" qualitative
  feel + accessibility sign-off (AC-1/AC-2/AC-7 feel gate + NFR-3 visual). Carried. Automated numeric
  legs (TC-401/402 sharper, TC-408 <=3x+smooth, TC-405 spacing) passed.
- TC-M-PIP [VISUAL]/[REAL-OS] — real frameless always-on-top PiP visual: bend renders correctly, never
  swings the road off-screen at the sized-down PiP (AC-11 real leg). Carried. Automated bound leg TC-412
  + both-surfaces smoke TC-415 passed.
- TC-M-NF1 [DEVICE] — sustained >=30fps on both surfaces with the sharper curve under `active`, macOS +
  Windows (NFR-1 device leg). Carried (on-device only; automated proxies TC-407 O(1) integral + TC-408
  no-alloc + TC-406 cadence-cost passed).
- TC-M-PRIV [AUDIT] — `/privacy-audit` PASS, ship-blocker (NFR-2). Already PASSED in `/review-code` for
  this slice; carried here for traceability and reinforced by TC-403/TC-404/TC-410 (pure-view static),
  all green.

## Notes
- No mechanical flake patched this run. The integration smoke (invocation 2) was run with `-d macos`
  from the start, so it did not hit the unsigned-iOS code-signing device flake that earlier slices
  corrected after-the-fact; it passed 1/1 on the macOS desktop device. No test source was modified.
- This slice's dynamic-curve files carry deterministic frame-structure / numeric assertions (no
  committed golden PNG baselines on this project, consistent with prior slices) — TC-413/TC-414 are
  structural held/swept-frame assertions, so there is no golden churn to review.
- Raw stdout/stderr saved alongside this file: `unit.log` (invocation 1, CR-delimited progress —
  read via `tr '\r' '\n'`), `smoke.log` (invocation 2, the `-d macos` run).

## Verdict
green
