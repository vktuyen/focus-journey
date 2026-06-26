# Journey cockpit lean — first-person POV tilts into the curve

**Status:** shipped (2026-06-26)
**Owner:** Kevin (Tuyen Vo)
**Last updated:** 2026-06-26

## Problem
The shipped `journey-pov` slice composites a flat first-person **cockpit foreground** (car: dashboard +
steering wheel + gauges + A-pillars; motorbike: handlebar + grips + gauge pod + fuel tank) over the
receding road, and the sibling `journey-dynamic-curve` slice just made the road **sweep** with F1-style
bends (`maxHeading 0.0016→0.0036`, `curveAmplitudeFrac 0.16→0.20`, peak slope ~2.25× baseline). But the
cockpit holds dead level through every bend — the road sweeps left and right beneath a frame that never
reacts. The eye reads this as a static photo pasted over a moving scene; cornering has no *physical* weight.

Kevin wants the cockpit to **lean / tilt into the curve** — as the road bends, the cockpit frame rolls a
little in the direction of the turn, the way your view rolls when a car or motorbike corners — so the drive
feels embodied. This is request **#2's** natural follow-on, carved out as its own slug because it is the
piece most at risk of inducing motion discomfort and of breaking the deterministic cockpit goldens, and
because it is only meaningful once the dramatic curve exists (`[blocked by: journey-dynamic-curve ✅]`).

The lean must stay inside three guardrails the existing scene guarantees: the **pure-view invariant**
(scene reads no OS signal, owns no journey logic), **deterministic goldens** (no wall-clock, no `Random`),
and the **"calm companion" tone / motion-sickness safety** (this is ambient background for a work session,
not a game). So the feature is a **bounded, eased, reduce-motion-gated rotation of the `CockpitPainter`
output only** — sampled from the curve the scene already computes — not a new camera, not physics.

## User & outcome
- **The focused individual** (developer / student / remote worker) — primary. Success = when the road
  sweeps into a bend in a car or motorbike, the cockpit visibly rolls *into* that bend (left turn → frame
  leans into the left turn) and rolls back as the road straightens, so cornering reads as a physical drive
  — yet the motion stays gentle enough to leave on-screen all session (no lurching, no nausea-grade roll).
  Observable: cockpit tilt is non-zero on a bend, signed to match curve direction, grows with curve
  magnitude up to a clamped maximum, and is smoothed so it never snaps.
- **The privacy-skeptical teammate** — unaffected. This is a **cosmetic, pure-view** change: the lean is
  sampled from the existing in-scene curve signal; the scene still reads no OS signal, owns no journey
  logic, accrues no distance. `/privacy-audit` stays PASS by construction (no new dependency).
- **The motion-sensitive user** — protected. When the OS/app reduce-motion preference is on, the cockpit
  tilt is **exactly zero** (the frame holds level), matching how reduce-motion already freezes the scroll
  and the sweep.

## Scope
### In
- **Signed lean sampled from the in-scene curve** — the cockpit roll angle is derived from the existing
  curve-at-camera signal the scene already computes (`RoadGeometry.lateralSlopeAt(worldDistance)` and/or
  `JourneyGame.centreLineOffsetAt(t≈1)` / `RoadPainter.centreLineOffset`). Sign matches the curve direction
  (the cockpit leans **into** the turn); magnitude is **monotonic** in curve magnitude up to a clamp.
- **Bounded maximum roll** — the tilt is clamped to a small tuned ceiling (a few degrees) so it reads as a
  lean, never a barrel-roll; the calm-companion tone is preserved.
- **Eased / low-pass smoothing (motion-sickness safety)** — the applied angle is a smoothed (low-pass /
  rate-limited) follow of the raw curve sample so it never snaps frame-to-frame, even if the underlying
  curve sample changes quickly. The smoothing rides the **same shared scroll phase** the scene already
  uses — no new clock/timer.
- **Reduce-motion gate (hard zero)** — when `reduceMotion` is on, the tilt is **exactly 0.0** and the
  cockpit holds level; the lean introduces no motion under reduce-motion.
