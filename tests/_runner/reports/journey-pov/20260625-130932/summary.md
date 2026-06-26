---
verdict: green
total: 948
passed: 948
failed: 0
flaky: 0
skipped: 0
run_at: 2026-06-25T13:09:32Z
feature: journey-pov
---

# Test Run Summary — journey-pov

First-person cockpit POV (car + motorbike). Cockpit-specific scripts plus the
journey-pov-modified separation/guard tests were executed as part of the
whole-package regression run, and the dedicated two-surface e2e was run headless.

## Runner

- Runner declared in `docs/architecture/overview.md`: **Flutter**, invoked via **fvm** (`fvm flutter test`).
- Runner version (`fvm flutter --version`): **Flutter 3.38.10 - stable - Dart 3.10.9 - DevTools 2.51.1** (revision c6f67dede3, engine cafcda5721).
- All commands run from `src/focus_journey/`.

## Invocations (exact)

| # | Command (cwd = `src/focus_journey/`) | Passed | Failed | Flaky | Skipped |
|---|---|---|---|---|---|
| 1 | `fvm flutter test` (whole-package unit/widget - regression incl. all in-scope cockpit + guard tests) | 946 | 0 | 0 | 0 |
| 2 | `fvm flutter test integration_test/cockpit_two_surface_test.dart` (e2e, headless) | 2 | 0 | 0 | 0 |
| | **Total** | **948** | **0** | **0** | **0** |

### Note on scope of invocation #1

The task's instruction #1 named `fvm flutter test test/features/journey/`. That
subtree alone is **270 tests** (also run, all passed) and is the journey-pov
in-scope superset, but the "877-style full in-scope count" reported by prior
slices (e.g. journey-scene-v2 at 642) is the **whole-package** suite. To preserve
that regression-traceable baseline this run executed the whole package
(`fvm flutter test` -> 946) which strictly contains all 20 journey test files
including every in-scope cockpit + guard script. The journey subtree result
(270/270 green) is a subset of the 946 and is not double-counted in the total.

Raw output saved alongside this file:
- `test-output.log` - `fvm flutter test test/features/journey/` (270/270, the named subtree)
- `test-output-fullpackage.log` - `fvm flutter test` (946/946, whole package)
- `test-output-integration.log` - `cockpit_two_surface_test.dart` (2/2)

## In-scope journey-pov automated test count

All cockpit-specific scripts + the journey-pov-modified guard/separation scripts
ran green. In-scope automated tests = the cockpit suite + modified guards
(members of the 946) plus the 2 e2e tests.

## Per-test -> case-ID mapping

### Cockpit-specific - test/features/journey/presentation/game/cockpit_assets_test.dart (AC-1/AC-17) PASS
- `JourneyAssets cockpit manifest` group (all_sevenCockpitGlyphs_appearInAll, all_containsNoDuplicatePaths, cockpitCar_isExactlyTheFourCarPaths_inDrawOrder, cockpitMotorbike_isExactlyTheThreeMotorbikePaths_inDrawOrder, cockpitCar/Motorbike_hasNoDuplicates, cockpitCarAndMotorbike_areDisjoint, everyCockpitListPath_isAlsoInAll, cockpitPaths_liveUnderTheCockpitDirectory) -> TC-219 / AC-1, AC-17 (PASS)

### test/features/journey/presentation/game/cockpit_seams_test.dart (AC-1/3/5/6/7/8/13/17) PASS
- `JourneyGame.isCockpitActive` (isTrue/isFalse per mode, tracksMode_independentOfMovingFlag) -> TC-201/TC-203/TC-206 / AC-1, AC-3, AC-6 (PASS)
- `JourneyGame.cockpitAssetPaths` (carMode/motorbikeMode/isEmpty per mode) -> TC-201/TC-203/TC-206/TC-219 / AC-1, AC-3, AC-6, AC-17 (PASS)
- `JourneyGame cockpit mode-switch` (carThenWalkThenCar_flipsActiveTrueFalseTrue, carThenMotorbike_swapsTheRequestedCockpitPaths) -> TC-207/TC-208 / AC-7, AC-8 (PASS)
- `JourneyGame.cockpitViewportFraction` (isWithinSpecBand_0_30_to_0_40, equalsCockpitPainterConstant, isInvariantAcrossModes) -> TC-205 / AC-5 (PASS)
- `JourneyGame.failedCockpitAssetPaths` (subsetOfFailedAssetPaths_forCarMode, unbundledCarGlyphs_degradeToPlaceholders_notThrow, nonCockpitMode_hasEmptyFailedCockpitSet, pumpingWithDegradedCockpit_doesNotThrow) -> TC-213 (graceful degradation) / AC-13 (PASS)
- `CockpitPainter constant + paint contract` (cockpitViewportFraction_is0_36_withinSpecBand, cockpitTop_isAboveTheBottomBand, paint_forNonCockpitMode_isNoOp, paint_carWithNullGlyphs_drawsFallback, paint_motorbikeWithNullGlyphs_drawsFallback, paint_movingTrueAndFalse_bothDrawWithoutThrowing) -> TC-205/TC-206/TC-213 / AC-5, AC-6, AC-13 (PASS)

