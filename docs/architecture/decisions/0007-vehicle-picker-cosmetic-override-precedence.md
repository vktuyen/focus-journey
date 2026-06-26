# ADR-0007: Vehicle picker — cosmetic skin-override precedence over engine-owned `TravelMode`

- Status: accepted (2026-06-26)
- Date: 2026-06-26
- Deciders: Kevin (Tuyen Vo)

## Context

> This ADR is the **gating prerequisite** for the Wave-3 `vehicle-picker` slice
> (`planning/backlog/vehicle-picker.md`, under the `visual-polish` epic). The product decision
> ("the user's vehicle pick is **cosmetic-only** — journey truth untouched") was **taken at capture**
> (Kevin, 2026-06-25); this ADR's job is to frame that decision rigorously as architecture rules an
> implementer follows, **not** to re-open it.
>
> It **supersedes no prior ADR** — it is net-new. It **builds on** ADR-0002 (Flutter/Bloc/Flame stack —
> the Flame scene is the presentation surface that owns the displayed skin), ADR-0003 (single-window
> two-mode / shared `JourneyGame` — so the chosen skin renders identically in the full window and the
> always-on-top mini-window PiP, with no second wiring), and ADR-0005 (custom routes — the route-start
> flow this picker hooks into at the presentation layer).

**The problem.** Six cosmetic vehicle skins exist (walk / run / bicycle / motorbike / car / ship) but there
is **no production UI for the user to choose one**. Today the displayed vehicle is driven entirely by the
engine/activity pipeline: `TravelMode` is **engine-owned journey truth** — set on `JourneyProgress`/
`JourneyEngine` (`journey_engine.dart:213` `TravelMode mode;`), read **verbatim** by `JourneyCubit`
(`updateFromEngine`, `journey_cubit.dart:42` reads `engine.mode`), surfaced on `JourneyViewState.mode`, and
applied to the scene by `JourneyGame.applyState({required TravelMode mode, …})`
(`journey_game.dart:139-146`), which selects the sprite and the cockpit-vs-side-view branch off `_mode`
(`journey_game.dart:71, 193, 210, 311`). A throwaway `dev-mode-switcher` (shipped 2026-06-26) let a
developer poke the mode for testing, but it was explicitly debug-only tooling, not a user-facing selector.

**Why now.** `journey-cockpit-lean` has shipped, the cockpit + decoupled-cosmetic-scroll seams are stable,
and the dev-mode-switcher needs to be replaced by a real production selector. The `visual-polish` epic
breakdown gates `vehicle-picker` on **"the precedence ADR is accepted."**

**The invariants at stake.** This slice must not erode three established invariants:

- **Cosmetic-only `TravelMode` (v1 single-speed invariant).** The engine comment is explicit:
  "The cosmetic travel skin. Settable; **does not affect accrual** in v1 (AC-13)"
  (`journey_engine.dart:212`). A single shared virtual rate drives all modes
  (`journey_engine.dart:161`). The vehicle pick must preserve this byte-for-byte: `mode` /
  `distanceKm` / progress / elapsed / idle accrual stay untouched.
- **Pure-view scene.** `JourneyGame` and siblings take plain values via `applyState` and never read the
  engine, Bloc, the activity plugin, the OS, or a clock (journey-pov AC-9/AC-10; journey-cockpit-lean
  AC-11/AC-12). The picker preference must not breach that — it enters the scene only as the same
  `mode:` value `applyState` already takes.
- **No new engine coupling.** `JourneyCubit.updateFromEngine` is a **pure reader** of the engine
  (`journey_cubit.dart:5, 29, 38-42`). The engine must remain unaware that a user preference exists.

**The forward-compat tension (the load-bearing reason this is an ADR).** A deferred slice,
`journey-energy-model`, will introduce **per-mode speeds** — i.e. `TravelMode` will become
**engine-affecting** (speed differs by mode). At that point there will be **two different mode concepts**
in play: an engine-owned `TravelMode` that drives speed/accrual, and a cosmetic skin the user picked.
Without an explicit boundary recorded **now**, a future implementer could easily wire the cosmetic pick
back into accrual ("the user picked 'car', so make them go car-speed"), silently breaking the cosmetic-only
invariant and turning a display preference into a way to game distance. This ADR exists to make that
boundary impossible to cross by accident.

**Two new requirements (Kevin, 2026-06-26)** the architecture must accommodate (they do not change the core
decision):

- **Two entry points for the picker:** (a) an ongoing/persistent place (Settings / journey overlay — change
  any time), and (b) **at new-route start** (the route-planner / begin-journey flow, ADR-0005). Both must
  read/write the **same single persisted preference**, and the route-start picker is **pre-seeded** with the
  current saved vehicle so the two stay in sync.
