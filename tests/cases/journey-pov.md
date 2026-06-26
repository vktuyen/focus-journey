# Test cases: journey-pov

Spec: [specs/journey-pov/spec.md](../../specs/journey-pov/spec.md) — **approved (2026-06-25)** — 17 ACs (AC-1..AC-17) + 3 NFRs (NFR-1..NFR-3).
Carved from: [specs/journey-scene-v2/spec.md](../../specs/journey-scene-v2/spec.md) (request #2) — shares the **same** `JourneyGame` instance + the mini-window PiP (ADR-0003). The pure-view invariant, reduce-motion handling, idle/paused parks, and graceful-degradation placeholder pattern are **inherited** and regression-guarded here. Existing cases: [tests/cases/journey-scene-v2.md](journey-scene-v2.md).
Resolved decisions driving these cases: spec `## Resolved decisions` — (1) cockpit = FOREGROUND overlay over the existing road scene, not a 3D camera; (2) car + motorbike ONLY; (3) stylized-flat, license-clean (CC BY 3.0 glyphs + original flat shapes; CC0 fallback wheel), attributed in CREDITS; (4) no rider hands in v1; (5) cosmetic single-speed pure-view, flows to the PiP for free; plus AC-2's "static decorative glyphs (may key off `moving`)" and AC-5's "≈30–40% of viewport height" resolutions.
Manual companion: [journey-pov-manual-checklist.md](journey-pov-manual-checklist.md) — the real-OS PiP confirmation, on-device fps, the stylized-flat art-cohesion review gate, and the `/privacy-audit` release gate that are not cheaply automatable.

## Coverage note (which layers cover which ACs; risky / under-covered areas)

- **Deterministic widget / golden tests (`src/focus_journey/test/`)** cover the bulk: the cockpit-active
  seam being true for `car`/`motorbike` plus the cockpit asset paths being requested (AC-1, AC-3), the
  gauges/glyphs not being wired to any numeric speed/fuel input (AC-2 — there is no such input on the
  scene, asserted structurally), no rider-hand asset loaded (AC-4), the framing ratio measuring the
  cockpit foreground at ≈30–40% of viewport height with the road readable above it (AC-5), mode-gating so
  walk/run/bicycle/ship draw the side-view sprite and **no** cockpit (AC-6), clean revert + restore across
  `applyState` mode switches (AC-7, AC-8), the cosmetic-only engine byte-for-byte equality (AC-10 runtime
  leg), missing-cockpit-asset → placeholder via `failedAssetPaths`/`hasPlaceholderAssets` never crashing
  (AC-13), reduce-motion adding no new motion + first-frame parked + idle/paused parks preserved
  (AC-14, AC-15), and the cockpit-asset⇄CREDITS manifest cross-check (AC-17). Companion **golden** tests
  pin the car cockpit frame, the motorbike cockpit frame, and the reduce-motion / parked cockpit frame.
- **Integration tests (`src/focus_journey/integration_test/`)** cover the shared-game wiring so the cockpit
  appears on **both** surfaces scaled per the AC-5 ratio (AC-11) and a headline mock-driven smoke
  (car↔motorbike↔walk across both surfaces — AC-1/AC-3/AC-6/AC-7/AC-8). The PiP frameless/always-on-top +
  occlusion-pause-unbroken **logic** leg (AC-12) rides the injected-visibility seam inherited from
  journey-scene-v2; its real-OS leg is a manual carry.
- **Static inspection** (grep / source review) covers the AC-9 separation invariant (scene + siblings
  import only `dart:*`, `package:flame/*`, `TravelMode`), the AC-10 dependency direction (engine holds no
  cockpit/mode-render reference), the AC-17 "no cockpit asset loaded that is absent from CREDITS", and the
  NFR-1 "no per-frame allocation / no new per-frame geometry for the cockpit" hot-path guard.
- **Manual / on-device + review checklist** covers what is **NOT cheaply automatable**, flagged `[REAL-OS]`
  / `[DEVICE]` / `[REVIEW]` / `[AUDIT]`: real-OS PiP confirmation that the cockpit is correct + does not
  break frameless/always-on-top/occlusion-pause on a live window (AC-12 real leg), sustained **≥30fps on
  both surfaces** with both cockpits loaded (NFR-1 device leg), the **stylized-flat art-cohesion** human
  judgement (AC-16) + the distinct car-vs-motorbike silhouette / not-colour-alone accessibility read
  (NFR-3 visual leg), and the `/privacy-audit` PASS release gate (NFR-2).

**Risky / under-covered areas (flagged):**

- **AC-2 "gauges are decorative" is proven structurally, not visually.** Automation proves the scene
  exposes **no** numeric speed/fuel/distance input the gauges could read (the only driven values are
  `moving`/`mode`/`reduceMotion`/`timeOfDayHours`) and that no cockpit element binds to a continuous
  readout — but "the needle does not display a real number" as a *visual* fact is pinned only by the
  golden (TC-202) + the art review. If a reviewer adjusts AC-2 toward a "subtle needle hint off the
  `moving` flag", the case asserts it reads **only** `moving` (the same binary the scene already has),
  never a continuous speed/fuel value.
- **AC-5 framing ratio is a numeric proxy for "the road is readable".** The automated bound asserts the
  cockpit foreground occupies ≈30–40% of viewport height and that the upper viewport (road/horizon) is
  unobscured and still scrolls; "the road actually reads clearly through the windshield / over the
  handlebars" as a perceptual fact is the manual review (TC-M4-ART) + the goldens. The exact pinned ratio
  is set by flame-game-developer in build (spec AC-5); if it is retuned, TC-205's band must be re-pinned.
- **AC-12 PiP behaviour — automation proves only the logic against an injected visibility signal.** That a
  real frameless always-on-top PiP renders the cockpit correctly and still pauses on real OS occlusion is
  the manual `[REAL-OS]` TC-M-PIP. The headless leg proves the cockpit adds no per-frame work that would
  defeat the inherited pause-when-hidden guarantee, reusing journey-scene-v2's per-surface seam.
- **AC-16 stylized-flat cohesion is a REVIEW gate, not a pass/fail assert.** Automation proves the cockpit
  assets are present, CREDITS-recorded, and render; "reads as the same flat/illustrated family as the
  Kenney scene, not a photoreal outlier, recoloured to the palette" is the human review gate TC-M4-ART.
- **NFR-1 (≥30fps both surfaces) is on-device only.** The deterministic proxy is the AC/NFR-1 static guard
  (no per-frame allocation, no new per-frame geometry for the static cockpit foreground) plus the inherited
  journey-view/journey-scene-v2 bounded-pool guards re-run with the cockpit loaded; sustained frame rate is
  the device leg TC-M-NF1.
- **NFR-2 (privacy) is an AUDIT ship-blocker.** The cockpit adds only static image assets and reads no OS
  signal; `/privacy-audit` PASS (TC-M-PRIV) gates ship, reinforced by the AC-9 separation + AC-10
  dependency-direction static cases. A fail blocks ship regardless of every other pass.

## Conventions used by these cases

- **No real OS, no real timers, no wall-clock waits.** As in `journey-view` / `journey-scene-v2`, the scene
  is driven exclusively through the public `applyState({moving, mode, reduceMotion, timeOfDayHours})`
  contract with plain values; frame advancement is explicit (`game.update(dt)` / `pump(duration)`), never
  by awaiting real time. The scene reads **no** Bloc/engine/OS — `mode` is the only thing the cockpit keys
  off.
- **"Cockpit-active seam."** The cockpit is considered **active** for a frame when (a) `currentMode` is
  `TravelMode.car` or `TravelMode.motorbike`, and (b) the corresponding cockpit asset paths are among the
  paths the scene requests/loads (and, where the build exposes it, a dedicated read-only seam — mirroring
  the existing `currentMode` / `currentVehicleAsset` seams — reports cockpit-active true). For
  walk/run/bicycle/ship the seam is **false** and `currentVehicleAsset` resolves to that mode's side-view
  sprite (per AC-6). Tests assert against this seam, not against pixels, except in the goldens.
- **"Cockpit asset paths."** The car cockpit (dashboard + steering wheel + speedometer + fuel glyphs +
  A-pillar/mirror) and the motorbike cockpit (handlebar + grips + gauge pod + fuel tank) are declared in
  the scene's asset manifest (`JourneyAssets.all`, mirroring how the vehicle skins + scenery are listed)
  so the AC-17 CREDITS cross-check and the AC-4 "no rider-hand asset" check are mechanical. The scene loads
  **nothing** absent from that manifest (inherited rule).
- **"Engine counters byte-for-byte unchanged" (AC-10).** For a fixed injected elapsed time and identical
  mock activity input, the engine's exposed `distanceKm` / progress / elapsed values are **exactly
  identical** whether the scene renders a cockpit (`car`/`motorbike`) or the no-cockpit baseline
  (e.g. `walk`) for the same inputs — compared with **exact equality**, not ±epsilon (engine truth, not
  rendered floats). The cockpit reads no OS signal, decides no active-vs-idle, accrues no distance.
- **"Framing ratio" (AC-5).** The cockpit foreground's top edge sits so the cockpit occupies the **lower**
  portion of the viewport — target **≈30–40% of viewport height** — leaving the upper ~60–70% (road +
  horizon) unobscured and still scrolling. Measured against the viewport `size.y`; the same ratio applies
  **proportionally** at the sized-down PiP. The exact pinned value is set in build (spec AC-5); the
  automated band accepts **30%..40%** unless re-pinned.
- **"No new motion" (AC-14 / NFR-1).** Across consecutive `update(dt)` pumps with the cockpit active, the
  cockpit foreground geometry is **static** — it contributes **no** per-frame scroll/animation/allocation
  of its own (the road below may scroll per the existing rules; the cockpit overlay does not move). A
  cockpit-active frame under reduce-motion shows the same suppressed-scroll presentation as without the
  cockpit.
- **"Clean revert" (AC-7).** After `applyState` is called with a non-cockpit mode, the cockpit-active seam
  is **false**, no cockpit asset path is among the requested paths for that frame, and the side-view sprite
  for the new mode is shown — **no** residual cockpit layer / leftover cockpit pixels (golden-pinned).
- **Float tolerance.** Rendered positions/ratios compare within **±1e-6** logical px / fraction unless a
  band is stated (AC-5 uses the 30%..40% band); engine counters use **exact** equality.
- **Test layer per `docs/architecture/overview.md`.** Executable tests live under `src/focus_journey/`:
  cockpit-active / gauges-not-data-driven / framing-ratio / mode-gating / revert-restore / reduce-motion /
  parks / placeholder behaviour + goldens → **widget/golden** (`test/`); shared-game both-surfaces wiring +
  headline smoke → **integration** (`integration_test/`); the separation invariant, dependency direction,
  asset⇄CREDITS, and NFR-1 hot-path guard → **static inspection**; the real-OS PiP, on-device fps, art
  cohesion, and `/privacy-audit` legs → manual. `tests/cases/` (this file) holds human-readable scenarios.

## Cases

### Case: Car cockpit foreground renders over the road for mode == car
**ID:** TC-201
**Priority:** P0
**Type:** happy-path
**Covers:** AC-1

Given the scene has received state via `applyState` with `mode == TravelMode.car` (`currentMode == TravelMode.car`), visible, the cockpit assets loaded
When the scene renders one frame
Then the cockpit-active seam is **true**, the car cockpit asset paths (dashboard + steering wheel + speedometer + fuel glyphs + A-pillar/mirror) are among the paths the scene requests, the cockpit is composited as a **foreground** over the road, and the upper viewport (road + Vietnam scenery + horizon) is **not fully occluded** — it remains visible and still scrolls per the existing scene rules

**Notes:** Widget test (`src/focus_journey/test/`) asserting cockpit-active true for `car` + the car cockpit asset paths requested + the upper-viewport scroll still advancing across pumps (road readable). Companion golden TC-211 pins the frame. Pure deterministic playback; no device.

---

### Case: Car gauges are decorative — not wired to speed / distance / fuel
**ID:** TC-202
**Priority:** P0
**Type:** edge
**Covers:** AC-2

Given the car cockpit is rendered
When the speedometer and fuel glyphs are inspected against the scene's inputs
Then they are **decorative** — they are NOT wired to engine speed, distance, fuel, or any per-mode value (the scene exposes no such input; the only driven values are `moving` / `mode` / `reduceMotion` / `timeOfDayHours`), and they display **no** numeric / continuous speed-or-fuel readout. At most a gauge may key off the existing **`moving`** flag for a parked-vs-running pose (the same binary the scene already has)

**Notes:** Widget + static test. Structural half: assert no cockpit element binds to a continuous numeric input (there is none on the scene) — drive `applyState` with wildly different inputs and assert the gauge geometry does not vary with anything other than the `moving` flag. Visual half (no real number displayed) is pinned by golden TC-211 + the art review TC-M4-ART. If AC-2 is adjusted toward a subtle needle hint, the case still asserts it reads **only** `moving`, never a continuous value.

---

### Case: Motorbike cockpit foreground renders "over the handlebars" for mode == motorbike
**ID:** TC-203
**Priority:** P0
**Type:** happy-path
**Covers:** AC-3

Given the scene has received state with `mode == TravelMode.motorbike` (`currentMode == TravelMode.motorbike`), visible, the cockpit assets loaded
When the scene renders one frame
Then the cockpit-active seam is **true**, the motorbike cockpit asset paths (handlebar + grips + gauge pod + fuel tank) are among the requested paths, the cockpit is composited as a **foreground** over the road so the road reads as seen **over the handlebars**, and the road/horizon remain visible above the handlebar (not fully occluded) and still scroll

**Notes:** Widget test mirroring TC-201 for `motorbike`. Assert cockpit-active true + motorbike cockpit asset paths requested + upper-viewport scroll still advances. Companion golden TC-212. The motorbike silhouette must be **distinct** from the car (NFR-3) — the silhouette-distinctness read is TC-M4-ART.

---

### Case: No rider hands / gloves are drawn in v1 (either cockpit)
**ID:** TC-204
**Priority:** P1
**Type:** edge
**Covers:** AC-4

Given the car cockpit renders (and, in a sibling run, the motorbike cockpit)
When the cockpit's loaded/requested asset set is inspected
Then **no** rider-hand / glove asset is loaded or drawn (omitted in v1 per Resolved decision 4) — the cockpit asset manifest contains no hand/glove path, and the cockpit reads as first-person without them

**Notes:** Static + widget test: enumerate the cockpit asset paths in `JourneyAssets.all`; assert none is a hand/glove asset, and the rendered cockpit composites only the dash/wheel/gauge (car) or handlebar/grips/pod/tank (motorbike) layers. The "still reads as first-person without hands" judgement is part of the art review TC-M4-ART.

---

### Case: Framing ratio — cockpit occupies ≈30–40% of the lower viewport, road readable above
**ID:** TC-205
**Priority:** P0
**Type:** edge
**Covers:** AC-5

Given a cockpit renders at the full-window size (`car` or `motorbike`, visible)
When the cockpit foreground's vertical extent is measured against the viewport height (`size.y`)
Then the cockpit foreground occupies the **lower portion** — its height is within the agreed band **30%..40% of the viewport height** (target ≈30–40% per AC-5) — and the upper ~60–70% (road + horizon) is left **unobscured and clearly visible** above it (and still scrolls per the existing rules)

**Notes:** Widget test measuring the cockpit foreground's top-edge / occupied fraction against `size.y`, asserting the 30%..40% band + that the upper viewport is unobscured (road centre-line / scroll still sampled there). Run for both cockpit modes. The exact pinned ratio is flame-game-developer's build decision (AC-5) — re-pin the band if retuned. The perceptual "road reads clearly through the windshield" leg is TC-M4-ART. PiP-proportional ratio is TC-209.

---

### Case: Mode-gating — walk / run / bicycle / ship show the side-view sprite and NO cockpit
**ID:** TC-206
**Priority:** P0
**Type:** happy-path
**Covers:** AC-6

Given the scene receives `mode` in {`walk`, `run`, `bicycle`, `ship`} (one per sibling run) via `applyState`
When it renders
Then **no cockpit foreground** is drawn (cockpit-active seam **false**, no cockpit asset path requested) and the current **side-view vehicle sprite** for that mode is shown unchanged — `currentVehicleAsset` resolves to that mode's existing sprite path (`vehicles/walk.png` / `run.png` / `bicycle.png` / `ship.png`), exactly as the shipped scene behaves

**Notes:** Widget test parameterised over the four non-cockpit modes. Assert cockpit-active false + no cockpit asset path requested + `currentVehicleAsset` equals the expected side-view sprite for each. Guards the gating boundary (only car + motorbike are special). Pairs with TC-201/TC-203 (the two that DO show a cockpit).

---

### Case: Clean revert — switching from a cockpit mode to a non-cockpit mode fully removes the cockpit
**ID:** TC-207
**Priority:** P0
**Type:** edge
**Covers:** AC-7

Given the scene is rendering a cockpit (`applyState` with `car`, then a sibling run with `motorbike`)
When `applyState` is next called with a non-cockpit mode (e.g. `walk`)
Then the cockpit foreground is **fully removed** — the cockpit-active seam is **false**, no cockpit asset path is among the requested paths for the new frame, there are **no leftover cockpit pixels / no residual cockpit layer**, and the side-view sprite for the new mode (`vehicles/walk.png`) is shown

**Notes:** Widget test: drive `car` → render → `walk` → render; assert cockpit-active flips to false, no cockpit path requested, `currentVehicleAsset == vehicles/walk.png`. Golden TC-213 pins "no residual cockpit pixels after revert". Repeat from `motorbike`. Covers Resolved decision / Open question "non-car/bike modes mid-session".

---

### Case: Restore — switching back to car / motorbike restores the cockpit cleanly
**ID:** TC-208
**Priority:** P0
**Type:** edge
**Covers:** AC-8

Given the cockpit was reverted by a switch to a non-cockpit mode (e.g. `walk`, cockpit-active false)
When `applyState` is later called again with `car` (and, in a sibling run, `motorbike`)
Then the corresponding cockpit foreground is **restored cleanly** — the cockpit-active seam is **true** again, the correct cockpit asset paths are requested, matching TC-201 / TC-203 — with no leftover state from the intervening non-cockpit mode

**Notes:** Widget test: `car` → `walk` → `car` (and `motorbike` → `ship` → `motorbike`); assert cockpit-active true again with the correct mode's cockpit paths and no carry-over. Pairs with TC-207 (the revert half). Confirms the round-trip is idempotent.

---

### Case: Cockpit appears on BOTH surfaces (full window + PiP) via the shared JourneyGame, scaled
**ID:** TC-209
**Priority:** P0
**Type:** happy-path
**Covers:** AC-11

Given the full window and the always-on-top mini-window PiP render the **same** `JourneyGame` instance (ADR-0003), with `mode` == `car` (and, in a sibling run, `motorbike`)
When each surface renders
Then the cockpit appears on **both** surfaces, correctly **scaled** at the sized-down PiP (the cockpit occupies the same ≈30–40% lower-viewport fraction proportionally at the PiP size per AC-5), with the road still readable through/over it at the PiP size

**Notes:** Integration test (`src/focus_journey/integration_test/`) against the shared-game per-surface wiring; render the cockpit at the full size and at the sized-down PiP size and assert the cockpit-active seam true on both + the cockpit fraction is within the AC-5 band relative to **each** surface's height (proportional, not fixed px). The real-OS "cockpit looks right in a live PiP" leg is TC-M-PIP.

---

### Case: PiP behaviour unbroken — cockpit adds no per-frame work, occlusion-pause still holds (logic)
**ID:** TC-210
**Priority:** P1
**Type:** regression
**Covers:** AC-12, NFR-1

Given the cockpit renders in the PiP surface (`car`/`motorbike`) with the injected per-surface visibility signal (inherited from journey-scene-v2) set to "not visible"
When the scene is advanced by several `update(dt)` pumps
Then the PiP **pauses** as before — its scroll offset is frozen and **no per-frame work runs** for that surface — i.e. the static cockpit foreground adds **no** per-frame work that would defeat the pause-when-hidden battery guarantee; and with the injected signal "visible" the cockpit renders without introducing any new per-frame animation of its own

**Notes:** Integration/widget test reusing the journey-scene-v2 injected-visibility + no-tick seam: assert frozen offset + suspended per-frame work when not-visible **with the cockpit active**, and no cockpit-driven per-frame motion when visible. This is the *logic* leg; the real-OS "frameless/always-on-top + real occlusion still pause" leg is TC-M-PIP. Guards that adding the cockpit does not silently revert the inherited battery promise.

---

### Case: Golden — car cockpit frame (dashboard + wheel + decorative gauges + framing) is visually stable
**ID:** TC-211
**Priority:** P1
**Type:** regression
**Covers:** AC-1, AC-2, AC-5, AC-4

Given `mode == TravelMode.car`, a fixed injected day-time clock, a fixed scroll phase, `moving == true`, visible, reduce-motion OFF, the cockpit assets loaded
When the scene renders one frame
Then it matches the committed "car cockpit" golden image — dashboard + steering wheel + decorative speedometer/fuel glyphs (no numeric readout) + A-pillar/mirror framing in the lower ≈30–40%, road + scenery visible above, and **no** rider hands

**Notes:** Golden test (`src/focus_journey/test/`). Determinism via fixed clock/mode/phase (as journey-scene-v2 TC-012). Pins the framing ratio, decorative-gauge look, and no-hands fact visually. Does **not** prove "reads as cohesive stylized-flat" — that is the review gate TC-M4-ART.

---

### Case: Golden — motorbike cockpit frame (handlebar + grips + gauge pod + tank) is visually stable
**ID:** TC-212
**Priority:** P1
**Type:** regression
**Covers:** AC-3, AC-5, AC-4

Given `mode == TravelMode.motorbike`, a fixed injected day-time clock, a fixed scroll phase, `moving == true`, visible, reduce-motion OFF, the cockpit assets loaded
When the scene renders one frame
Then it matches the committed "motorbike cockpit" golden image — handlebar + grips + gauge pod + fuel tank in the lower ≈30–40% "over the handlebars", road + scenery visible above, **no** rider hands, and a silhouette **distinct** from the car cockpit

**Notes:** Golden test. Pins the over-the-handlebars framing, the distinct-from-car silhouette (supporting NFR-3 "not colour alone"), and no-hands. Qualitative cohesion + silhouette-distinctness read is TC-M4-ART.

---

### Case: Golden — clean revert leaves NO residual cockpit pixels after switching to a non-cockpit mode
**ID:** TC-213
**Priority:** P1
**Type:** regression
**Covers:** AC-7

Given the scene rendered a `car` cockpit, then `applyState` is called with `walk`, fixed clock/phase, visible
When the scene renders the post-switch frame
Then it matches the committed "walk side-view, no cockpit" golden — identical to the shipped no-cockpit scene for `walk`, with **no** leftover cockpit pixels / residual cockpit layer

**Notes:** Golden test pinning AC-7's "no residual cockpit pixels". The post-revert frame should be byte-identical to the existing shipped `walk` scene golden (a cockpit switch must leave no trace). Pairs with TC-207's seam-level assertion.

---

### Case: Separation invariant — scene + siblings import only dart:*, package:flame/*, TravelMode
**ID:** TC-214
**Priority:** P0
**Type:** regression
**Covers:** AC-9

Given the cockpit is added to the Flame scene (`journey_game.dart` + its presentation/game siblings, including any new cockpit-painter/asset source)
When the scene's source and its siblings are inspected statically (imports + references)
Then they import **only** `dart:*`, `package:flame/*`, and the pure-Dart domain `TravelMode` — **no** `flutter_bloc`, `JourneyEngine`, `ActivityPlugin`, `MethodChannel` / platform channel, or any OS idle/lock/screen/location read (the only Flutter surface remains the asset bundle/manifest used by `JourneySprites`), and the cockpit is driven solely by `applyState` values (it keys off `mode`)

**Notes:** Static-inspection case (grep / import scan / dependency-direction) over `lib/features/journey/presentation/game/*.dart`, mirroring journey-scene-v2 TC-003 + the file's own SEPARATION INVARIANT docstring. Re-run on any new cockpit source file. Reinforces NFR-2.

---

### Case: Cosmetic-only — engine distanceKm / progress / elapsed byte-for-byte unchanged from the no-cockpit baseline
**ID:** TC-215
**Priority:** P0
**Type:** edge
**Covers:** AC-10

Given identical mock activity input and a fixed injected elapsed time, run once with the scene rendering a cockpit (`mode == car`) and once with the no-cockpit baseline (`mode == walk`)
When the engine's exposed `distanceKm` / progress / elapsed counters are read at the same elapsed points in both runs
Then the engine counters are **exactly identical** between the two runs — rendering a cockpit perturbs **no** engine number; the cockpit reads no OS signal, decides no active-vs-idle, and accrues no distance (cosmetic, single-speed, pure-view)

**Notes:** Widget/integration test asserting **exact equality** (not ±epsilon) of engine `distanceKm`/progress/elapsed across the cockpit vs no-cockpit runs for the same injected elapsed. The runtime half of AC-10; the static half (engine holds no cockpit/mode-render reference) is folded into TC-214's dependency-direction inspection. Drives state via `applyState`; advances frames via the harness.

---

### Case: Cockpit asset failure is non-fatal — placeholder drawn, failed path surfaced, no crash
**ID:** TC-216
**Priority:** P0
**Type:** negative
**Covers:** AC-13

Given a cockpit asset (e.g. the steering-wheel glyph or a dash shape) is absent from the bundle or faults while decoding, `mode == car` (and a sibling run `motorbike`)
When the scene loads via the existing `loadAll` never-throws pattern and renders
Then a neutral **placeholder** is drawn in that element's place, the failed path is surfaced through `failedAssetPaths` and `hasPlaceholderAssets == true`, and the scene **never crashes or blanks** (the rest of the cockpit + the road still render)

**Notes:** Widget test injecting a missing/faulting cockpit asset path (mirror journey-view/journey-scene-v2 TC-014). Assert `failedAssetPaths` contains the missing cockpit path, `hasPlaceholderAssets` true, no exception thrown, and the frame still renders the road + remaining cockpit layers. Confirms the cockpit reuses the shipped graceful-degradation seam.

---

### Case: Reduce-motion — cockpit introduces no new motion; existing reduce-motion presentation unchanged
**ID:** TC-217
**Priority:** P0
**Type:** edge
**Covers:** AC-14, NFR-3

Given a cockpit renders (`car`/`motorbike`) and reduce-motion is ON (`applyState(..., reduceMotion: true)`, `reduceMotion == true`)
When the scene is advanced by several `update(dt)` pumps
Then the cockpit foreground is **static** — it introduces **no new motion** across pumps (its geometry is frozen frame-over-frame) — and the existing reduce-motion presentation (suppressed scroll, state still conveyed via the parked-vs-running pose + overlay handled by the wrapper) is **unchanged** by adding the cockpit (the cockpit overlays it without re-introducing scroll)

**Notes:** Widget test with reduce-motion true + cockpit active. Assert (a) the cockpit foreground does not move across pumps, (b) the inherited reduce-motion suppressed-scroll behaviour is identical with vs without the cockpit, (c) state is still observable. Companion golden TC-218. Inherits + extends journey-scene-v2 TC-010 with the cockpit overlay. NFR-3 reduce-motion leg.

---

### Case: First-frame parked + idle / paused parks preserved under a cockpit
**ID:** TC-218
**Priority:** P0
**Type:** regression
**Covers:** AC-15

Given the scene before its first `applyState` (`hasReceivedState == false`) and, in sibling runs, an `idle`/`paused` state (`moving == false`) with `mode == car` / `motorbike`
When the scene renders the first frame / settles and is advanced by several `update(dt)` pumps
Then the first-frame parked/stopped default and the idle/paused park behaviour (road + objects stopped, vehicle/cockpit parked, "Paused — idle" overlay shown by the wrapper) are **preserved** — the cockpit overlays them without altering either; the cockpit does **not** force motion when stopped and does **not** obscure the "Paused — idle" overlay

**Notes:** Widget test: (1) render before any `applyState` and assert the parked default + cockpit-active reflects the default mode without forcing motion; (2) `applyState(moving: false, mode: car/motorbike, ...)` and assert road/objects frozen + overlay still visible above/around the cockpit (NFR-3 "does not obscure the overlay"). Companion golden reuses a parked cockpit frame. Regression guard inherited from journey-view/journey-scene-v2 parks; the new clause is the cockpit overlay leaving them intact.

---

### Case: Every cockpit asset path has a CREDITS entry; scene loads no uncredited cockpit asset
**ID:** TC-219
**Priority:** P0
**Type:** regression
**Covers:** AC-17

Given the cockpit ships new assets declared in `JourneyAssets.all`, and `assets/CREDITS.md`
When the set of cockpit asset paths the scene declares/loads is enumerated and cross-checked against `assets/CREDITS.md`
Then **every** new cockpit asset that requires attribution (the CC BY 3.0 glyphs — steering wheel, speedometer, fuel gauge) is listed with its **source + licence**, any CC0 fallback (e.g. the Wikimedia wheel) is recorded as zero-attribution, the **original flat shapes** (dash/handlebar/tank) are recorded as original/own-work, and the scene loads **no** cockpit asset that is **absent** from CREDITS (each requested cockpit path has a matching CREDITS entry)

**Notes:** Static-inspection / manifest test (`src/focus_journey/test/`) mirroring journey-view TC-011 / journey-scene-v2 TC-009: enumerate the cockpit paths in `JourneyAssets.all`, parse `assets/CREDITS.md`, assert each has a matching entry with source + licence and that no uncredited cockpit path is loadable. CC BY 3.0 requires the attribution be **present** (stronger than the CC0 scenery). Re-run whenever a cockpit asset is added. The licence-correctness + "actually license-clean" judgement is reinforced by TC-M-PRIV / curator provenance.

---

### Case: NFR-1 hot-path guard — cockpit adds no per-frame allocation / no new per-frame geometry
**ID:** TC-220
**Priority:** P1
**Type:** regression
**Covers:** NFR-1

Given both cockpits' assets are loaded and a cockpit is active (`car`/`motorbike`)
When the scene's render/update hot path is inspected (static) and exercised across many `update(dt)` pumps
Then the cockpit foreground is a **static composited layer** that adds **no per-frame allocation** and **no new per-frame geometry computation** of its own — it does not allocate per frame, does not recompute cockpit geometry per frame, and does not add work to the bounded side-object/scroll hot path (the inherited bounded-pool / no-alloc guards still hold with the cockpit loaded)

**Notes:** Static inspection + the inherited journey-view/journey-scene-v2 bounded-pool / no-per-frame-allocation widget guards re-run with the cockpit loaded. Deterministic proxy for NFR-1; sustained ≥30fps on-device is the device leg TC-M-NF1. Guards that the cockpit does not introduce a hidden per-frame cost.

---

### Case: End-to-end smoke — mock-driven cockpit on both surfaces; car↔motorbike↔walk gating, clean revert/restore
**ID:** TC-221
**Priority:** P1
**Type:** regression
**Covers:** AC-1, AC-3, AC-6, AC-7, AC-8, AC-11

Given the app launched with the mock activity + mock window/visibility path, the shared `JourneyGame` rendering on both surfaces
When the mock drives `mode = car` (cockpit appears on both surfaces), then `motorbike` (motorbike cockpit on both), then `walk` (cockpit removed, side-view sprite, no residual), then back to `car` (cockpit restored)
Then across the flow the correct cockpit appears on **both** surfaces for car/motorbike (scaled at the PiP), no cockpit appears for walk (side-view sprite shown), the revert leaves no residual cockpit, and the restore is clean — confirming the full `applyState`↔mode↔cockpit wiring on the shared game

**Notes:** `integration_test` (`src/focus_journey/integration_test/`) on the real widget tree with the **mock** activity + window/visibility path (deterministic, no real OS). The mock-path twin of the manual real-OS PiP leg. Drives mode via the mock; frames via the harness. Per-surface scaling detail is TC-209.

---

## Manual / on-device + review legs (see the companion checklist)

These verify what is **NOT cheaply automatable**. They live in
[journey-pov-manual-checklist.md](journey-pov-manual-checklist.md) and are flagged here.

- **TC-M-PIP** `[REAL-OS]` — on a **real** frameless always-on-top PiP, the cockpit renders correctly
  (scaled, road readable) and does **not** break the PiP's frameless/always-on-top behaviour nor its
  occlusion/visibility pause (AC-11/AC-12 real leg). Automated logic legs: TC-209/TC-210/TC-221.
- **TC-M4-ART** `[REVIEW]` — stylized-flat art-cohesion + accessibility read: the cockpit reads as the same
  **flat/illustrated** family as the Kenney scene (recoloured to the palette), **not** a photoreal outlier;
  gauges read as **decorative** (no numeric speed/fuel); **no** rider hands; the car-vs-motorbike
  **silhouette is distinct** (not colour-alone); the road reads clearly through the windshield / over the
  handlebars and the "Paused — idle" overlay is not obscured (AC-16 gate + AC-2/AC-4/AC-5 visual legs +
  NFR-3 visual leg).
- **TC-M-NF1** `[DEVICE]` — sustained **≥30fps on both surfaces** (full window + sized-down PiP) with both
  cockpits loaded while `active` (NFR-1). Automated proxy: TC-220 + inherited hot-path guards.
- **TC-M-PRIV** `[AUDIT]` — `/privacy-audit` PASS: the cockpit adds **no** new OS signal / input / screen /
  location read, only static image assets (NFR-2). **Ship-blocker.** Reinforced by TC-214/TC-215.

---

## Coverage table (AC / NFR → covering case IDs)

| Item | Description | Covered by |
|---|---|---|
| AC-1 | car cockpit foreground renders over the road; road readable above | TC-201, TC-211, TC-221 |
| AC-2 | car gauges decorative — not wired to speed/distance/fuel | TC-202, TC-211; **[REVIEW]** TC-M4-ART |
| AC-3 | motorbike cockpit renders "over the handlebars" | TC-203, TC-212, TC-221 |
| AC-4 | no rider hands in v1 (either cockpit) | TC-204, TC-211, TC-212; **[REVIEW]** TC-M4-ART |
| AC-5 | framing ratio ≈30–40% lower viewport, road readable above | TC-205, TC-211, TC-212; **[REVIEW]** TC-M4-ART |
| AC-6 | only car + motorbike show a cockpit; others keep side-view sprite | TC-206, TC-221 |
| AC-7 | clean revert on mode-switch away — no residual cockpit | TC-207, TC-213, TC-221 |
| AC-8 | restore on mode-switch back to car/motorbike | TC-208, TC-221 |
| AC-9 | separation invariant — only dart:*, flame/*, TravelMode | TC-214 |
| AC-10 | cosmetic-only — engine counters byte-for-byte unchanged | TC-215 (+ static via TC-214) |
| AC-11 | cockpit on both surfaces via shared game, scaled at PiP | TC-209, TC-221; **[REAL-OS]** TC-M-PIP |
| AC-12 | PiP frameless/always-on-top + occlusion-pause unbroken | TC-210; **[REAL-OS]** TC-M-PIP |
| AC-13 | cockpit asset failure non-fatal — placeholder, surfaced, no crash | TC-216 |
| AC-14 | no new motion + reduce-motion honoured | TC-217 |
| AC-15 | first-frame parked + idle/paused parks preserved under cockpit | TC-218 |
| AC-16 | cohesive stylized-flat art (review gate) | **[REVIEW]** TC-M4-ART (assets present/render: TC-211/TC-212/TC-219) |
| AC-17 | every CC BY cockpit asset attributed; none uncredited loaded | TC-219 |
| NFR-1 | ≥30fps both surfaces; no per-frame alloc/geometry for cockpit | TC-220, TC-210; **[DEVICE]** TC-M-NF1 |
| NFR-2 | pure-view; no new OS signal; /privacy-audit PASS | **[AUDIT]** TC-M-PRIV (reinforced by TC-214, TC-215) |
| NFR-3 | reduce-motion honoured; distinct silhouette not colour-alone; no focus trap / overlay obscured | TC-217, TC-218, TC-212; **[REVIEW]** TC-M4-ART |

Every AC (AC-1..AC-17) and every NFR (NFR-1..NFR-3) maps to at least one case. No AC/NFR is orphaned.

### Coverage notes / flagged gaps

- **AC-2 is proven structurally + by golden, not by reading a needle.** Automation proves the scene has no
  numeric speed/fuel/distance input the gauges could bind to and the gauge geometry varies with nothing
  beyond the `moving` flag (TC-202); the "no number displayed" visual fact is the golden (TC-211) + the
  review (TC-M4-ART).
- **AC-5/AC-16 — numeric proxy + a review gate.** Automation proves the cockpit occupies ≈30–40% with the
  road unobscured (TC-205) and the cockpit assets render + are credited (TC-211/TC-212/TC-219); "reads as
  cohesive stylized-flat, road reads clearly through the windshield" is the **review gate** TC-M4-ART.
- **AC-11/AC-12 — automation proves the logic against an injected visibility signal.** The cockpit appears
  on both surfaces scaled (TC-209) and adds no per-frame work that defeats the inherited pause (TC-210);
  the real frameless always-on-top PiP + real OS occlusion leg is the manual **[REAL-OS]** TC-M-PIP,
  consistent with the journey-scene-v2 / mini-window precedent.
- **NFR-1 (≥30fps both surfaces) — DEVICE only.** TC-220 + the inherited bounded-pool / no-alloc guards
  re-run with the cockpit loaded are the deterministic proxy; sustained frame rate is on-device TC-M-NF1.
- **NFR-2 (privacy) — AUDIT gate.** The cockpit adds only static image assets; `/privacy-audit` PASS
  (TC-M-PRIV) is the ship-blocker, reinforced by the AC-9 separation (TC-214) + the AC-10 dependency
  direction (TC-214/TC-215). A fail blocks ship regardless of every other pass.
- No AC was left without a **meaningful** case — every functional AC has at least one deterministic case;
  the only clauses without a fully automated case (real-OS PiP, on-device fps, art cohesion, privacy
  audit) are explicitly captured in the manual checklist with the journey-scene-v2 deferral precedent, not
  silently dropped.
