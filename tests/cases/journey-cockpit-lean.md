# Test cases: journey-cockpit-lean

Spec: [specs/journey-cockpit-lean/spec.md](../../specs/journey-cockpit-lean/spec.md) — **approved (2026-06-25)** — 14 ACs (AC-1..AC-14) + 3 NFRs (NFR-1..NFR-3).
Extends (shipped): [specs/journey-pov/spec.md](../../specs/journey-pov/spec.md) — this slice **rotates the `CockpitPainter` output** journey-pov composites; the pure-view invariant, reduce-motion handling, graceful-degradation placeholder path, and the cockpit-active seam are **inherited** and regression-guarded here. Existing cases: [tests/cases/journey-pov.md](journey-pov.md).
Blocked by (tuned against its final curve): [specs/journey-dynamic-curve/spec.md](../journey-dynamic-curve/spec.md) — the lean signal is sampled from the **shipped** dynamic-curve geometry (`maxHeading 0.0036`, `curveAmplitudeFrac 0.20`); the `lateralSlopeAt` / `centreLineOffsetAt` seams those cases exercise are the lean's only input. Sibling cases: [tests/cases/journey-dynamic-curve.md](journey-dynamic-curve.md).
Related (shipped): [specs/mini-window/spec.md](../mini-window/spec.md) — the always-on-top PiP renders the **same** `JourneyGame` instance (ADR-0003); the lean flows to it for free and the rotated frame must still cover the cockpit band at the sized-down PiP (AC-13).
Manual companion: [journey-cockpit-lean-manual-checklist.md](journey-cockpit-lean-manual-checklist.md) — the human feel / motion-comfort sign-off, the on-device ≥30fps on both surfaces, the real-OS frameless PiP visual, and the `/privacy-audit` release gate that are not cheaply automatable.

## Automation status (test-script-author, 2026-06-25)

TC-501..TC-518 are AUTOMATED (18/18) and green locally (`fvm flutter test`). Files (one TC → its named
group, traceable by TC-id in the test descriptions):

- `src/focus_journey/test/features/journey/presentation/game/journey_cockpit_lean_behaviour_test.dart`
  — TC-501, TC-502, TC-503, TC-504, TC-505, TC-506, TC-507, TC-508, TC-509 (seam leg), TC-513, TC-515.
- `src/focus_journey/test/features/journey/presentation/game/journey_cockpit_lean_golden_test.dart`
  — TC-509 (byte-for-byte non-cockpit leg), TC-510, TC-516 (structural goldens; repo ships no PNG baselines).
- `src/focus_journey/test/features/journey/presentation/game/journey_cockpit_lean_separation_static_test.dart`
  — TC-511, TC-512, TC-517 (static no-alloc/no-loop source leg).
- `src/focus_journey/test/features/journey/presentation/game/journey_cockpit_lean_perf_test.dart`
  — TC-517 (runtime constant-cost / bounded-draw proxy).
- `src/focus_journey/integration_test/journey_cockpit_lean_two_surface_test.dart` — TC-514 (passes on `-d macos`).
- `src/focus_journey/integration_test/journey_cockpit_lean_smoke_test.dart` — TC-518 (passes on `-d macos`).

Re-pinned against the SHIPPED build (noted in-test): TC-508 asserts AC-7 as "near-level at the flattest
reachable frame" + exact-settling determinism, because the shipped `journey-dynamic-curve` geometry has NO
reachable scroll offset with `lateralSlopeAt == 0.0` exactly (the slope passes through zero only at the
fractional offset where `cos(phase)==π/2`, which the discrete scroll never lands on; flattest reachable
`|slope| ≈ 1e-8`). An exact `appliedLeanAngle == 0.0` is therefore only reachable via reduce-motion (TC-507)
and non-cockpit modes (TC-509), both asserted exactly.

Manual carries (NOT automated, in `journey-cockpit-lean-manual-checklist.md`): **TC-M-FEEL** `[VISUAL]`,
**TC-M-PIP** `[REAL-OS]`, **TC-M-NF1** `[DEVICE]`, **TC-M-PRIV** `[AUDIT]`.

## Coverage note (which layers cover which ACs; risky / under-covered areas)

- **Deterministic unit / widget tests (`src/focus_journey/test/.../game/`) over the applied-angle seam** carry
  the bulk. The lean is a pure function of the (smoothed) shared scroll phase with no clock and no `Random`,
  so the headline measurements are exact and stable against a read-only **`appliedLeanAngle`-style seam** (see
  Conventions: the implementer adds it, mirroring how journey-pov exposed `isCockpitActive` and
  journey-dynamic-curve exposed `centreLineOffsetAt` / `liveCentreLinePoints`). These cover: the angle being
  non-zero and **signed into the turn** asserted against `sign(lateralSlopeAt)` / `sign(centreLineOffsetAt(t≈1))`
  (AC-1), monotonic `|angle|` vs `|curveSample|` below saturation and clamped at the ceiling (AC-2, AC-3), the
  per-frame angle delta at the eased cruise `scrollDelta` staying under the smoothness cap with no snap (AC-4),
  replay determinism + no wall-clock/`Random` (AC-5), reduce-motion **hard zero from the first frame**
  including at a sharp-curve offset (AC-6), straight-road settled angle `0.0` (AC-7), and mode-gating so a
  non-zero settled angle only appears when `isCockpitActive` (AC-8).
- **Golden / painter tests (`src/focus_journey/test/`)** pin the **non-cockpit modes byte-for-byte unchanged**
  vs the no-lean baseline (AC-8 visual leg), the **scene renderer output identical to the no-lean baseline at a
  given scroll offset** so only the cockpit carries the transform (AC-9), the rotated **placeholder** frame on
  a faulted asset (AC-14 visual leg), and a leaning car/motorbike cockpit frame at a fixed curving scroll
  offset (regression anchor for AC-1/AC-3/AC-4).
- **Static inspection** (grep / source review) covers: the AC-11 separation invariant (`cockpit_painter.dart` /
  `journey_game.dart` + scene siblings import only `dart:*`, `package:flame/*`, `TravelMode`), the AC-10
  signal-source inspection (the lean's only input is `lateralSlopeAt` / `centreLineOffsetAt` — no Bloc/engine/OS
  read, no second phase), the AC-5 determinism static half (no `DateTime`/`Stopwatch`/`Random`/`Timer`/second
  clock in the lean path), and the NFR-1 hot-path guard (no per-frame allocation in the cockpit compositing
  path; constant per-frame angle-update cost independent of scroll length).
