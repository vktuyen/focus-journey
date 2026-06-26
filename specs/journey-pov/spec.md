# Journey POV (first-person cockpit frame — car + motorbike)

**Status:** shipped (2026-06-25)
**Owner:** Kevin (Tuyen Vo)
**Last updated:** 2026-06-25

> **Test verdict (2026-06-25): `green`** — 948/948 passed (report
> `tests/_runner/reports/journey-pov/20260625-130932/`). `/review-code` `approved` · `/privacy-audit` `pass`.
> Ticked ACs are verified by the green automated run + privacy gate. **Carried as pre-public-release legs**
> (manual / review-gate, consistent with prior slices): **AC-12** real-OS frameless/always-on-top PiP
> confirmation (two-surface logic automated green via TC-209); **AC-16** stylized-flat art-cohesion (visual
> review gate, TC-M4-ART); **NFR-1** on-device ≥30fps (automated no-alloc/no-new-geometry proxy green;
> device fps is TC-M-NF1); **NFR-3** distinct car-vs-motorbike silhouette visual leg (reduce-motion half is
> automated via AC-14).

## Problem
The journey scene shipped by `journey-view` / `journey-scene-v2` already renders a forward, winding road
receding to the horizon with parallax Vietnam scenery — but the traveller is drawn as a small **side-view
vehicle sprite sitting on the road** (a chase/3rd-person read). It never feels like *you* are the one
driving up the country. Kevin wants the journey to read as a genuine **first-person cockpit POV** — for a
**car**, looking through the windshield over a dashboard + steering wheel; for a **motorbike**, looking out
over the handlebars + gauge cluster. (Reference: real driving-POV footage Kevin supplied.) This is request
**#2**, carved out of `journey-scene-v2` as the single biggest, loosest, highest-redo-risk piece of the
scene rework so it could get its own art-direction spike and review gate.

**Art direction is already settled (spike, 2026-06-25).** A `ui-asset-curator` spike confirmed there is
**no license-clean photoreal cockpit art** anywhere (photoreal is paid-stock only), and Kevin reviewed a
visual mock and chose the **stylized flat** direction: a flat, illustrated cockpit cohesive with the
existing Kenney-flat scene, built from CC-BY/CC0 glyph primitives + original flat shapes. So this feature is
scoped around that achievable look, not the photoreal references.

## User & outcome
- **The focused individual** (developer / student / remote worker) — primary. Success = the journey reads
  as first-person — they feel seated in the vehicle, road and Vietnam scenery flowing toward them through a
  windshield (car) or over the handlebars (motorbike). Observable: switching to car or motorbike shows a
  cockpit foreground frame; the same immersive view appears in the always-on-top mini-window PiP.
- **The privacy-skeptical teammate** — unaffected. This is a **cosmetic, pure-view** change: the scene still
  reads no OS signal, owns no journey logic, accrues no distance. `/privacy-audit` stays PASS by
  construction (no new dependency that reads input/screen/location — only static image assets).

## Scope
### In
- **Car first-person cockpit** — a flat **dashboard + steering wheel + small dash gauges (speedometer,
  fuel) + A-pillar/mirror framing**, composited as a **foreground layer** over the existing forward road
  scene, so the road + scenery read as seen *through the windshield*.
- **Motorbike first-person cockpit** — a flat **handlebar + grips + gauge pod + fuel tank** foreground over
  the scene, so the road reads as seen *over the handlebars*.
- **Stylized flat art, license-clean** — CC BY 3.0 glyphs (steering wheel, speedometer, fuel gauge —
  Delapouite / game-icons.net; CC0 Wikimedia wheel as a zero-attribution fallback) + **original flat
  dash/handlebar/tank shapes**, recoloured to the journey palette. Sourced/placed/registered via
  `ui-asset-curator` (`/source-assets`); **CC BY attribution recorded in `assets/CREDITS.md`**.
- **Perspective tuning** of the existing road/horizon so it sits naturally below the windshield / over the
  handlebars (no ground-up camera rewrite — see Out).
- **Mode-gated rendering** — the cockpit frame renders **only** for `TravelMode.car` and
  `TravelMode.motorbike`; the cosmetic frame swaps with the mode (mirrors journey-view: the vehicle visual
  swaps with mode). All other modes are unchanged (see Out).
- **One scene, two surfaces** — the cockpit flows automatically to the **mini-window PiP**, since both
  surfaces render the same `JourneyGame` instance (ADR-0003).
- **Graceful degradation** — a cockpit asset that fails to load renders a placeholder (mirror the shipped
  `JourneySprites.loadAll` never-throws / placeholder pattern), never crashing the scene.

### Out
- **First-person for walk / run / bicycle / ship** — those four modes keep the current side-view sprite on
  the road. (Bicycle/ship/walk/run POV deferred; not requested.)
