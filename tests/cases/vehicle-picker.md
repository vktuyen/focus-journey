# Test cases: vehicle-picker

Spec: [specs/vehicle-picker/spec.md](../../specs/vehicle-picker/spec.md) — **approved (2026-06-26)** — 15 ACs (AC-1..AC-15) + 3 NFRs (NFR-1..NFR-3).
Gating ADR: [docs/architecture/decisions/0007-vehicle-picker-cosmetic-override-precedence.md](../../docs/architecture/decisions/0007-vehicle-picker-cosmetic-override-precedence.md) — the cosmetic-override **precedence + forward-compat firewall** these cases guard.
Builds on (shipped, regression-guarded here): [specs/journey-pov/spec.md](../../specs/journey-pov/spec.md) (cockpit / `isCockpitActive` / `currentVehicleAsset` seams, cosmetic-only AC-10, CREDITS cross-check AC-17), [specs/journey-cockpit-lean/spec.md](../../specs/journey-cockpit-lean/spec.md) (separation-static / engine byte-for-byte AC-11/AC-12), and the local-stats `SettingsCubit` / `AppSettings` / `SettingsRepository` persistence pattern (`setIdleThreshold` → `emit` + `_persist`). Sibling cases: [tests/cases/journey-pov.md](journey-pov.md), [tests/cases/journey-cockpit-lean.md](journey-cockpit-lean.md), [tests/cases/route-planner-v2.md](route-planner-v2.md), [tests/cases/local-stats.md](local-stats.md).
Manual companion: [vehicle-picker-manual-checklist.md](vehicle-picker-manual-checklist.md) — the icon-cohesion / not-colour-alone art review, the real-OS keyboard + screen-reader a11y pass, the on-device ≥30fps confirmation, and the `/privacy-audit` PASS release gate that are not cheaply automatable.

> **Build assumption (load-bearing — note for the implementer).** These cases assume the build **ADDS**
> `AppSettings.vehiclePreference: TravelMode?` (nullable, JSON round-tripped) + `SettingsCubit.setVehicle(TravelMode)`
> (mirroring `setIdleThreshold`: `emit` the copy-with + `_persist` via `SettingsRepository.save`), and that the
> effective displayed mode is composed as `vehiclePreference ?? engineDerivedMode` **at or above**
> `JourneyViewState.mode` (NOT inside `JourneyCubit.updateFromEngine`, which stays a pure engine reader, and NOT
> inside the engine — ADR-0007 decision 2 / rejected alternative 4). `JourneyScreen._applyToScene` already hands
> `s.mode` to `JourneyGame.applyState(mode:)`; the override term is applied where `s.mode` is assembled so the
> scene's one-value contract is unchanged. The cases assert against `vehiclePreference`, the composed
> `JourneyViewState.mode`, and the existing scene seams `JourneyGame.currentMode` / `isCockpitActive` /
> `currentVehicleAsset` — precisely so the precedence + firewall can genuinely **fail**, the way prior slices
> exposed `isCockpitActive` and `centreLineOffsetAt`.

## Coverage note (which layers cover which ACs; risky / under-covered areas)

- **Deterministic unit / Cubit tests (`src/focus_journey/test/.../stats/` + `.../journey/presentation/`)** carry
  the bulk and are exact (no clock, no `Random`, no OS): the pick→display swap and cockpit-branch resolution off
  the composed mode (AC-1, AC-2), the precedence `vehiclePreference ?? engineMode` in both directions including
  first-launch-default `motorbike` (AC-3, AC-4), the `setVehicle` emit+persist (AC-5), restore-before-first-applyState
  (AC-6), absent/corrupt → `null` no-crash (AC-7), the engine byte-for-byte equality across all six picks (AC-8),
  the `JourneyCubit` no-engine-write / engine no-preference-read runtime leg (AC-9), and the single-source binding
  of both pickers (AC-11) + route-start pre-seed (AC-12).
- **Static inspection / structural guard tests** (sibling to journey-cockpit-lean TC-511/TC-512's separation
  guards) carry the **load-bearing firewall** (AC-10): the engine references neither `vehiclePreference`, the
  settings store, nor `SettingsCubit`, and the preference reaches the render only via `applyState(mode:)` — designed
  to go **RED** if anyone wires the pick into accrual. Static also carries the AC-9 structural half and the NFR-1
  no-per-frame-cost half.
- **Widget tests** carry the iconography (distinct icon per all six modes, icon-based not a text dropdown — AC-14)
  and the route-start surfacing + write-back via `onConfirmed` (AC-13). The asset⇄CREDITS manifest cross-check
  (AC-15) is a static/manifest test (journey-pov AC-17 pattern).
- **Integration test (`src/focus_journey/integration_test/`)** carries the two-entry-points-one-source smoke
  (change in Settings reflects in route-start and vice-versa; pick on route-start propagates to the displayed mode
  on both surfaces) — AC-11/AC-12/AC-13.
