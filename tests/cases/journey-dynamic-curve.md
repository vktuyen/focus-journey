# Test cases: journey-dynamic-curve

Spec: [specs/journey-dynamic-curve/spec.md](../../specs/journey-dynamic-curve/spec.md) — **approved (2026-06-25)** — 11 ACs (AC-1..AC-11) + 3 NFRs (NFR-1..NFR-3).
Enhances (shipped): [specs/journey-scene-v2/spec.md](../../specs/journey-scene-v2/spec.md) — this slice intensifies that scene's **winding road** (its AC-6 curve / AC-7 even-spacing). The pure-view invariant, scroll-phase determinism, reduce-motion handling, and the bounded-pool / arc-length-spacing mechanism are **inherited** and regression-guarded here. Existing cases: [tests/cases/journey-scene-v2.md](journey-scene-v2.md).
Related (shipped): [specs/mini-window/spec.md](../../specs/mini-window/spec.md) / [tests/cases/journey-pov.md](journey-pov.md) — the always-on-top PiP renders the **same** `JourneyGame` instance (ADR-0003); the sharper curve flows to it for free and must stay on-screen at the sized-down PiP (AC-11).
Sibling (blocked by this): `journey-cockpit-lean` — cockpit lean is tuned against the **final** curve shipped here; out of scope for these cases.
Decisions driving these cases: spec `## Resolved decisions` — (1) **enhance the existing parameterised curve** (raise intensity + animate via scroll phase), not a new model/spline/3D camera; (2) animate via the **existing scroll-phase input**, never a wall-clock; (3) **"sweeping but smooth" ceiling** (~2–3× bracket, Kevin 2026-06-25); (4) **AC-7 even-spacing is non-negotiable** — re-derive spawn cadence as arc-length-aware **iff** a tune alone breaks ±20%; (5) curve + cockpit lean ship as two slices.
Manual companion: [journey-dynamic-curve-manual-checklist.md](journey-dynamic-curve-manual-checklist.md) — the on-device ≥30fps, the "F1-like but calm" qualitative feel sign-off, the real-OS PiP visual read, and the `/privacy-audit` release gate that are not cheaply automatable.

## Coverage note (which layers cover which ACs; risky / under-covered areas)

- **Deterministic unit tests over the pure model (`src/focus_journey/test/.../road_geometry_test.dart` +
  siblings)** carry the bulk. The curve is a pure function of world distance with no clock and no `Random`,
  so the headline measurements are exact and stable: peak per-distance slope of `RoadGeometry.lateralAt`
  vs the pinned baseline (AC-1), the closed-form O(1) integral staying allocation-free and constant-cost at
  any `worldDistance` magnitude (NFR-1), and the arc-length even-spacing computed from the geometry integral
  over consecutive `spawnWorldDistance` values (AC-5/AC-6). These are pure-math units — **no widget pump, no
  device**.
- **Painter / widget tests (`src/focus_journey/test/`)** cover the on-screen story: the near-camera
  `RoadPainter.centreLineOffset(size, scrollOffset, t≈1)` peak excursion beating the baseline painter
  (AC-2), the bend being a smooth, non-constant, deterministic, repeatable function of `scrollOffset`
  (AC-3), the per-frame near-camera delta at the eased cruise `scrollDelta` staying under the smoothness cap
  (AC-7), reduce-motion / held-phase freezing the bend (AC-10), and the PiP-size on-screen bound (AC-11).
  Companion **golden** tests pin a swept-curve active frame, the held reduce-motion frame, and the PiP-size
  frame.
- **Static inspection** (grep / source review) covers: the AC-4 single-shared-phase invariant (the curve's
  only time input is `scrollOffset` / `worldDistance` — no second clock/timer/`Random`/per-component
  phase), the AC-8 pure-view import invariant (`road_geometry.dart` / `road_painter.dart` /
  `side_object_pool.dart` import only `dart:*`, `package:flame/*`, `TravelMode`), and the NFR-1
  no-per-frame-allocation hot-path guard (and, if AC-6 takes the arc-length-aware fork, that the new cadence
  is O(1)/alloc-free too).
- **Integration tests (`src/focus_journey/integration_test/`)** cover the two-surface read (the sharper
  curve renders on both the full window and the sized-down PiP from one shared `JourneyGame`, AC-11) and a
  headline mock-driven smoke (sweep-while-active → freeze-on-reduce-motion across both surfaces — AC-3 /
  AC-10 / AC-11).
- **Manual / on-device + review checklist** covers what is **NOT cheaply automatable**, flagged `[DEVICE]`
  / `[VISUAL]` / `[AUDIT]`: sustained **≥30fps on both surfaces** with the sharper curve under `active`
  (NFR-1 device leg), the **"reads as a real sweeping F1-like drive yet stays calm — no nausea-grade
  swings"** qualitative sign-off (AC-1/AC-7/AC-2 feel gate), the real-OS PiP visual confirmation that the
  bend never swings the road off-screen on a live frameless PiP (AC-11 real leg), and the `/privacy-audit`
  PASS release gate (NFR-2).

**Risky / under-covered areas (flagged):**

