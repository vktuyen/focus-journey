# Journey POV — motorbike/car first-person vehicle frame

**Intake date:** 2026-06-24  **Requested by:** Kevin  **Size (rough):** L
**Part of epic:** [Wave 2 feature requests](wave2-feature-requests.md) · S1b
**Carved out of:** [journey-scene-v2](journey-scene-v2.md) (request #2)

## Why
Make the journey vehicle read as a real **first-person POV** — a steering-wheel / handlebar foreground
frame with a more realistic vehicle and nicer, more-real objects (req #2). It's the single biggest,
loosest, highest-redo-risk item of the scene rework, so it was split out of `journey-scene-v2` to get
its own spec, art spike, and review gate rather than stalling the rest of the scene work.

## Domain notes (brief)
Presentation-only, like its parent: must preserve the **pure-view invariant** (scene mirrors engine
truth, owns no journey logic) and stay **cosmetic, single-speed** — per-mode speed/energy is the
separate `journey-energy-model` slice, explicitly out of scope here. Assets (dash/handlebar overlay,
realistic vehicle, people/characters) go through `ui-asset-curator` (`/source-assets`) as tasteful,
content-appropriate, CC0/permissive only, recorded in `assets/CREDITS.md`. Applies to both surfaces
(full window + mini-window PiP) since they share the one `JourneyGame` instance (ADR-0003).

## Candidate ADRs (carried from parent)
- [ ] **POV reframing approach** — dash/handlebar foreground overlay, camera/horizon relationship, and
      `mode`-sprite handling. Likely needs an art-direction spike first (is it a nicer sprite, or a full
      scene redirection?). Reconfirm scope at `/capture-idea`/`/new-feature` time.

## Resolved at kickoff (Kevin, 2026-06-25 — with reference images)
**Visual target = true first-person cockpit POV** (Kevin supplied reference stills):
- **Car** — through-windshield view: dashboard + steering wheel (+ hands), A-pillar/mirror framing; road +
  Vietnam scenery seen **ahead**, receding to the horizon.
- **Motorbike** — over-the-handlebars view: gauge cluster + grips (+ gloved hands) + fuel tank; road ahead.
- The shipped scene already renders a forward, receding-to-horizon winding road, so the likely mechanism is
  a detailed **mode-specific cockpit FOREGROUND frame** composited over the existing world (+ perspective
  tuning of the horizon), rather than a ground-up camera rewrite. Confirm in the spike. Flows to the
  mini-window PiP for free (shared `JourneyGame`, ADR-0003).

**Mode coverage = car + motorbike ONLY.** The other 4 modes (walk / run / bicycle / ship) keep the current
on-road sprite view. (Bicycle/ship/walk/run first-person deferred — out of scope.)

**Process = art-direction SPIKE first, THEN `/new-feature`.** Photoreal art like the references is almost
certainly NOT CC0/license-clean, and this project ships **license-clean only** (`ui-asset-curator`).

**SPIKE DONE (2026-06-25) — direction approved: A · Stylized flat.** The `ui-asset-curator` spike confirmed
**no license-clean photoreal cockpit exists** (photoreal is paid-stock only). Kevin reviewed a visual mock
(`scratchpad/pov-cockpit-direction.html`) and approved the **stylized flat cockpit** direction: a flat,
illustrated cockpit cohesive with the Kenney scene, composed from **CC BY 3.0 glyphs** (steering wheel,
speedometer, fuel gauge, all Delapouite / game-icons.net; CC0 Wikimedia wheel as a zero-attribution
fallback) over **original flat dash/handlebar/tank shapes** recoloured to the journey palette. Photoreal
(paid/commissioned, asset-policy exception) was offered and **declined** — may return later as its own slug.
Candidate assets staged in `scratchpad/pov-spike/`; spike report at `scratchpad/pov-spike/SPIKE-REPORT.md`.

## Signals
Ready when **`journey-scene-v2` has shipped** (this builds on the reworked winding road + scenery +
motion). `[blocked by: journey-scene-v2]`. Re-run a focused `/capture-idea journey-pov` to deepen the
art-direction framing if the POV proves to be a full redirection, before promoting.

## First step
Run `/new-feature journey-pov` to promote this slice into a spec — **only after `journey-scene-v2` ships.**