- **Manual / review checklist** carries what is **NOT cheaply automatable**, flagged `[VISUAL]` / `[REAL-OS]` /
  `[DEVICE]` / `[AUDIT]`: the icon-cohesion + not-colour-alone art read (AC-14 / NFR-3 visual leg — **TC-M-ART**),
  the real keyboard-reachability + per-mode screen-reader-label pass (NFR-3 — **TC-M-A11Y**), on-device ≥30fps with
  the override resolved (NFR-1 device leg — **TC-M-NF1**), and the `/privacy-audit` PASS ship gate (NFR-2 —
  **TC-M-PRIV**).

**Risky / under-covered areas (flagged):**

- **HEADLINE — AC-10 is the load-bearing firewall and is only a structural/static guard.** "No code path from
  `vehiclePreference` into accrual/speed, now or after `journey-energy-model`" cannot be proven by a behavioural
  assertion in v1 (with a single shared rate, wiring the pick into accrual would be *inert today* and silently pass
  AC-8). TC-606 is therefore designed as an **import/reference inspection** of `journey_engine.dart` (and the engine
  read path) that **FAILS** if the engine imports/references `AppSettings.vehiclePreference`, `SettingsCubit`, or the
  settings store — i.e. it goes RED if someone routes the pick toward accrual. TC-606b is its negative mutation twin
  (a hypothetical engine read of the preference must be a red test). Treat this as the most important case; AC-8 alone
  is NOT sufficient to protect the forward-compat boundary.
- **AC-4 "no preference" semantics is a spec-flagged open question.** The spec's *proposed* resolution (default =
  "follow engine cosmetic mode"; first launch shows the engine default **motorbike** until the user picks) is asserted
  by TC-604. The spec marks this open for product-domain-expert / reviewer (whether first launch should instead nudge
  the user to pick). **If the resolution changes** (e.g. first launch prompts), TC-604's first-launch leg must be
  re-pinned. The cases assume the proposed resolution; flagged here so it is not treated as settled.
- **AC-8 byte-for-byte is necessary but NOT sufficient for the firewall.** It proves the pick changes no engine
  number *in v1*; it does not prove the *absence of a path* that would matter once per-mode speeds land. The path
  absence is AC-10 (TC-606). Both are required; neither replaces the other. (Same relationship as journey-pov
  AC-10-runtime vs journey-cockpit-lean AC-10/AC-11 static.)
- **AC-14 icon cohesion is a REVIEW gate, not a pass/fail assert.** Automation proves a **distinct** icon
  asset/widget is present per all six modes and the picker is icon-based (not a bare text dropdown) and renders;
  "the icons read as one cohesive set in the journey art family, and the chosen-vs-available state is legible without
  relying on colour" is the human review gate **TC-M-ART** (+ the NFR-3 not-colour-alone leg).
- **NFR-3 a11y — keyboard reach + real screen-reader labels are a manual carry.** Automation proves each option
  exposes a per-mode semantics **label** naming the mode and is focus-reachable in the widget tree (a `Semantics`
  inspection), but a real VoiceOver/Narrator pass and real keyboard-only operation are **TC-M-A11Y**.
- **NFR-1 ≥30fps is on-device only.** The deterministic proxy is the O(1)-composition / no-per-frame-cost static
  guard (TC-616): the override is a single nullable-coalesce where the view state is assembled (not in `JourneyGame`
  per frame), so `applyState`'s contract and the scene hot path are unchanged. Sustained frame rate is **TC-M-NF1**.
- **NFR-2 (privacy) is an AUDIT ship-blocker.** The picker stores only a local cosmetic `TravelMode?`; it reads no
  OS/activity/screen/location signal, opens no network, adds no dependency or platform channel. `/privacy-audit` PASS
  (**TC-M-PRIV**) gates ship, reinforced by the AC-10 firewall (TC-606) + the AC-9 separation. A fail blocks ship
  regardless of every other pass.

## Conventions used by these cases

- **No real OS, no real timers, no wall-clock waits, no real `shared_preferences`.** The `SettingsCubit` is driven
  directly against an **in-memory `SettingsRepository` fake** (the local-stats pattern), and the scene is driven
  exclusively through `JourneyGame.applyState({required bool moving, required TravelMode mode, required bool
  reduceMotion, double timeOfDayHours})` with plain values; frames advance explicitly (`game.update(dt)` /
  `pump`), never by awaiting real time.
- **"Composed displayed mode."** The single value handed to `applyState(mode:)` — i.e. `JourneyViewState.mode`
  after the override is applied — equals `vehiclePreference ?? engineDerivedMode`. Tests assert against this composed
  value AND against `JourneyGame.currentMode` after the next emission propagates through `applyState` (they must
  agree). "Engine-derived mode" = `JourneyEngine.mode` (the cosmetic, settable engine field, default `motorbike`).
- **"≤ 1 frame" (AC-1 / NFR-1).** The pick lands on the **next state emission**: calling `SettingsCubit.setVehicle(m)`
  causes the composed `JourneyViewState.mode` to become `m`, and the next `applyState` (the existing emission seam,
  no extra wiring / no awaited delay) makes `JourneyGame.currentMode == m`. Tests assert the composed value updates
  on the emission triggered by the pick and `currentMode == m` after that single `applyState` — not after N frames.