- **Integration tests (`src/focus_journey/integration_test/`)** cover the two-surface read (the lean appears on
  **both** the full window and the sized-down PiP from one shared `JourneyGame`, AC-13) including the rotated
  cockpit frame still fully covering the cockpit band at the PiP across a scroll sweep (no exposed un-painted
  corners), plus a headline mock-driven smoke (bend → lean both surfaces → reduce-motion hard-zero → straight →
  walk no-lean — AC-1/AC-6/AC-7/AC-8/AC-13).
- **Manual / on-device + review checklist** covers what is **NOT cheaply automatable**, flagged `[VISUAL]`
  / `[REAL-OS]` / `[DEVICE]` / `[AUDIT]`: the **motion-comfort + feel** sign-off (the cockpit reads as an
  embodied lean into the turn yet stays a calm companion — no nausea-grade roll — and does not obscure the road
  / "Paused — idle" overlay) (AC-3/AC-4/NFR-3 feel gate — **TC-M-FEEL**), the real-OS frameless always-on-top
  PiP visual that the leaning cockpit still covers the band with no exposed corners (AC-13 real leg —
  **TC-M-PIP**), sustained **≥30fps on both surfaces** with the lean active (NFR-1 device leg — **TC-M-NF1**),
  and the `/privacy-audit` PASS release gate (NFR-2 — **TC-M-PRIV**).

**Risky / under-covered areas (flagged):**

- **HEADLINE — these cases assume a read-only applied-angle seam that does not exist yet.** AC-1/2/3/4/5/6/7/8
  are only cheaply assertable if the build exposes the **deterministic applied roll angle** as a read-only
  seam (a pure function of the smoothed scroll phase), the way journey-pov exposed `isCockpitActive` and
  journey-dynamic-curve exposed `centreLineOffsetAt` / `liveCentreLinePoints` precisely so the invariant could
  genuinely **fail**. The cases below are phrased against that seam (called `appliedLeanAngle` here for
  concreteness — the implementer pins the exact name/signature) **plus** the existing curve seams
  (`lateralSlopeAt` / `centreLineOffsetAt(t)`). Without it, AC-1's sign convention and AC-2's monotonicity can
  only be inferred from goldens (much weaker — a sign flip or a non-monotonic clamp would slip a pixel golden
  far more easily than an exact angle assert). **The implementer must add this seam**; the test-script-author
  asserts against it.
- **AC-1 SIGN CONVENTION is the most failure-prone leg — a sign flip is silent in a golden.** "Leans INTO the
  turn" vs "away from the turn" differ by one minus sign and both produce a tilted cockpit a pixel golden may
  accept. TC-501 asserts `sign(appliedLeanAngle)` **equals the fixed expected function** of
  `sign(lateralSlopeAt(worldDistance))` (and/or `sign(centreLineOffsetAt(t≈1))`) at curving frames — a **left
  bend** must lean into the left turn, a **right bend** into the right — and TC-502 is a dedicated **negative**
  case that FAILS if the sign is flipped. This is the spec's explicit "tilt away from the curve is wrong"
  constraint; treat it as the load-bearing assertion.
- **AC-3 clamp ceiling + AC-4 per-frame cap are NUMERIC PROXIES for "physical but calm".** Automation asserts
  `|appliedLeanAngle| ≤ maxRollCap` (target ≈3° / ~0.05 rad) and `|Δangle/frame| ≤ maxAnglePerFrame` (target
  ≈0.2°/frame / ~0.0035 rad) at the eased cruise `scrollDelta`; "reads as an embodied lean yet never induces
  motion discomfort, comfortable to leave on all session" is the **feel gate TC-M-FEEL**, not a pass/fail
  assert. The exact ceiling + smoothing time-constant are pinned in build by flame-game-developer (spec AC-3 /
  AC-4 proposed resolutions); if retuned, TC-503 / TC-504's bands must be re-pinned. **Open question** — the
  lean signal (slope vs centre-line offset) and the pivot point are flame-game-developer build decisions; the
  cases assert against **whichever signal seam the build threads in** (they take `sign`/magnitude from the
  signal the lean actually consumed, per AC-10) and against the AC-13 "covers the band" outcome regardless of
  pivot.
- **AC-9 "only the cockpit rotates" is proven by a baseline-equality golden + a no-transform inspection.**
  Automation proves the scene renderer's output for a fixed scroll offset is **identical** to the no-lean
  baseline (the scene receives no rotation) and that only the cockpit compositing step carries the transform;
  "the world visibly does not tilt" as a perceptual fact is reinforced by TC-M-FEEL. If the baseline scene
  golden is re-pinned by an upstream art slice, TC-509's reference must be re-pinned with it.
- **AC-13 PiP leg — automation proves the band-coverage geometry, not the live-OS visual.** TC-512 asserts the
  rotated cockpit's painted region still fully covers the cockpit band (no exposed un-painted canvas corners)
  across a scroll sweep at representative PiP + full sizes; that a real frameless always-on-top PiP shows the
  leaning cockpit correctly is the manual `[REAL-OS]` TC-M-PIP, consistent with the journey-pov / mini-window
  precedent.
- **NFR-1 (≥30fps both surfaces) is on-device only.** The deterministic proxies are the constant-per-frame
  angle-update guard (TC-513 — the angle update cost does not grow with how long the session has scrolled) +
  the no-per-frame-allocation static guard re-run with the lean active; sustained frame rate is the device leg
  TC-M-NF1.
- **NFR-2 (privacy) is an AUDIT ship-blocker.** The lean adds no new OS signal — only a canvas transform driven
  by the existing in-scene curve sample; `/privacy-audit` PASS (TC-M-PRIV) gates ship, reinforced by the AC-11
  separation (TC-510) + the AC-10 signal-source inspection (TC-511). A fail blocks ship regardless of every
  other pass.

## Conventions used by these cases

- **No real OS, no real timers, no wall-clock waits.** As in `journey-pov` / `journey-dynamic-curve`, the scene
  is driven exclusively through the public `applyState({required bool moving, required TravelMode mode,
  required bool reduceMotion, double timeOfDayHours})` contract with plain values; frame advancement is explicit
  (`game.update(dt)` / `pump(duration)`) or by stepping `roadScrollOffset`, never by awaiting real time. The
  scene reads **no** Bloc/engine/OS; the lean keys off the in-scene curve sample only.