- **Photoreal / paid / commissioned cockpit art** — Kevin declined the asset-policy exception; may return
  later as its own slug. v1 is stylized-flat, license-clean only.
- **Animated or static rider hands/gloves** (present in the references) — **no license-clean source**;
  omitted in v1 (the cockpit reads as first-person without them). May be drawn original later.
- **A ground-up 3D first-person camera / perspective engine** — we composite a cockpit **foreground** over
  the existing receding-road renderer + tune the horizon; we do **not** rebuild the road into a true 3D
  projection.
- **Per-mode speeds / energy / fuel behaviour** — that is `journey-energy-model`. The cockpit is
  **cosmetic, single-speed**; the gauges are decorative, not driven by real speed/fuel.
- **Any change to journey logic** — engine, distance accrual, idle/active decisions, the route/map, stats.

## Constraints & assumptions
- **Pure-view invariant (hard, load-bearing).** The Flame scene + its siblings import **only** `dart:*`,
  `package:flame/*`, and the pure-Dart domain `TravelMode`. The cockpit is driven solely by the existing
  `applyState({moving, mode, reduceMotion, timeOfDayHours})` values (it keys off `mode`) — **no** Bloc, no
  `JourneyEngine`, no `ActivityPlugin`, no `MethodChannel`, no OS read. It decides no active-vs-idle and
  accrues no distance.