### test/features/journey/presentation/game/cockpit_render_behaviour_test.dart (AC-1/2/3/5/6/7/8/14/15 + NFR-1) PASS
- `TC-201/TC-203 cockpit composited over the road` (car/motorbike _render_addsCockpitDrawsOverTheBaselineScene, _upperViewport_remainsVisibleAndStillScrolls) -> TC-201, TC-203 / AC-1, AC-3 (PASS)
- `TC-202 gauges decorative` (car_geometryIndependentOf_timeOfDayHours_whenMovingFixed, car_needlePose_varies_ONLY_with_movingFlag) -> TC-202 / AC-2 (PASS)
- `TC-205 framing ratio - lower 30%..40%` (car/motorbike _cockpitBand_isWithin30to40pct_lowerViewport, _cockpitBulk_belowDashLine_roadUnobscuredAbove) -> TC-205 / AC-5 (PASS)
- `TC-206 mode-gating - no cockpit for non-cockpit modes` (bicycle/ship/walk _addsNoCockpitLayer_renderSmallerThanCarCockpit) -> TC-206 / AC-6 (PASS)
- `TC-207/TC-208 clean revert + restore` (per-mode _thenWalk_leavesNoResidualCockpitDraws, _walk_<mode>_restoresCockpitCleanly) -> TC-207, TC-208 / AC-7, AC-8 (PASS)
- `TC-217 reduce-motion - cockpit adds no new motion` (per-mode _reduceMotionOn_cockpitGeometryFrozenAcrossPumps) -> TC-217 / AC-14 (PASS)
- `TC-218 first-frame parked + idle parks under a cockpit` (beforeFirstApplyState_parkedDefault_rendersWithoutMotion, per-mode _idleStopped_freezesRoad_cockpitDoesNotForceMotion) -> TC-218 / AC-15 (PASS)
- `TC-220 NFR-1 hot-path - cockpit draw work bounded/stable` (per-mode _drawCount_isStableAcrossManyPumps) -> TC-220 / NFR-1 (PASS)

### test/features/journey/presentation/game/cockpit_separation_static_test.dart (AC-9/AC-10) PASS
- `TC-214 cockpit_painter separation invariant` (cockpitPainter_importsOnly_dart_flame_orPureSiblings, _hasNoForbiddenOsBlocOrEngineToken, _importsNo_flutter_widgets_or_material) -> TC-214 / AC-9 (PASS)
- `TC-214 the scene composites the cockpit but stays clean` (journeyGame_referencesCockpitPainter_butNoEngineOrBloc, journeyAssets_cockpitManifest_isPureDart_noOsSurface) -> TC-214 / AC-9 (PASS)
- `TC-215 cosmetic-only dependency direction (static half)` (engineAndDomain_holdNoCockpitOrSceneRenderReference) -> TC-215 / AC-10 (PASS)

### test/features/journey/domain/cockpit_cosmetic_engine_test.dart (AC-10) PASS
- `TC-215 car/motorbike (cockpit) byte-for-byte identical to walk (no cockpit) (AC-10)` -> TC-215 / AC-10 (PASS)

### e2e - integration_test/cockpit_two_surface_test.dart (AC-1/3/5/6/7/8/11) PASS
- `TC-209 cockpit on BOTH surfaces, scaled per the AC-5 band (AC-11)` -> TC-209 / AC-5, AC-11 (PASS)
- `TC-221 headline smoke: car -> motorbike -> walk -> car on both surfaces` -> TC-221 / AC-1, AC-3, AC-6, AC-7, AC-8, AC-11 (PASS)

### Modified guards / separation (journey-pov touched these) PASS
- test/features/journey/presentation/game/journey_assets_test.dart - TC-011/TC-009 CREDITS guards, **TC-219** cockpit-CREDITS reverse guard (everyCockpitManifestPath_hasACreditsEntry, everyCcByGlyph_recordsSourceAndLicence, everyProceduralShape_recordsAsOriginalOwnWork, sceneLoadsNoCockpitAssetAbsentFromCredits) -> TC-219 / AC-17 (PASS); TC-014 graceful-degradation guard (PASS)
- test/features/journey/presentation/game/journey_sprites_no_orphan_test.dart - B-1 orphan-asset regression guard (no cockpit asset triggers an orphan "Unable to load asset"); reinforces TC-213 / AC-13 (PASS)
- test/features/journey/presentation/journey_separation_static_test.dart - TC-009/TC-010 scene-purity + state-mutation guards, plus engine-not-to-scene one-way dependency; reinforces TC-214/TC-215 / AC-9, AC-10 (PASS)

Cases without a discretely-named in-scope automation test (TC-204, TC-210, TC-211, TC-212, TC-216 idle-trace/legend lineage) are exercised at runtime by the rendering, mode-switch, and separation guards above and/or carry into the manual/golden checklist; none surfaced as a failure within the 948 green tests.

## Manual carries - DEFERRED (not executed by this run)

These are manual / out-of-band per tests/cases/journey-pov-manual-checklist.md and are NOT run by `fvm flutter test`:
- **TC-M-PIP** - picture-in-picture / mini-window visual carry. Deferred: requires live windowed/PiP visual inspection on macOS; not automatable in the headless test runner.
- **TC-M4-ART** - cockpit art-quality / fidelity sign-off. Deferred: subjective visual review of the cockpit glyphs; manual checklist item.
- **TC-M-NF1** - NFR-1 perceived-performance / smoothness manual confirmation. Deferred: NFR-1's automatable bound is covered by TC-220 (draw-count stability); the perceptual smoothness sign-off remains manual.
- **TC-M-PRIV** - privacy audit. Deferred: handled out-of-band via `/privacy-audit` (privacy-guardian), not by the test runner.

## Notes

- No flakes observed. No mechanical patches applied. No scripts were edited.
- All in-scope cockpit scripts + modified guards + the two-surface e2e passed on the first run.
- The integration build emitted the usual cosmetic macOS-foregrounding noise during `Building macOS`; both assertion groups loaded and passed. Not a failure, not a flake.
- No raw data-file redirection (coverage/traces) was requested for this run, so nothing was littered at the repo or package root; only the three runner logs above sit in this folder.

## Verdict

green
