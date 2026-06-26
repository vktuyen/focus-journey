---
verdict: green
total: 730
passed: 730
failed: 0
flaky: 0
skipped: 0
run_at: 2026-06-25T00:48:44Z
feature: map-experience
---

# Test Run Summary — map-experience (Wave 2 / v2)

All in-scope automated tests passed. The whole-package unit/widget suite was run once
with coverage (726 pass) — this also serves as the cross-feature regression sweep
confirming the map slice did not break shipped v1 + v2 (journey-engine, journey-view,
route-progress, idle-accounting, local-stats, activity-detection, mini-window,
journey-scene-v2) — and the single map-experience integration file was run
individually on the macOS device (4 pass), per this project's one-file-at-a-time
integration-harness limitation. No flake was observed; the previously-noted
map_surface_test.dart concurrency flake did NOT recur (the suite ran serially).
No mechanical patch was applied; no production logic or assertions were touched. The
real-OS tile fetch / offline-on-real-network, >=30fps device timing, colour-blind
perception, real screen-reader, and /privacy-audit legs are not cheaply automatable
and are carried below as deferred-to-manual (NOT failures).

## Runner

- Runner (per docs/architecture/overview.md "Automation testing"): Flutter
  (flutter test), fvm-pinned Flutter 3.38.10 -> always invoked as fvm flutter.
- Executable tests live INSIDE the package under src/focus_journey/test/ (unit/widget)
  and src/focus_journey/integration_test/ (e2e), not under the top-level tests/ tree
  (documented project deviation from the chassis).

## Commands run (exact)

All from src/focus_journey/.

1. Whole-package unit/widget suite + coverage (also the regression sweep):
   fvm flutter test --coverage
   -> coverage/lcov.info moved into this report folder (lcov.info); the package-root
   coverage/ dir was removed after the move so nothing is left at the package root.
2. Integration — map-experience wiring (macOS device, run individually):
   fvm flutter test integration_test/map_experience_wiring_test.dart -d macos
   (No headless fallback was needed — the macOS device run succeeded.)

## Pass/fail counts per invocation

| Invocation | Passed | Failed | Flaky | Skipped |
|---|---|---|---|---|
| Whole-package unit/widget — fvm flutter test --coverage (all v1 + v2) | 726 | 0 | 0 | 0 |
| Integration — map_experience_wiring_test.dart (macos device) | 4 | 0 | 0 | 0 |
| Total | 730 | 0 | 0 | 0 |

Final markers observed: whole-package run ended +726: All tests passed! (zero [E],
zero -N: regressions); integration run ended +4: All tests passed!. The
map-experience in-scope tests are members of the 726 whole-package pass; they are
enumerated in the mapping below.

## Expected console noise (NOT failures)

- Exception: Invalid image data lines during map_view_test.dart — the offline-fallback
  tests deliberately feed an invalid-tile provider; the exceptions are swallowed by
  errorTileCallback and the tests assert takeException() == null. Expected, not a failure.
- [flutter_map] OSM tile-usage-policy warnings during the integration run — informational
  banner from the package; the fake/offline tile seam means no real network call is made.
  Expected, not a failure.

## Per-test-area -> case-ID (TC) -> AC mapping (PASS)

### Unit — test/features/route/domain/route_polyline_projector_test.dart
- atZero/belowZero/nonFinite clamps -> TC-205 / AC-6, AC-10 (PASS)
- atRouteLength/beyondRouteLength clamps -> TC-206 / AC-6, AC-10 (PASS)
- coordinateAt interior of a leg -> TC-203 / AC-6, AC-4 (PASS)
- stretchBetween single leg (withinOneLeg, zeroWidthSpan, outOfRouteSpan) -> TC-201 (+TC-203) / AC-6 (PASS)
- spanCrossingNodeB_includesBAsInteriorVertex_followsRoadNotChord -> TC-202 / AC-6 (PASS)
- boundaryNodeNotDuplicated (ends/starts exactly on node) -> TC-207 / AC-6, AC-10 (PASS)
- determinism (sameSpan twice, reversedArguments) -> TC-NF1, reinforces TC-207 (PASS)
- baseRoutePolyline + orderedNodes + both directions (north/south, production) ->
  reinforces TC-209/TC-211 / AC-4, AC-5; arc-length<->distance leg of TC-210 (PASS)

### Unit — test/features/route/domain/idle_trace_mapper_test.dart
- classification filtering (idle->one stretch, active->none, mixed) -> TC-201/TC-204 / AC-6 (PASS)
- zero-idle route (noSegments, allActive -> empty) -> TC-213 / AC-7; all-active complement of TC-208 (PASS)
- re-base by offset + clip (beforeOffset dropped, beyondEnd dropped, inWindow re-based,
  partial trimmed, tail clamped) -> TC-214 / AC-8 (PASS)
