# Journey View (Flame POV road scene)

**Status:** shipped (2026-06-24)
**Owner:** Kevin (Tuyen Vo)
**Last updated:** 2026-06-24

## Problem
Vietnam Focus Journey turns real focus time into a virtual road trip — but the shipped
`journey-engine` only produces *numbers* (`distanceKm`, `state`, `mode`, the time counters). Numbers
don't motivate anyone. **This slice is the main emotional screen**: a stylized 2D first-person (POV)
road scene that makes "I am travelling because I am focused" *felt*, not just reported.

The scene must be a faithful, honest mirror of engine state and nothing more. When the engine says
`active`, the road scrolls forward, side objects stream past, and the vehicle's running/engine
animation plays. When the engine says `idle`/`paused`, the road stops, the vehicle parks, and a quiet
"Paused — idle" message appears. The scene **owns no activity logic** — it never reads idle seconds,
never decides active vs idle, never accrues distance. It is a pure *view* of the journey Bloc, which
in turn reflects the `JourneyEngine`. This separation is what keeps the product honest: there is one
source of truth for "are we moving," and the screen can't quietly disagree with it.

Visually it is a fake-3D trapezoid road (wide at the near camera, narrowing to a horizon), scrolling
lane markings that move toward the viewer to create forward motion, parallax roadside objects (v1:
trees, houses, street lights, road signs) that start small at the horizon and grow as they near
the camera, a day/night tint, and the current vehicle **skin** sprite. In v1 the skin is cosmetic
only — walk/bike/car share one speed; only the sprite differs.

Two hard constraints shape the build: (1) it must run **smoothly on desktop** (steady frame rate,
no jank when toggling active↔idle), and (2) it must consume **only license-clean assets** curated via
`/source-assets` and recorded in `assets/CREDITS.md` — nothing drawn from scratch, nothing with an
unclear licence.

## User & outcome
- **The focused individual** (developer / student / remote worker) — the primary beneficiary. The POV
  scene is the screen they glance at to feel momentum: travelling when they work, parked when they
  step away. Success = the scene's motion unmistakably tracks their focus, with no perceptible lag
  between resuming work and the road moving again.
- **The privacy-skeptical teammate** — benefits indirectly: because the view is a pure consumer of
  engine state and reads no OS signals itself, it adds **zero** new privacy surface. A glance at the
  code shows the scene only ever receives `state`, `mode`, and `distanceKm` — never input data.

**Observable success:** with the app driven by a mock activity source, toggling active→idle visibly
**stops** the road within one tick and parks the vehicle with a "Paused — idle" message; toggling
idle→active visibly **resumes** scrolling within one tick. The vehicle skin matches the engine's
`mode`. The scene holds a smooth frame rate on desktop and references only assets present in
`assets/CREDITS.md`.

## Scope
### In
- **A Flame `Game`/scene embedded in a Flutter widget**, placed on the main journey screen and driven
  entirely by the journey Bloc's state (the Bloc adapts `JourneyEngine` output — see `journey-engine`).
- **Fake-3D POV road**: a trapezoid road rendered wide at the near camera and narrowing to a horizon,
  with **scrolling lane markings** that move toward the viewer to convey forward motion.
- **Parallax roadside objects** — v1 ships **four kinds: trees, houses, street lights, road signs** —
  that spawn small near the horizon and scale up as they travel toward the camera, at depth-appropriate
  speeds. (Narrowed during Phase-4 review, H-2: distant **background** parallax layers — mountains,
  rice fields, clouds — are deferred to a later polish wave so the scene ships no loaded-but-unrendered
  assets. See Out.)
- **Vehicle skin sprite** reflecting the engine's `mode` (cosmetic in v1: walk/bike/car all move at
  the same scene speed; only the sprite differs). Running/engine animation while active; parked pose
  while idle.
- **Two visual states bound to engine `state`:**
  - **active** → road + lane lines scroll, side objects stream past, vehicle animation plays.
  - **idle / paused** → road and objects stop, vehicle parks, a quiet "Paused — idle" overlay shows.
- **Day/night tint** over the scene (a cosmetic ambient layer). v1 may derive it from a simple
  injected/clock-based notion of time-of-day; full weather is out.
- **State-to-motion binding**: the scene subscribes to Bloc state and starts/stops motion within one
  tick of a state change, with no jarring jump (a brief ease is acceptable, see open questions).
- **Smooth desktop performance**: steady frame rate, bounded object pool (recycle off-screen objects
  rather than unbounded spawning), no per-frame allocations in the hot path, animation suspended when
  the scene isn't visible.
- **Assets sourced via `/source-assets`** (`ui-asset-curator`), every one recorded with licence +
  attribution in `assets/CREDITS.md`. The scene loads only those assets.

### Out
- **Any activity/idle logic, distance accrual, or persistence** — owned by `journey-engine`
  (consumed) and the activity ticker (app layer). The scene only *reads* state.
- **Province chain, map, start-province/direction, "% of country", checkpoints** — that is
  `route-progress`. The scene shows generic forward travel, not geographic position.
