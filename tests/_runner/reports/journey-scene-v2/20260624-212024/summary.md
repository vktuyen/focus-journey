---
verdict: green
total: 642
passed: 642
failed: 0
flaky: 0
skipped: 0
run_at: 2026-06-24T21:20:24Z
feature: journey-scene-v2
---

# Test Run Summary — journey-scene-v2 (Wave 2 / v2)

All in-scope automated tests passed. The whole-package unit/widget suite was run
once with coverage (641 pass) — this also confirms **no cross-feature regression**
in the shipped v1 + v2 slices — and the single journey-scene-v2 integration file
was run individually on the macOS device (1 pass), per this project's one-file-at-a-time
integration harness limitation. No flakes were observed; no mechanical patch was
applied; no production logic or assertions were touched. The real-OS occlusion, fps,
qualitative "looks even/curved", and privacy-audit legs are **not automatable** and
are carried below as deferred-to-manual (NOT failures).

## Runner

- Runner (per `docs/architecture/overview.md`): **Flutter** (`flutter test`), fvm-pinned
  Flutter 3.38.10 → always invoked as `fvm flutter`.
- Executable tests live INSIDE the package under `src/focus_journey/test/` (unit/widget)
  and `src/focus_journey/integration_test/` (e2e), not under the top-level `tests/` tree.

## Commands run (exact)

All from `src/focus_journey/`.

1. Whole-package unit/widget suite + coverage (also the regression sweep):
   `fvm flutter test --coverage`
   -> `coverage/lcov.info` moved into this report folder.
2. Integration — journey-scene-v2 smoke (macOS device, run individually):
   `fvm flutter test integration_test/journey_scene_v2_smoke_test.dart -d macos`

## Pass/fail counts per invocation

| Invocation | Passed | Failed | Flaky | Skipped |
|---|---|---|---|---|
| Whole-package unit/widget — `fvm flutter test --coverage` (all v1 + v2) | 641 | 0 | 0 | 0 |
| Integration — `journey_scene_v2_smoke_test.dart` (macos) | 1 | 0 | 0 | 0 |
| **Total** | **642** | **0** | **0** | **0** |

The whole-package run (641 pass, all green) confirms **no regression** in the shipped
slices (journey-engine, journey-view, route-progress, local-stats, activity-detection,
mini-window). The journey-scene-v2 in-scope tests are members of that 641; they are
enumerated in the mapping below.

## Per-test -> case-ID mapping (PASS)

### Unit/widget — `test/features/journey/presentation/game/journey_scene_v2_test.dart`
- `TC-001 rendered scroll rate is ~0.33x of the v1 baseline` (+ `production_default_isV2PlaybackRate_withinBand`, `v2_isAboutThreeTimesSlowerThanV1_sameElapsed`, `v1_and_v2_cruiseConstants_areRenderLayerOnly`) -> TC-001 / AC-1; the render-layer-only sub-case also reinforces TC-002/TC-003 / AC-1, AC-2 (PASS)
- `TC-007 the road visibly curves; lanes/objects follow` (+ `centreLineOffset_isNonConstantOverDepth_andBendsBothWays`, `horizon_offset_isTiny_trapezoidReadPreserved`, `curveFrozen_whenStopped`) -> TC-007 / AC-6 (PASS)
- `TC-008 even spacing along the curve, variance <= 20% of mean` (+ `renderedArcLengthGaps_alongTheCurve_betweenLiveObjects_withinBound`, `spawnCadence_isUniformByConstruction_documentsTheEvenSource`) -> TC-008 / AC-7, AC-6 (PASS)
- `TC-009 richer scenery families are surfaced` (+ `everyNamedFamily_andAll16Kinds_areReachableOverAScrollCycle`, `mountainAndHills_backgroundBands_areDeclaredScenery`) -> TC-009 / AC-8 (PASS)
- `TC-010 reduce-motion OVERRIDES the slower scroll` (+ `reduceMotionActive_noScroll_evenAtV2Rate`, `reduceMotion_stillDistinguishesActiveFromStopped_viaPose`) -> TC-010 / AC-9, NFR-3 (PASS)
- `TC-011 idle/paused still parks — independent of #3/#5` (+ `idle_freezesRoadObjectsAndVehicle_atV2Rate`) -> TC-011 / AC-10 (PASS)

