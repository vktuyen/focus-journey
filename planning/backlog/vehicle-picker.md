# Vehicle picker — let the user choose their vehicle (cosmetic)

**Intake date:** 2026-06-25  **Requested by:** Kevin (Tuyen Vo)  **Size (rough):** M
**Part of epic:** [visual-polish](visual-polish.md) · Wave 3

## Why
Kevin: *"I don't see the option to choose vehicle."* Six skins exist (walk/run/bicycle/motorbike/car/ship) but
there's no UI to pick one — `TravelMode` is set by the activity/engine pipeline, not the user. Add a vehicle
picker. **Decision taken at capture (Kevin, 2026-06-25): cosmetic-only override** — the pick changes the
*displayed* vehicle + cockpit only; engine `mode`/distance/progress/idle stay byte-for-byte untouched (mirrors
the v1 single-speed, cosmetic-`TravelMode` invariant). This is a functional UI feature, not art polish.

## Signals
Ready when: **the precedence ADR is accepted** (cosmetic skin override vs engine-owned `TravelMode`; incl.
forward-compat with the deferred `journey-energy-model` per-mode-speed slice — a cosmetic pick must never later
change accrual). Then: selecting a vehicle changes the on-screen vehicle + cockpit within one frame, **persists
across restart** (`shared_preferences`), resolves the cockpit-vs-side-view branch consistently (pick "car"
while engine mode is "walk" → show the car cockpit), and **changes no journey state**. New preference flows
`JourneyCubit` → `JourneyViewState` → `applyState` without leaking into engine truth.
`[blocked by: precedence ADR]` (write it with `/add-adr` before `/new-feature`).

## Added requirements (Kevin, 2026-06-26)
- **Surface the picker at route-start too.** Beyond a persistent place (Settings / journey overlay), the
  picker must also appear **when the user starts a new route** (the route-planner / new-route flow) — pick
  your vehicle as part of "begin this journey." So the picker has **two entry points**: ongoing (change any
  time) + at new-route kickoff. (The persisted preference is the single source so both entry points stay in
  sync — pre-seed the route-start picker with the current saved vehicle.)
- **Richer, fun iconography.** The picker should use **distinct vehicle icons** (not a plain text dropdown
  like the dev switcher) to make choosing feel fun — one clear icon per mode (walk/run/bicycle/motorbike/
  car/ship). Source **license-clean** icons via `ui-asset-curator` (`/source-assets`) and register
  attribution; reuse the existing journey art family where possible for cohesion.
- _Supersedes the debug-only `dev-mode-switcher` (shipped 2026-06-26) — that was throwaway dev tooling; this
  is the production selector._

## First step
Accept the precedence ADR (`/add-adr`), then run `/new-feature vehicle-picker` to promote this slice into a spec.