- **Implemented as a rotation of the `CockpitPainter` output only** — the lean is a canvas transform
  applied around a tuned pivot when compositing the cockpit foreground; the road/scene renderer is
  **untouched**. This keeps the cockpit-vs-scene separation invariant and lets the existing cockpit
  goldens stay deterministic (golden at a fixed scroll offset → fixed angle).
- **Car + motorbike only** — the lean applies only where a cockpit renders (`TravelMode.car`,
  `TravelMode.motorbike`); all other modes are unchanged (they have no cockpit to tilt).
- **One scene, two surfaces** — the lean flows automatically to the always-on-top mini-window PiP, since
  both surfaces render the same `JourneyGame` instance (ADR-0003).

### Out
- **Leaning the road / scene / horizon** — only the cockpit foreground rotates; the road, scenery, sky,
  and side objects are not re-projected or tilted (that would be a camera rewrite — see
  `journey-dynamic-curve` Out). The lean is the *frame's* roll, not the world's.
- **A physics / dynamics model** (lateral g, suspension, weight transfer, counter-steer) — the lean is a
  direct eased function of the geometric curve sample, not a simulated dynamic.
- **Lean for walk / run / bicycle / ship** — those modes have no cockpit foreground; nothing to tilt.
- **A new motion source or wall-clock animation** — the lean derives only from the shared scroll-phase /
  curve sample; no `DateTime.now`, no independent timer, no `Random` (goldens stay deterministic; the lean
  freezes when the scene is stopped or reduce-motion is on).
- **Per-mode / per-speed lean tuning** — single cosmetic lean curve; per-mode behaviour is the deferred
  `journey-energy-model`.
- **Any change to journey logic** — engine, distance accrual, idle/active decisions, route/map, stats.

## Constraints & assumptions
- **Pure-view invariant (hard, load-bearing).** `CockpitPainter`, `JourneyGame` and the scene siblings
  import **only** `dart:*`, `package:flame/*`, and the pure-Dart domain `TravelMode`. The lean is driven
  solely by the existing in-scene curve sample (a pure function of the shared scroll offset) — **no** Bloc,
  `JourneyEngine`, `ActivityPlugin`, `MethodChannel`, or OS read. It decides no active-vs-idle and accrues
  no distance (mirrors journey-pov AC-9/AC-10, journey-dynamic-curve AC-8/AC-9).
- **Frame-deterministic.** The applied tilt is a pure function of the (smoothed) scroll phase — no clock,
  no `Random` — so unit tests and goldens are stable: the same scroll offset history yields the same angle.