### Unit/widget — `test/features/journey/presentation/game/road_geometry_test.dart`
- `B1/NFR-1 closed-form integral == naive summed loop (byte-identical)` (+ `matchesReferenceAcrossSmallAndVeryLargeDistances`, `matchesReference_onAFineSweepThroughManyCycles`, `output_isAlwaysBoundedInMinusOneToOne`) -> AC-6 geometry / winding-road O(1) closed-form equivalence (NFR-1 hot-path guard) (PASS)
- `AC-6 the centre-line is non-constant and bends both ways` (+ `isNonConstant_andCrossesZeroBothDirections`) -> TC-007 / AC-6 (PASS)

### Unit/widget — `test/features/journey/presentation/game/journey_assets_test.dart`
- `TC-011 every shipped asset is CREDITS-recorded` (+ `manifestPaths_thatShip_eachAppearInCredits`, `absentShip_isDocumentedAsAKnownGap_notAFailure`, `credits_referencesEveryShippedAsset_noOrphanLoad`) -> TC-009 / AC-8 (manifest<->CREDITS forward direction) (PASS)
- `TC-009 reverse guard — every bundled journey PNG is CREDITS-recorded` (+ `everyBundledJourneyPng_appearsInCredits`) -> TC-009 / AC-8 (reverse direction) (PASS)
- `TC-014 missing/failed asset degrades gracefully (no crash)` (+ `onLoad_completesWithoutThrowing_shipPngBecomesPlaceholder`, `afterMissingAsset_sceneStillRendersAndPumps_noCrash`) -> AC-8 robustness (graceful-degradation guard) (PASS)

### Unit/widget — `test/features/mini_window/presentation/app_shell_visibility_test.dart`
- `AC-3 animate when visible-but-unfocused` (+ `mainVisible_active_runsEvenWhenFocusElsewhere`) -> TC-004 / AC-3 (PASS)
- `AC-4 pause when not visible (frozen, no per-frame work)` (+ `notVisible_<variant>_active_pauses`, `returnsToVisible_resumes`) -> TC-005 / AC-4 (PASS)
- `AC-5 per-surface — one visible, the other hidden` (+ `compactShown_gatesOnPip_notMain`) -> TC-006 / AC-5 (PASS)

### Unit/widget — `test/features/window_visibility/data/method_channel_window_visibility_controller_test.dart`
- `start ingests the snapshot list into per-surface readings`, `decodes + de-dups EventChannel stream emissions (AC-4/NFR-1)`, `ignores malformed events without throwing`, `missing plugin: start does not throw; defaults to visible`, `start is idempotent` -> AC-4/AC-5 visibility seam (production MethodChannel controller, occlusion-gated) (PASS)

### Unit/widget — `test/features/window_visibility/data/mock_window_visibility_controller_test.dart`
- `defaults both surfaces to visible`, `start records the call and marks started`, `setVisible(false) flips a surface to hidden (AC-4)`, `emits a per-surface change on transition (AC-5)`, `per-surface independence: hiding pip leaves main visible (AC-5)`, `de-duplicates identical consecutive emissions (NFR-1)`, `visibilityOf carries the surface tag`, `dispose closes the stream` -> AC-4/AC-5 visibility seam (mock controller; NFR-8 deterministic path) (PASS)

### Integration — `integration_test/journey_scene_v2_smoke_test.dart` (macos)
- `TC-013 mock-driven flow on the shared game across visibility` -> TC-013 / AC-1, AC-3, AC-4, AC-5, AC-10 (end-to-end on AppShell with MockWindowVisibilityController) (PASS)

## In-scope AC / NFR coverage (covered-by-automation vs deferred-manual)