- cause preserved (voluntary, lockSleep, mixed) -> TC-216 mapping leg / AC-9, AC-12 (PASS)
- multiple non-contiguous (threeIdleSegments->threeStretchesInOrder) -> TC-204 / AC-6 (PASS)
- result unmodifiable -> read-only leg of TC-226 / AC-12 (PASS)
- zero-width idle segment documented honest result -> edge guard (PASS)

### Unit — test/features/route/domain/province_geography_test.dart
- GeoCoordinate lerpTo + Equatable (clamp, midpoint/quarter, equality) -> AC-4 primitive (PASS)
- chain-integrity guard + production data integrity (every checkpoint has coord,
  covers 13 provinces, inside Vietnam bbox, south-tip->north-tip order, road not a single
  straight line) -> TC-209 / AC-4 (PASS)
- marker-via-reused-routeDistanceKm, single geography model -> TC-211 / AC-5 (PASS)

### Widget — test/features/route/presentation/map_view_test.dart
- AC-6 / TC-224 idle span renders a red Polyline; active not red -> TC-224 / AC-6 (PASS)
- AC-7 / TC-213 zero-idle route draws no red anywhere -> TC-213 / AC-7 (PASS)
- AC-9 / TC-216 / TC-225 voluntary=solid vs lockSleep=dashed, same red (same red Color,
  distinct StrokePattern: solid segments==null, dashed differs) -> TC-216 / AC-9, NFR-3.
  TC-225 golden DEFERRED (project-wide golden-deferral precedent journey-view/local-stats
  TC-NF4); non-colour cue asserted behaviourally here. (PASS)
- AC-10 / TC-217 overlay states start/mid/completed (start km=0: marker present, no red) -> TC-217 / AC-10 (PASS)
- AC-11 OSM attribution + offline fallback (TC-218 attribution widget shown when tiles
  configured) -> TC-218 / AC-11 + TC-219 / AC-11 (invalid-tile -> errorTileCallback,
  takeException()==null, tab does not break) (PASS)

### Widget — test/features/route/presentation/map_surface_test.dart
- AC-1 / TC-220 inline overlay on journey tab; no standalone Map tab (renders inline; nav
  exposes NO destination labelled "Map") -> TC-220 / AC-1; nav-not-broken -> TC-221 / AC-1 (PASS)
- AC-2 / TC-222 tap -> full-screen SAME window (no new window) -> TC-222 / AC-2 (PASS)
- AC-3 / TC-223 dismiss full-screen -> inline, tab functional (close button + Esc key) -> TC-223 / AC-3 (PASS)
- Re-homed flows: start-picker (no route) + celebration (completed) -> AC-10 completion passthrough (PASS)
- NFR-2 / TC-231 tile requests are anonymous {z}/{x}/{y} GETs -> TC-231 / NFR-2 (PASS)

### Unit/Bloc — test/features/route/presentation/map_cubit_test.dart
- route + snapshot projection (markerAtMidLeg matchesResolverDrivenProjection) -> TC-211 / AC-5 (PASS)
- idleSegment_producesRedStretch_activeDoesNot -> TC-201 Bloc leg / AC-6 (PASS)
- zeroIdleRoute_emitsNoRedStretches -> TC-213 / AC-7 (PASS)
- current route only — offset re-base (idleKeyedToAbsoluteKm re-based, idleFromPriorRoute excluded) -> TC-214 / AC-8 (PASS)
- re-emits on a new snapshot (feedingNewSegments updates idleStretches) -> AC-12 read-consumer (PASS)
- seeded (restored) selection reproduces the trace -> TC-215 restore leg / AC-8 (PASS)
- NFR-1 / TC-229 projector cached; no needless geometry recompute -> TC-229 / NFR-1 (PASS)
- completion state passthrough (routeAtDestination completed; routeAtStart no red) -> TC-205/TC-206/TC-217 / AC-10 (PASS)

### Static separation — test/features/route/route_separation_static_test.dart
- TC-016 route source reads no OS/activity surface; noPlatformServicesImport;
  noJourneyEngineCoupling; TC-017 route mutates no engine state; routeOwnedDistanceKm
  never accrued; TC-NF3 non-map route uses no network/tile token
  -> TC-227 (no re-classification/accrual/ActivityPlugin) + static subset of TC-230
  (no GPS/location import) / AC-12, NFR-2 (PASS)