- **Richer iconography:** the picker uses distinct per-mode vehicle icons (license-clean, via
  `ui-asset-curator`) rather than a text dropdown, to make choosing feel fun.

## Decision

**The user's vehicle pick is a COSMETIC SKIN OVERRIDE applied at a presentation seam — it changes only the
*displayed* vehicle sprite + first-person cockpit, never engine truth — and the boundary that keeps it
display-only is permanent (it survives the future per-mode-speed model).**

### (1) Cosmetic skin override, never engine truth — RATIFIED.

The picked vehicle is a **view/settings-layer preference**, call it `vehiclePreference: TravelMode?`. It
overrides only the **displayed** `mode` and **nothing else**. The engine's `mode`, `distanceKm`, progress,
elapsed, and idle accrual remain **byte-for-byte identical** to a build with no picker — this mirrors the
shipped v1 invariant (`journey_engine.dart:212`, single shared rate `:161`) and the pure-view scene
invariant (journey-pov AC-9/AC-10, journey-cockpit-lean AC-11/AC-12). The engine and
`JourneyCubit.updateFromEngine` (the pure engine reader) **must not read, reference, or depend on**
`vehiclePreference` in any way.

### (2) Precedence rule + data-flow seam — RATIFIED.

The existing display pipeline is:

```
JourneyEngine.mode (engine truth, cosmetic-in-v1)
  → JourneyCubit.updateFromEngine (pure reader)
  → JourneyViewState.mode
  → JourneyScreen
  → JourneyGame.applyState(mode: …)   // sprite + cockpit branch off this one value
```

The override is applied **at the presentation seam**, between "what the engine says" and "what
`applyState` is handed". Concretely:

- **Precedence:** the value passed to `applyState(mode:)` is `vehiclePreference ?? engine-derived mode`
  — i.e. **when a user pick exists, the user pick wins for display**; when none exists, the
  engine-derived cosmetic mode is shown (today's behaviour, so the picker is purely additive).
- **Where it lives:** the preference is held by the **view/settings layer** (a settings cubit/source the
  `JourneyCubit` or `JourneyScreen` composes), and the effective display mode is resolved **at or above
  `JourneyViewState`** — never inside `updateFromEngine` reading the engine, and never inside the engine.
  The recommended shape is that the effective display mode is computed where the view state is assembled,
  so `JourneyGame.applyState` continues to take exactly **one** `mode:` value and the scene stays unaware
  there is an override at all (pure-view preserved — the scene's contract does not change).
- **Cockpit-vs-side-view branch resolves off the effective display mode, consistently.** Because the
  scene branches the cockpit-vs-side-view and the sprite off the single `_mode` it is handed
  (`journey_game.dart:193, 210, 311`), overriding that one value resolves the whole render coherently:
  picking **"car" while the engine cosmetic mode is "walk" shows the car cockpit** — no split-brain where
  the sprite and the cockpit disagree.

### (3) Persistence — RATIFIED, no new dependency.

`vehiclePreference` persists across restart via **`shared_preferences`**, which is **already a project
dependency** (`pubspec.yaml:39` `shared_preferences: ^2.5.5`) — this adds **no new dependency** for
persistence. It is stored in a **view/settings-layer store** (its own key/repository), **not** in engine
state and **not** in the `RoutePlan`/`RouteRepository` route store (ADR-0005). On startup the saved
preference seeds the effective display mode before the first `applyState`.

### (4) Two entry points, one source of truth — RATIFIED.

Both the persistent picker (change any time) and the route-start picker (ADR-0005 begin-journey flow)
read and write the **same single `vehiclePreference`**. The route-start picker is **pre-seeded** with the
current saved value, and committing the route writes the (possibly changed) preference back to the same
store, so the two surfaces never drift. This couples the picker to the route-start flow **only at the
presentation layer** — the route engine/resolver/projector (ADR-0005) neither reads nor stores the
vehicle preference, so there is still **no engine coupling** on either path.

### (5) Forward-compat boundary — the permanent rule — RATIFIED.

**A cosmetic vehicle pick must NEVER — now or after `journey-energy-model` ships — change accrual or
speed.** When per-mode speeds arrive:

- the **engine-owned `TravelMode`** (set from the activity pipeline / `JourneyProgress`) drives speed and
  accrual; and
- the **cosmetic skin-override `vehiclePreference`** stays **display-only and orthogonal** — it continues
  to flow only through the `applyState(mode:)` seam and is never read by the engine, the speed model, or
  `updateFromEngine`.

These are **two distinct concerns that must not be merged**: a future implementer adding per-mode speed
takes the speed from the engine's own `TravelMode`, **not** from `vehiclePreference`. The presentation-layer
override seam is precisely the firewall that keeps the user's chosen *look* from becoming a lever on
journey *truth*.

## Consequences

- **Easier / preserved.** The cosmetic-only, pure-view, and no-engine-coupling invariants all hold by
  construction: the scene's `applyState(mode:)` contract is unchanged, the engine and `updateFromEngine`
  never learn the preference exists, and per ADR-0003 the chosen skin renders in both the full window and
  the mini-window PiP from the one shared `JourneyGame` with no extra wiring. The user gains real agency
  (a control that was missing) without any risk to distance/progress/idle. Persistence reuses an existing
  dependency (`shared_preferences`) — **no new dependency**. The design is **forward-compatible** with
  `journey-energy-model`: the speed model will read the engine's `TravelMode`, untouched by this seam.
- **Harder / new obligations.** There is now a **presentation-layer override seam** to maintain (resolve
  `vehiclePreference ?? engine mode` above `JourneyViewState`, never below). The route-start coupling
  (ADR-0005) means the begin-journey flow must read/seed and write the **same** preference store as the
  persistent picker — a small cross-surface sync obligation. New **license-clean per-mode icons** must be
  sourced via `ui-asset-curator` (`/source-assets`) and each given a `CREDITS.md` attribution row
  (journey-pov AC-17 pattern). And a **standing discipline** is created: the future per-mode-speed slice
  must take speed from the engine's `TravelMode`, never from `vehiclePreference` (decision 5).
- **What the `vehicle-picker` spec must assert.** (a) A **cosmetic-only equality test** — selecting any
  vehicle changes the rendered skin/cockpit but leaves engine `mode`/`distanceKm`/progress/elapsed/idle
  byte-for-byte identical (mirror journey-cockpit-lean AC-12's no-state-bleed assertion). (b) The chosen
  skin renders within one frame and resolves the cockpit-vs-side-view branch consistently (e.g. pick "car"
  while engine mode is "walk" → car cockpit). (c) **Persistence across restart** via `shared_preferences`.
  (d) **Both entry points stay in sync** off the single preference (route-start pre-seeded with the saved
  value). (e) `/privacy-audit` stays PASS (a local settings preference adds no network egress).

## Alternatives considered

### (1) User pick sets the engine's `TravelMode` directly
**Rejected.** It couples a purely cosmetic choice to accrual: today it would technically be inert (single
shared rate), but it directly violates the cosmetic-only invariant (`journey_engine.dart:212`) and, once
`journey-energy-model` adds per-mode speeds, would let the user game distance by picking the "fastest"
vehicle. It also breaks the pure-reader contract of `updateFromEngine`. The whole point of recording this
ADR is to forbid this path permanently (decision 5).

### (2) Session-only preference, no persistence
**Rejected.** Poor UX — the user would have to re-pick their vehicle on every launch, and the route-start
picker would have nothing meaningful to pre-seed. `shared_preferences` is already a dependency, so durable
persistence is cheap and adds no new dependency (decision 3).

### (3) Text-only dropdown picker (reuse the dev-mode-switcher style)
**Rejected** per the fun-iconography requirement (Kevin, 2026-06-26): the production picker uses distinct
per-mode vehicle icons, not a plain text dropdown. (This is a spec/asset concern, handled as a consequence —
license-clean icons via `ui-asset-curator` — not part of the core architectural decision.)

### (4) Apply the override inside `JourneyCubit.updateFromEngine` (read engine, then swap mode)
**Rejected.** Even though it would not touch the engine itself, it would make the engine **reader** depend
on a view/settings preference, blurring the "pure reader" boundary (`journey_cubit.dart:5, 29, 38`) and
making it tempting later to feed the preference back toward accrual. Resolving the effective display mode
**at/above `JourneyViewState`** keeps `updateFromEngine` a clean engine mirror and isolates the override at
the presentation seam (decision 2).

## References

- Backlog: `planning/backlog/vehicle-picker.md`; epic `planning/backlog/visual-polish.md` (Wave 3,
  Candidate ADRs).
- Code seams: `journey_engine.dart:161, 212-213` (cosmetic mode, single shared rate);
  `journey_cubit.dart:38-42` (`updateFromEngine` pure reader); `journey_view_state.dart` (`mode`);
  `journey_game.dart:139-146, 193, 210, 311` (`applyState(mode:)`, sprite + cockpit branch).
- `pubspec.yaml:39` — `shared_preferences: ^2.5.5` (existing dependency; no new dependency added).
- ADR-0002 — Flutter/Bloc/Flame stack (the Flame scene owns the displayed skin).
- ADR-0003 — single-window two-mode / shared `JourneyGame` (skin renders in full window + PiP for free).
- ADR-0005 — custom routes (the route-start entry point this picker hooks into at the presentation layer).
- Pure-view ACs: journey-pov AC-9/AC-10; journey-cockpit-lean AC-11/AC-12 (cosmetic-only / no-state-bleed).