Covered by automation (deterministic, headless / mock-driven):
- AC-1 (~0.33x scroll + engine counters unchanged) -> TC-001, TC-013
- AC-2 (one-way dependency; scroll constants render-layer-only) -> reinforced by `v1_and_v2_cruiseConstants_areRenderLayerOnly`
- AC-3 (animate when visible-but-unfocused) -> TC-004, TC-013
- AC-4 (pause when hidden/minimized/tray) -> TC-005, TC-013, visibility-seam tests
- AC-5 (per-surface evaluation on shared game) -> TC-006, TC-013, visibility-seam tests
- AC-6 (winding road curves, lanes/objects follow, trapezoid) -> TC-007, road_geometry closed-form
- AC-7 (arc-length spacing variance <= +/-20%) -> TC-008
- AC-8 (richer scenery families; manifest<->CREDITS both directions; graceful degrade) -> TC-009 (both directions)
- AC-9 / NFR-3 (reduce-motion overrides slower scroll + #5) -> TC-010
- AC-10 (idle/paused parks, independent of #3/#5) -> TC-011, TC-013

## Deferred-to-manual / on-device legs (NOT failures)

From `tests/cases/journey-scene-v2-manual-checklist.md` — these are NOT cheaply
automatable and are carried as ship-gate manual work, not as automation failures:
- **TC-M1** `[REAL-OS]` — real per-OS occlusion signal exists & fires (macOS `NSWindow.occlusionState`, Windows visibility/minimize) for a frameless always-on-top PiP (spec Decision (b) spike). Automated logic leg: TC-004/005/006.
- **TC-M2** `[REAL-OS]` — a visible-but-unfocused real surface keeps scrolling while another app holds focus (AC-3 real leg). Automated logic leg: TC-004.
- **TC-M3** `[REAL-OS]` — a hidden/minimized/tray real surface pauses (AC-4) + real per-surface independence (AC-5 real leg). Automated logic leg: TC-005/006.
- **TC-M4** `[REVIEW]` — qualitative/content-appropriateness: reads as a calm real winding trip, evenly spaced, cohesive scenery, no realistic/identifiable people (AC-6/AC-7/AC-8 judgement gate).
- **TC-M-NF1** `[DEVICE]` — sustained >=30fps on both surfaces under the full winding road + richer scenery while active (NFR-1). Hot-path is regression-guarded by the road_geometry O(1) closed-form test + inherited journey-view pool/alloc guards, but device frame-timing is on-device only.
- **TC-M-PRIV** `[AUDIT]` — `/privacy-audit` PASS: no new OS signal beyond the app's own window occlusion/visibility; reads no other-app or input data (NFR-2). **Ship-blocker.** Reinforced by the AC-2 dependency-direction inspection.

## Flakes

None. No test was re-run; no mechanical patch (selector / timing / wait-condition /
ordering) was applied. The whole-package suite and the integration file each ran
exactly once and passed. No production logic or assertions were touched.

## Notes for the reviewer

- Coverage data captured: `tests/_runner/reports/journey-scene-v2/20260624-212024/lcov.info` (whole-package lcov from invocation 1). The package-root `coverage/` dir was emptied after the move so nothing is left at the package root.
- The integration smoke build emitted the usual cosmetic macOS-foregrounding noise during `Building macOS`; the test loaded and its single assertion group passed. Not a failure, not a flake.
- TC-002 / TC-003 (engine byte-for-byte unchanged; one-way dependency direction) are not standalone named tests in the in-scope file set — they are reinforced at runtime by `v1_and_v2_cruiseConstants_areRenderLayerOnly` and at the integration level by TC-013. The full static dependency-direction + privacy verdict folds into the `/privacy-audit` (TC-M-PRIV) recorded above as deferred-manual, not as an automation failure.
- TC-012 (golden — winding road + richer scenery frame) was not surfaced as a discretely-named in-scope golden in the listed file set; the winding geometry, lane-following, and scenery layout are covered numerically by TC-007/TC-008/TC-009 and by the road_geometry closed-form equivalence. If a committed golden exists it ran as part of the 641 whole-package pass.

## Verdict

green