- **"Engine truth" (AC-8) = exact equality.** `JourneyEngine`'s `distanceKm` / `state` / `activeTimeToday` /
  `rawActiveTime` / `idleTimeToday` for the same injected input sequence are compared with **exact** equality (not
  ±epsilon) between the no-preference baseline and each preference run (mirrors journey-pov AC-10 / journey-cockpit-lean
  AC-12).
- **"No-preference baseline."** The reference is the build with `vehiclePreference == null` — i.e. the displayed mode
  follows `engine.mode`, today's purely-additive behaviour. The engine run for the baseline and for each preference
  run uses the **identical** injected input sequence.
- **"Six modes."** `TravelMode.values` = {`walk`, `run`, `bicycle`, `motorbike`, `car`, `ship`} (engine default
  `motorbike`). Cockpit modes (per journey-pov) = {`car`, `motorbike`}; side-view = the other four.
- **"Icon path."** The picker requests a per-mode icon asset path declared in the asset manifest (mirroring how the
  cockpit / vehicle skins are listed), so the AC-15 CREDITS cross-check is mechanical and the AC-14 distinctness check
  is over the requested set. The picker loads **no** icon absent from `assets/CREDITS.md` (inherited rule, journey-pov
  AC-17).
- **Test layer per `docs/architecture/overview.md`.** Executable tests live under `src/focus_journey/`: `setVehicle`
  emit+persist / restore / absent-corrupt / precedence / engine-equality / cubit-no-write → **unit/Cubit**
  (`test/.../stats/`, `test/.../journey/presentation/`); pick→display swap / cockpit branch / iconography distinctness /
  route-start surfacing → **widget** (`test/...`); firewall import-inspection / separation / asset⇄CREDITS / NFR-1
  no-per-frame-cost → **static inspection**; two-entry-points-one-source + route-start propagation → **integration**
  (`integration_test/`); icon cohesion, real a11y, on-device fps, privacy audit → **manual**. `tests/cases/` (this
  file) holds human-readable scenarios only.

## Cases

### Case: A pick changes the displayed vehicle within ≤1 frame (sprite + branch off the one composed mode)
**ID:** TC-601
**Priority:** P0
**Type:** happy-path
**Covers:** AC-1, NFR-1