- **HEADLINE RISK 1 — AC-5/AC-6 is the binding invariant and its pass path is not yet known.** Whether the
  **fixed** longitudinal cadence (`spawnEveryWorldPx`) still holds the **arc-length** ±20% bound at the
  chosen sharper curvature is unknown until measured. The spec leaves an explicit implementation fork
  (Resolved decision 4): either the tune alone passes (no cadence change), **or** the spawn cadence becomes
  **arc-length-aware**. **TC-405 is designed to pass under EITHER path** — it asserts the *outcome*
  (arc-length gaps along the curving centre-line within ±20% of the mean), not the mechanism. **Important
  seam caveat:** `JourneyGame.liveSpawnDistances` exposes only the fixed cadence and is even *by
  construction* (it can never fail), so TC-405 must measure over `JourneyGame.liveCentreLinePoints` (each
  object's real `(world, lateral)` on the curving centre-line) — the seam the v2 author added precisely so
  the arc-length variance check can genuinely fail. If AC-6 takes the arc-length-aware fork, TC-406 also
  guards the new cadence stays O(1)/alloc-free (NFR-1).
- **HEADLINE RISK 2 — the baseline for AC-1 / AC-2 / AC-7 is a pinned constant, not a live build.** Like
  journey-scene-v2's "v1 baseline" (its Conventions), the "sharper than baseline" assertions compare the
  shipped dynamic-curve params against a **pinned reference** representing the journey-scene-v2 curve
  (`RoadGeometry(segmentLength: 900, maxHeading: 0.0016)` + `_curveAmplitudeFrac = 0.16`), re-derived
  independently in the test exactly as `road_geometry_test.dart` re-derives `_referenceLateral`. If the
  baseline params are refactored, the pinned reference must be re-pinned or these cases silently drift.
- **AC-1 / AC-7 "~2× lower, ~3× ceiling" multiples are a numeric proxy for "F1-like but calm".** Automation
  asserts peak slope `≥ K·baseline` (K≈2) and `≤ ~3×` baseline and the per-frame delta cap; "reads as a
  genuine sweeping drive yet stays a calm companion, no motion discomfort" is the **review/feel gate**
  TC-M-FEEL, not a pass/fail assert. The exact achieved multiple + the px/frame cap are pinned in build by
  flame-game-developer within the Kevin-approved 2–3× bracket.
- **AC-11 PiP read — automation proves the on-screen *bound*, not the live-OS visual.** TC-409 asserts
  `|centreLineOffset(size, off, 1.0)| + nearHalf ≤ size.width/2` across a scroll sweep at representative
  PiP + full sizes; that a real frameless always-on-top PiP shows the bend correctly without clipping is
  the manual `[VISUAL]` TC-M-PIP. The exact PiP test size may be adjusted by the reviewer (spec AC-11).
- **NFR-1 (≥30fps both surfaces) is on-device only.** The deterministic proxies are the O(1)-integral
  constant-cost guard (TC-407) + the no-per-frame-allocation static guard (TC-408) re-run with the sharper
  curve loaded; sustained frame rate is the device leg TC-M-NF1.
- **NFR-2 (privacy) is an AUDIT ship-blocker.** The curve adds only `dart:math` and the existing shared
  scroll phase; `/privacy-audit` PASS (TC-M-PRIV) gates ship, reinforced by the AC-8 pure-view static case
  (TC-403). A fail blocks ship regardless of every other pass.

## Conventions used by these cases

- **Pure-math first, no real OS / clock / timers.** The curve is a pure function of world distance, so the
  AC-1/AC-5/AC-7/NFR-1 measurements run directly against `RoadGeometry.lateralAt` /
  `RoadPainter.centreLineOffset` with plain numeric inputs — **no widget pump and no device**. Where a
  scene is needed (AC-3 sweep, AC-10 freeze, AC-11 PiP), it is driven exclusively through `applyState({moving,
  mode, reduceMotion, timeOfDayHours})` and advanced explicitly (`game.update(dt)` / `pump`), never by
  awaiting real time — as in journey-scene-v2 / journey-pov.
- **"Baseline" = the pinned journey-scene-v2 curve.** Every "sharper than baseline" / "≤ ~3× baseline"
  assertion compares the shipped dynamic-curve `RoadGeometry` + painter amplitude against a **pinned
  reference** for `RoadGeometry(segmentLength: 900, maxHeading: 0.0016)` + `_curveAmplitudeFrac = 0.16`,
  independently re-derived in the test (mirroring how `road_geometry_test.dart` re-derives
  `_referenceLateral` rather than copying production constants). Re-pin if the baseline params are
  refactored.
- **"Peak per-distance slope" (AC-1 / AC-7).** `max over d of |lateralAt(d + h) − lateralAt(d)| / h` for a
  small fixed step `h`, sampled densely over at least one full heading cycle (16·`segmentLength`) — the
  finite-difference proxy for `max |d(lateralAt)/d(worldDistance)|`. The same `h` is used for baseline and
  shipped so the *ratio* is what is asserted, not the absolute.
- **"Near-camera excursion" (AC-2 / AC-7 / AC-11).** Measured at `t → 1` (near camera, where the depth
  weighting `t*t` is strongest) via `RoadPainter.centreLineOffset(size, scrollOffset, 1.0)` at a fixed
  viewport size, swept over a range of `scrollOffset` covering at least one full heading cycle; "peak
  excursion" is the max `|offset|` over the sweep.
- **"Cruise `scrollDelta`" (AC-7 per-frame cap).** The per-frame near-camera centre-line change is measured
  by stepping `scrollOffset` by ONE eased cruise frame's delta — the steady `JourneyGame.cruiseSpeed`
  (`kV2CruiseSpeed`) × a representative `dt` (e.g. 1/60 s) — and asserting `|centreLineOffset(size, off+Δ,
  1.0) − centreLineOffset(size, off, 1.0)| ≤ cap` for every `off` across the sweep. The cap target is **≤
  ~2% of viewport width per frame** (spec AC-7); the exact px/frame value is pinned in build.
- **"Arc-length along the curving road" (AC-5).** The gap between two objects at world coordinates `w0 <
  w1` is `∫ from w0 to w1 of √(1 + (d·lateralPx/d·world)²) dworld`, where `lateralPx(world) =
  lateralAt(world) × nearAmp` (`nearAmp = size.width × _curveAmplitudeFrac`, the strongest near-camera
  bend — matching `JourneyGame.liveCentreLinePoints`). Computed numerically (fine longitudinal step) from
  the pure geometry, NOT screen-space pixel distance. **Measure over `liveCentreLinePoints`**, never
  `liveSpawnDistances` (the latter is even by construction — see Headline risk 1).
- **"Sweep" / "smooth" / "deterministic" (AC-3).** *Sweeps* = `centreLineOffset(size, off, 1.0)` is
  non-constant as `off` advances over a cycle. *Smooth* = no discontinuity — consecutive cruise-frame steps
  stay under the AC-7 cap. *Deterministic / repeatable* = the SAME `scrollOffset` yields the SAME output on
  a second call (compared exactly, ±1e-9), and no `DateTime.now` / `Random` / wall-clock is read (static).
- **"Cosmetic-only / byte-for-byte" (AC-9).** For a fixed injected elapsed time and identical mock activity
  input, the engine's exposed `distanceKm` / progress / elapsed / idle-vs-active values are **exactly
  identical** whether the scene renders the sharper curve or the baseline curve — compared with **exact
  equality**, not ±epsilon (engine truth, not rendered floats). The curve reads no OS signal, decides no
  active-vs-idle, accrues no distance.
- **Float tolerance.** Pure-geometry samples / rendered offsets compare within **±1e-6** logical px unless
  stated (the curve↔naive-loop equality uses ±1e-9, per `road_geometry_test.dart`); the AC-1/AC-7 slope
  *multiples* use the agreed K-band; engine counters (AC-9) use **exact** equality.
- **Test layer per `docs/architecture/overview.md`.** Executable tests live under `src/focus_journey/`:
  curve slope / arc-length spacing / O(1) integral / per-frame cap → **unit** (`test/.../game/`);
  on-screen excursion / sweep determinism / freeze / PiP bound + goldens → **widget/golden** (`test/`);
  both-surfaces render + headline smoke → **integration** (`integration_test/`); pure-view imports /
  single-phase / no-per-frame-alloc → **static inspection**; on-device fps, feel, real-OS PiP, privacy
  audit → manual. `tests/cases/` (this file) holds human-readable scenarios only.

## Cases

### Case: Peak model curvature is clearly sharper than the pinned baseline
**ID:** TC-401
**Priority:** P0
**Type:** happy-path
**Covers:** AC-1

Given the pinned journey-scene-v2 baseline geometry (`RoadGeometry(segmentLength: 900, maxHeading: 0.0016)`) independently re-derived as a reference, and the shipped dynamic-curve `RoadGeometry`
When both are sampled densely with the same small finite-difference step over at least one full heading cycle (`d ∈ [0, N·segmentLength]`) and each one's peak per-distance lateral slope `max_d |lateralAt(d+h) − lateralAt(d)| / h` is computed
Then the shipped geometry's peak slope is **at least K× the baseline's peak slope** (target **K ≈ 2.0×** — Kevin-approved 2–3× bracket), proving the model curve is materially sharper, not merely retuned within noise

**Notes:** Pure-math unit test (`src/focus_journey/test/.../game/road_geometry_test.dart`), no device. Re-derive the baseline reference independently (do NOT import the shipped params as the baseline — they ARE the new value). Use the SAME `h` for both so the asserted quantity is the ratio. The achieved multiple is pinned in build within the 2–3× bracket; its UPPER bound is TC-407-adjacent AC-7 (TC-408? no — the slope ceiling is in TC-408's sibling). Pairs with TC-408 (≤ ~3× ceiling) — together they bracket "sharper but bounded". The "feels F1-like" judgement is TC-M-FEEL.

---

### Case: Sharper bend reaches the screen — near-camera painter excursion beats the baseline
**ID:** TC-402
**Priority:** P0
**Type:** happy-path
**Covers:** AC-2

Given the dynamic-curve geometry feeding `RoadPainter.centreLineOffset(size, scrollOffset, t)` at a fixed viewport size, and the pinned baseline painter (`_curveAmplitudeFrac = 0.16` + baseline geometry) as a reference
When the near-camera offset (`t → 1`) is swept across a `scrollOffset` range covering at least one full heading cycle and each path's peak absolute excursion `max |centreLineOffset(size, off, 1.0)|` is collected
Then the shipped painter's peak near-camera excursion **exceeds the baseline painter's peak excursion by a clear, asserted margin** — i.e. the sharper model is actually rendered on screen and the painter (its depth weighting / amplitude) does not clamp the extra curvature away

**Notes:** Widget/unit test against `RoadPainter.centreLineOffset` (or the `JourneyGame.centreLineOffsetAt(t)` seam at a fixed size), no device. The on-screen counterpart to TC-401's model-space assertion — guards against a sharper model being flattened by the painter. Companion golden TC-410 pins the swept frame. Note the painter's `_curveAmplitudeFrac` may itself be raised as part of the intensification; the case asserts the *rendered* excursion ratio regardless of which knob moved.

---

### Case: Bend sweeps with scroll — smooth, non-constant, and a deterministic repeatable function of scroll phase only
**ID:** TC-403
**Priority:** P0
**Type:** happy-path
**Covers:** AC-3, AC-4

Given the scene is `active` so `roadScrollOffset` advances, a fixed viewport size, reduce-motion OFF
When the near-camera centre-line (`centreLineOffset(size, scrollOffset, 1.0)`) is sampled across a sequence of advancing `scrollOffset` values (one full cycle), then re-sampled at the SAME recorded `scrollOffset` values a second time
Then (a) the bend **sweeps** — the offset is **non-constant** as `scrollOffset` advances; (b) it is **smooth** — consecutive cruise-frame steps show no discontinuity (each within the AC-7 per-frame cap); (c) it is **deterministic / repeatable** — the second pass at the same `scrollOffset` values yields **byte-identical** output (±1e-9); and (d) it is a function of **scroll phase only** — no `DateTime.now` / wall-clock / `Random` is read, and the curve's only time input is the same `scrollOffset` / `worldDistance` the road body, dashes and pool already consume (no second clock/timer/per-component phase)

**Notes:** Widget test for the sweep + repeatability (advance `roadScrollOffset` via `update(dt)`, record offsets, replay) **plus a static-inspection leg** for AC-4 / the "scroll-phase only" half: grep `road_geometry.dart` / `road_painter.dart` for `DateTime`, `Stopwatch`, `Random`, `Timer`, and any second phase input — assert the only time-varying input threaded into the curve is `scrollOffset`/`worldDistance`. Mirrors journey-scene-v2's scroll-phase determinism. The determinism here is what keeps goldens (TC-410..TC-412) stable. AC-4 is the harder-to-observe one — see findings.

---

### Case: Single shared phase — the curve introduces no second motion source
**ID:** TC-404
**Priority:** P0
**Type:** regression
**Covers:** AC-4

Given the rest of the scene (lane dashes, side objects, parallax bands, sky) already rides the single shared scroll phase (`JourneyGame.roadScrollOffset` → `_motion.offset`)
When the dynamic-curve source files are inspected statically AND the scene is held with a **frozen** scroll phase across several `update(dt)` pumps
Then the curve derives its sweep from that **same single phase input** and introduces **no** new independent clock, timer, `Random`, or per-component phase — confirmed structurally (the curve's only time argument is `scrollOffset`/`worldDistance`) and behaviourally (with the phase frozen, the bend is constant frame-to-frame, i.e. nothing else animates it)

**Notes:** Static-inspection case over `lib/features/journey/presentation/game/{road_geometry,road_painter,side_object_pool}.dart` (no `DateTime`/`Stopwatch`/`Random`/`Timer`/second-phase field) reinforced by the frozen-phase behavioural check (shares the harness with TC-413's freeze). The behavioural half overlaps AC-10 (TC-413) — together they prove "no second motion source". Pairs with TC-403(d).

---

### Case: Even arc-length spacing holds at the sharper curvature — under EITHER cadence implementation
**ID:** TC-405
**Priority:** P0
**Type:** edge
**Covers:** AC-5, AC-6

Given the side-object pool runs a full scroll cycle with the **sharper** curve loaded (`state = active`), regardless of whether the cadence stayed the fixed `spawnEveryWorldPx` (tune-only path) or was made arc-length-aware (rework path)
When consecutive live objects' real positions on the curving centre-line are read via `JourneyGame.liveCentreLinePoints` (each `(world, lateral)`), and the **arc-length** gap between consecutive objects is computed from the pure geometry integral `∫√(1 + (d·lateralPx/d·world)²) dworld` between their `world` coordinates
Then every consecutive arc-length gap stays **within ±20% of the mean gap** — `max |gap − mean| ≤ 0.20 × mean` — with **no** gap collapsing toward zero (clumping) and **no** stretch far exceeding the mean (empty stretch), preserving journey-scene-v2 AC-7 along the now-sharper road

**Notes:** **THE BINDING CASE.** Unit/widget test. **Must measure over `liveCentreLinePoints`, NOT `liveSpawnDistances`** — the latter exposes only the fixed cadence and is even by construction (can never fail), so it would give a false PASS (see Coverage note Headline risk 1 + the `JourneyGame.liveCentreLinePoints` docstring, which exists for exactly this). The case asserts the OUTCOME (±20% along the curve), so it passes under whichever fork the implementer chose. If this FAILS with the fixed cadence, the spec mandates the arc-length-aware cadence (AC-6) — then TC-406 guards that fork's cost. The "looks evenly spaced, no clumping" human read is TC-M-FEEL.

---

### Case: Arc-length-aware cadence (if taken) stays allocation-free and O(1) per spawn
**ID:** TC-406
**Priority:** P0
**Type:** edge
**Covers:** AC-6, NFR-1

Given the implementer measured arc-length variance at the chosen curvature and (per AC-6) **either** kept the fixed `spawnEveryWorldPx` cadence **or** switched to an arc-length-aware spawn cadence to pass TC-405
When the spawn path is inspected statically and exercised across a long scroll run
Then **whichever path was taken** keeps the pool **allocation-free** on the hot `advance` path and **O(1) per spawn** (no per-frame heap allocation, no unbounded per-spawn loop): if the cadence stayed fixed, the inherited journey-view/journey-scene-v2 no-alloc / bounded-plateau guards still hold; if it became arc-length-aware, the new equal-arc-length spawn computation is itself a closed form / bounded step that allocates nothing per frame and does not grow with `worldDistance`

**Notes:** Static inspection + the inherited bounded-pool (`liveCount` plateau ≤ `capacity`) / no-per-frame-allocation guards re-run with the sharper curve, AND — if the arc-length-aware fork was taken — an added assertion that the new cadence math is constant-cost (e.g. reuses the geometry's closed-form arc-length, not a growing accumulating loop). This case is an implementation FORK guard: it must validate whichever path TC-405 was satisfied by. Pairs with TC-407 (the geometry integral's own O(1) guard). If an ADR was needed (spec Resolved decision 4), reference it here.

---

### Case: O(1) closed-form curve integral — constant call cost independent of worldDistance magnitude
**ID:** TC-407
**Priority:** P0
**Type:** regression
**Covers:** NFR-1

Given the sharper-curve `RoadGeometry` (`_integratedHeading` closed form, cyclic heading table + precomputed prefix sums)
When `lateralAt(worldDistance)` is evaluated at small distances and at very large distances reached after a long focus session (e.g. up to ~1.5M–10M px) and compared against an independent naive per-segment summing loop
Then the closed form is **byte-identical** to the summed loop at every sampled distance (±1e-9) — proving it remains a TRUE O(1) closed form whose cost does **not** grow with `worldDistance` (no unbounded per-frame accumulating loop), however sharp the bend or however long the session has scrolled, and the output stays bounded in `[-1, 1]`

**Notes:** Extends the existing `road_geometry_test.dart` "B1/NFR-1 closed-form integral == naive summed loop" group, re-run with the **sharper** `maxHeading` / `segmentLength`. Re-derive the naive reference independently with the SHIPPED params (mirror `_referenceLateral` but with the new constants). The headline NFR-1 deterministic proxy; on-device ≥30fps is TC-M-NF1. If the intensification changes the heading table, also re-pin the `_prefix` precomputed sums match a freshly-summed cycle.

---

### Case: Calm-tone ceiling — peak slope ≤ ~3× baseline AND per-frame near-camera delta within the smoothness cap
**ID:** TC-408
**Priority:** P0
**Type:** edge
**Covers:** AC-7

Given the chosen (sharper) curvature and the pinned baseline reference, a fixed viewport size, and the eased cruise scroll rate (`JourneyGame.cruiseSpeed` × a representative frame `dt`)
When (a) the peak per-distance slope of `lateralAt` is compared to the baseline's peak slope, and (b) the near-camera centre-line is stepped by ONE cruise-frame's `scrollDelta` across a full scroll sweep and the per-frame change `|centreLineOffset(size, off+Δ, 1.0) − centreLineOffset(size, off, 1.0)|` is collected
Then (a) the peak slope is **≤ ~3× the baseline** (the upper bound complementing TC-401's ~2× lower target — sharper but bounded, the Kevin-approved 2–3× bracket), (b) the per-frame near-camera delta stays **≤ the smoothness cap (~2% of viewport width per frame)** for every step (no abrupt snap / chicane), and (c) `|lateralAt| ≤ 1` everywhere by construction so the centre-line stays on screen

**Notes:** Pure-math + widget unit test, no device. Brackets TC-401 from above: TC-401 = "≥ ~2× (sharp enough)", TC-408 = "≤ ~3× and smooth (calm enough)". The exact px/frame cap is pinned in build against the actual eased cruise `scrollDelta` — re-pin the band if retuned. The qualitative "calm, no nausea-grade swings" sign-off is TC-M-FEEL. Guards that the intensification did not overshoot the calm-companion tone.

---

### Case: Cosmetic-only — engine distanceKm / progress / idle decisions byte-for-byte unchanged vs baseline
**ID:** TC-409
**Priority:** P0
**Type:** edge
**Covers:** AC-9

Given identical mock activity input and a fixed injected elapsed time, run once with the scene rendering the **sharper** curve and once with the **baseline** curve (same inputs otherwise)
When the engine's exposed `distanceKm` / progress / elapsed / idle-vs-active decisions are read at the same elapsed points in both runs
Then the engine values are **exactly identical** between the two runs — intensifying the curve perturbs **no** engine number; the curve reads no OS signal, decides no active-vs-idle, and accrues no distance (cosmetic, single-speed, pure-view)

**Notes:** Widget/integration test asserting **exact equality** (not ±epsilon) across the sharper-curve vs baseline-curve runs for the same injected elapsed. Mirrors journey-pov TC-215 / journey-scene-v2 TC-002. The static half (no engine reference to the curve; pure-view imports) is TC-403/TC-404. Drives state via `applyState`; advances frames via the harness.

---

### Case: Pure-view invariant preserved — curve sources import only dart:*, package:flame/*, TravelMode
**ID:** TC-410
**Priority:** P0
**Type:** regression
**Covers:** AC-8

Given the sharper curve is implemented across `road_geometry.dart`, `road_painter.dart`, and `side_object_pool.dart` (and any new arc-length-aware-cadence source if AC-6 took that fork)
When their source (imports + references) is inspected statically
Then they import **only** `dart:*`, `package:flame/*`, and the pure-Dart domain `TravelMode` — **no** `flutter_bloc`, `JourneyEngine`, `ActivityPlugin`, `MethodChannel` / platform channel, or any OS idle/lock/screen/location read — and the curve is driven solely by the shared scroll offset (world distance), mirroring journey-scene-v2's separation AC and journey-pov AC-9

**Notes:** Static-inspection case (grep / import scan) over `lib/features/journey/presentation/game/{road_geometry,road_painter,side_object_pool}.dart` + any new cadence file, mirroring journey-pov TC-214 and the files' own SEPARATION INVARIANT docstrings. Re-run on any new source file. Reinforces NFR-2 (TC-M-PRIV).

---

### Case: Reduce-motion freezes the sweep — held scroll phase yields identical centre-line samples
**ID:** TC-411
**Priority:** P0
**Type:** edge
**Covers:** AC-10, NFR-3

Given reduce-motion is ON (`applyState(..., reduceMotion: true)`) so the scroll phase is frozen (`scrollDelta == 0`), the surface visible, `state = active`
When the scene is advanced by several `update(dt)` pumps and the near-camera centre-line (`centreLineOffset(size, scrollOffset, t)` at a held `scrollOffset`) is sampled on successive frames
Then the bend is **frozen** — successive `centreLineOffset` samples are **identical** (±1e-6) frame-to-frame because the curve is a pure function of the frozen scroll phase — i.e. the sharper curve introduces **no** new independent motion source that would animate under reduce-motion (mirrors journey-scene-v2 AC-9 / journey-pov AC-14)

**Notes:** Widget test with reduce-motion true; assert frozen `roadScrollOffset` AND identical centre-line samples across pumps. Companion golden TC-412. Inherits journey-scene-v2's reduce-motion freeze; the new clause is that the SHARPER curve still freezes (it added no clock). The behavioural twin of TC-404's frozen-phase leg. NFR-3 reduce-motion leg.

---

### Case: Sharper curve stays on-screen at the sized-down PiP (and at full size) across a scroll sweep
**ID:** TC-412
**Priority:** P0
**Type:** edge
**Covers:** AC-11, NFR-3

Given the full window and the always-on-top mini-window PiP render the **same** `JourneyGame` instance (ADR-0003), at a representative PiP size and a full-window size
When the near-camera **centre-line** is swept across a full scroll cycle at each size
Then at **both** sizes the road **centre-line stays on screen** for every offset in the sweep — `|centreLineOffset(size, scrollOffset, 1.0)| ≤ size.width / 2` (in fact ≤ `RoadPainter.curveAmplitudeFrac · width = 0.20·width`, a comfortable margin) — so the sharper bend never swings the road centre out of the viewport, and the bend still reads as a sweeping curve (non-constant excursion)

**CORRECTED BOUND (deviation noted 2026-06-25):** the original literal `|centreLineOffset| + nearHalf ≤ width/2` (road EDGE inside the viewport) is **unsatisfiable even at the journey-scene-v2 baseline** — the trapezoid's `_roadNearHalfFrac = 0.46` plus the baseline amplitude already pushes the near road EDGE past `width/2` BY DESIGN (the road edge intentionally extends past the viewport so the road fills the bottom of the frame). It is therefore not a regression introduced by the sharper curve and cannot be a pass/fail assert. Per **spec AC-11**, the satisfiable, meaningful invariant is the road **centre-line** staying on screen (above), which the automation asserts. The real frameless-PiP "edge looks right, never clips visibly" read remains the manual `[VISUAL]` TC-M-PIP.

**Notes:** Unit/widget test at representative PiP + full sizes (the PiP test size may be adjusted by the reviewer per spec AC-11). Asserts the on-screen centre-line BOUND across the sweep; the real frameless always-on-top PiP visual confirmation is the manual `[VISUAL]` TC-M-PIP. NFR-3 "does not obscure the road" leg. Pairs with TC-415 (both surfaces actually render the same curve).

---

### Case: Golden — swept sharper-curve active frame is visually stable
**ID:** TC-413
**Priority:** P1
**Type:** regression
**Covers:** AC-1, AC-2, AC-3, AC-7

Given a fixed `mode`, fixed injected day-time clock, a fixed (non-zero) scroll phase mid-sweep, `state = active`, visible, reduce-motion OFF, the sharper curve loaded
When the scene renders one frame
Then it matches the committed "dynamic-curve swept active" golden image — a visibly sharper-than-baseline bend, road + lanes + side objects all following the same curving centre-line, trapezoid (near→horizon narrowing) preserved

**Notes:** Golden test (`src/focus_journey/test/`). Determinism via fixed clock/mode/phase + the scroll-phase-only curve (TC-403). Regression guard that the sharper geometry / painter amplitude do not silently change. Does NOT prove "reads as F1-like but calm" — that is TC-M-FEEL. Expect this golden to be re-pinned when the curve is first tuned in build (golden churn is why this slice is sequenced after journey-scene-art-v3, per spec).

---

### Case: Golden — reduce-motion held frame (curve frozen) is visually stable
**ID:** TC-414
**Priority:** P1
**Type:** regression
**Covers:** AC-10

Given `reduceMotion == true`, a fixed `mode`, fixed injected day-time clock, a held scroll phase, visible
When the scene renders one frame and is re-rendered after several `update(dt)` pumps
Then both renders match the committed "dynamic-curve reduce-motion held" golden — the bend is frozen (identical across pumps) and the curve does not animate under reduce-motion

**Notes:** Golden test pinning AC-10's freeze visually. Pairs with TC-411's seam-level assertion. Reuses the reduce-motion frame convention from journey-scene-v2 TC-010 / journey-pov TC-218.

---

### Case: End-to-end smoke — sharper curve renders on both surfaces, sweeps while active, freezes on reduce-motion
**ID:** TC-415
**Priority:** P1
**Type:** regression
**Covers:** AC-3, AC-10, AC-11

Given the app launched with the mock activity + mock window/visibility path, the shared `JourneyGame` rendering on **both** the full window and the sized-down PiP surface
When the mock drives `active` (the curve sweeps as the scroll phase advances), then reduce-motion ON (the curve freezes), then reduce-motion OFF + `active` again (the sweep resumes)
Then across the flow the **same** sharper curve appears on **both** surfaces (staying on-screen at the PiP size per TC-412), sweeps while active, freezes under reduce-motion, and resumes on return — confirming the curve↔scroll-phase↔both-surfaces wiring on the shared game

**Notes:** `integration_test` (`src/focus_journey/integration_test/`) on the real widget tree with the **mock** activity + window/visibility path (deterministic, no real OS). The mock-path twin of the manual real-OS PiP leg TC-M-PIP. Drives state via the mock; frames via the harness. Per-surface on-screen bound detail is TC-412.

---

## Manual / on-device + review legs (see the companion checklist)

These verify what is **NOT cheaply automatable**. They live in
[journey-dynamic-curve-manual-checklist.md](journey-dynamic-curve-manual-checklist.md) and are flagged here.

- **TC-M-FEEL** `[VISUAL]` — qualitative feel + accessibility read: the road **reads as a genuine sweeping
  F1-like drive** (clearly sharper than before) **yet stays a calm companion** (no abrupt chicanes, no
  nausea-grade swings, comfortable to leave on-screen all session), scenery still **looks evenly spaced**,
  and the curve does **not** obscure the road / vehicle / "Paused — idle" overlay (AC-1 / AC-2 / AC-7 feel
  gate + NFR-3 visual leg). Automated numeric legs: TC-401/TC-402 (sharper), TC-408 (≤3× + smooth),
  TC-405 (spacing).
- **TC-M-PIP** `[VISUAL]`/`[REAL-OS]` — on a **real** frameless always-on-top PiP, the sharper bend renders
  correctly and **never swings the road off-screen** at the sized-down PiP, and reads as a sweeping curve
  (AC-11 real leg). Automated bound leg: TC-412; both-surfaces smoke: TC-415.
- **TC-M-NF1** `[DEVICE]` — sustained **≥30fps on both surfaces** (full window + sized-down PiP) with the
  sharper curve under `active` on macOS + Windows (NFR-1). Automated proxy: TC-407 (O(1) integral) + TC-408
  no-alloc / TC-406 cadence-cost + inherited bounded-pool guards.
- **TC-M-PRIV** `[AUDIT]` — `/privacy-audit` PASS: the curve adds **no** new OS signal / input / screen /
  location read — only `dart:math` + the existing shared scroll phase (NFR-2). **Ship-blocker.** Reinforced
  by TC-403/TC-404/TC-410.

---

## Coverage table (AC / NFR → covering case IDs)

| Item | Description | Covered by |
|---|---|---|
| AC-1 | peak model curvature ≥ ~2× baseline peak slope | TC-401, TC-413; **[VISUAL]** TC-M-FEEL |
| AC-2 | sharper ON SCREEN — near-camera painter excursion > baseline | TC-402, TC-413; **[VISUAL]** TC-M-FEEL |
| AC-3 | bend sweeps smoothly + deterministically with scroll phase | TC-403, TC-413, TC-415 |
| AC-4 | single shared phase — no second motion source | TC-404, TC-403 (static + frozen-phase) |
| AC-5 | even arc-length spacing ±20% at the sharper curvature | TC-405 (over `liveCentreLinePoints`) |
| AC-6 | arc-length-aware cadence IFF fixed cadence fails — O(1)/alloc-free | TC-405 (outcome), TC-406 (cost, either fork) |
| AC-7 | calm-tone ceiling — peak slope ≤ ~3× + per-frame delta ≤ ~2% width | TC-408, TC-413; **[VISUAL]** TC-M-FEEL |
| AC-8 | pure-view imports preserved | TC-410 (+ TC-403/TC-404 static) |
| AC-9 | cosmetic-only — engine distanceKm/progress/idle byte-for-byte unchanged | TC-409 |
| AC-10 | reduce-motion freezes the sweep | TC-411, TC-414, TC-415 |
| AC-11 | two-surface PiP read — road stays on-screen at PiP + full size | TC-412, TC-415; **[VISUAL]** TC-M-PIP |
| NFR-1 | O(1)/alloc-free integral + cadence; ≥30fps both surfaces | TC-407, TC-406 (+ TC-408 no-alloc); **[DEVICE]** TC-M-NF1 |
| NFR-2 | pure-view; no new OS read; /privacy-audit PASS | **[AUDIT]** TC-M-PRIV (reinforced by TC-403/TC-404/TC-410) |
| NFR-3 | reduce-motion honoured; curve doesn't obscure road/vehicle/overlay | TC-411, TC-412; **[VISUAL]** TC-M-FEEL, TC-M-PIP |

Every AC (AC-1..AC-11) and every NFR (NFR-1..NFR-3) maps to at least one case. No AC/NFR is orphaned.

### Coverage notes / flagged gaps

- **AC-5/AC-6 is the binding risk and TC-405 must use the right seam.** TC-405 asserts the *outcome*
  (arc-length ±20% along the curving centre-line) so it passes under EITHER the tune-only or the
  arc-length-aware-cadence fork; TC-406 then guards the chosen fork stays O(1)/alloc-free. TC-405 **must**
  measure over `JourneyGame.liveCentreLinePoints` (real `(world, lateral)` on the curve), never
  `liveSpawnDistances` (even by construction → false PASS). If TC-405 fails with the fixed cadence, the
  spec mandates the arc-length-aware fork (possibly an ADR).
- **AC-1/AC-2/AC-7 multiples are against a PINNED baseline, not a live build.** Re-derive the
  journey-scene-v2 baseline (`segmentLength 900`, `maxHeading 0.0016`, `_curveAmplitudeFrac 0.16`)
  independently in-test (as `road_geometry_test.dart` re-derives `_referenceLateral`); re-pin if the
  baseline params are refactored or these cases drift silently. The 2–3× bracket and px/frame cap are the
  numeric proxy; "F1-like but calm" is the review gate TC-M-FEEL.
- **AC-3/AC-4 — sweep + single-phase proven by behaviour + static inspection.** The sweep/repeatability is
  behavioural (TC-403); "scroll-phase only, no second clock" is structural (TC-403 static leg + TC-404 grep
  for `DateTime`/`Stopwatch`/`Random`/`Timer`/second phase) reinforced by the frozen-phase behavioural
  check. AC-4 is the hardest to make a single positive assertion for — see findings.
- **AC-11 — automation proves the on-screen BOUND, not the live-OS visual.** TC-412 asserts
  `|centreLineOffset| + nearHalf ≤ width/2` across a sweep at PiP + full sizes; the real frameless PiP
  visual is TC-M-PIP. The PiP test size may be adjusted by the reviewer (spec AC-11).
- **NFR-1 (≥30fps both surfaces) — DEVICE only.** TC-407 (O(1) integral, byte-identical to the naive loop
  at huge distances) + TC-408's no-alloc + TC-406's cadence-cost + the inherited bounded-pool guards are
  the deterministic proxy; sustained frame rate is on-device TC-M-NF1.
- **NFR-2 (privacy) — AUDIT gate.** The curve adds only `dart:math` + the shared scroll phase;
  `/privacy-audit` PASS (TC-M-PRIV) is the ship-blocker, reinforced by the pure-view static cases
  (TC-403/TC-404/TC-410). A fail blocks ship regardless of every other pass.
- No AC was left without a **meaningful** case — every functional AC has at least one deterministic case;
  the only clauses without a fully automated case (on-device fps, "F1-like but calm" feel, real-OS PiP
  visual, privacy audit) are explicitly captured in the manual checklist with the
  journey-scene-v2 / journey-pov deferral precedent, not silently dropped.
