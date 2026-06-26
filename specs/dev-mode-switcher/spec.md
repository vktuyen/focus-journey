# Dev mode switcher — debug-only travel-mode dropdown

**Status:** shipped (2026-06-26)
**Owner:** Kevin (Tuyen Vo)
**Last updated:** 2026-06-26
**Lane:** quick-change (small, low-risk dev tooling — no ADR, no new dependency, no native surface)

**Placement (confirmed Kevin, 2026-06-26):** a small **top-center** floating overlay (clear of the existing
corners — reduce-motion top-left, distance top-right, PiP bottom-left, minimap bottom-right); **full journey
window only** (not the compact mini-window PiP).

## Problem
There is no in-app way to switch the journey's travel mode (`walk`/`run`/`bicycle`/`motorbike`/`car`/`ship`)
at runtime — it defaults to `motorbike` and is only changeable in code or via a persisted progress file. That
makes it impossible to eyeball the just-shipped `journey-cockpit-lean` (and the car-vs-motorbike cockpit / the
per-mode sprites) without editing source. We want a **debug-only** dropdown to flip modes live. This is *not*
the production vehicle picker (that's the planned Wave-3 `vehicle-picker`, which needs its own precedence ADR);
this is throwaway dev tooling that must never appear in a release build.

## Outcome
In a debug build, a small dropdown on the journey screen lets you pick any `TravelMode` and the Flame scene
swaps its cockpit/sprite immediately; in release/profile builds nothing changes.

## Scope
### In
- A `kDebugMode`-gated dropdown overlay on the journey screen listing all six `TravelMode` values, showing the
  current mode selected.
- Selecting a mode sets the **source of truth** — `JourneyEngine.mode` — and republishes via
  `JourneyCubit.updateFromEngine(engine)`, so the change flows through the existing pipeline
  (`JourneyViewState.mode` → `JourneyScreen` → `JourneyGame.applyState(mode:)`) and survives the next ticker tick.
- Wiring is a callback injected from `main.dart` (which owns `_engine` + `_cubit`) down to the journey screen;
  `JourneyScreen` gains an optional `onDevModeSelected` (default `null` → no control rendered).

### Out
- The production vehicle-picker UX, its placement/visual design, and the user-choice-vs-auto precedence rule
  (that is the Wave-3 `vehicle-picker` slug + its ADR).
- Any change to journey accrual / engine logic (mode stays **cosmetic** in v1 — does not affect
  distance/state/idle).
- Persistence semantics changes (the engine already round-trips `mode` via `toProgress()`; we add nothing).
- Adding the switcher to the mini-window PiP surface.

## Constraints & assumptions
- **Debug-only:** gated on `kDebugMode` so it is tree-shaken out of release/profile builds — no production
  surface added.
- **Pipeline-respecting:** the control writes only `engine.mode` (the existing settable cosmetic field) and
  calls the existing `cubit.updateFromEngine`; `JourneyCubit` keeps its "never writes to the engine" purity
  (the write happens in `main.dart`'s callback, not in the cubit).
- In-scope edits only: `main.dart` (wire callback) + `journey_screen.dart` (optional callback + gated overlay
  widget). No new package.

## Acceptance criteria
- [x] AC-1 (dropdown visible in debug with all modes): Given a debug build (`kDebugMode == true`) of the
      journey screen wired with `onDevModeSelected`, When it renders, Then a travel-mode dropdown is visible
      listing **all six** `TravelMode` values, with the current `JourneyViewState.mode` shown as selected.
- [x] AC-2 (selecting a mode swaps the scene): Given the dropdown, When a different mode is selected, Then
      `JourneyEngine.mode` is set to it and `JourneyCubit` re-emits, so `JourneyGame.currentMode` (and the
      rendered cockpit/sprite) becomes the selected mode — observable via the cubit emitting a
      `JourneyViewState` with the new `mode`, and (e.g. car↔motorbike) `JourneyGame.isCockpitActive` /
      `currentVehicleAsset` reflecting it.
- [x] AC-3 (no production surface): Given a non-debug build (`kDebugMode == false`), When the journey screen
      renders, Then the dev switcher is **not** built (the overlay is absent) — verifiable by gating the
      widget on `kDebugMode` (and a widget test that asserts absence when the gate/ callback is off).
- [x] AC-4 (cosmetic-only — accrual untouched): Given a mode is selected via the switcher, When the engine
      ticks, Then `distanceKm` / `state` / idle accrual are **unchanged** versus the same inputs without a
      mode switch — `mode` remains a cosmetic skin (engine v1 invariant).

## Related
- Extends visibility for: [specs/journey-cockpit-lean/spec.md](../journey-cockpit-lean/spec.md) (the lean this lets you eyeball)
- Superseded later by: planned Wave-3 `vehicle-picker` (production UX + precedence ADR) — see [planning/roadmap.md](../../planning/roadmap.md)
- Code: `lib/main.dart` (owns `_engine`+`_cubit`; wires the callback), `lib/features/journey/presentation/journey_screen.dart` (optional `onDevModeSelected` + gated overlay), `journey_cubit.dart` (`updateFromEngine`), `journey_engine.dart` (`mode` field), `domain/travel_mode.dart` (`TravelMode.values`)
- Architecture: [docs/architecture/overview.md](../../docs/architecture/overview.md)
