# Vehicle picker — choose your vehicle (cosmetic skin override)

**Status:** shipped (2026-06-26)
**Owner:** Kevin (Tuyen Vo)
**Last updated:** 2026-06-26

## Problem
Six vehicle skins exist (`walk`/`run`/`bicycle`/`motorbike`/`car`/`ship`) and each has a distinct sprite +
(car/motorbike) first-person cockpit, but **the user can't choose one** — `TravelMode` is set by the
engine/activity pipeline and defaults to `motorbike`. Kevin: *"I don't see the option to choose vehicle."*
A throwaway debug dropdown (`dev-mode-switcher`, shipped 2026-06-26) proved the wiring but is `kDebugMode`-only.
This slice is the **production** picker: a real, persisted, fun way to pick the vehicle you ride. It is the
sole Wave-3 slice of the `visual-polish` epic and is gated on the now-**accepted ADR-0007**.

The picker is **cosmetic-only by decision** (ADR-0007): the pick changes the *displayed* vehicle + cockpit
only; the engine's `mode`/`distanceKm`/progress/elapsed/idle accrual stay **byte-for-byte untouched**, and a
cosmetic pick must **never, now or later, feed accrual/speed** (forward-compat with the deferred
`journey-energy-model` per-mode-speed slice). This is the load-bearing constraint the ADR exists to protect.

## User & outcome
- **The focused individual** — primary. Success = they can pick the vehicle they want to ride and the
  on-screen vehicle + cockpit changes to match within a frame, the choice **sticks across restarts**, and the
  picker is **fun** (distinct per-mode icons, not a bare text dropdown). They can pick it **two ways**: change
  it any time from a persistent place, and choose it **when starting a new route** ("begin this journey as…").
- **The privacy-skeptical teammate** — unaffected. Cosmetic preference stored locally
  (`shared_preferences`); no OS/activity signal read; no journey truth touched. `/privacy-audit` stays PASS.

## Scope
### In
- **A vehicle preference** persisted via the existing `SettingsRepository` / `AppSettings` +
  `shared_preferences` store (a new `AppSettings` field, e.g. `vehiclePreference: TravelMode?` with
  `SettingsCubit.setVehicle(...)`, mirroring `setIdleThreshold`). **No new dependency.**
- **Cosmetic precedence applied at the presentation seam** (ADR-0007): the *displayed* mode is
  `vehiclePreference ?? engine-derived mode`, resolved at/above `JourneyViewState` so
  `JourneyGame.applyState(mode:)` still takes one value. The engine never reads the preference. The
  cockpit-vs-side-view branch resolves by the displayed mode (pick `car` while engine mode is `walk` → car
  cockpit). Change reflects in **≤ 1 frame**.
- **Two entry points, one source of truth:**
  1. **Persistent picker** — change the vehicle any time (placement: Settings screen and/or a journey-screen
     affordance — pinned in the AC framing).
  2. **At new-route start** — the picker also appears in the `RoutePlannerFlow` review/confirm step so the
     user picks a vehicle as part of beginning a route; it is **pre-seeded** from the saved preference and
     writes back to the **same** `SettingsCubit` preference (both entry points stay in sync).
- **Fun, distinct iconography** — one clear per-mode icon for all six modes (license-clean, sourced via
  `ui-asset-curator` / `/source-assets`, attributed in `assets/CREDITS.md`), cohesive with the existing
  journey art family — not a plain text dropdown.
- **Accessible** — keyboard-reachable, labelled (screen-reader names per mode), mode conveyed not by colour
  alone (the per-mode icon/silhouette carries it).

### Out
- **Any engine / accrual / speed change** — the pick is cosmetic; `distanceKm`/progress/elapsed/idle and
  the idle-vs-active decision are untouched (ADR-0007). **Per-mode speeds are the deferred
  `journey-energy-model`** — explicitly out, and ADR-0007 forbids the cosmetic pick from ever feeding it.
- **New travel modes** — the picker chooses among the existing six skins only.
- **Auto-deriving mode from real activity type** (e.g. detecting walking vs driving) — not in scope; the
  engine's cosmetic `mode` default stands when no user preference is set.
- **Per-route vehicle memory** (a different saved vehicle per route) — v1 has **one** global preference; the
  route-start picker just edits that one preference. (Could be a later slice.)
- **Removing/altering the shipped `dev-mode-switcher`** beyond it being superseded in practice (leave the
  debug tool as-is unless trivially in the way).