- **"Applied-angle seam" (`appliedLeanAngle`).** The cases assert against a read-only seam exposing the
  **deterministic applied roll angle** for the current frame — a pure function of the smoothed scroll-phase
  history (no clock, no `Random`), mirroring how the build exposed `isCockpitActive` (journey-pov) and
  `centreLineOffsetAt(t)` / `liveCentreLinePoints` (journey-dynamic-curve) precisely so the invariant can
  genuinely fail. The implementer pins the exact name/signature in build; here it is `appliedLeanAngle` in
  radians, signed. Tests assert against this angle + the curve seams (`lateralSlopeAt(worldDistance)`,
  `centreLineOffsetAt(t≈1)`), not against pixels, except in the goldens.
- **"Curve sample" = the in-scene lean signal.** Everywhere "curve sample" means the **shipped
  `journey-dynamic-curve`** signal the lean consumes — the signed `RoadGeometry.lateralSlopeAt(worldDistance)`
  (`cos(phase)·heading(segment)·maxHeading`) sampled at the camera and/or `JourneyGame.centreLineOffsetAt(t≈1)`
  (`RoadPainter.centreLineOffset(size, roadScrollOffset, t)` at `t≈1`, near camera). The chosen signal + the
  `t` are a flame-game-developer build decision (AC-10 proposed resolution); cases take the `sign` / magnitude
  from **whichever signal the lean actually consumed** so the assertion follows the build, per AC-10.
- **"Signed into the turn" (AC-1).** The expected sign of `appliedLeanAngle` is a **fixed** function of the
  sign of the in-scene curve sample at that frame: a left bend (one sign of `lateralSlopeAt` /
  `centreLineOffset`) rolls the cockpit into the left turn, a right bend into the right. Tests assert
  `sign(appliedLeanAngle) == expectedSign(sign(curveSample))` at curving frames; the negative TC-502 asserts a
  **flipped** convention FAILS.
- **"Settled angle" (AC-7).** Because the lean is low-pass / rate-limited (AC-4), "settled" means the smoothed
  follow has converged — sampled after advancing enough frames at the held scroll phase that the angle stops
  changing (within ±1e-6 frame-to-frame). AC-7's "zero when straight" and AC-8's "non-zero only for cockpit
  modes" are asserted on the **settled** angle so the smoothing transient is not mistaken for a value.
- **"Cruise `scrollDelta`" (AC-4 per-frame cap).** The per-frame angle change is measured by stepping
  `roadScrollOffset` by ONE eased cruise frame's delta — the steady `JourneyGame.cruiseSpeed`
  (`kV2CruiseSpeed`) × a representative `dt` (e.g. 1/60 s) — and asserting `|appliedLeanAngle(off+Δ) −
  appliedLeanAngle(off)| ≤ maxAnglePerFrame` for every `off` across a full scroll sweep, **including** at
  offsets where the raw curve sample jumps sharply (the rate-limit must hold there too). Target cap ≈0.2°/frame
  (~0.0035 rad), pinned in build (spec AC-4).
- **"Clamp ceiling" (AC-3).** `maxRollCap` is the tuned small maximum (target ≈3° / ~0.05 rad, pinned in build,
  spec AC-3). Tests sweep `lateralSlopeAt` / `centreLineOffsetAt` across at least one full heading cycle of the
  **sharpest** shipped curve and assert `|appliedLeanAngle| ≤ maxRollCap` at every frame.
- **"Reduce-motion HARD ZERO" (AC-6).** With `reduceMotion == true` (`applyState(reduceMotion: true)`,
  `JourneyGame.reduceMotion == true`), `appliedLeanAngle == 0.0` **exactly** (not ±epsilon) on **every** frame
  — including the very first frame before any scroll, and at a sharp-curve scroll offset — the cockpit never
  starts tilted (a hard zero, not "frozen at the last value"). Mirrors journey-dynamic-curve AC-10 / journey-pov
  AC-14.
- **"Byte-for-byte unchanged" — two distinct flavours.** (a) **Non-cockpit-mode render** (AC-8) and **scene
  renderer at a fixed scroll offset** (AC-9): the **rendered output** is byte-for-byte identical to the no-lean
  baseline (golden equality). (b) **Engine state** (AC-12): for a fixed injected elapsed time and identical mock
  activity input, the engine's `distanceKm` / progress / elapsed / idle-vs-active values are **exactly
  identical** with vs without the lean — compared with **exact equality**, not ±epsilon (engine truth, not
  rendered floats).
- **"No-lean baseline."** The reference is the scene **as shipped by journey-pov + journey-dynamic-curve with
  the lean disabled** — i.e. `appliedLeanAngle` forced to `0.0` / the rotation transform identity. Where a
  pinned baseline golden is needed (AC-8 non-cockpit modes, AC-9 scene renderer), it is the existing committed
  scene golden for that mode/offset; re-pin if an upstream slice re-pins it.
- **Float tolerance.** Applied angles / rendered offsets compare within **±1e-6** rad / logical px unless a band
  is stated (AC-3 clamp band, AC-4 per-frame cap band, both pinned in build); the reduce-motion hard zero
  (AC-6) and the straight-road zero (AC-7, settled) use **exact** `== 0.0`; engine counters (AC-12) use
  **exact** equality.
- **Test layer per `docs/architecture/overview.md`.** Executable tests live under `src/focus_journey/`:
  applied-angle sign / monotonicity / clamp / per-frame cap / determinism / reduce-motion / straight-road /
  mode-gating → **unit/widget** (`test/.../game/`); non-cockpit-mode + scene-renderer baseline equality +
  rotated placeholder + leaning cockpit anchor → **golden** (`test/`); both-surfaces band-coverage + headline
  smoke → **integration** (`integration_test/`); separation imports / signal-source / single-phase /
  no-per-frame-alloc → **static inspection**; feel/motion-comfort, on-device fps, real-OS PiP, privacy audit →
  manual. `tests/cases/` (this file) holds human-readable scenarios only.

## Cases

### Case: Lean exists and is signed INTO the turn at a curving frame
**ID:** TC-501
**Priority:** P0
**Type:** happy-path
**Covers:** AC-1, AC-10