### Integration — integration_test/map_experience_wiring_test.dart (macos device)
- TC-215 (AC-8) red trace restored unchanged after restart (fresh MapCubit seeded from
  reloaded selection re-projects same stretches + marker) -> TC-215 / AC-8 (PASS)
- TC-222 (AC-2) tap opens full-screen SAME window (pushes MaterialPageRoute, invokes no
  window API) -> TC-222 / AC-2 (PASS)
- TC-226 / TC-228 (AC-12) pure visualizer — zero writes through a sweep (driving distances
  + segment sets never persists/mutates; toggling overlay off/on leaves upstream unchanged)
  -> TC-226 + TC-228 / AC-12 (PASS)

## In-scope AC / NFR coverage (automation vs deferred-manual)

Covered by automation (deterministic, headless / fake-tile-driven):
- AC-1 -> TC-220, TC-221
- AC-2 -> TC-222 (widget + integration)
- AC-3 -> TC-223 (close + Esc)
- AC-4 -> TC-209, TC-203, TC-210 leg
- AC-5 -> TC-211, TC-212, TC-210
- AC-6 -> TC-201, TC-202, TC-203, TC-204, TC-205, TC-206, TC-207, TC-224 (+TC-208 complement)
- AC-7 -> TC-213
- AC-8 -> TC-214, TC-215, TC-212
- AC-9 -> TC-216 (behavioural; golden TC-225 deferred)
- AC-10 -> TC-205, TC-206, TC-207, TC-217
- AC-11 -> TC-218, TC-219 (fake/invalid tile seam)
- AC-12 -> TC-226, TC-227, TC-228
- NFR-1 -> TC-229
- NFR-2 -> TC-230 (static), TC-231
- NFR-3 -> TC-216

## Deferred-to-manual / on-device legs (NOT failures)

From tests/cases/map-experience-manual-checklist.md:
- TC-M1 [REAL-OS] real OSM tile round-trip + real attribution (AC-11). Logic leg: TC-218.
- TC-M2 [REAL-OS] real offline/airplane-mode fallback on a real network stack (AC-11). Logic leg: TC-219.
- TC-M3 [REVIEW] colour-blind perception of idle + cause distinction (AC-9/NFR-3). Logic leg: TC-216.
- TC-M4 [REVIEW] real screen-reader announces open/dismiss controls (NFR-3). Deterministic semantics
  leg folds into TC-232 (keyboard reachability exercised by close/Esc in TC-223); full Semantics-label
  assertion carried as manual AT gate, per project AT-deferral precedent.
- TC-M-NF1 [DEVICE] sustained >=30fps macOS + Windows incl. inline<->full-screen with live tiles
  (NFR-1). Hot-path regression-guarded by TC-229. Windows on-device legs DEFERRED — required before
  any Windows release.
- TC-M-PRIV [AUDIT] /privacy-audit PASS: runtime socket/egress inspection that only anonymous tile
  GETs leave the machine (NFR-2, CRITICAL). Ship-blocker. Static legs reinforced by TC-230/TC-231 and
  the route_separation static test.

## Flakes

None. No test was re-run; no mechanical patch (selector/timing/wait-condition/ordering) was applied.
The whole-package suite and the integration file each ran exactly once and passed. The
historically-observed map_surface_test.dart concurrency flake (only when two flutter test processes
ran concurrently) did NOT recur — the suite was run serially, so no isolation re-run was needed. No
production logic or assertions were touched.

## Notes for the reviewer

- Coverage data: tests/_runner/reports/map-experience/20260625-004844/lcov.info (whole-package lcov
  from invocation 1). Package-root coverage/ removed after the move.
- TC-208 (all-idle paints whole travelled road) and TC-210 (polyline arc-length <-> route-progress
  distance consistency) are not discretely-named in the in-scope file set; covered structurally —
  TC-208 as the exact complement of TC-213's zero-idle result in idle_trace_mapper_test.dart, and
  TC-210 by the projector's coordinateAt single-axis behaviour (production north/south + ordered-node
  arc-length). Both ran green within the 726 whole-package pass.
- TC-227 (static separation) + TC-230 (no GPS/location import) covered by
  route_separation_static_test.dart; TC-231 (anonymous tile GET) by map_surface_test.dart. Full
  runtime egress + /privacy-audit verdict is the TC-M-PRIV gate (deferred-manual, ship-blocker),
  mirroring how idle-accounting / route-progress split the privacy promise.
- TC-225 golden DEFERRED (project-wide golden-deferral precedent); solid-vs-dashed non-colour cue
  asserted behaviourally in TC-216 — NOT a failure.

## Verdict

green