## Constraints & assumptions (from ADR-0007)
- **Cosmetic-only, no engine coupling (hard).** The preference lives in the view/settings layer; the
  `JourneyEngine` neither reads nor depends on it. `JourneyCubit` stays a pure engine-reader — the override is
  composed at/above `JourneyViewState`, not by writing `engine.mode`. Engine outputs for the same inputs are
  **byte-for-byte unchanged** vs. no-preference (mirrors journey-cockpit-lean AC-12 / journey-pov AC-10).
- **Forward-compat boundary (load-bearing).** When `journey-energy-model` lands per-mode speeds, speed is
  driven by the **engine-owned** `TravelMode`; the cosmetic preference must remain display-only and orthogonal.
  The build must not create any path from the preference into accrual/speed.
- **Persistence.** Uses the already-present `shared_preferences` via the existing settings repository pattern;
  survives restart; tolerates absent/corrupt stored value (falls back to "no preference" → engine default).
- **Pure-view scene invariant preserved.** The scene/cockpit keep importing only `dart:*`, `package:flame/*`,
  `TravelMode` — the preference reaches the scene as the plain `mode` value via `applyState`, exactly as today.
- **Two entry points, single source.** Persistent picker + route-start picker both bind the **same**
  `SettingsCubit` preference (route-start pre-seeded from it); no second store, no divergence.
- **License-clean assets only.** New icons CC0/CC-BY with attribution in `CREDITS.md` (route via
  `ui-asset-curator`); no unclear/paid licences.
- **Desktop targets:** macOS + Windows. Stack per `docs/architecture/overview.md` (ADR-0002); route-start
  flow per ADR-0005; shared `JourneyGame` per ADR-0003.

## Resolved decisions
1. **Cosmetic skin override, never engine truth; precedence `vehiclePreference ?? engineMode` at the
   presentation seam** (ADR-0007).
2. **Two entry points (persistent + at new-route start), one persisted preference** (Kevin, 2026-06-26).
3. **Fun per-mode iconography, license-clean** (Kevin, 2026-06-26) — not a text dropdown.
4. **One global preference in v1** (no per-route memory).
5. **Persisted via the existing `SettingsRepository`/`shared_preferences`** — no new dependency.
6. **Persistent-picker placement = Settings row + a journey-screen affordance** (Kevin, 2026-06-26) — most
   discoverable; resolves the open question on AC-14.
7. **Route-start picker = skippable, pre-seeded** (Kevin, 2026-06-26) — on the `RoutePlannerFlow`
   review/confirm step, pre-filled with the saved vehicle; the user may change it or just confirm (not a
   mandatory step). Resolves the open question on AC-13.

## Acceptance criteria
Each item is a checkable, observable statement and the ship gate. If it isn't testable, rewrite it.
These ACs ARE the contract — `tests/cases/vehicle-picker.md` will reference them by ID; there is no
separate acceptance-criteria file. All ACs are observable through the **real seams** named in the spec:
the persistence path `SettingsCubit.setVehicle(...)` → `AppSettings.vehiclePreference` →
`SettingsRepository.save/load` (`shared_preferences`); the display pipeline `JourneyEngine.mode` →
`JourneyCubit.updateFromEngine` (pure reader) → composed `JourneyViewState.mode` → `JourneyScreen` →
`JourneyGame.applyState(mode:)`; the scene seams `JourneyGame.currentMode` / `isCockpitActive` /
`currentVehicleAsset`; the route-start entry point `RoutePlannerFlow` (`onConfirmed(ResolvedRoute)`); and
`TravelMode.values`. "Engine truth unchanged" everywhere means `JourneyEngine`'s `distanceKm` / `state` /
`activeTimeToday` / `rawActiveTime` / `idleTimeToday` for the same inputs (mirrors journey-cockpit-lean
AC-12 / journey-pov AC-10).

**Selecting a vehicle changes the displayed mode**
- [x] AC-1 (a pick changes the rendered vehicle within ≤1 frame): Given the journey scene is rendering and
      `TravelMode.values` are selectable, When the user picks a mode `m` in the picker (which calls
      `SettingsCubit.setVehicle(m)`), Then the composed `JourneyViewState.mode` becomes `m` and the next
      `JourneyGame.applyState(mode: m)` makes `JourneyGame.currentMode == m` — both the **sprite**
      (`currentVehicleAsset` for `m`) and the **cockpit-vs-side-view branch** resolve off that single value
      — within **≤ 1 frame** of the pick (the change is pushed through the existing `applyState` seam on the
      next state emission, no extra wiring). Observable: assert `currentMode == m` and the matching
      `currentVehicleAsset` after the pick propagates.