Given the journey scene is rendering through the existing `applyState` seam, the engine-derived mode is some mode `e`, and `TravelMode.values` are selectable in the picker
When the user picks a mode `m` (`m != e`), which calls `SettingsCubit.setVehicle(m)`
Then on the **next state emission** the composed `JourneyViewState.mode` becomes `m`, the next `JourneyGame.applyState(mode: m)` makes `JourneyGame.currentMode == m`, and **both** the sprite (`currentVehicleAsset` resolves to `m`'s skin) and the cockpit-vs-side-view branch resolve off that single value — within **≤ 1 frame** of the pick, with no extra wiring beyond the existing emission seam

**Notes:** Cubit/widget test. Pick `m` via `setVehicle`; assert the composed view-state mode and `currentMode == m` + matching `currentVehicleAsset` after the single propagating `applyState` (not after multiple pumps). The ≤1-frame claim = "on the emission triggered by the pick", not a wall-clock wait. Pairs with TC-602 (the cockpit-branch case) and the NFR-1 no-per-frame-cost guard TC-616.

---

### Case: Cockpit branch resolves off the displayed mode — car-over-walk shows the car cockpit (no split-brain)
**ID:** TC-602
**Priority:** P0
**Type:** edge
**Covers:** AC-2

Given the engine-derived cosmetic `mode` is a **side-view** mode (`walk`)
When the user picks `car` (`vehiclePreference == car`)
Then the composed displayed mode is `car`: `JourneyGame.currentMode == car`, `isCockpitActive == true`, and the **car** cockpit + sprite render — there is **no split-brain** where the sprite and cockpit disagree, because the whole render resolves off the one overridden `mode:` handed to `applyState`. Symmetrically, with engine mode `car` and a pick of a side-view mode (`bicycle`): `currentMode == bicycle`, `isCockpitActive == false`, and the bicycle side-view sprite shows

**Notes:** Widget test reusing the journey-pov `isCockpitActive` / `currentVehicleAsset` seams. Two legs: (a) engine `walk` + pick `car` → `isCockpitActive == true`, car sprite; (b) engine `car` + pick `bicycle` → `isCockpitActive == false`, bicycle sprite. Proves the cockpit branch follows the *displayed* (overridden) mode, not the engine mode (ADR-0007 decision 2). Pairs with TC-603 (precedence).

---

### Case: A set preference wins for display regardless of the engine-derived mode
**ID:** TC-603
**Priority:** P0
**Type:** happy-path
**Covers:** AC-3

Given a non-null `vehiclePreference == p`
When the engine-derived mode is varied across several values (`walk`, `car`, `ship`, …) while `vehiclePreference` stays `p`, and the displayed mode is composed at/above `JourneyViewState`
Then the value passed to `applyState(mode:)` is **`p`** at every emission — `JourneyViewState.mode == p` and `JourneyGame.currentMode == p` regardless of the engine-derived mode (the user pick wins for display)

**Notes:** Cubit/widget test. Hold `vehiclePreference == p`, drive several engine modes, assert the composed mode stays `p` every time. The precedence is `vehiclePreference ?? engineMode` with `p` non-null → `p`. Pairs with TC-604 (the `null` half). Parameterise `p` across at least one cockpit and one side-view mode.

---

### Case: No preference → engine-derived mode shows; first launch shows the engine default (motorbike)
**ID:** TC-604
**Priority:** P0
**Type:** edge
**Covers:** AC-4

Given `vehiclePreference == null`
When the displayed mode is composed while the engine-derived cosmetic mode varies, and separately on a **fresh first launch** with no stored preference
Then the displayed mode equals the **engine-derived cosmetic mode** at every emission (the picker changes nothing until a pick exists — purely additive), and on first launch with no stored preference the displayed mode is the **engine default `motorbike`** until the user picks

**Notes:** Cubit/widget test. Leg (a): `vehiclePreference == null`, vary engine mode, assert composed mode tracks the engine mode exactly. Leg (b): construct `SettingsCubit` with default settings (no stored preference → `vehiclePreference == null`) and a fresh engine; assert composed mode is `motorbike` (the `JourneyViewState.initial`/engine default). **FLAGGED:** the spec marks "no-preference semantics" an open question (proposed: default = follow engine, first launch shows motorbike); re-pin leg (b) if the reviewer changes first-launch to a nudge-to-pick. Pairs with TC-603.

---

### Case: A pick is persisted — setVehicle emits the preference AND saves it via the repository
**ID:** TC-605
**Priority:** P0
**Type:** happy-path
**Covers:** AC-5

Given a `SettingsCubit` over an in-memory `SettingsRepository` fake, current `vehiclePreference == null`
When the user picks `m` (`SettingsCubit.setVehicle(m)` runs)
Then the cubit **emits** an `AppSettings` with `vehiclePreference == m` **and** `_persist`es it via `SettingsRepository.save(AppSettings)` carrying `vehiclePreference == m` — mirroring `setIdleThreshold` (emit + persist), using the **existing** repository with **no new dependency**

**Notes:** Cubit test against the in-memory fake (local-stats pattern). Assert (a) the emitted `state.vehiclePreference == m`, (b) `repository.save` was called with `vehiclePreference == m`. Assumes the build adds `setVehicle` + the `AppSettings.vehiclePreference` field + its `copyWith`/`toJson`/`fromJson` round-trip (note: a unit case below — TC-607 — exercises the JSON round-trip on the corrupt/absent path). No real `shared_preferences`.

---

### Case: A persisted pick is restored on relaunch and seeds the displayed mode before the first applyState
**ID:** TC-606p
**Priority:** P0
**Type:** edge
**Covers:** AC-6

Given a `vehiclePreference == m` was saved in a prior session (the repository fake returns settings carrying it from `load`)
When the app relaunches and `SettingsCubit` is constructed with `initialSettings` seeded from `SettingsRepository.load`
Then the restored `vehiclePreference == m` seeds the composed displayed mode **before the first `applyState`**, so the scene opens on `m`: the **first** composed `JourneyViewState.mode == m` and the first `applyState` hands `m` to the scene (`currentMode == m`)

**Notes:** Cubit/widget test. Construct `SettingsCubit` with `initialSettings.vehiclePreference == m`; assert the very first composed view-state mode is `m` (not the engine default), proving the restore is seeded ahead of the first frame (the local-stats restore-before-apply pattern, e.g. `setIdleThreshold` re-applied in the constructor). Pairs with TC-605 (the save half) and TC-607 (the safe-load half).

---

### Case: Absent / corrupt stored value falls back to "no preference" — null, never crashes
**ID:** TC-607
**Priority:** P0
**Type:** negative
**Covers:** AC-7

Given the stored vehicle value is **absent** (key never written) or **corrupt / unparseable** (e.g. a string that is not a valid `TravelMode` name, or a wrong-typed JSON value)
When settings load on startup (`AppSettings.fromJson` / the load path runs)
Then loading **does not crash**, `vehiclePreference` resolves to **`null`** ("no preference"), and the displayed mode follows the engine-derived mode per AC-4

**Notes:** Unit test on the `AppSettings.fromJson` / load path (mirrors the existing degrade-safely pattern: missing/wrong-typed fields fall back to defaults rather than throwing). Two legs: (a) absent key → `vehiclePreference == null`; (b) garbage value (`'spaceship'`, a number, a map) → `vehiclePreference == null`, **no** thrown exception. Confirms the nullable preference round-trips and degrades safely. Pairs with TC-604 (displayed-mode fallback).

---

### Case: Cosmetic-only — engine truth byte-for-byte identical across all six picks vs the no-preference baseline
**ID:** TC-608
**Priority:** P0
**Type:** edge
**Covers:** AC-8

Given a fixed injected input sequence run through the engine once as the **no-preference baseline** (`vehiclePreference == null`)
When the **same** input sequence is run once per each of `TravelMode.values` set as `vehiclePreference`
Then for **every** preference the engine's `distanceKm` / `state` / `activeTimeToday` / `rawActiveTime` / `idleTimeToday` are **byte-for-byte identical** (exact equality, not ±epsilon) to the no-preference baseline — the pick changes the rendered skin/cockpit only, accrues no distance, and shifts no idle/active decision

**Notes:** Cubit/integration test asserting **exact equality** of all five engine outputs across the baseline vs each of the six preference runs, same injected elapsed/activity. Parameterise over all six modes. The runtime half of the cosmetic-only guarantee; the *path-absence* half is the firewall TC-610 (necessary AND sufficient only together). Mirrors journey-pov AC-10 / journey-cockpit-lean AC-12.

---

### Case: JourneyCubit stays a pure reader — never writes the engine to apply the preference; engine never reads the preference (runtime)
**ID:** TC-609
**Priority:** P0
**Type:** edge
**Covers:** AC-9

Given the override is composed at/above `JourneyViewState`, with a non-null `vehiclePreference == p` differing from the engine mode
When `JourneyCubit.updateFromEngine(engine)` runs across several ticks
Then it stays a **pure reader** — it does **not** write `engine.mode` (nor any engine field) to apply the preference; `engine.mode` is unchanged by the picker, and the effective displayed mode (`p`) is resolved **above** the view state, not by `updateFromEngine` mutating or re-reading the engine to swap the mode

**Notes:** Cubit test: set `vehiclePreference == p`, capture `engine.mode` before/after several `updateFromEngine` calls, assert `engine.mode` is unchanged (no write) AND the composed displayed mode is `p` (resolved above the view state). The runtime half of AC-9; the structural half (engine holds no reference to the preference / `updateFromEngine` does not read it to swap) is folded into the firewall TC-610. Guards ADR-0007 rejected-alternative 4 (do **not** apply the override inside `updateFromEngine`).

---

### Case: FIREWALL — the engine references neither the preference nor the settings store (static; goes RED if wired into accrual)
**ID:** TC-610
**Priority:** P0
**Type:** regression
**Covers:** AC-10

Given ADR-0007's permanent rule that the cosmetic pick must **never** feed accrual or speed (now or after `journey-energy-model`)
When the engine source and the engine-read path are inspected statically (imports + references)
Then `JourneyEngine` (`journey_engine.dart`) has **no import of / reference to** `AppSettings`, `AppSettings.vehiclePreference`, `SettingsCubit`, `SettingsRepository`, or the settings store, and the preference reaches the render **only** via the `applyState(mode:)` seam (composed above `JourneyViewState`, never read by the engine) — a structural guard sibling to journey-cockpit-lean TC-511/TC-512's separation guards

**Notes:** **Load-bearing case.** Static-inspection test (grep / import + reference scan) over `journey_engine.dart` and the engine read path. Assert the engine imports only its pure-domain deps and references **none** of {`AppSettings`, `vehiclePreference`, `SettingsCubit`, `SettingsRepository`}. **Designed to FAIL RED** the moment someone wires the pick toward accrual/speed (the deferred `journey-energy-model` must take speed from the *engine-owned* `TravelMode`, never from `vehiclePreference`). AC-8 (TC-608) is NOT sufficient here — in v1 a path would be inert and pass AC-8 silently. Pairs with the negative mutation twin TC-610b.

---

### Case: FIREWALL negative twin — an engine that reads the preference must be a RED test
**ID:** TC-610b
**Priority:** P0
**Type:** negative
**Covers:** AC-10

Given the firewall assertion of TC-610 (engine references neither the preference nor the settings store)
When a hypothetical build makes the engine import/reference `AppSettings.vehiclePreference` (or the settings store) — e.g. to drive accrual/speed from the cosmetic pick
Then TC-610's assertion **FAILS** — confirming the firewall is genuinely checked and a wiring-the-pick-into-accrual regression cannot pass silently (the most dangerous regression this slice can suffer, invisible in AC-8 while v1 is single-speed)

**Notes:** The **mutation / guard** companion to TC-610: documents that TC-610 is an *absence-of-reference* assertion, not merely a happy-path import scan. The test-script-author may realise this as a fault-injection (introduce a stub engine reference behind a test flag and assert the inspection flags it) or as the explicit "engine references NONE of {…}" assertion in TC-610 with this case as its rationale. Load-bearing per ADR-0007 decision 5 ("never, now or later, feed accrual/speed").

---

### Case: Two entry points, one source — a change in either picker reflects in the other (no second store)
**ID:** TC-611
**Priority:** P0
**Type:** happy-path
**Covers:** AC-11

Given one `SettingsCubit` with both the **persistent picker** (Settings row + journey affordance) and the **route-start picker** (`RoutePlannerFlow`) bound to it
When the vehicle is changed via the **persistent** picker to `m1` and then, separately, via the **route-start** picker to `m2`
Then both writes go through the **same** `SettingsCubit.setVehicle(...)` to the **single** `AppSettings.vehiclePreference` — there is **no second store**: after the persistent-picker change the route-start picker reads `m1`, and after the route-start change the persistent picker (and the displayed mode) reads `m2`, with no divergence

**Notes:** Widget/integration test against **one** `SettingsCubit`. Leg (a): change via persistent picker → assert route-start picker's selection + `vehiclePreference == m1`. Leg (b): change via route-start picker → assert persistent picker + displayed mode == `m2`. Asserts a single source of truth (no parallel preference field). Pairs with TC-612 (pre-seed) and TC-613 (route-start write-back).

---

### Case: Route-start picker is pre-seeded from the saved preference
**ID:** TC-612
**Priority:** P0
**Type:** edge
**Covers:** AC-12

Given a saved `vehiclePreference == m`
When the route-start picker surfaces on the `RoutePlannerFlow` review/confirm step
Then it opens **pre-seeded** to `m` (the current saved value), not blank/default — the user sees their existing choice; and with `vehiclePreference == null` it pre-seeds to the engine-default display (`motorbike`) per AC-4

**Notes:** Widget test mounting the route-start picker bound to a `SettingsCubit`. Leg (a): `vehiclePreference == m` → initial selection is `m`. Leg (b): `vehiclePreference == null` → initial selection is `motorbike`. Confirms pre-seed reads the single source (ADR-0007 decision 4). Pairs with TC-611, TC-613.

---

### Case: Route-start surfaces the skippable picker; confirming keeps the chosen vehicle (write-back, survives)
**ID:** TC-613
**Priority:** P0
**Type:** happy-path
**Covers:** AC-13

Given the user begins a new route via `RoutePlannerFlow`, the vehicle-pick affordance surfaced on the review/confirm step (pre-seeded per AC-12, **skippable** — not a mandatory step)
When the user picks a vehicle `m'` in the route-start flow and confirms the route (`onConfirmed(ResolvedRoute)` fires)
Then the chosen vehicle is **applied and kept** — written back to the **same** `vehiclePreference` via `SettingsCubit.setVehicle(m')` so it survives per AC-5/AC-6 — and the scene displays `m'`; confirming the route does **not** reset or discard the pick. Symmetric skip leg: a user who does **not** touch the picker and just confirms keeps their current vehicle unchanged

**Notes:** Widget/integration test over `RoutePlannerFlow`'s review/confirm step. Leg (a): pick `m'`, confirm → assert `vehiclePreference == m'` after `onConfirmed` and the composed displayed mode == `m'`. Leg (b): do not touch the picker, confirm → assert `vehiclePreference` unchanged (skippable). The route engine/resolver does NOT store the vehicle (ADR-0007 decision 4 — presentation-layer coupling only). Pairs with TC-611/TC-612.

---

### Case: Distinct icon per all six modes — an icon-based picker, not a bare text dropdown
**ID:** TC-614
**Priority:** P0
**Type:** edge
**Covers:** AC-14

Given the picker renders
When its option set is inspected
Then it shows a **distinct icon (asset/widget) per mode for all six `TravelMode.values`** (`walk` / `run` / `bicycle` / `motorbike` / `car` / `ship`) — a visual, icon-based picker, **not** a bare text dropdown — with no two modes sharing the same icon asset

**Notes:** Widget test: enumerate the six options and assert each surfaces a distinct icon asset/widget (six distinct icon paths/keys), and that the control is icon-based (e.g. a tappable icon grid/row, not a `DropdownButton<TravelMode>` of text labels). The "reads as one cohesive set in the journey art family" + chosen-vs-available legible not-by-colour-alone judgement is the review gate **TC-M-ART** (and the NFR-3 not-colour-alone leg). Pairs with TC-615 (CREDITS) and TC-617 (a11y labels).

---

### Case: Every new icon path is license-clean and CREDITS-attributed; picker loads no uncredited icon
**ID:** TC-615
**Priority:** P0
**Type:** regression
**Covers:** AC-15

Given the picker ships new icon assets declared in the asset manifest, and `assets/CREDITS.md`
When the set of icon paths the picker declares/loads is enumerated and cross-checked against `assets/CREDITS.md`
Then **every** icon that requires attribution (CC0/CC-BY, sourced via `ui-asset-curator` / `/source-assets`) is listed with its **source + licence**, and the picker loads **no** icon asset that is **absent** from CREDITS (each requested icon path has a matching CREDITS entry) — no unclear / paid / "personal-use-only" licences

**Notes:** Static/manifest test (`src/focus_journey/test/`) mirroring journey-pov TC-219: enumerate the picker icon paths, parse `assets/CREDITS.md`, assert each has a matching entry with source + licence and that no uncredited icon path is loadable. CC-BY requires the attribution be **present**. Re-run whenever a picker icon is added. The "actually license-clean" provenance judgement is reinforced by TC-M-PRIV / curator provenance.

---

### Case: NFR-1 guard — override is an O(1) composition above the view state; no new per-frame cost in JourneyGame
**ID:** TC-616
**Priority:** P1
**Type:** regression
**Covers:** NFR-1

Given the override `vehiclePreference ?? engineDerivedMode` is resolved at/above `JourneyViewState` and `JourneyGame.applyState` still takes one `mode:` value
When the override resolution is inspected (static) and the scene is exercised across many `update(dt)` pumps with a preference set
Then resolving the override adds at most an **O(1)** nullable-coalesce where the view state is assembled — **no new per-frame work** in `JourneyGame` (its `applyState(mode:)` contract is unchanged, it does not re-resolve the preference per frame), **no per-frame allocation** introduced by the override, and the inherited journey-pov / journey-cockpit-lean no-per-frame-alloc / bounded-pool guards still hold with a preference set

**Notes:** Static inspection + the inherited hot-path guards re-run with `vehiclePreference` set. Assert (a) the override is composed once where the view state is built (not inside the scene's per-frame loop), (b) `JourneyGame` gained no new per-frame work / allocation for the override, (c) `applyState`'s signature/contract is unchanged. Deterministic proxy for NFR-1; sustained ≥30fps on both surfaces (full window + PiP) is the device leg **TC-M-NF1**.

---

### Case: NFR-3 widget leg — each mode option exposes a per-mode screen-reader label and is focus-reachable
**ID:** TC-617
**Priority:** P1
**Type:** edge
**Covers:** NFR-3, AC-14

Given the picker renders with the six mode options
When the widget tree's semantics are inspected
Then each of the six options carries a **semantics label naming the mode** (e.g. "Walk", "Run", "Bicycle", "Motorbike", "Car", "Ship"), each option is **focus-reachable** (in the focus traversal, operable without a pointer), and the chosen/available state is conveyed by the per-mode icon + label (not by colour alone); the picker does **not** trap focus or obscure essential journey readouts

**Notes:** Widget test using the semantics tester: assert a `Semantics` label per mode naming it, all six in the focus traversal order, and no focus trap (focus can leave the picker). The widget-level half of NFR-3; the **real** keyboard-only operation + real VoiceOver/Narrator announcement pass is the manual `[REAL-OS]` **TC-M-A11Y**, and the not-colour-alone visual read is **TC-M-ART**. Pairs with TC-614 (distinct icons carry the mode).

---

### Case: End-to-end smoke — pick in Settings reflects on both surfaces; route-start pick propagates; restart restores
**ID:** TC-618
**Priority:** P1
**Type:** regression
**Covers:** AC-1, AC-6, AC-11, AC-13

Given the app launched with the mock activity + mock window/visibility path, the shared `JourneyGame` rendering on **both** the full window and the sized-down PiP, one `SettingsCubit` over an in-memory repository, `vehiclePreference == null` initially (displayed mode follows engine default)
When the user picks `car` in the persistent picker (the car cockpit appears on **both** surfaces), then begins a route via `RoutePlannerFlow`, changes the route-start picker to `ship` and confirms (the displayed mode becomes `ship` on both surfaces, `vehiclePreference == ship`), then the app is "relaunched" by reconstructing `SettingsCubit` from the persisted settings
Then across the flow the pick reflects on **both** surfaces within a frame, both pickers stay in sync off the single preference, the route-start confirm keeps the pick, and after relaunch the scene opens on `ship` (restored before the first `applyState`) — confirming the picker↔preference↔display wiring on the shared game

**Notes:** `integration_test` (`src/focus_journey/integration_test/`) on the real widget tree with the **mock** activity + window/visibility path (deterministic, no real OS). The mock-path twin of the manual real-OS legs. Drives picks via the real pickers; frames via the harness. Per-surface / cockpit-branch detail is TC-601/TC-602; restore detail is TC-606p.

---

## Manual / on-device + review legs (see the companion checklist)

These verify what is **NOT cheaply automatable**. They live in
[vehicle-picker-manual-checklist.md](vehicle-picker-manual-checklist.md) and are flagged here.

- **TC-M-ART** `[VISUAL]` `[REVIEW]` — icon cohesion + not-colour-alone accessibility read: the six per-mode icons
  read as **one cohesive set** in the journey art family (not a mismatched outlier), each mode's icon/silhouette is
  **distinct**, and the chosen-vs-available state is legible **without relying on colour alone** (AC-14 gate +
  NFR-3 visual leg). Automated structural legs: distinct-icon-per-mode TC-614, asset⇄CREDITS TC-615, semantics
  labels TC-617. A cohesion or not-colour-alone fail **blocks ship for the picker art** even if TC-614/TC-615 pass.
- **TC-M-A11Y** `[REAL-OS]` — real keyboard-only operation + screen-reader pass: the picker is reachable and
  operable with the keyboard alone, and a real VoiceOver (macOS) / Narrator (Windows) pass announces each option's
  per-mode name; the picker does not trap focus or obscure the journey readouts (NFR-3 real leg). Automated widget
  leg: TC-617.
- **TC-M-NF1** `[DEVICE]` — sustained **≥30fps on both surfaces** (full window + sized-down PiP) with a preference
  set and the displayed mode overridden, while `active` on macOS + Windows (NFR-1). Automated proxy: TC-616
  (O(1) composition, no new per-frame cost) + the inherited bounded-pool / no-alloc guards.
- **TC-M-PRIV** `[AUDIT]` — `/privacy-audit` PASS: the picker stores **only** a local cosmetic `TravelMode?`
  preference via the existing `shared_preferences` settings store — it reads **no** OS / activity / screen /
  location signal, opens no network egress, and adds no new dependency or platform channel (NFR-2). **Ship-blocker.**
  Reinforced by the AC-10 firewall (TC-610) + the AC-9 separation.

---

## Coverage table (AC / NFR → covering case IDs)

| Item | Description | Covered by |
|---|---|---|
| AC-1 | pick → displayed mode swaps ≤1 frame (sprite + branch off one value) | TC-601, TC-618 |
| AC-2 | cockpit branch resolves off displayed mode (car-over-walk → car cockpit) | TC-602 |
| AC-3 | set preference wins for display | TC-603 |
| AC-4 | no preference → engine-derived mode; first launch motorbike | TC-604 |
| AC-5 | pick persisted — setVehicle emit + repository save | TC-605 |
| AC-6 | persisted pick restored, seeded before first applyState | TC-606p, TC-618 |
| AC-7 | absent / corrupt stored value → null, no crash | TC-607 |
| AC-8 | engine truth byte-for-byte identical across all six picks | TC-608 |
| AC-9 | JourneyCubit pure reader; engine never reads the preference (runtime) | TC-609 (+ static via TC-610) |
| AC-10 | **firewall** — no path from preference into accrual/speed (static guard) | **TC-610**, TC-610b (negative) |
| AC-11 | two entry points, one source — no divergence, no second store | TC-611, TC-618 |
| AC-12 | route-start picker pre-seeded from the saved preference | TC-612 |
| AC-13 | route-start surfaces skippable picker; confirm keeps the pick | TC-613, TC-618 |
| AC-14 | distinct icon per all six modes, not a text dropdown | TC-614, TC-617; **[VISUAL]** TC-M-ART |
| AC-15 | every icon license-clean + CREDITS-attributed; none uncredited loaded | TC-615 |
| NFR-1 | O(1) composition, no new per-frame cost; ≥30fps both surfaces | TC-616; **[DEVICE]** TC-M-NF1 |
| NFR-2 | cosmetic local pref only; no OS read / network / dep; /privacy-audit PASS | **[AUDIT]** TC-M-PRIV (reinforced by TC-610, TC-609) |
| NFR-3 | keyboard-reachable; per-mode screen-reader labels; not colour-alone | TC-617; **[REAL-OS]** TC-M-A11Y, **[VISUAL]** TC-M-ART |

Every AC (AC-1..AC-15) and every NFR (NFR-1..NFR-3) maps to at least one case. No AC/NFR is orphaned.

### Coverage notes / flagged gaps

- **AC-10 is the load-bearing firewall and is a static absence-of-reference guard, not a behavioural assert.** TC-610
  asserts `JourneyEngine` references **none** of {`AppSettings`, `vehiclePreference`, `SettingsCubit`,
  `SettingsRepository`} and the preference reaches the render only via `applyState(mode:)`; TC-610b is the dedicated
  **negative** twin documenting that an engine that reads the preference must be a RED test. AC-8 (TC-608,
  byte-for-byte) is **necessary but not sufficient** — in v1's single-speed world a wired-in path would be inert and
  pass AC-8 silently, which is exactly why the static path-absence guard exists.
- **AC-4 "no preference" semantics is a spec-flagged open question** (proposed: default = follow engine cosmetic
  mode; first launch shows motorbike until the user picks). TC-604 asserts the proposed resolution; **re-pin** the
  first-launch leg if product-domain-expert / reviewer changes first launch to a nudge-to-pick.
- **AC-14 icon cohesion is a REVIEW gate, not a pass/fail assert.** TC-614 proves a distinct icon per all six modes
  and that the picker is icon-based (not a text dropdown); "reads as one cohesive set, legible without colour alone"
  is the review gate TC-M-ART (+ NFR-3 not-colour-alone leg).
- **NFR-3 — widget semantics are automated; real keyboard + screen-reader is manual.** TC-617 asserts per-mode
  semantics labels + focus-reachability + no focus trap in the widget tree; the real keyboard-only operation +
  VoiceOver/Narrator announcement is the manual `[REAL-OS]` TC-M-A11Y.
- **NFR-1 (≥30fps both surfaces) — DEVICE only.** TC-616 (O(1) composition above the view state, no new per-frame
  cost in `JourneyGame`, `applyState` contract unchanged) + the inherited bounded-pool / no-alloc guards are the
  deterministic proxy; sustained frame rate is on-device TC-M-NF1.
- **NFR-2 (privacy) — AUDIT gate.** The picker stores only a local cosmetic `TravelMode?` and reads no OS signal /
  opens no network / adds no dependency; `/privacy-audit` PASS (TC-M-PRIV) is the ship-blocker, reinforced by the
  AC-10 firewall (TC-610) + the AC-9 separation (TC-609 / the engine-import inspection). A fail blocks ship regardless
  of every other pass.
- No AC was left without a **meaningful** case — every functional AC has at least one deterministic case; the only
  clauses without a fully automated case (icon cohesion, real keyboard/screen-reader, on-device fps, privacy audit)
  are explicitly captured in the manual checklist with the journey-pov / journey-cockpit-lean deferral precedent,
  not silently dropped.
</content>
</invoke>