Given a cockpit mode (`car`; sibling run `motorbike`, `isCockpitActive == true`), reduce-motion OFF, and the scene scrolled to a frame where the road is **bending** (`lateralSlopeAt(worldDistance) != 0` / `centreLineOffsetAt(t≈1) != 0`), the smoothed follow settled
When the applied roll angle is read via the `appliedLeanAngle` seam at a **left-bend** offset and, in a sibling sample, at a **right-bend** offset
Then `appliedLeanAngle` is **non-zero** at each, and its **sign is the fixed expected function of the sign of the in-scene curve sample** — `sign(appliedLeanAngle) == expectedSign(sign(lateralSlopeAt(worldDistance)))` (and/or `sign(centreLineOffsetAt(t≈1))`) — so a left bend rolls the cockpit into the left turn and a right bend into the right; the angle is derived **solely** from that in-scene curve sample (AC-10)

**Notes:** Unit/widget test (`src/focus_journey/test/.../game/`) against `appliedLeanAngle` + the curve seams, no device. Sample at least one left-bend and one right-bend scroll offset of the **shipped** dynamic-curve geometry (`maxHeading 0.0036`, `curveAmplitudeFrac 0.20`). The sign convention itself (into vs away) is fixed in build; this case pins that it tracks the curve sign. Pairs with the negative TC-502 (a flip must fail). Companion golden TC-508 anchors a leaning frame.

---

### Case: A sign flip is caught — leaning AWAY from the turn fails
**ID:** TC-502
**Priority:** P0
**Type:** negative
**Covers:** AC-1

Given the same curving left-bend and right-bend frames as TC-501, and the expected "into the turn" sign convention from the spec ("tilt away from the curve is wrong")
When a hypothetical build negates the applied angle (rolls the cockpit **away** from the turn, i.e. `sign(appliedLeanAngle)` is the **opposite** of the expected function of `sign(curveSample)`)
Then the assertion **FAILS** — TC-501's sign equality does not hold — confirming the sign convention is genuinely checked and a one-minus-sign regression cannot pass silently (the most failure-prone leg, invisible in a pixel golden)

**Notes:** This is the **mutation / guard** companion to TC-501: it documents that TC-501's assertion is `sign(appliedLeanAngle) == expectedSign(...)` (an exact sign match), NOT merely `appliedLeanAngle != 0`, so a flipped sign is a red test, not a green one. The test-script-author may realise this as a fault-injection unit test (force the negated angle through a test seam and assert the sign check fails) or simply as the explicit `==` sign assertion in TC-501 with this case as its rationale. Load-bearing per the spec "tilt away from the curve is wrong" constraint.

---

### Case: Monotonic |angle| vs |curve| below saturation
**ID:** TC-503
**Priority:** P0
**Type:** edge
**Covers:** AC-2

Given a cockpit mode, reduce-motion OFF, and a sequence of curving frames sampled across a scroll sweep, each with the smoothed follow settled, restricted to frames **below** the clamp saturation point
When the settled `appliedLeanAngle` is collected alongside the in-scene `|curveSample|` (`|lateralSlopeAt|` / `|centreLineOffsetAt(t≈1)|`) at each frame and the pairs are ordered by `|curveSample|`
Then `|appliedLeanAngle|` is **monotonic non-decreasing** in `|curveSample|` — for any two below-saturation frames A, B with `|curveSample(B)| > |curveSample(A)|`, `|appliedLeanAngle(B)| >= |appliedLeanAngle(A)|` — a bigger bend produces a bigger (or equal) tilt, never an inversion, until the clamp (TC-504)

**Notes:** Unit/widget test sampling the settled angle across the sweep, filtering to below-saturation frames, asserting monotonicity of `|angle|` vs `|curveSample|`. "Below saturation" = where `|appliedLeanAngle| < maxRollCap − ε` (the unclamped region). Pairs with TC-504 (the clamp ceiling) — together they prove "grows with the bend, up to a bounded max". Sample the settled angle (post-smoothing) so the transient does not corrupt the ordering.

---

### Case: Bounded maximum roll — clamp ceiling at the sharpest bend (motion-sickness ceiling)
**ID:** TC-504
**Priority:** P0
**Type:** edge
**Covers:** AC-3

Given a cockpit mode, reduce-motion OFF, and the **sharpest** shipped `journey-dynamic-curve` bend, the smoothed follow settled
When the in-scene curve sample is swept across at least one full heading cycle and the settled `appliedLeanAngle` is collected at every frame (including the peak-curvature frame)
Then `|appliedLeanAngle| <= maxRollCap` at **every** frame (target `maxRollCap ≈ 3°` / ~0.05 rad, pinned in build) — the tilt saturates at the tuned small ceiling so it reads as a lean, never a barrel-roll, and the calm-companion tone is preserved

**Notes:** Pure-math + widget unit test, no device. Sweep the curve seam across a full cycle; assert the settled `|angle| ≤ maxRollCap` everywhere, and that the angle actually **reaches** (within tolerance) the cap at the sharpest bend (the clamp is exercised, not vacuous). The exact ceiling is flame-game-developer's build decision (spec AC-3) — re-pin the band if retuned. Brackets TC-503 from above (monotonic up to here). The qualitative "calm, no nausea-grade roll" sign-off is TC-M-FEEL.

---

### Case: Eased / low-pass — per-frame angle delta within the smoothness cap, no snap even when the curve sample jumps
**ID:** TC-505
**Priority:** P0
**Type:** edge
**Covers:** AC-4

Given the engine is `active` (scroll advancing at the eased cruise `scrollDelta`), a cockpit mode, reduce-motion OFF
When `roadScrollOffset` is stepped by ONE cruise-frame's `scrollDelta` across a full scroll sweep and the per-frame change `|appliedLeanAngle(off+Δ) − appliedLeanAngle(off)|` is collected at every step — **including** at offsets where the raw curve sample changes sharply (a near-discontinuity in `lateralSlopeAt`)
Then the per-frame angle delta stays **<= maxAnglePerFrame** (target ≈0.2°/frame / ~0.0035 rad at cruise velocity, pinned in build) for **every** step — the applied angle is a low-pass / rate-limited follow of the raw curve sample, so even a fast change in the underlying curve produces a smooth angle response and the cockpit **never snaps** frame-to-frame

**Notes:** Widget unit test stepping `roadScrollOffset` by one eased cruise frame's delta (the `kV2CruiseSpeed × dt` convention shared with journey-dynamic-curve TC-408). Crucially, the assertion must hold at offsets where the **raw** curve sample jumps — pick a step that straddles a sharp curvature change and confirm the *applied* angle still moves ≤ cap (proving the smoothing, not just that the raw curve is smooth). Sibling to journey-dynamic-curve AC-7's per-frame curve-delta cap. The cap is pinned in build (spec AC-4); re-pin if retuned. Qualitative "visibly eased, never abrupt" is TC-M-FEEL.