- **Stats, streaks, badges, settings, onboarding/privacy screens** — that is `local-stats`.
- **Per-mode speeds / energy / fuel** — v2 (`journey-energy-model`). v1 skins are cosmetic; one speed.
- **Distant background parallax layers** (mountains, rice fields, clouds) — deferred to a later polish
  wave (H-2, 2026-06-24). v1 ships the procedural sky/ground + the four roadside object kinds only.
- **Rive character polish, real weather system, 3D** — deferred (Flame-only 2D for v1; Rive → v2).
- **Mini-window / always-on-top PiP / tray rendering** — v2 (`mini-window`).
- **Drawing original art** — all visuals come from curated free assets, not hand-authored sprites.

## Constraints & assumptions
- **Pure view; one source of truth.** The scene owns no journey logic and never reads OS signals. It
  binds to the journey Bloc, which reflects `JourneyEngine`. If the Bloc says stopped, the scene stops.
- **License-clean assets only.** Every visual asset is CC0/permissive, sourced via `/source-assets`,
  and recorded in `assets/CREDITS.md`. Nothing with an unclear licence ships; nothing drawn from
  scratch.
- **Smooth on desktop (hard constraint).** Steady frame rate on macOS + Windows; object pooling, no
  hot-path allocations, animation paused (not just hidden) when the scene isn't visible.
- **Cosmetic skins, single speed (v1).** `mode` selects the sprite only; scene scroll speed is shared
  across modes. Per-mode speed / energy is v2.
- **Stack per `docs/architecture/overview.md`:** Flutter desktop, Bloc, Clean Architecture, **Flame**
  for the scene (ADR-0002). The scene is *presentation*; it depends inward on domain via the Bloc.
- **Motion reflects "travelling vs stopped," not distance math.** Distance is the engine's job; the
  scene's only interpretation is binary forward motion while travelling, stopped while idle/paused.

## Resolved decisions
> All six open questions resolved by Kevin on 2026-06-23 (spec reviewed + approved). Plus four
> domain-expert flags given safe v1 defaults below.

- [x] **Active↔idle transition feel** — **short ease.** A short bounded ramp (≤ ~0.5 s) to decelerate
      to a stop / accelerate from rest. Must still read unmistakably as "stopped within one tick" — the
      ease is capped so the stopped state is never ambiguous.
- [x] **Scene scroll speed ↔ engine state mapping** — **binary.** A single constant scroll speed while
      `active`, zero while `idle`/`paused`. Never proportional to `distanceKm`, elapsed time, or any
      engine number (matches speed-only, cosmetic skins).
- [x] **Day/night source** — **injected clock.** Tint derives from an injected/clock-based notion of
      time-of-day so it is deterministic, testable, and cheap. Full weather remains out of scope.
- [x] **"Paused — idle" copy** — **generic.** The overlay reads "Paused — idle" with no configured
      threshold value, avoiding coupling to the configurable threshold owned by `local-stats`.
- [x] **Live distance counter ownership** — **plain Flutter widget**, layered over the Flame scene, not
      rendered by the scene. Keeps the scene purely the road; the counter is easier to style/localise.
- [x] **Asset style cohesion** — **use a single Kenney pack** (CC0) as the primary source for road,
      side objects, and vehicle skins, so the scene reads as one consistent style. `ui-asset-curator`
      may supplement from other CC0/permissive sources only where Kenney lacks an asset, keeping the
      style cohesive; every asset is recorded in `assets/CREDITS.md`.
- [x] **`idle` vs `paused` visual** — **identical in v1** (both render as "stopped + parked + 'Paused —
      idle' overlay"). Safe under the default `G = T = 5 min`, which makes the engine's pre-threshold
      `idle` band empty. Distinct copy/visuals for the two → deferred (revisit if the threshold/grace
      knobs ever diverge).
- [x] **Reduced motion (accessibility)** — **honour the OS/app "reduce motion" preference in v1**:
      reduce or replace the scrolling motion with a static/minimal-motion presentation that still
      conveys active vs stopped. Exact visual treatment is an implementation detail for the Flame
      developer; the requirement (honour the preference, still convey state) is fixed.
- [x] **First-frame / pre-state behaviour** — before the Bloc emits a real `state`, the scene renders
      the **parked/stopped** look (no motion). The same stopped default applies to any unrecognised /
      loading / error state.
- [x] **Missing or failed asset at runtime** — **degrade gracefully**: render a neutral placeholder
      (or the parked vehicle) and continue; never crash the scene or block the screen on a missing
      sprite.

## Related
- Epic: [planning/backlog/vietnam-focus-journey.md](../../planning/backlog/vietnam-focus-journey.md) · Wave 1 (v1)
- Backlog slice: [planning/backlog/journey-view.md](../../planning/backlog/journey-view.md)
- Upstream (shipped): [specs/journey-engine/spec.md](../journey-engine/spec.md) — provides `state`, `mode`, `distanceKm` via the journey Bloc · **[blocked by: journey-engine]**
- Plan detail: `planning/backlog/vietnam_focus_journey_plan.md` §13 (First-Person Journey View), §0.A.1/§11 (pacing → flavour), §0.A.4 (cosmetic skins), §22 step 6b/7 (source-assets then Flame scene)
- Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md)
- Architecture: [docs/architecture/overview.md](../../docs/architecture/overview.md) — "Journey view (Flame scene)" in Components; ADR-0002 (stack)
