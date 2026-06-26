# Visual polish — scene beautification, dynamic drive & vehicle choice (EPIC)

**Intake date:** 2026-06-25
**Requested by:** Kevin (Tuyen Vo)
**Size (rough):** XL (epic)
**Status:** FRAMED (Phase 0) — epic broken into 4 child slices; promote Wave 1 with `/new-feature`.

> Expanded 2026-06-25 from the original parked "hi-res scene art" note into a 4-ask epic after `journey-pov`
> shipped. Two product decisions taken at capture time (Kevin, 2026-06-25): **vehicle pick = cosmetic-only
> override** (journey truth untouched); **F1-curve and cockpit-lean ship as two separate slices.**

## Why
**Who it's for:** the focused individual — the journey is a calm, ambient companion in the main window + the
always-on-top mini-window PiP, not a game they actively pilot. The scene now *functions* (winding road,
parallax scenery, first-person cockpit, decoupled cosmetic scroll) but Kevin's eye says it still looks
placeholder-grade and static, and one expected control is missing. Four user-felt outcomes:
1. **"It looks cheap / flat."** Today's art is whatever CC0 asset was available, with known gaps (beach/coast
   + side-view animals omitted at journey-scene-v2 AC-8 for lack of a cohesive license-clean source). Want:
   *the trip looks beautiful enough to keep on-screen all session.* (House direction stays **stylized-flat** —
   photoreal was declined for journey-pov; "more beautiful" = higher-craft stylized, not photoreal.)
2. **"The road feels tame."** Gentle winding road today; Kevin wants **F1-track-grade sweeping, animated bends**
   — *cornering reads as a real, dynamic drive.*
3. **"Cornering doesn't feel physical."** The cockpit holds level through bends; Kevin wants it to **lean/tilt
   into the curve** — *I feel the corner from the cockpit.* Extends the shipped `journey-pov` cockpit.
4. **"I can't pick my vehicle."** Six skins exist (walk/run/bicycle/motorbike/car/ship) but there's **no UI to
   choose one** — `TravelMode` is set by the activity/engine pipeline, not the user. Want: *I can choose how I
   travel* (cosmetic only — see decision below).

**Why now:** `journey-pov` shipped 2026-06-25 and explicitly parked this `[blocked by: journey-pov]`. The
cockpit + decoupled-scroll seams now exist, so lean-into-curve and dramatic road have a foundation.

## Domain notes
**Personas:** the focused individual (all four asks). (`docs/domain/personas.md` is still an empty template —
inferred from shipped slices.) **Edge cases / tensions flagged (not decided):**
- **F1 curve vs "calm companion" tone** — an aggressive track risks pulling focus *toward* the scene during a
  work session. Likely needs a "sweeping but smooth" ceiling, not literal racetrack chicanes.
- **Cockpit lean vs motion-sickness / reduce-motion** — a tilting first-person frame (esp. in peripheral PiP)
  is a known nausea trigger. Lean MUST be gated by the existing reduce-motion override + a max-tilt clamp.