---

### Case: Deterministic — replaying the same scroll-offset sequence yields the identical angle sequence
**ID:** TC-506
**Priority:** P0
**Type:** happy-path
**Covers:** AC-5

Given a cockpit mode, reduce-motion OFF, and a recorded sequence of advancing `roadScrollOffset` values (one full heading cycle) driven via `applyState` / explicit scroll advance
When the lean is driven through the recorded offset sequence once and the `appliedLeanAngle` at each step is recorded, then the **same** sequence is replayed from the same initial smoothing state and the angles re-recorded
Then the second pass yields the **byte-identical** angle sequence (±1e-9) as the first — the applied angle is a **pure deterministic function of the (smoothed) scroll-phase history** — and a static inspection confirms the lean reads **no** `DateTime.now` / wall-clock / `Stopwatch` / `Random` (its only time input is the shared scroll phase), so goldens at fixed scroll offsets stay stable

**Notes:** Widget test for the replay (record offsets + angles, reset smoothing state, replay, compare ±1e-9) **plus a static-inspection leg**: grep the lean path (`cockpit_painter.dart` / the lean-angle source in `journey_game.dart`) for `DateTime`, `Stopwatch`, `Random`, `Timer`, and any second phase input — assert the only time-varying input threaded into the lean is `roadScrollOffset` / the curve sample derived from it. Mirrors journey-dynamic-curve TC-403/TC-404 scroll-phase determinism. This determinism is what keeps the goldens (TC-508/TC-509) stable. **Note:** because the smoothing is stateful (low-pass history), the replay must reset to the same initial smoothing state for an exact match — the determinism is over the *same history*, per AC-5.

---

### Case: Reduce-motion is a HARD ZERO from the first frame, even at a sharp-curve offset
**ID:** TC-507
**Priority:** P0
**Type:** edge
**Covers:** AC-6, NFR-3

Given `reduceMotion == true` (`applyState(..., reduceMotion: true)`, `JourneyGame.reduceMotion == true`), a cockpit mode (`car`; sibling `motorbike`)
When the `appliedLeanAngle` is read (a) on the **very first frame** before any scroll has advanced, (b) at a **sharp-curve** scroll offset where a non-reduce-motion run would tilt hard, and (c) across several `update(dt)` pumps
Then `appliedLeanAngle == 0.0` **exactly** at every point — the cockpit holds dead level, never starts tilted, and introduces **no** motion under reduce-motion (a hard zero, not "frozen at the last value")

**Notes:** Widget test with reduce-motion true. Assert exact `== 0.0` (not ±epsilon) on the first frame, at a sharp-curve offset (the same offset that produces a near-clamp angle in TC-504 with reduce-motion OFF), and across pumps. Mirrors journey-dynamic-curve AC-10 / journey-pov AC-14. Companion golden may reuse a level reduce-motion cockpit frame. NFR-3 reduce-motion hard-zero leg.

---

### Case: Straight road (zero curvature, settled) → level cockpit, angle exactly zero
**ID:** TC-508
**Priority:** P0
**Type:** edge
**Covers:** AC-7

Given a cockpit mode, reduce-motion OFF, and a scroll phase where the road is **straight** (`lateralSlopeAt(worldDistance) == 0` / `centreLineOffsetAt(t≈1) == 0` at that phase), advanced enough frames that the smoothed follow has **settled**
When the settled `appliedLeanAngle` is read
Then `appliedLeanAngle == 0.0` (a level cockpit) — the lean exists only while the road bends; at zero curvature the smoothed follow settles to exactly level

**Notes:** Unit/widget test at a straight-road scroll offset (where the in-scene curve sample is zero), sampled after the smoothing settles. Assert exact `== 0.0` once settled. Distinct from TC-507 (reduce-motion zero from frame 1) — this is the zero-curvature zero with reduce-motion OFF after settling. Pairs with TC-501 (non-zero at curving frames) — together they prove "leans only while bending".

---

### Case: Mode-gating — non-zero lean only for car/motorbike; walk/run/bicycle/ship render byte-for-byte unchanged
**ID:** TC-509
**Priority:** P0
**Type:** happy-path
**Covers:** AC-8

Given a curving scroll offset, reduce-motion OFF; run once per mode in {`car`, `motorbike`} (`isCockpitActive == true`) and once per mode in {`walk`, `run`, `bicycle`, `ship`} (`isCockpitActive == false`), each with the smoothed follow settled
When the settled `appliedLeanAngle` is read for each mode, and the **rendered output** of each non-cockpit mode is compared to the no-lean baseline for that mode at the same scroll offset
Then a **non-zero** settled angle appears **only** when `isCockpitActive` (car/motorbike); for the four non-cockpit modes there is **no lean** (`appliedLeanAngle == 0.0` / not applied) and their rendered side-view output is **byte-for-byte unchanged** from the no-lean baseline — those modes have no cockpit foreground to tilt

**Notes:** Widget + golden test. Seam half: assert non-zero settled angle only for car/motorbike, zero/absent for the four others (parameterised). Golden half: render each non-cockpit mode at a curving offset and assert byte-for-byte equality with the existing shipped scene golden for that mode (the lean slice must leave them untouched). Guards the gating boundary — only car + motorbike are special. Pairs with TC-501 (the cockpit modes that DO lean).

---

### Case: Only the cockpit rotates — scene renderer output identical to the no-lean baseline at a fixed scroll offset
**ID:** TC-510
**Priority:** P0
**Type:** edge
**Covers:** AC-9

Given a cockpit mode (`car`/`motorbike`), a curving (non-zero-lean) scroll offset, reduce-motion OFF
When the **scene renderer** output (`RoadPainter`, side-object pool, parallax bands, sky, horizon) is captured for that scroll offset and compared to the no-lean baseline scene render for the same offset, and the compositing pipeline is inspected
Then the scene renderer output is **identical** to the no-lean baseline (the road / scenery / horizon / sky / side objects are **NOT** tilted or re-projected — the scene receives **no** rotation transform), and **only** the `CockpitPainter` compositing step carries the rotation transform around the tuned pivot