- **Motion-sickness safety ceiling.** The tilt is clamped to a small maximum and low-pass smoothed so the
  per-frame change at cruise scroll velocity stays below a smoothness cap (sibling to
  `journey-dynamic-curve` AC-7's per-frame curve-delta cap). flame-game-developer pins the exact max-angle
  and smoothing time-constant in build; reviewer signs off the feel.
- **Reduce-motion is a hard zero**, not merely "frozen at the last value": with reduce-motion on the angle
  is 0.0 from the first frame (the cockpit never starts tilted).
- **Tilt away from the curve is wrong.** The sign must put the lean *into* the turn; the build must assert
  the sign convention against `lateralSlopeAt` / `centreLineOffset` so a sign flip is caught.
- **One scene, two surfaces.** Full window + always-on-top mini-window PiP render the same `JourneyGame`
  (ADR-0003); the rotated cockpit must still read correctly and not expose un-painted corners at the
  sized-down PiP (a rotation around a pivot can reveal canvas edges — the build must guard the frame still
  covers the cockpit band after rotation).
- **Performance (NFR-1).** The lean adds at most an O(1) canvas transform + a single smoothed-angle update
  per frame — no per-frame allocation, no new geometry, no accumulating loop — preserving the scene's
  ≥30fps at both surfaces.
- **Desktop targets:** macOS + Windows. Stack per `docs/architecture/overview.md`; scene is Flame
  presentation (ADR-0002).

## Resolved decisions (from backlog framing, Kevin 2026-06-25)
1. **Lean = a bounded, eased, reduce-motion-gated rotation of the `CockpitPainter` output only** — not a
   road/scene tilt, not a 3D camera, not a physics model. Keeps the separation invariant + deterministic
   goldens.
2. **Signal = the existing in-scene curve-at-camera** (`RoadGeometry.lateralSlopeAt` /
   `centreLineOffsetAt(t≈1)`), tuned against the **final** `journey-dynamic-curve` curve. No new input.
3. **Signed into the turn, monotonic in curve magnitude up to a clamped max.**
4. **Eased / low-pass** for motion-sickness safety; **exactly zero** when reduce-motion is on or curvature
   is zero.
5. **Car + motorbike only**; flows to the mini-window PiP for free (shared `JourneyGame`, ADR-0003).

## Acceptance criteria
Each item is a checkable, observable statement and the ship gate. If it isn't testable, rewrite it.
These ACs ARE the contract — `tests/cases/journey-cockpit-lean.md` will reference them by ID; there is
no separate acceptance-criteria file. "Curve" everywhere means the **shipped `journey-dynamic-curve`
geometry** (`maxHeading 0.0036`, `curveAmplitudeFrac 0.20`) the lean is tuned against; all tilt is
observable through the scene seams (`JourneyGame.applyState`, `centreLineOffsetAt(t)`,
`RoadGeometry.lateralSlopeAt(worldDistance)`, `roadScrollOffset`, `currentMode`, `isCockpitActive`,
`reduceMotion`) and the rotated `CockpitPainter` output. There is no clock/`Random` in the scene; goldens
are taken at fixed scroll offsets.

**Signed lean into the turn**
- [x] AC-1 (lean exists and is signed into the turn): Given a cockpit mode (`car` or `motorbike`) and the
      scene scrolled to a frame where the road is **bending** (`lateralSlopeAt(worldDistance) != 0` /
      `centreLineOffsetAt(t≈1) != 0`), When the cockpit foreground is composited, Then the applied roll
      angle is **non-zero** and its **sign rolls the cockpit INTO the turn** — the sign of the applied
      angle is a fixed function of the sign of the in-scene curve sample (`lateralSlopeAt` /
      `centreLineOffset`), so a sign flip is caught. Observable: assert `sign(appliedAngle)` against
      `sign(lateralSlopeAt(worldDistance))` (and/or `sign(centreLineOffsetAt(t≈1))`) at curving frames; a
      left bend leans the frame into the left turn, a right bend into the right.
- [x] AC-2 (monotonic in curve magnitude up to the clamp): Given two curving frames A and B with
      `|curveSample(B)| > |curveSample(A)|` and both below the saturation point, When the lean is applied
      at each, Then `|appliedAngle(B)| >= |appliedAngle(A)|` — bigger bend produces a bigger (or equal)
      tilt, monotonically, until the angle saturates at the clamped maximum (AC-3). Observable by sampling
      the applied angle across a scroll sweep and asserting monotonicity of `|angle|` vs `|curveSample|`
      below saturation.
- [x] AC-3 (bounded maximum roll — motion-sickness ceiling): Given any curve sample (up to and including
      the sharpest `journey-dynamic-curve` bend), When the lean is applied, Then `|appliedAngle|` never
      exceeds a tuned small ceiling so it reads as a lean, never a barrel-roll, and the calm-companion tone
      is preserved. Observable: sweep `centreLineOffsetAt` / `lateralSlopeAt` across a full heading cycle
      and assert `|appliedAngle| <= maxRollCap` at every frame. _proposed resolution to Open question "Max
      lean angle & smoothing time-constant" (max-angle half): target **maxRollCap ≈ 3° (~0.05 rad)** — a
      visible "physical but calm" lean, well under nausea-grade roll; flame-game-developer pins the exact
      ceiling against the final curve in build, reviewer signs off the feel._

**Eased / smoothed (no snap)**
- [x] AC-4 (eased / low-pass smoothing — no frame-to-frame snap): Given the engine is `active` (scroll
      advancing at the eased cruise `scrollDelta`), When `roadScrollOffset` advances over successive
      frames, Then the **per-frame change of the applied angle** stays below a tuned smoothness cap and the
      angle never snaps — the applied angle is a low-pass / rate-limited follow of the raw curve sample,
      so even a fast change in the underlying curve produces a smooth angle response (sibling to
      `journey-dynamic-curve` AC-7's per-frame curve-delta cap). Observable: step the scene by one
      cruise-frame's `scrollDelta` and assert `|appliedAngle(n) - appliedAngle(n-1)| <= maxAnglePerFrame`.
      _proposed resolution to Open question "Max lean angle & smoothing time-constant" (smoothing half):
      target a low-pass time-constant giving **per-frame angle delta ≤ ~0.2°/frame (~0.0035 rad)** at
      cruise velocity (visibly eased, never abrupt); flame-game-developer pins the exact time-constant /
      rate-limit against the actual eased cruise `scrollDelta` in build, reviewer signs off the feel._

**Deterministic**
- [x] AC-5 (deterministic — pure function of the smoothed scroll-phase history): Given the smoothing rides
      the **same shared scroll phase** the scene already uses (`roadScrollOffset` → `_motion.offset`), no
      independent clock or timer, When the cockpit is rendered, Then the applied angle is a **pure
      deterministic function of the (smoothed) scroll-phase history** — replaying the same sequence of
      scroll offsets yields the **identical** angle sequence, and **no `DateTime.now` / wall-clock /
      `Random`** is read (goldens at fixed scroll offsets stay stable). Observable: drive `applyState` /
      advance `roadScrollOffset` through a recorded offset sequence twice and assert identical applied
      angles; inspect that the lean's only time input is the shared scroll phase.

**Reduce-motion (hard zero)**
- [x] AC-6 (reduce-motion is a HARD ZERO from the first frame): Given `reduceMotion == true` (via
      `applyState(reduceMotion: true)`, `JourneyGame.reduceMotion == true`), When the cockpit renders —
      **including the very first frame** — Then the applied roll angle is **exactly `0.0`** and the cockpit
      holds dead level; the lean never starts tilted and introduces no motion under reduce-motion (this is
      a hard zero, not "frozen at the last value"). Observable: with `reduceMotion` on at any scroll
      offset, including before any scroll, assert `appliedAngle == 0.0` and a level cockpit frame (mirrors
      `journey-dynamic-curve` AC-10 / journey-pov AC-14).

**Zero curvature → level**
- [x] AC-7 (relaxes toward level as the road straightens): Given a cockpit mode and a frame where the
      road is **straightening** (`|lateralSlopeAt(worldAtCamera(scrollOffset))|` near its minimum for the
      scroll phase, once the smoothed follow has settled), When the cockpit renders, Then the applied roll
      angle **relaxes toward level** — `|appliedAngle|` is well below the visible band (a small fraction of
      the `maxLeanRadians` clamp) — so the lean exists only while the road meaningfully bends. _Resolution
      to the build finding (both test agents + self-review, 2026-06-25): the shipped `journey-dynamic-curve`
      geometry is a continuously-meandering procedural curve with **no reachable scroll offset where
      `lateralSlopeAt` is exactly `0`** (the flattest reachable frame has `|slope| ≈ 1.4e-8` → target
      ≈ 2.5e-7 rad), so a literal `appliedAngle == 0.0` on a "straight road" is not satisfiable on the live
      curve. **Exactly `0.0` is reserved for the two hard-zero gates** — reduce-motion (AC-6) and non-cockpit
      modes (AC-8) — which the seam returns bit-exact; this AC asserts the curvature-driven case as "settles
      to `|angle| ≲ 1e-4` at the flattest reachable frame, and the lean relaxes toward level on the flat
      stretch."_ Observable: at the flattest reachable scroll offsets, assert the settled applied angle is
      `≲ 1e-4`; and that `appliedAngle` starts at exactly `0.0` before any scroll.

**Mode-gating (cockpit modes only)**
- [x] AC-8 (lean applies to car + motorbike only): Given `mode` in {`car`, `motorbike`}
      (`isCockpitActive == true`), When the road bends, Then the cockpit leans per AC-1; and Given `mode`
      in {`walk`, `run`, `bicycle`, `ship`} (`isCockpitActive == false`), When the scene renders, Then
      **no lean is applied** — those modes have no cockpit foreground to tilt and their existing side-view
      presentation is **byte-for-byte unchanged** by this slice. Observable: assert a non-zero settled
      angle only when `isCockpitActive`, and that the non-cockpit modes' rendered output is unchanged from
      the no-lean baseline.

**Rotation of the cockpit foreground ONLY**
- [x] AC-9 (only the cockpit rotates — the scene does not tilt): Given the lean is applied, When a curving
      frame is rendered, Then **only the `CockpitPainter` output is rotated** (a canvas transform around
      the tuned pivot when compositing the foreground) — the **road / scene / horizon / sky / side objects
      are NOT tilted or re-projected**, and the scene renderer (`RoadPainter`, side-object pool, parallax
      bands) is **untouched** by this slice. Observable: the scene renderer receives no rotation transform
      (its output for a given scroll offset is identical to the no-lean baseline); only the cockpit
      compositing step carries the rotation. _proposed resolution to Open question "Pivot point of the
      rotation": target a pivot at **bottom-centre of the viewport (or just below it, a horizon-style
      pivot)** so the lean reads naturally and the rotated frame still covers the cockpit band without
      exposing un-painted corners (see AC-12); flame-game-developer pins the exact pivot in build, reviewer
      signs off the feel._
- [x] AC-10 (lean signal sourced from the in-scene curve only): Given the lean must be tuned against the
      final `journey-dynamic-curve` road, When its input is inspected, Then the roll angle is derived
      **solely** from the existing in-scene curve sample — `RoadGeometry.lateralSlopeAt(worldDistance)`
      (signed per-distance slope = `cos(phase)·heading(segment)·maxHeading`) and/or
      `JourneyGame.centreLineOffsetAt(t)` at the camera — and from **no other input** (no Bloc, engine,
      OS read, second phase). Observable by inspection plus AC-5 determinism. _proposed resolution to Open
      question "Lean signal: slope vs centre-line offset": target the **signed `lateralSlopeAt` (rate of
      bend) sampled at the camera (`t≈1`)** as the lean signal — it is the natural "how hard is the road
      turning right now" signal and is already signed into the turn; flame-game-developer may instead use
      `centreLineOffsetAt(t≈1)` (how far the road has swung at the camera) or a blend, and pins the chosen
      `t` in build, reviewer signs off the feel._

**Pure-view & separation**
- [x] AC-11 (separation invariant preserved): Given the lean is added to the Flame scene, When
      `cockpit_painter.dart`, `journey_game.dart` and the scene siblings are inspected, Then they still
      import **only** `dart:*`, `package:flame/*`, and the pure-Dart domain `TravelMode` — **no**
      `flutter_bloc`, `JourneyEngine`, `ActivityPlugin`, `MethodChannel`/platform channel, or OS
      idle/lock/screen/location read (mirrors journey-pov AC-9 / journey-dynamic-curve AC-8). The lean is
      driven solely by the shared scroll offset via the in-scene curve sample.
- [x] AC-12 (cosmetic-only — engine state byte-for-byte unchanged): Given the lean renders for
      `car`/`motorbike`, When the journey runs the same inputs as the no-lean baseline, Then the engine's
      `distanceKm` / progress / elapsed / idle-vs-active decisions are **byte-for-byte unchanged** from
      baseline — the lean reads no OS signal, decides no active-vs-idle, and accrues no distance (cosmetic,
      pure-view; mirrors journey-pov AC-10 / journey-dynamic-curve AC-9).

**One scene / two surfaces**
- [x] AC-13 (lean on both surfaces; rotated frame covers the cockpit band at the PiP): Given the full
      window and the always-on-top mini-window PiP render the **same** `JourneyGame` instance (ADR-0003),
      When `mode` is `car` or `motorbike` and the road bends, Then the lean appears on **both** surfaces,
      and at the sized-down PiP the **rotated cockpit frame still fully covers the cockpit band** — a
      rotation around the pivot does **not** expose un-painted canvas corners or reveal the scene where the
      cockpit should be. Observable: at representative PiP + full sizes, assert the rotated cockpit's
      painted region still covers the cockpit band across a scroll sweep (no exposed corners). _(The
      real-OS frameless/always-on-top PiP visual confirmation may be a manual carry, consistent with prior
      slices — TC-M-PIP.)_

**Graceful degradation**
- [x] AC-14 (rotation does not break the cockpit placeholder / asset-failure path): Given a cockpit asset
      is absent or faults while decoding (the existing `loadAll` never-throws / placeholder path), When the
      leaning cockpit renders, Then the **placeholder is rotated correctly** in place of the failed asset,
      the failed path is still surfaced through `failedAssetPaths` / `hasPlaceholderAssets`, and the scene
      never crashes or blanks — the lean does not regress journey-pov AC-13.

### Non-functional
- [x] NFR-1 Performance: The lean adds at most an **O(1) canvas transform + a single smoothed-angle update
      per frame** — **no per-frame allocation, no new geometry, no accumulating loop** — and the scene
      holds **≥30fps** on macOS + Windows at **both** surfaces (full window and the sized-down PiP) under
      `active`. _(Automated guards: assert constant per-frame work for the angle update independent of how
      long the session has scrolled, and no per-frame allocation in the cockpit compositing path; on-device
      ≥30fps both surfaces is a manual carry before public release — TC-M-NF1 — consistent with journey-pov
      / journey-dynamic-curve NFR-1.)_
- [x] NFR-2 Security/Privacy (gating): The lean is **pure-view** — it adds **no** new OS signal, input,
      screen, or location read; it derives solely from the existing in-scene curve sample (a pure function
      of the shared scroll phase). `/privacy-audit` stays **PASS** by construction. **Gating** — ship
      blocks until `/privacy-audit` returns PASS. _`/privacy-audit` **PASS** (privacy-guardian, 2026-06-26):
      no new dependency/import/channel/egress; signal is `lateralSlopeAt(worldAtCamera(scrollOffset))` only;
      separation invariant enforced as a shipped guard (TC-511/TC-512)._
- [x] NFR-3 Accessibility: The OS/app "reduce motion" preference is honoured as a **hard zero** (per AC-6 —
      `appliedAngle == 0.0`, the cockpit holds level); the lean does **not** obscure essential journey
      readouts — the road read and any "Paused — idle" overlay stay visible and unrotated (the scene is not
      tilted, per AC-9) — and it does **not** induce motion discomfort **by construction** via the clamp
      (AC-3) plus the easing (AC-4).

## Open questions
- [ ] **Max lean angle & smoothing time-constant** — the exact clamped maximum (a few degrees?) and the
      low-pass time-constant / rate-limit that read as "physical but calm" against the final
      `journey-dynamic-curve` curve — owner: flame-game-developer (tune in build; pin targets here).
- [ ] **Lean signal: slope vs centre-line offset** — sample the curve via `RoadGeometry.lateralSlopeAt`
      (rate of bend) or `centreLineOffsetAt(t≈1)` (how far the road has swung at the camera), and at which
      `t` — owner: flame-game-developer.
- [ ] **Pivot point of the rotation** — where the cockpit frame rotates about (bottom-centre? a point below
      the viewport, like a horizon pivot?) so the lean reads naturally and does not expose un-painted
      corners at the PiP — owner: flame-game-developer.

## Related
- Backlog framing: [planning/backlog/journey-cockpit-lean.md](../../planning/backlog/journey-cockpit-lean.md)
- Parent epic / Wave 2: [planning/backlog/visual-polish.md](../../planning/backlog/visual-polish.md)
- Extends: [specs/journey-pov/spec.md](../journey-pov/spec.md) (the cockpit foreground this rotates)
- Blocked by (tuned against its final curve): [specs/journey-dynamic-curve/spec.md](../journey-dynamic-curve/spec.md)
- Code: `cockpit_painter.dart` (`paint` — rotate its output), `journey_game.dart`
  (`centreLineOffsetAt(t)`, `reduceMotion`, `currentMode`, cockpit seams), `road_geometry.dart`
  (`lateralSlopeAt`), `road_painter.dart` (`centreLineOffset`)
- Architecture: [docs/architecture/](../../docs/architecture/) — ADR-0002 (Flutter/Bloc/Flame stack),
  ADR-0003 (single-window two-mode / shared `JourneyGame`), ADR-0006 (arc-length-aware side-object cadence)
- Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md)