- [x] AC-2 (cockpit branch resolves off the displayed mode, not the engine mode): Given the engine's
      cosmetic `mode` is a side-view mode (e.g. `walk`), When the user picks `car`, Then the displayed mode
      is `car`: `JourneyGame.isCockpitActive == true` and the **car cockpit** renders (per journey-pov
      AC-1) — there is **no split-brain** where the sprite and the cockpit disagree, because the whole
      render resolves off the one overridden `mode:` handed to `applyState`. Observable: with engine `mode`
      `walk` and `vehiclePreference == car`, assert `isCockpitActive == true` and the car cockpit/sprite are
      shown; symmetrically, picking a side-view mode (e.g. `bicycle`) while the engine mode is `car` yields
      `isCockpitActive == false` and the bicycle side-view sprite.

**Precedence rule (`vehiclePreference ?? engineDerivedMode`)**
- [x] AC-3 (a set preference wins for display): Given a non-null `vehiclePreference == p`, When the
      displayed mode is composed at/above `JourneyViewState`, Then the value passed to
      `JourneyGame.applyState(mode:)` is **`p`** regardless of the engine-derived cosmetic mode — the user
      pick wins for display. Observable: vary the engine mode while `vehiclePreference == p` and assert
      `JourneyViewState.mode == p` and `currentMode == p` at every emission.