**Notes:** Golden + inspection test. Golden half: render the scene **layer without the cockpit** at a curving offset, lean ON, and assert byte-for-byte equality with the no-lean baseline scene golden at the same offset (proves the world does not tilt). Inspection half: confirm the rotation transform is applied **only** in the cockpit compositing path, not threaded into `RoadPainter` / the side-object pool. The perceptual "the world visibly does not tilt" is reinforced by TC-M-FEEL. If the baseline scene golden is re-pinned upstream, re-pin this reference.

---

### Case: Lean signal sourced solely from the in-scene curve sample
**ID:** TC-511
**Priority:** P0
**Type:** regression
**Covers:** AC-10

Given the lean must be tuned against the final `journey-dynamic-curve` road
When the lean-angle source is inspected statically (its inputs + references) and exercised
Then the roll angle is derived **solely** from the existing in-scene curve sample — `RoadGeometry.lateralSlopeAt(worldDistance)` (signed per-distance slope) and/or `JourneyGame.centreLineOffsetAt(t)` at the camera — and from **no other input**: no Bloc, `JourneyEngine`, `ActivityPlugin`, OS read, or second independent phase; the lean's only time-varying input is the shared scroll phase that feeds the curve sample (reinforced by AC-5 determinism, TC-506)

**Notes:** Static-inspection case over the lean-angle source in `journey_game.dart` / `cockpit_painter.dart`: assert the only data feeding the angle computation is the curve seam (`lateralSlopeAt` / `centreLineOffsetAt`) plus `reduceMotion` / `currentMode` gates — no engine/Bloc/OS reference, no `DateTime`/`Random`/second clock. Pairs with TC-506 (determinism) and TC-512 (separation imports). Reinforces NFR-2 (TC-M-PRIV). The chosen signal (slope vs centre-line offset) + `t` are a build decision (spec AC-10 / Open question); the case asserts it is **one of those in-scene seams and nothing else**.

---

### Case: Separation invariant — cockpit + scene siblings import only dart:*, package:flame/*, TravelMode
**ID:** TC-512
**Priority:** P0
**Type:** regression
**Covers:** AC-11

Given the lean is added to the Flame scene (`cockpit_painter.dart`, `journey_game.dart`, and the scene siblings, including any new lean-angle source)
When their source (imports + references) is inspected statically
Then they import **only** `dart:*`, `package:flame/*`, and the pure-Dart domain `TravelMode` — **no** `flutter_bloc`, `JourneyEngine`, `ActivityPlugin`, `MethodChannel` / platform channel, or any OS idle/lock/screen/location read — and the lean is driven solely by the shared scroll offset via the in-scene curve sample (mirrors journey-pov AC-9 / journey-dynamic-curve AC-8)

**Notes:** Static-inspection case (grep / import scan) over `lib/features/journey/presentation/game/{cockpit_painter,journey_game}.dart` + any new lean source, mirroring journey-pov TC-214 / journey-dynamic-curve TC-410 and the files' own SEPARATION INVARIANT docstrings. Re-run on any new source file. Reinforces NFR-2 (TC-M-PRIV).

---

### Case: Cosmetic-only — engine distanceKm / progress / elapsed / idle decisions byte-for-byte unchanged
**ID:** TC-513
**Priority:** P0
**Type:** edge
**Covers:** AC-12

Given identical mock activity input and a fixed injected elapsed time, `mode == car` (sibling `motorbike`), run once with the lean **active** and once with the lean **disabled** (no-lean baseline), same inputs otherwise
When the engine's exposed `distanceKm` / progress / elapsed / idle-vs-active decisions are read at the same elapsed points in both runs
Then the engine values are **exactly identical** between the two runs — adding the lean perturbs **no** engine number; the lean reads no OS signal, decides no active-vs-idle, and accrues no distance (cosmetic, pure-view; mirrors journey-pov AC-10 / journey-dynamic-curve AC-9)

**Notes:** Widget/integration test asserting **exact equality** (not ±epsilon) of engine `distanceKm`/progress/elapsed/idle across the lean-active vs no-lean runs for the same injected elapsed. The runtime half of AC-12; the static half (engine holds no reference to the lean) is folded into TC-511 / TC-512. Drives state via `applyState`; advances frames via the harness.

---

### Case: Lean on both surfaces; rotated frame still fully covers the cockpit band at the PiP (no exposed corners)
**ID:** TC-514
**Priority:** P0
**Type:** edge
**Covers:** AC-13, NFR-3

Given the full window and the always-on-top mini-window PiP render the **same** `JourneyGame` instance (ADR-0003), `mode == car` (sibling `motorbike`), reduce-motion OFF, the road bending, at a representative PiP size and a full-window size
When the near-camera curve is swept across a full scroll cycle at **each** size and, at each peak-bend offset, the rotated cockpit's painted region is checked against the cockpit band
Then the lean appears on **both** surfaces (`appliedLeanAngle` non-zero on each at curving frames), and at **both** sizes — especially the sized-down PiP — the **rotated cockpit frame still fully covers the cockpit band**: the rotation around the pivot does **not** expose un-painted canvas corners or reveal the scene where the cockpit should be, for **every** offset in the sweep (including the peak-clamp angle)

**Notes:** Integration test (`src/focus_journey/integration_test/`) against the shared-game per-surface wiring; render the leaning cockpit at the full size and the sized-down PiP size and assert (a) `appliedLeanAngle` non-zero on both at curving frames, (b) the rotated cockpit's painted region covers the cockpit band with no exposed un-painted corner across the sweep at peak lean. The exact pivot is a build decision (spec AC-9 / Open question — bottom-centre / horizon-style); this case asserts the **coverage outcome** regardless of pivot. The real frameless always-on-top PiP visual is the manual `[REAL-OS]` TC-M-PIP. NFR-3 "does not obscure the road / overlay" leg (the scene + overlay are not rotated, per TC-510). PiP test size may be adjusted by the reviewer.

---

### Case: Graceful degradation — a faulted cockpit asset is rotated as a placeholder, still surfaced, no crash
**ID:** TC-515
**Priority:** P0
**Type:** negative
**Covers:** AC-14

Given a cockpit asset (e.g. the steering-wheel glyph or a dash shape) is absent from the bundle or faults while decoding (the existing `loadAll` never-throws / placeholder path), `mode == car` (sibling `motorbike`), the road bending so the cockpit leans
When the leaning cockpit renders
Then the neutral **placeholder** is rotated correctly in place of the failed asset (it leans with the rest of the cockpit), the failed path is still surfaced through `failedAssetPaths` and `hasPlaceholderAssets == true`, and the scene **never crashes or blanks** — the lean does not regress journey-pov AC-13