- **Curve (#2) and lean (#3) share the bend signal** — design with the same source even though shipped as two
  slices (lean tuned against the final curve).
- **"Vehicle" == `TravelMode`? — RESOLVED at capture:** **cosmetic-only override.** A user pick changes the
  *displayed* vehicle/cockpit only; engine `mode`/distance/progress/idle are untouched (mirrors the v1
  single-speed, cosmetic-`TravelMode` invariant). Must state forward-compat with the deferred
  `journey-energy-model` (per-mode speeds): a cosmetic pick must NOT later change accrual.

**Conflict with `docs/domain/business-rules.md`:** none codified — the file is still the empty template. The
pure-view / cosmetic / single-speed / calm-tone / reduce-motion invariants live only in spec + code comments,
not in `docs/domain`. Codifying them is overdue if this epic is promoted (see candidates).

## Candidate domain updates
Flagged only — promotion-time decisions.
- [ ] candidate glossary term: **"travel mode"** (activity-derived, cosmetic, single-speed) — formalize.
- [ ] candidate glossary term: **"vehicle selection"** — a cosmetic user-choice layered on top of travel mode.
- [ ] candidate glossary term: **"cockpit lean"** (tilt-into-curve cockpit animation).
- [ ] candidate glossary term: **"house art direction = stylized-flat"** (photoreal declined).
- [ ] candidate business rule: **user-chosen vehicle is cosmetic only — does NOT alter distance/progress/idle**
  (the confirmed decision; mirror the single-speed invariant) + forward-compat with `journey-energy-model`.
- [ ] candidate business rule: **calm-tone ceiling** — scene drama (curvature, cockpit tilt) must not pull
  focus from the work session; define a max-intensity bound.
- [ ] candidate business rule: **reduce-motion override applies to cockpit lean + dramatic curve** (+ a
  motion-sickness clamp).
- [ ] candidate business rule (meta): **codify the pure-view / cosmetic invariant in `business-rules.md`** — it
  governs every visual slice but is undocumented in `docs/domain`.

## Feasibility (high-level)
The scene is a clean **pure-view** stack: `journey_game.dart` + siblings import only `dart:*`,
`package:flame/*`, `TravelMode`; state enters via one `applyState({moving, mode, reduceMotion, timeOfDayHours})`
call. `TravelMode` is **engine-owned journey truth** (set from `JourneyProgress`, read verbatim by
`JourneyCubit`) — the load-bearing fact behind the vehicle picker.
- **#1 art (`journey-scene-art-v3`)** — **M**, curation-heavy not code-heavy. Flows through the existing
  `journey_assets` manifest + `journey_sprites` graceful-degradation loader; new beach/coast/animal
  `SideObjectKind`s are additive. Risk: the CC0 + cohesive-art-direction constraint is exactly what failed
  before for beach/animals → **a short art-direction spike gates it.** Keep `FilterQuality.low` + bounded pool;
  every asset needs a CREDITS row (journey-pov AC-17 pattern). No ADR.
- **#2 F1 curve (`journey-dynamic-curve`)** — **M** (S if pure tune). Sharper/animated bends are reachable by
  tuning `RoadGeometry`'s existing parameterised curve (raise `maxHeading`/amplitude, shorten `segmentLength`);
  animated bends must fold time-variation into the existing **scroll-phase** input (no wall-clock → goldens
  hold). **Key risk:** side objects spawn at a fixed *longitudinal* cadence but even-spacing (AC-7) is measured
  as *arc-length* (±20%) — a sharper bend raises arc-length variance and **can fail AC-7**, so it may need
  arc-length-aware spawn cadence (a small model rework → candidate ADR). O(1) integral → no ≥30fps risk.
- **#3 cockpit lean (`journey-cockpit-lean`)** — **S–M**. Tilt the `CockpitPainter` output by a bounded angle
  sampled from the existing curve-at-camera (`centreLineOffsetAt(t≈1)`) — stays pure-view (no new OS/clock).
  **Hard requirements:** gate on `_reduceMotion` (upright when on, like `_bob()`); bounded + eased + low-pass
  (motion-sickness); rotation of the painter output only (keeps separation + deterministic goldens). Car/
  motorbike only.
- **#4 vehicle picker (`vehicle-picker`)** — **M** (cosmetic option). New persisted preference
  (`shared_preferences`) → new field through `JourneyCubit` → `JourneyViewState` → `applyState`, plus a picker
  widget in `journey_screen.dart`. The override must resolve the cockpit-vs-side-view branch consistently
  (pick "car" while engine mode is "walk" → show the car cockpit) **without leaking into engine truth.**

## Candidate ADRs
- [ ] **ADR: user-selected vehicle vs engine-owned `TravelMode` — precedence & journey-truth boundary.**
  Decision taken: **cosmetic skin override, journey truth untouched**; ADR formalizes it + the
  `journey-energy-model` forward-compat clause. **Required before `vehicle-picker` spec.**
- [ ] **ADR: dynamic-curve model change & its effect on even-spacing (AC-7) + ≥30fps (NFR-1).** Only if the
  change exceeds a parameter tune (i.e. spawn cadence becomes arc-length-aware / AC-7 tolerance re-derived).
- [ ] *(spec ACs, not an ADR)* cockpit-lean motion-safety (bounded angle, reduce-motion gate, optional toggle).
- [ ] *(not an ADR)* hi-res art direction — a `/source-assets` curation effort + CREDITS.

## Headline success signals (epic-level)
1. **Sharper animated curves than baseline.** Peak curvature exceeds the shipped journey-scene-v2 maximum by a
   clear margin and the bend sweeps over time, while side-object spacing variance stays within ±20% and
   reduce-motion freezes the sweep. *(Auto: curvature, spacing, reduce-motion gate. Manual: "feels F1-like.")*
2. **Cockpit leans into curves, proportionally and gated.** Tilt is non-zero on a bend, signed to match curve
   direction, monotonic in curve magnitude up to a clamped max, and **exactly zero when reduce-motion is on**
   or curvature is zero. *(Auto: sign/magnitude/clamp/zero. Manual: reads naturally, not nauseating.)*
3. **Vehicle picker swaps skin instantly, no state bleed.** Selecting a vehicle changes the on-screen vehicle +
   cockpit within one frame, the choice **persists across restart**, and **no journey state (distance/progress/
   idle) changes** as a result. *(Auto: state-isolation, persistence, render reflects choice. Manual: each skin
   looks correct.)*
4. **Every new asset is higher-res and license-clean.** Each newly-sourced asset has greater resolution than
   its predecessor (or is net-new) AND has a CC0/license-clean `CREDITS.md` entry with source + licence.
   *(Auto: resolution compare, CREDITS completeness. Manual: stylized-flat cohesion.)*
5. **New scenery categories actually appear.** Beach/coast + animal side-objects show up in the spawn rotation
   during a journey (not just shipped as files), without breaking the spawn cadence. *(Auto: reachable in pool,
   cadence unchanged. Manual: variety + placement plausible.)*

## Breakdown
Delivered as independently-shippable slices (wave discipline — each enhances a *shipped* component as a NEW
slug, never a re-`/implement`). Promote each with `/new-feature <slug>` in wave order.

| Wave | Slice (slug) | Scope (one line) | Depends on |
|------|--------------|------------------|------------|
| 1 | [journey-scene-art-v3](journey-scene-art-v3.md) | Hi-res cohesive stylized-flat re-source of scene + side scenery; closes the deferred beach/coast + animals (journey-scene-v2 AC-8). Opens with an art-direction spike. | journey-pov ✅ |
| 2 | [journey-dynamic-curve](journey-dynamic-curve.md) | F1-style sweeping/animated bends; preserve even-spacing (AC-7, arc-length-aware if needed) + ≥30fps. Enhances journey-scene-v2. | — |
| 2 | [journey-cockpit-lean](journey-cockpit-lean.md) | Cockpit tilts into the curve — bounded, eased, reduce-motion-gated. Enhances journey-pov. | [blocked by: journey-dynamic-curve] |
| 3 | [vehicle-picker](vehicle-picker.md) | UI to choose your vehicle (cosmetic-only override) + persisted preference + Bloc plumbing. | [blocked by: precedence ADR] |

Sequencing notes: `journey-scene-art-v3`'s spike is the only true gate. `journey-dynamic-curve` is the highest
risk-to-invariants slice (AC-7) and deserves its own golden-review cycle; sequence it after art-v3 to reduce
golden churn. `journey-cockpit-lean` follows the curve so the lean is tuned once. `vehicle-picker` must not
start until its precedence ADR is accepted.

## First step
Promote Wave 1: `/new-feature journey-scene-art-v3` (its spec opens with the art-direction spike).