- [x] AC-4 (no preference → engine-derived cosmetic mode shows): Given `vehiclePreference == null`, When
      the displayed mode is composed, Then the displayed mode equals the **engine-derived cosmetic mode**
      (today's purely-additive behaviour) — the picker changes nothing until a pick exists. On **first
      launch with no stored preference**, the displayed mode is the engine default (**motorbike**) until the
      user picks. Observable: with `vehiclePreference == null`, assert `JourneyViewState.mode` tracks the
      engine's cosmetic `mode`, and a fresh first launch shows `motorbike`. _proposed resolution to Open
      question "'No preference' semantics": the default is literally **"follow the engine cosmetic mode"**
      (the override term is omitted, not a sentinel value), and first launch shows the engine default
      (motorbike) until the user picks; product-domain-expert / reviewer may adjust whether first launch
      instead nudges the user to pick._

**Persistence across restart**
- [x] AC-5 (a pick is persisted via the settings store): Given the user picks `m`, When
      `SettingsCubit.setVehicle(m)` runs, Then it `emit`s an `AppSettings` with `vehiclePreference == m`
      **and** `_persist`es it via `SettingsRepository.save(AppSettings)` to `shared_preferences` — mirroring
      the existing `setIdleThreshold` pattern (emit + persist), using the existing repository, **no new
      dependency**. Observable: assert the emitted `AppSettings.vehiclePreference == m` and that
      `SettingsRepository.save` was called with that value.
- [x] AC-6 (a persisted pick is restored on relaunch): Given a `vehiclePreference == m` was saved in a
      prior session, When the app relaunches and the settings load path seeds `SettingsCubit`'s
      `initialSettings` from `SettingsRepository.load`, Then the restored `vehiclePreference == m` seeds the
      composed displayed mode **before the first `applyState`**, so the scene opens on `m`. Observable:
      construct `SettingsCubit` with restored settings carrying `vehiclePreference == m` and assert the
      first composed `JourneyViewState.mode == m`.
- [x] AC-7 (absent / corrupt stored value falls back to "no preference", never crashes): Given the stored
      vehicle value is **absent** (never set) or **corrupt / unparseable** (e.g. not a valid `TravelMode`
      name), When settings load on startup, Then loading **does not crash**, `vehiclePreference` resolves to
      **`null`** ("no preference"), and the displayed mode follows the engine-derived mode per AC-4.
      Observable: feed an absent and a garbage stored value to the load path and assert `vehiclePreference
      == null` with no thrown exception.

**Cosmetic-only — engine truth byte-for-byte unchanged** (echoes journey-cockpit-lean AC-12 / journey-pov AC-10)
- [x] AC-8 (selecting any vehicle leaves engine truth byte-for-byte identical): Given the journey runs the
      **same inputs** as a no-preference baseline, When **any** `vehiclePreference` is set (each of
      `TravelMode.values`), Then the engine's `distanceKm` / `state` / `activeTimeToday` / `rawActiveTime` /
      `idleTimeToday` are **byte-for-byte identical** to the no-preference baseline — the pick changes the
      rendered skin/cockpit only and accrues no distance and shifts no idle/active decision. Observable: run
      the engine through a fixed input sequence twice (baseline vs. each preference) and assert equality of
      all five engine outputs.
- [x] AC-9 (`JourneyCubit` never writes the engine; the engine never reads the preference): Given the
      override is composed at/above `JourneyViewState`, When `JourneyCubit.updateFromEngine` runs, Then it
      stays a **pure reader** — it does **not** write `engine.mode` (nor any engine field) to apply the
      preference — and the engine resolves its own cosmetic `mode` with **no reference** to
      `vehiclePreference` / the settings store. Observable: assert `updateFromEngine` performs no engine
      mutation, and the effective display mode is resolved above the view state (not inside
      `updateFromEngine` reading the engine, per ADR-0007 decision 2 / rejected-alternative 4).

**Forward-compat boundary (the ADR-0007 firewall)**
- [x] AC-10 (no code path from the preference into accrual/speed — guarded): Given ADR-0007's permanent
      rule that the cosmetic pick must **never** feed accrual or speed (now or after `journey-energy-model`),
      When the engine and its inputs are inspected, Then there is **no code path** from `vehiclePreference`
      (the settings store / `AppSettings` field) into the engine's accrual or any future speed input — the
      `JourneyEngine` has **no import of / reference to** the settings store, `AppSettings.vehiclePreference`,
      or `SettingsCubit`, and the preference reaches the render only via the `applyState(mode:)` seam.
      Observable: a structural guard test (by import/reference inspection, sibling to journey-cockpit-lean
      TC-511/TC-512's separation guards) asserts the engine references neither the preference nor the
      settings store, and the preference is consumed solely at the presentation seam.

**Two entry points, one source of truth**
- [x] AC-11 (both pickers bind the same persisted preference — no divergence): Given the **persistent
      picker** and the **route-start picker** (`RoutePlannerFlow`) are both surfaced, When either picker
      changes the vehicle, Then both write through the **same** `SettingsCubit.setVehicle(...)` to the
      **single** `AppSettings.vehiclePreference` — there is **no second store**. A change made in one surface
      is reflected in the other (and in the displayed mode) with no divergence. Observable: change the
      vehicle via the persistent picker and assert the route-start picker reads the same value, and
      vice-versa, against one `SettingsCubit`.
- [x] AC-12 (route-start picker is pre-seeded from the saved preference): Given a saved
      `vehiclePreference == m`, When the route-start picker surfaces in `RoutePlannerFlow`, Then it opens
      **pre-seeded** to `m` (the current saved value), not a blank/default — so the user sees their existing
      choice. Observable: with `vehiclePreference == m`, open the route-start picker and assert its initial
      selection is `m`; with `vehiclePreference == null`, it pre-seeds to the engine-default display
      (motorbike) per AC-4.

**Route-start surfacing**
- [x] AC-13 (starting a new route surfaces the picker; confirming keeps the chosen vehicle): Given the user
      begins a new route via `RoutePlannerFlow`, When the flow reaches the vehicle-pick affordance
      (pre-seeded per AC-12), Then the user can pick a vehicle as part of starting the route, and on
      `onConfirmed(ResolvedRoute)` the chosen vehicle is **applied and kept** (written back to the same
      `vehiclePreference` via `SettingsCubit.setVehicle`, so it survives per AC-5/AC-6). Confirming the route
      does **not** reset or discard the pick. Observable: pick a vehicle `m'` in the route-start flow,
      confirm the route, and assert `vehiclePreference == m'` and the scene displays `m'`. _proposed
      resolution to Open question "Route-start picker UX": surface the picker as a **control on the existing
      review/confirm step** of `RoutePlannerFlow` (not a new mandatory step) — **skippable**, defaulting to
      the saved preference (pre-seeded), so a user who does not touch it keeps their current vehicle;
      product-domain-expert / flutter-app-developer may promote it to a dedicated step if the review screen
      is too crowded._

**Fun iconography**
- [x] AC-14 (distinct per-mode icon for all six modes, not a text dropdown): Given the picker renders, When
      it is inspected, Then it shows a **distinct icon per mode for all six `TravelMode.values`**
      (`walk` / `run` / `bicycle` / `motorbike` / `car` / `ship`) — a visual, icon-based picker, **not** a
      bare text dropdown — cohesive with the existing journey art family. Observable: assert a distinct icon
      asset/widget is present for each of the six modes. _proposed resolution to Open question
      "Persistent-picker placement": surface the persistent picker as a **row on the Settings screen** (next
      to the existing settings, reusing the `SettingsCubit`) **and** a lightweight journey-screen affordance
      that opens the same picker; flutter-app-developer / reviewer may drop the journey-screen affordance if
      the Settings row suffices._
- [x] AC-15 (every new icon is license-clean and attributed): Given the picker ships new icon assets, When
      `assets/CREDITS.md` is inspected, Then **every** icon that requires attribution (CC0/CC-BY, sourced via
      `ui-asset-curator` / `/source-assets`) is listed with its **source + licence**, and the picker loads
      **no** icon asset absent from CREDITS (observable: each requested icon path has a matching CREDITS
      entry — journey-pov AC-17 pattern). No unclear / paid / "personal-use-only" licences.

### Non-functional
- [x] NFR-1 Performance: Resolving the override and selecting a vehicle add at most an **O(1)** composition
      of the displayed mode (`vehiclePreference ?? engineDerivedMode`) at/above `JourneyViewState` — **no
      new per-frame cost** in `JourneyGame` (it still takes one `mode:` value via `applyState`, exactly as
      today), **no per-frame allocation**, and the selection→display change lands within **≤ 1 frame**
      (AC-1). The scene's **≥30fps** on macOS + Windows (full window and the always-on-top mini-window PiP,
      ADR-0003) is **unaffected**. _(Automated guard: assert the override resolution adds no per-frame work
      and `applyState`'s contract is unchanged; on-device ≥30fps is a manual carry before public release,
      consistent with prior slices.)_
- [x] NFR-2 Security/Privacy (gating): The picker stores **only a cosmetic local preference**
      (`AppSettings.vehiclePreference` via the existing `shared_preferences` settings store) — it reads
      **no** OS / activity / screen / location signal, opens no network egress, and adds no new dependency
      or platform channel. `/privacy-audit` stays **PASS** by construction. **Gating** — ship blocks until
      `/privacy-audit` returns PASS.
- [x] NFR-3 Accessibility: The picker is **keyboard-reachable** and operable without a pointer; each of the
      six mode options carries a **screen-reader label** naming the mode (e.g. "Car", "Motorbike"); and the
      chosen / available mode is conveyed **not by colour alone** — the distinct per-mode icon/silhouette
      (AC-14) plus the text label carry it. The picker does **not** trap focus or obscure essential journey
      readouts.

## Open questions
- [x] **Persistent-picker placement** — **RESOLVED (Kevin, 2026-06-26): Settings row + a journey-screen affordance** (Resolved decision 6, AC-14).
- [x] **Route-start picker UX** — **RESOLVED (Kevin, 2026-06-26): skippable, pre-seeded control on the `RoutePlannerFlow` review/confirm step** (not a mandatory step) (Resolved decision 7, AC-13).
- [ ] **Icon set + style** — which six icons, from which CC0/CC-BY source, matching the journey art family — owner: ui-asset-curator (during build via `/source-assets`)
- [ ] **"No preference" semantics** — is the default literally "follow engine cosmetic mode," and does first launch show motorbike (engine default) until the user picks? — owner: product-domain-expert _(proposed: yes — default = follow engine cosmetic mode; first launch shows motorbike until the user picks. Reviewer may adjust.)_

## Related
- **Gating decision:** [ADR-0007](../../docs/architecture/decisions/0007-vehicle-picker-cosmetic-override-precedence.md) (cosmetic-override precedence) — **accepted 2026-06-26**
- Backlog framing: [planning/backlog/vehicle-picker.md](../../planning/backlog/vehicle-picker.md)
- Parent epic / Wave 3: [planning/backlog/visual-polish.md](../../planning/backlog/visual-polish.md)
- Supersedes (in practice): the debug-only `dev-mode-switcher` ([planning/done/dev-mode-switcher.md](../../planning/done/dev-mode-switcher.md))
- Code seams: `lib/features/stats/presentation/settings_cubit.dart` + `domain/stats_repositories.dart` + `data/shared_preferences_settings_repository.dart` (persist the preference), `AppSettings` (new field), `lib/features/journey/presentation/journey_cubit.dart` / `journey_view_state.dart` (compose the displayed mode), `journey_game.dart` `applyState(mode:)` (unchanged seam), `lib/features/route/presentation/route_planner_flow.dart` (route-start entry point), `domain/travel_mode.dart` (`TravelMode.values`)
- Architecture: ADR-0002 (Flutter/Bloc/Flame), ADR-0003 (shared `JourneyGame`), ADR-0005 (custom routes / route-start flow)