**Notes:** Widget test injecting a missing/faulting cockpit asset path (mirror journey-pov TC-216) **with the lean active at a curving offset**. Assert `failedAssetPaths` contains the missing cockpit path, `hasPlaceholderAssets == true`, no exception thrown, and the placeholder is composited inside the rotated cockpit layer (not left un-rotated / detached). Companion golden may pin the rotated-placeholder frame. Confirms the rotation transform wraps the placeholder path too, not only the happy-path assets.

---

### Case: Golden — leaning car / motorbike cockpit frame at a fixed curving scroll offset is visually stable
**ID:** TC-516
**Priority:** P1
**Type:** regression
**Covers:** AC-1, AC-3, AC-4, AC-9

Given `mode == TravelMode.car` (sibling `motorbike`), a fixed injected day-time clock, a **fixed curving** scroll offset (mid-bend), `moving == true`, visible, reduce-motion OFF, the smoothed follow settled, the cockpit assets loaded
When the scene renders one frame
Then it matches the committed "leaning car cockpit" golden — the cockpit frame is rolled **into** the bend at the settled clamped angle, the **road / scenery / horizon behind it are NOT tilted** (only the cockpit carries the transform), and the rotated frame covers the cockpit band with no exposed corner

**Notes:** Golden test (`src/focus_journey/test/`). Determinism via fixed clock/mode/**fixed scroll offset** + the scroll-phase-only lean (TC-506) — no clock/`Random` in the scene, so the golden is stable. Pins the lean direction, the clamped magnitude, the no-snap-at-this-offset, and AC-9's "world not tilted" visually at one anchor. Does **not** prove "feels physical yet calm" — that is TC-M-FEEL. Expect re-pin if the clamp / pivot / signal is tuned in build (golden churn is expected during build tuning, per the journey-dynamic-curve precedent).

---

### Case: NFR-1 hot-path guard — lean adds constant per-frame angle-update cost, no per-frame allocation
**ID:** TC-517
**Priority:** P1
**Type:** regression
**Covers:** NFR-1

Given a cockpit is active (`car`/`motorbike`), the lean applied, the scene exercised across many `update(dt)` pumps and a long scroll run
When the lean's render/update hot path is inspected (static) and exercised across short and very long scroll runs
Then the lean adds at most an **O(1) canvas transform + a single smoothed-angle update per frame** — **no per-frame allocation** in the cockpit compositing path, **no new geometry**, and **no accumulating loop**: the per-frame angle-update cost is **constant**, independent of how long the session has scrolled (the angle update at a small `roadScrollOffset` and at a very large one after a long session does the same bounded work), and the inherited journey-pov / journey-dynamic-curve bounded-pool / no-alloc guards still hold with the lean active

**Notes:** Static inspection + the inherited bounded-pool / no-per-frame-allocation widget guards re-run with the lean active. Assert (a) no allocation per frame in the lean/compositing path, (b) the angle-update work does not grow with `roadScrollOffset` magnitude (constant-cost — mirrors journey-dynamic-curve TC-407's "cost does not grow with worldDistance" but for the angle update). Deterministic proxy for NFR-1; sustained ≥30fps on both surfaces is the device leg TC-M-NF1.

---

### Case: End-to-end smoke — lean on both surfaces; bend → lean, reduce-motion → level, straight → level, walk → no-lean
**ID:** TC-518
**Priority:** P1
**Type:** regression
**Covers:** AC-1, AC-6, AC-7, AC-8, AC-13

Given the app launched with the mock activity + mock window/visibility path, the shared `JourneyGame` rendering on **both** the full window and the sized-down PiP surface, `mode == car`
When the mock drives `active` into a **bend** (the cockpit leans on both surfaces), then reduce-motion ON (the lean **hard-zeros** to level on both), then reduce-motion OFF on a **straight** stretch (settles level), then `mode = walk` (no cockpit, no lean), then back to `car` in a bend (lean restored on both)
Then across the flow the leaning cockpit appears on **both** surfaces in bends (covering the band at the PiP per TC-514), hard-zeros to level under reduce-motion, settles level on straight road, applies **no** lean for walk, and restores cleanly on return — confirming the curve-sample↔lean↔both-surfaces wiring on the shared game

**Notes:** `integration_test` (`src/focus_journey/integration_test/`) on the real widget tree with the **mock** activity + window/visibility path (deterministic, no real OS). The mock-path twin of the manual real-OS PiP leg TC-M-PIP. Drives mode/state via the mock; frames via the harness. Per-surface band-coverage detail is TC-514; the angle assertions reuse the `appliedLeanAngle` seam.

---

## Manual / on-device + review legs (see the companion checklist)

These verify what is **NOT cheaply automatable**. They live in
[journey-cockpit-lean-manual-checklist.md](journey-cockpit-lean-manual-checklist.md) and are flagged here.

- **TC-M-FEEL** `[VISUAL]` — feel + motion-comfort + accessibility read: the cockpit reads as an **embodied
  lean into the turn** (a real drive corners, not a static photo) **yet stays a calm companion** — the roll is
  gentle, never lurches or snaps, no nausea-grade swing, comfortable to leave on-screen all session; the world
  (road / scenery / horizon) visibly does **not** tilt (only the frame rolls); and the lean does **not** obscure
  the road read or the "Paused — idle" overlay (AC-3/AC-4 feel gate + AC-9 perceptual + NFR-3 visual leg).
  Automated numeric legs: TC-503/TC-504 (monotonic + clamp), TC-505 (no snap), TC-510 (world not tilted),
  golden TC-516. A "too aggressive / nauseating", "snaps", or "tilts the world / obscures the road" verdict
  **blocks ship** even if every numeric case passes.
- **TC-M-PIP** `[REAL-OS]` — on a **real** frameless always-on-top PiP, the leaning cockpit renders correctly,
  still **fully covers the cockpit band** at the sized-down size (no exposed un-painted corners at peak lean),
  and does **not** break the PiP's frameless / always-on-top behaviour nor its occlusion/visibility pause
  (AC-13 real leg). Automated band-coverage leg: TC-514; both-surfaces smoke: TC-518.
- **TC-M-NF1** `[DEVICE]` — sustained **≥30fps on both surfaces** (full window + sized-down PiP) with the lean
  active while `active` on macOS + Windows (NFR-1). Automated proxy: TC-517 (constant per-frame angle-update,
  no alloc) + the inherited bounded-pool guards re-run with the lean.
- **TC-M-PRIV** `[AUDIT]` — `/privacy-audit` PASS: the lean adds **no** new OS signal / input / screen /
  location read — only a canvas transform driven by the existing in-scene curve sample (NFR-2). **Ship-blocker.**
  Reinforced by the AC-11 separation (TC-512) + the AC-10 signal-source inspection (TC-511).

---

## Coverage table (AC / NFR → covering case IDs)

| Item | Description | Covered by |
|---|---|---|
| AC-1 | lean exists + signed INTO the turn (sign tracks curve sample) | TC-501, TC-502 (negative), TC-516, TC-518 |
| AC-2 | monotonic \|angle\| vs \|curve\| below saturation | TC-503 |
| AC-3 | bounded maximum roll — clamp ceiling (motion-sickness ceiling) | TC-504, TC-516; **[VISUAL]** TC-M-FEEL |
| AC-4 | eased / low-pass — per-frame delta cap, no snap on curve jump | TC-505, TC-516; **[VISUAL]** TC-M-FEEL |
| AC-5 | deterministic — replay identical angle sequence, no clock/Random | TC-506 |
| AC-6 | reduce-motion HARD ZERO from the first frame | TC-507 |
| AC-7 | zero tilt when curvature is zero (settled) | TC-508 |
| AC-8 | car/motorbike only; non-cockpit modes byte-for-byte unchanged | TC-509, TC-518 |
| AC-9 | only the cockpit rotates — scene renderer identical to baseline | TC-510, TC-516; **[VISUAL]** TC-M-FEEL |
| AC-10 | lean signal sourced solely from the in-scene curve sample | TC-511, TC-501 (+ TC-506 determinism) |
| AC-11 | separation invariant — only dart:*, flame/*, TravelMode | TC-512 |
| AC-12 | cosmetic-only — engine counters byte-for-byte unchanged | TC-513 (+ static via TC-511/TC-512) |
| AC-13 | lean on both surfaces; rotated frame covers the cockpit band at PiP | TC-514, TC-518; **[REAL-OS]** TC-M-PIP |
| AC-14 | rotation does not break the cockpit placeholder / asset-failure path | TC-515 |
| NFR-1 | O(1) transform + constant per-frame angle update, no alloc; ≥30fps both surfaces | TC-517; **[DEVICE]** TC-M-NF1 |
| NFR-2 | pure-view; no new OS read; /privacy-audit PASS | **[AUDIT]** TC-M-PRIV (reinforced by TC-511, TC-512) |
| NFR-3 | reduce-motion hard zero; road/overlay unobscured & unrotated; no motion discomfort by construction | TC-507, TC-514, TC-510; **[VISUAL]** TC-M-FEEL |

Every AC (AC-1..AC-14) and every NFR (NFR-1..NFR-3) maps to at least one case. No AC/NFR is orphaned.

### Coverage notes / flagged gaps

- **The cases assume a read-only applied-angle seam (`appliedLeanAngle`) the build must add.** AC-1/2/3/4/5/6/7/8
  are asserted against it (a pure function of the smoothed scroll phase), mirroring the `isCockpitActive` /
  `centreLineOffsetAt` / `liveCentreLinePoints` seams the prior slices added so the invariant could genuinely
  fail. Without it these reduce to weak golden inference; the implementer adds it, the test-script-author
  asserts against it.
- **AC-1 sign convention is the load-bearing leg.** TC-501 asserts `sign(appliedLeanAngle) == expectedSign(sign(curveSample))`
  (an exact sign match, not merely `!= 0`); TC-502 is the dedicated **negative** case documenting that a flipped
  sign FAILS — a one-minus-sign regression is invisible in a pixel golden, so this is treated as the most
  failure-prone assertion ("tilt away from the curve is wrong").
- **AC-3 clamp + AC-4 per-frame cap are numeric proxies for "physical but calm".** TC-504 (`|angle| ≤ maxRollCap`)
  and TC-505 (`|Δangle/frame| ≤ maxAnglePerFrame`, including across a sharp curve-sample jump) are the numeric
  stand-ins; "embodied yet never nauseating, comfortable all session" is the **review gate TC-M-FEEL**. The exact
  ceiling + time-constant are pinned in build (spec AC-3/AC-4); re-pin the bands if retuned. The lean **signal**
  (slope vs centre-line offset) and the **pivot** are build decisions; cases assert against whichever signal the
  lean consumed (AC-10) and against the AC-13 coverage outcome regardless of pivot.
- **AC-9 "only the cockpit rotates" is a baseline-equality golden + a no-transform inspection.** TC-510 asserts
  the scene renderer output at a fixed scroll offset is byte-for-byte identical to the no-lean baseline (the
  world does not tilt) and only the cockpit step carries the transform; the perceptual fact is reinforced by
  TC-M-FEEL.
- **AC-13 PiP read — automation proves the band-coverage geometry, not the live-OS visual.** TC-514 asserts the
  rotated cockpit covers the band with no exposed corners across a sweep at PiP + full sizes; the real frameless
  always-on-top PiP visual is the manual `[REAL-OS]` TC-M-PIP, consistent with the journey-pov / mini-window
  precedent. The PiP test size may be adjusted by the reviewer.
- **NFR-1 (≥30fps both surfaces) — DEVICE only.** TC-517 (constant per-frame angle-update independent of scroll
  length, no per-frame allocation) + the inherited bounded-pool guards re-run with the lean are the deterministic
  proxy; sustained frame rate is on-device TC-M-NF1.
- **NFR-2 (privacy) — AUDIT gate.** The lean adds only a canvas transform driven by the existing in-scene curve
  sample; `/privacy-audit` PASS (TC-M-PRIV) is the ship-blocker, reinforced by the AC-11 separation (TC-512) +
  the AC-10 signal-source inspection (TC-511). A fail blocks ship regardless of every other pass.
- No AC was left without a **meaningful** case — every functional AC has at least one deterministic case; the
  only clauses without a fully automated case (feel / motion-comfort, on-device fps, real-OS PiP visual, privacy
  audit) are explicitly captured in the manual checklist with the journey-pov / journey-dynamic-curve deferral
  precedent, not silently dropped.