- **License-clean only.** CC0 preferred; CC BY 3.0 acceptable **with attribution recorded in
  `assets/CREDITS.md`** (the candidate glyphs are CC BY 3.0). No "free for personal use", no unclear
  licences, no paid art (Kevin's decision). New assets routed through `ui-asset-curator`.
- **Stylized flat, cohesive.** The cockpit must read as the same flat/illustrated family as the existing
  Kenney scene + tray icons — recoloured to the journey palette; not a photoreal outlier.
- **One scene, two surfaces.** The full window and the always-on-top mini-window PiP render the **same**
  `JourneyGame` instance (ADR-0003) — the cockpit must look correct at both the full size and the sized-down
  PiP, and must not break the PiP's frameless always-on-top behaviour or its battery/occlusion pause.
- **Reduce-motion honoured; first-frame parked look preserved.** The cockpit foreground is essentially
  static (no new motion), so reduce-motion is unaffected; the pre-`applyState` parked/stopped default and
  the idle/paused park behaviour stay intact.
- **Asset failure is non-fatal.** Mirror `JourneySprites`: `loadAll` never throws; a missing cockpit asset
  becomes a placeholder, and the failed path is exposed via the existing test seam.
- **Desktop targets:** macOS + Windows. Stack per `docs/architecture/overview.md`; scene is Flame
  presentation (ADR-0002).

## Resolved decisions (Kevin, 2026-06-25 — kickoff + approved art-direction spike)
1. **First-person cockpit = a FOREGROUND overlay over the existing forward road scene** (composite + tune
   the horizon), **not** a ground-up 3D camera rewrite. The shipped scene already recedes to a horizon, so
   the cockpit frame + perspective tuning deliver the POV read at bounded risk.
2. **Scope = car + motorbike ONLY.** walk / run / bicycle / ship keep the current side-view sprite.
3. **Art = stylized flat, license-clean** (CC BY 3.0 glyphs + original flat shapes; CC0 fallback wheel),
   recoloured to the palette and attributed in `CREDITS.md`. **Photoreal/paid declined** (may be a future
   slug).
4. **Rider hands omitted in v1** (no license-clean source).
5. **Cosmetic, single-speed, pure-view; flows to the mini-window PiP for free.** Gauges are decorative.

## Acceptance criteria
Each item is a checkable, observable statement and the ship gate. If it isn't testable, rewrite it.
These ACs ARE the contract — `tests/cases/journey-pov.md` references them by ID; there is no separate
acceptance-criteria file.

**Car cockpit**
- [x] AC-1 (car cockpit renders): Given the scene has received state with `mode == TravelMode.car`
      (via `applyState`, `currentMode == TravelMode.car`), When the scene renders, Then a first-person
      car cockpit **foreground** is composited over the road — a flat **dashboard + steering wheel +
      small dash gauges (speedometer + fuel) + A-pillar / mirror framing** — and the receding road +
      Vietnam scenery remain visible "through the windshield" (the road/horizon are not fully occluded;
      the unobscured viewport above the dash still scrolls per the existing scene). Observable via a
      cockpit-active test seam keyed off `currentMode` plus the cockpit asset paths being requested.
- [x] AC-2 (car gauges are decorative, not data-driven): Given the car cockpit is rendered, When the
      gauges are inspected, Then the speedometer and fuel glyphs are **decorative** — they are NOT wired
      to engine speed, distance, fuel, or any per-mode value (there is no such input on the scene).
      _proposed resolution to Open question "gauges static vs subtly reactive": gauges are **static
      decorative glyphs** in v1 — at most they may key off the existing `moving` flag for a parked-vs-
      running pose (the same binary the scene already has), and MUST NOT display a numeric/continuous
      readout of speed or fuel; reviewer may adjust toward a subtle needle hint that still reads only the
      existing `moving` flag._

**Motorbike cockpit**
- [x] AC-3 (motorbike cockpit renders): Given the scene has received state with
      `mode == TravelMode.motorbike` (`currentMode == TravelMode.motorbike`), When the scene renders, Then
      a first-person motorbike cockpit **foreground** is composited over the road — a flat **handlebar +
      grips + gauge pod + fuel tank** — and the road reads as seen **over the handlebars** (road/horizon
      still visible above the handlebar, not fully occluded). Observable via the cockpit-active seam +
      requested motorbike cockpit asset paths.
- [x] AC-4 (no rider hands in v1): Given either cockpit renders, When it is inspected, Then **no rider
      hands / gloves** are drawn (omitted in v1 per Resolved decision 4) — the cockpit reads as
      first-person without them.

**Cockpit framing (shared)**
- [x] AC-5 (framing ratio leaves the road readable): Given a cockpit renders at the full-window size,
      When the viewport is measured, Then the cockpit foreground occupies the **lower portion** of the
      viewport and leaves the road/horizon read clearly visible above it. _proposed resolution to Open
      question "cockpit height / road framing ratio": target the cockpit foreground at **≈30–40% of the
      viewport height** (tuned horizon sitting just above the dash/handlebar line), with the same ratio
      applied proportionally at the PiP; flame-game-developer pins the exact value in build, reviewer may
      adjust._

**Mode-gating**
- [x] AC-6 (only car + motorbike show a cockpit): Given the scene receives `mode` in
      {`walk`, `run`, `bicycle`, `ship`}, When it renders, Then **no cockpit foreground** is drawn and the
      current **side-view vehicle sprite** for that mode is shown unchanged (the existing
      `currentVehicleAsset` / vehicle-sprite path for that mode), exactly as the shipped scene behaves.
- [x] AC-7 (clean revert on mode-switch away): Given the scene is rendering a cockpit (`car` or
      `motorbike`), When `applyState` is next called with a non-cockpit mode (e.g. `walk`), Then the
      cockpit foreground is fully removed with **no leftover cockpit pixels / no residual cockpit layer**
      and the side-view sprite for the new mode is shown. _proposed resolution to Open question "non-car/
      bike modes mid-session"; reviewer may adjust._
- [x] AC-8 (restore on mode-switch back): Given the cockpit was reverted by a switch to a non-cockpit
      mode, When `applyState` is later called again with `car` or `motorbike`, Then the corresponding
      cockpit foreground is restored cleanly (cockpit-active seam true again), matching AC-1 / AC-3.

**Pure-view & separation**
- [x] AC-9 (separation invariant preserved): Given the cockpit is added to the Flame scene, When the
      scene's source and its siblings are inspected, Then they still import **only** `dart:*`,
      `package:flame/*`, and the pure-Dart domain `TravelMode` — **no** `flutter_bloc`, `JourneyEngine`,
      `ActivityPlugin`, `MethodChannel`/platform channel, or OS idle/lock/screen/location read (mirrors
      journey-scene-v2's separation AC; the only Flutter surface remains the asset bundle/manifest used
      by `JourneySprites`).
- [x] AC-10 (cosmetic-only — no journey state touched): Given the cockpit renders for `car`/`motorbike`,
      When the journey runs, Then the engine's `distanceKm` / progress / elapsed / idle-vs-active
      decisions are **byte-for-byte unchanged** from the no-cockpit baseline for the same inputs — the
      cockpit reads no OS signal, decides no active-vs-idle, and accrues no distance (cosmetic, single-
      speed, pure-view).

**One scene / two surfaces**
- [x] AC-11 (cockpit on both surfaces via the shared game): Given the full window and the always-on-top
      mini-window PiP render the **same** `JourneyGame` instance (ADR-0003), When `mode` is `car` or
      `motorbike`, Then the cockpit appears on **both** surfaces, correctly scaled at the sized-down PiP
      (per the AC-5 ratio), with the road still readable through/over it at the PiP size.
- [ ] AC-12 (PiP behaviour unbroken): Given the cockpit renders in the PiP, When the PiP is exercised,
      Then it does **not** break the PiP's frameless / always-on-top behaviour nor its occlusion/visibility
      pause (the cockpit is static foreground art and does not add per-frame work that would defeat the
      pause-when-hidden battery guarantee). _(Real-OS PiP confirmation may be a manual carry, consistent
      with prior slices.)_

**Graceful degradation**
- [x] AC-13 (cockpit asset failure is non-fatal): Given a cockpit asset (e.g. steering-wheel glyph,
      dash shape) is absent from the bundle or faults while decoding, When the scene loads via the
      existing `loadAll` never-throws pattern, Then a neutral **placeholder** is drawn in its place, the
      failed path is surfaced through `failedAssetPaths` and `hasPlaceholderAssets`, and the scene never
      crashes or blanks.

**Reduce-motion & parked/idle regression**
- [x] AC-14 (no new motion + reduce-motion honoured): Given the cockpit renders, When reduce-motion is
      on, Then the cockpit introduces **no new motion** (it is static foreground art), and the existing
      reduce-motion presentation (suppressed scroll, state still conveyed) is unchanged by adding the
      cockpit.
- [x] AC-15 (first-frame parked + idle/paused unchanged): Given the scene before its first `applyState`
      (`hasReceivedState == false`) and given an `idle`/`paused` state, When it renders for `car`/
      `motorbike`, Then the first-frame parked/stopped default and the idle/paused park behaviour
      (road + objects stopped, "Paused — idle" overlay) are preserved — the cockpit overlays them without
      altering either.

**Stylized-flat & license-clean**
- [ ] AC-16 (cohesive stylized-flat art): Given the cockpit renders, When its art is reviewed, Then it
      reads as the same **flat / illustrated** family as the existing Kenney-flat scene (recoloured to the
      journey palette), not a photoreal outlier (content/cohesion review gate for this slice).
- [x] AC-17 (every CC BY asset attributed): Given the cockpit ships new assets, When `assets/CREDITS.md`
      is inspected, Then **every** new cockpit asset that requires attribution (the CC BY 3.0 glyphs) is
      listed with its **source + licence**, and the scene loads no cockpit asset absent from CREDITS
      (observable: each requested cockpit asset path has a matching CREDITS entry).

### Non-functional
- [ ] NFR-1 Performance: With both cockpits' assets loaded, the cockpit foreground adds **no per-frame
      motion work** (static composited layer) and the scene holds **≥30fps** on macOS + Windows at **both**
      surfaces (full window and the sized-down PiP) under `active` — mirrors journey-scene-v2 NFR-1.
      _(Automated guards: no per-frame allocation / no new per-frame geometry for the cockpit; on-device
      ≥30fps measurement is a manual carry before public release, consistent with prior slices.)_
- [x] NFR-2 Security/Privacy (gating): The cockpit is **pure-view** — it adds **no** new OS signal,
      input, screen, or location read; it adds only **static image assets**. `/privacy-audit` stays
      **PASS** by construction. **Gating** — ship blocks until `/privacy-audit` returns PASS.
- [ ] NFR-3 Accessibility: The OS/app "reduce motion" preference is honoured (per AC-14); the cockpit
      conveys the travel mode **without relying on colour alone** (distinct car-vs-motorbike silhouette,
      not just hue); and it does **not** trap focus or obscure essential journey readouts (the road read
      and any "Paused — idle" overlay stay visible).

## Open questions
- [ ] **Cockpit height / road framing ratio** — how much of the viewport the cockpit occupies (and the
      tuned horizon line) so the road reads as "ahead" without crowding the scene, at both full size and the
      sized-down PiP — owner: flame-game-developer (tune in build; pin a target in the spec)
- [ ] **Gauges static vs subtly reactive** — are the speedometer/fuel glyphs purely decorative (static), or
      may a needle hint at moving-vs-parked (still cosmetic, no real speed/fuel)? — owner: product-domain-expert
- [ ] **Non-car/bike modes mid-session** — confirm switching mode away from car/bike cleanly reverts to the
      side-sprite view with no leftover cockpit — owner: flame-game-developer

## Related
- Backlog framing + spike outcome: [planning/backlog/journey-pov.md](../../planning/backlog/journey-pov.md)
- Carved from: [specs/journey-scene-v2/spec.md](../journey-scene-v2/spec.md) (request #2) — shares the scene + the mini-window PiP
- Parent epic / Wave 2: [planning/backlog/wave2-feature-requests.md](../../planning/backlog/wave2-feature-requests.md)
- Parked follow-up: [planning/backlog/visual-polish.md](../../planning/backlog/visual-polish.md)
- Architecture: [docs/architecture/](../../docs/architecture/) — ADR-0002 (Flutter/Bloc/Flame stack), ADR-0003 (single-window two-mode / shared `JourneyGame`)
- Spike assets + report: `scratchpad/pov-spike/` · approved mock: `scratchpad/pov-cockpit-direction.html`
