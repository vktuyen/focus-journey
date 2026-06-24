# Test cases: mini-window

Spec: [specs/mini-window/spec.md](../../specs/mini-window/spec.md) — **approved (2026-06-24)**
Acceptance criteria: [specs/mini-window/acceptance-criteria.md](../../specs/mini-window/acceptance-criteria.md)
Decision: [ADR-0003](../../docs/architecture/decisions/0003-mini-window-single-window-two-mode.md) — single-window two-mode (full ⇄ compact PiP), not multi-window (extends ADR-0002).
Upstream (shipped): [specs/journey-view/spec.md](../../specs/journey-view/spec.md) — the Flame scene reused, sized down (state→motion contract these cases inherit).
Upstream (shipped): [specs/journey-engine/spec.md](../../specs/journey-engine/spec.md) — supplies `state` ∈ {active, idle, paused}, cosmetic `mode`, `distanceKm` via the journey Bloc.
Related (shipped): [specs/local-stats/spec.md](../../specs/local-stats/spec.md) — **owns launch-at-startup**; this slice adds no second mechanism.

## Scope of these cases

These cases verify the **mini-window slice** — a user-invoked, frameless, always-on-top **compact PiP
mode** and an always-present **menu-bar / system-tray** surface — as a **pure mirror of journey state**
on top of the single shared engine/Bloc/Flame `JourneyGame` (ADR-0003: one `FlutterEngine`, one window
that transforms between **full** and **compact**, never a second window/engine/scene). They cover:

- the **compact scene** as a pure VIEW of the Bloc — scrolls while `active`, parks while `idle`/`paused`,
  reacts within one tick, shows a distance + active/idle readout that equals the Bloc's values, defaults
  to parked before a real state, and honours reduce-motion (mirrors `journey-view`'s state→motion contract);
- **mutual exclusion** between main and PiP, both directions (enter PiP → main hides to dock; Show app /
  open main → PiP dismissed; never both visible);
- **hide-to-tray-keeps-tracking** on close, **restore via Show app** with continuous state (no reset / no
  second engine), **Quit** as the only full-exit path (and Quit flushes state);
- the **tray icon reflecting state**, the **tray menu actions** (Show app · Enter compact/PiP · Quit), an
  optional status line / mode-aware items;
- **fixed-size PiP**, position persisted across restart and **clamped** when off-screen/invalid;
- the **separation / privacy** invariants (PiP reads only `state`/`mode`/`distanceKm`; zero new user-data
  surface; passes `/privacy-audit`); cross-platform **parity** authored via `window_manager` +
  `tray_manager`; the **mock window/tray path** that makes the above deterministic headlessly;
- **NFR-1** (animation paused — not just hidden — when idle/paused or not visible).

They deliberately do **NOT** re-exercise: active/idle judgment, the grace/threshold model, distance
accrual, sleep/wake, midnight rollover (all `journey-engine`, tested there); the *full*-mode road scene's
own state→motion goldens (`journey-view`, tested there — these cases assert the **compact** instance and
the **shared-game** wiring); stats / streaks / badges / settings / onboarding (`local-stats`); real OS
idle/lock acquisition (`activity-detection`); per-mode speeds / energy (v2 `journey-energy-model`);
launch-at-startup (owned by shipped `local-stats` — explicitly out of this slice).

## Conventions used by these cases

- **Mock window + tray path, no real OS window.** Per NFR-8 and ADR-0003, the `window_manager` /
  `tray_manager` backends sit behind a Dart interface with an **injectable mock/dev path** (analogous to
  `--mock-activity`, e.g. a `mock-window=true` dart-define / DI flag). Automated cases drive PiP
  visibility, mode, always-on-top, geometry persistence, tray icon state, and menu actions through the
  **mock** — asserting the **calls made** and the **resulting app/window-state model**, with **no real OS
  window, no real tray, no real dock**. Cases that genuinely need a real OS window (real stacking over
  another app, frameless drag, dock hide, real tray rendering) live in the **companion manual checklist**
  ([mini-window-manual-checklist.md](mini-window-manual-checklist.md)) and are flagged `[REAL-OS]` here.
- **No real OS, no real timers, no wall-clock waits (compact scene).** As in `journey-view`, the journey
  Bloc is replaced by a **deterministic, scriptable state source** (a fake Bloc / mocked stream emitting
  `state`/`mode`/`distanceKm` on command); frame advancement is driven explicitly
  (`game.update(dt)` / `pump(duration)`), never by awaiting real time.
- **"Within one tick / one render frame"** means: after the Bloc emits a new `state`, the compact scene's
  motion responds on the **next** `update(dt)` pump — asserted by comparing scroll offset across one or
  two explicit pumps, not by measuring wall-clock latency.
- **"Stopped" / "moving" assertions** reuse `journey-view`'s definitions: *stopped* = road/lane/side-object/
  vehicle-travel offsets all unchanged across consecutive pumps (±1e-6); *moving* = those quantities
  advance monotonically while `state == active`.
- **"Same game instance" assertion (AC-9).** The compact view and full view must render the **same** Flame
  `JourneyGame` object (identity), not a copy — asserted by comparing object identity of the game passed to
  each `GameWidget`, plus static inspection that the mini-window code constructs no new
  engine/ticker/`JourneyGame`/scene.
- **Window-state model.** The mock window backend exposes an observable model — `{ mode ∈ {full, compact},
  mainVisible: bool, pipVisible: bool, alwaysOnTop: bool, frameless: bool, position, isClosedToTray: bool,
  processAlive: bool }` — so window transitions are deterministically assertable headlessly. The mock tray
  backend exposes `{ iconVariant, tooltip, menuItems[], lastInvokedAction }`.
- **Test layer per `docs/architecture/overview.md`.** Executable tests live under `src/focus_journey/`:
  compact-scene behaviour, mock-window transitions, tray model, geometry persistence/clamp → **widget /
  integration tests** (`src/test/`, `src/integration_test/`); the single-engine / no-OS-signal separation,
  asset-credit, and privacy cases → **static inspection** (grep / source review) and the manual
  `/privacy-audit`. `tests/cases/` (this file) holds the human-readable scenarios only; no executable test
  is placed under the top-level `tests/` tree. Reports go to `tests/_runner/reports/mini-window/<timestamp>/`.
- **Float tolerance.** Scroll offsets / window positions compare within **±1e-6** logical px unless stated
  otherwise.

## Cases

### Case: Compact PiP scene scrolls + shows the live distance/active readout while active
**ID:** TC-001
**Priority:** P0
**Type:** happy-path
**Covers:** AC-1

Given the app is driven by a mock activity source, the PiP/compact view is visible, and the fake Bloc has emitted `state = active` with a known `distanceKm`
When the compact scene is advanced by several explicit `update(dt)` pumps
Then it renders a **compact instance of the shipped `journey-view` Flame scene** (same POV road / lane markings / parallax side objects / vehicle skin, sized down) whose road scrolls forward (motion quantities advance monotonically across the pumps), and a small readout shows the current distance and an active indicator — driven by binding to the **same** journey Bloc the main window uses, not a second engine/ticker/scene

**Notes:** Widget test (`src/test/`) on the compact subtree with the mock window path; assert scroll/lane/side-object/vehicle advance across pumps + the readout text. Single-source verification is TC-009/TC-010; this is the observable "PiP shows the live scene" check. The visible-above-another-app leg is the real-OS [REAL-OS] TC-M2 in the manual checklist.

---

### Case: Compact scene parks when the Bloc says idle/paused, readout shows parked
**ID:** TC-002
**Priority:** P0
**Type:** happy-path
**Covers:** AC-2

Given the compact view is visible and the fake Bloc emits `state = idle` (and, in a sibling run, `state = paused`)
When the compact scene settles and is advanced by several `update(dt)` pumps
Then the road/lanes/side-objects stop (offsets unchanged across pumps), the vehicle shows its parked pose, and the readout shows the idle/paused (parked) indication — matching `journey-view`'s stopped visual, with **no** visual distinction drawn between `idle` and `paused` in v1 (inherited)

**Notes:** Widget test (`src/test/`) asserting stopped quantities + the parked readout for both `idle` and `paused`. Reuses `journey-view`'s "stopped" definition. Readout text legibility/semantics is TC-021.

---

### Case: Compact scene starts/stops within one render tick of the state change, no jump/jank
**ID:** TC-003
**Priority:** P0
**Type:** happy-path
**Covers:** AC-3

Given the compact view is visible and the fake Bloc emits an `active ↔ idle` (and, separately, `active ↔ paused`) state change on the shared Bloc
When the compact scene is pumped once across the transition
Then motion starts (stopped → active) or stops (active → stopped) on that **next** `update(dt)` pump — no extra frames of delay between "Bloc says X" and the scene reacting — with no perceptible lag and no instantaneous offset jump/jank (offset changes continuously, not in one large step)

**Notes:** Widget/integration test snapshotting offset at the emission, pumping once, asserting the expected start/stop on that pump. Mirrors `journey-view` AC-5/AC-6. "Within one tick" == next pump, never a wall-clock measurement. On-device no-jank is the [REAL-OS] perf leg TC-M-NF2 (deferred per NFR-2).

---

### Case: Readout distance + active/idle equals the Bloc's values (PiP computes nothing of its own)
**ID:** TC-004
**Priority:** P0
**Type:** happy-path
**Covers:** AC-4

Given the fake Bloc reports a known `distanceKm` and `state`, with the full-mode readout (or a sibling-instant snapshot) available for comparison
When the compact readout renders
Then the distance shown **equals** the Bloc's `distanceKm` (consistent with the main window at the same instant) and the active/idle indication **equals** the Bloc's `state` — the PiP computes no distance and decides no active-vs-idle of its own; changing `distanceKm`/`state` on the Bloc changes only what is displayed

**Notes:** Widget test (`src/test/`) asserting readout value == Bloc value across several `(distanceKm, state)` snapshots, tolerating documented display rounding while asserting the underlying value. Pairs with the write-free purity case TC-010.

---

### Case: First-frame / pre-state / unrecognised state defaults to parked (never auto-scrolls)
**ID:** TC-005
**Priority:** P0
**Type:** edge
**Covers:** AC-5

Given the compact view is shown **before** the Bloc has emitted a real `state` (and, in sibling runs, the Bloc emits an unrecognised / loading / error state)
When the compact scene renders and is pumped across several `update(dt)` frames
Then in every case it shows the parked/stopped look with **no** motion — it never auto-scrolls before a real `active` state arrives (inherits `journey-view` AC-13)

**Notes:** Widget test covering (a) initial pre-emission state, (b) an unknown/loading/error state value. Assert zero motion across pumps + parked pose. Guards against a default "always scrolling" compact scene.

---

### Case: User-invoked PiP collapse hides main to dock; entering compact is frameless + always-on-top
**ID:** TC-006
**Priority:** P0
**Type:** happy-path
**Covers:** AC-6 (mock leg), AC-12 (Enter compact via menu)

Given the app is in **full** mode with the main window visible (mock window backend)
When the user invokes the **Enter compact / PiP** control (from the main window or the tray menu)
Then the window-state model transitions to `{ mode: compact, pipVisible: true, mainVisible: false, frameless: true, alwaysOnTop: true }` — i.e. the app enters a small frameless always-on-top compact view **and the main window hides to the dock** — and the mock backend records the corresponding `window_manager` calls (resize to the fixed compact size, `setAsFrameless`/hidden title bar, always-on-top window level, hide main)

**Notes:** Widget/integration test (`src/test/`, `src/integration_test/`) against the **mock window** path; assert the resulting model + the recorded calls. Reuses the same control whether triggered from the main window or the tray menu (Enter-compact leg of AC-12). The **real-OS** "actually floats above a different focused app" + "frameless body is draggable" legs are the [REAL-OS] spike-gate cases TC-M1/TC-M2 in the manual checklist.

---

### Case: Mutual exclusion the other direction — Show app / open main dismisses the PiP
**ID:** TC-007
**Priority:** P0
**Type:** happy-path
**Covers:** AC-6 (mutual-exclusion, reverse direction), AC-12 (Show app)

Given the app is in **compact** mode (`pipVisible: true, mainVisible: false`)
When the user re-opens the main window (via the **Show app** tray action or by opening the main window from the dock)
Then the window-state model transitions to `{ mode: full, mainVisible: true, pipVisible: false }` — the **PiP is dismissed** as the main window is restored/foregrounded — so the main window and PiP are **never visible at the same time** (YouTube-style)

**Notes:** Widget/integration test (mock window path) asserting `pipVisible` flips to false exactly as `mainVisible` flips to true (and the reverse for TC-006). The mutual-exclusion **invariant** ("never both true") is additionally asserted directly in TC-008.

---

### Case: Mutual-exclusion invariant — main and PiP are never simultaneously visible across any sequence
**ID:** TC-008
**Priority:** P0
**Type:** edge
**Covers:** AC-6 (invariant)

Given the mock window backend exposing `mainVisible` and `pipVisible`
When the app is driven through an arbitrary sequence of transitions — Enter compact, Show app, close-to-tray, Enter compact again, Show app, Quit — pumping after each
Then at **no** observed step are `mainVisible` and `pipVisible` **both true** simultaneously; every step satisfies `not (mainVisible and pipVisible)` (they may both be false — e.g. closed-to-tray, TC-014/TC-018)

**Notes:** Property/sequence integration test (`src/integration_test/`) asserting the invariant after every transition. Guards the YouTube-style co-visibility ban regardless of path. Complements the directional TC-006/TC-007.

---

### Case: Single shared engine/ticker/scene drives both modes — no second instance (code inspection + identity)
**ID:** TC-009
**Priority:** P0
**Type:** regression
**Covers:** AC-9, NFR-7 (one-interface structural part)

Given the mini-window source (compact view + window/tray wiring) and the running app
When inspected statically **and** the game objects backing the full and compact `GameWidget`s are compared at runtime
Then there is exactly **one** journey Bloc / `JourneyEngine` / activity-ticker / Flame `JourneyGame` instance driving **both** modes — the full and compact subtrees are passed the **same** `JourneyGame` object (identity equal) and consume the **same** `JourneyCubit`; the mini-window code constructs **no** second engine, **no** second ticker, and forks **no** second scene implementation (per ADR-0003's lifted shared-game refinement)

**Notes:** Static-inspection (grep/source review: no new `JourneyEngine(...)`/ticker/`JourneyGame(...)` originating in mini-window code) **plus** a runtime identity assertion (`identical(fullGame, compactGame)`). The lifted game surviving re-parenting between subtrees without re-init is TC-013. Re-run on any change to the mini-window files.

---

### Case: PiP reads only Bloc state/mode/distanceKm and mutates no journey state (separation invariant)
**ID:** TC-010
**Priority:** P0
**Type:** regression
**Covers:** AC-10, NFR-4 (reinforcement)

Given the mini-window + tray source
When inspected statically (and exercised at runtime through any state sequence)
Then it reads **only** the journey Bloc's `state`, `mode`, and `distanceKm` for what it renders — it makes **no** call to `ActivityPlugin`, `getSystemIdleSeconds()`, `isScreenLocked()`, any idle/lock/OS-input API or platform channel for user signals, and contains **no** active-vs-idle decision or distance-accrual logic; it never writes `distanceKm`, `activeTimeToday`, `rawActiveTime`, `idleTimeToday`, or `state`. The only platform calls present are **window-geometry** and **tray-icon/menu** APIs (`window_manager` / `tray_manager`)

**Notes:** Static-inspection (grep over mini-window files for the forbidden APIs / state writes) + an optional runtime guard via a fake Bloc that records any write attempt and asserts none. Allowed platform calls: window geometry + tray icon/menu only (NFR-4). Pairs with TC-009 and is the static backbone of the `/privacy-audit` case TC-019. Re-run on any change.

---

### Case: Tray icon is present and its variant/tooltip reflects active vs idle/paused
**ID:** TC-011
**Priority:** P0
**Type:** happy-path
**Covers:** AC-11

Given the app is running with the mock tray backend
When the tray/menu-bar surface initialises and the fake Bloc emits `state = active`, then `state = idle`/`paused`
Then a tray icon is present from launch, and an observer can **distinguish** active from idle/paused **from the tray surface alone** — the mock backend's `iconVariant` and/or `tooltip` differs between the two states and **updates** when the Bloc's `state` changes; the icon is **static** (no animation), conveying state via variant/tooltip only

**Notes:** Widget/integration test (mock tray path) asserting `iconVariant`/`tooltip` differs between active and idle/paused and changes on state emission. The exact icon art is `ui-asset-curator`'s (via `/source-assets`, recorded in `assets/CREDITS.md`); the testable requirement is **distinguishability**, asserted on the mock model. Real tray rendering is the [REAL-OS] TC-M3 manual leg.

---

### Case: Tray menu offers and correctly performs Show app · Enter compact/PiP · Quit
**ID:** TC-012
**Priority:** P0
**Type:** happy-path
**Covers:** AC-12, AC-16 (Show-app restore + Quit-only-exit legs)

Given the tray menu is open (mock tray + mock window backends)
When the user invokes each menu item in turn
Then the menu offers **Show app**, **Enter compact / PiP**, and **Quit**, and each produces the observable effect: **Show app** → `{ mode: full, mainVisible: true, pipVisible: false }` (dismissing the PiP if active); **Enter compact / PiP** → `{ mode: compact, pipVisible: true, mainVisible: false }`; **Quit** → `processAlive: false` (full exit — the only such path, per AC-15/AC-16)

**Notes:** Integration test (`src/integration_test/`) against the mock backends asserting the window-state model after each action. Enter-compact / Show-app overlap TC-006/TC-007; Quit's state-flush is asserted separately in TC-017. Real tray clicking is the [REAL-OS] TC-M3 manual leg; menu reachability is the a11y TC-022.

---

### Case: Tray status line reflects journey state and distance (if present)
**ID:** TC-013-STATUS
**Priority:** P1
**Type:** edge
**Covers:** AC-13

Given the tray menu is open with a status line in scope and the fake Bloc reports a known `state` and `distanceKm`
When the menu renders
Then the status line text reflects the current journey state consistent with the Bloc (e.g. "Travelling — 1,240 km" while `active`, "Paused — idle" while `idle`/`paused`), equalling the Bloc's `state`/`distanceKm`; if the status line is omitted, AC-11's icon/tooltip state-reflection still holds (this case then asserts the icon/tooltip fallback)

**Notes:** Widget/integration test (mock tray path) asserting the status-line text == projected Bloc state/distance, OR — if the line is omitted as "not cheap" — asserting the AC-11 icon/tooltip fallback conveys state. P1 / conditional; tolerate display rounding while asserting the underlying value.

---

### Case: Shared JourneyGame survives full⇄compact re-parenting without re-init (no reset)
**ID:** TC-013
**Priority:** P0
**Type:** edge
**Covers:** AC-9 (re-parenting refinement), AC-16 (continuity reinforcement)

Given the single lifted `JourneyGame` rendering in the full subtree with a known accrued in-scene state (e.g. scroll phase) and the Bloc mid-journey
When the app transitions full → compact → full (re-parenting the shared game between subtrees, e.g. via `IndexedStack`/`Offstage`/keep-alive)
Then the **same** `JourneyGame` instance is re-used across both subtrees (identity preserved, no `onLoad`/re-init re-run, no scene rebuild) and the journey continues from its current state — there is no reset and no second engine created by the transition

**Notes:** Integration test (`src/integration_test`) asserting `identical(gameBefore, gameAfter)` and that `onLoad` was not invoked a second time across the transition (e.g. an init-count spy). Encodes ADR-0003's secondary spike obligation. Pairs with TC-009 (one instance) and TC-016 (Show-app continuity).

---

### Case: Optional always-on-top toggle changes stacking behaviour (P2 nicety)
**ID:** TC-014-AOT
**Priority:** P2
**Type:** edge
**Covers:** AC-7

Given the (optional) always-on-top toggle while in compact mode (mock window backend)
When the toggle is turned **off** and then **on**
Then the window-state model's `alwaysOnTop` flips false then true, and the mock backend records the corresponding `window_manager` set-always-on-top calls — so toggling off makes the PiP behave as an ordinary window (may be covered) and toggling on restores floating-above-others

**Notes:** Widget test (mock window path) asserting the `alwaysOnTop` flag + recorded call. P2 — not required to ship; the PiP is always-on-top by default (TC-006). The **real** stacking-order effect over a focused app is the [REAL-OS] TC-M2-AOT manual leg.

---

### Case: Main-window close hides to tray, keeps the process alive, and keeps tracking
**ID:** TC-014
**Priority:** P0
**Type:** happy-path
**Covers:** AC-15

Given the app is tracking under a mock active source (Bloc accruing journey state, `distanceKm` advancing while `active`) with the main window visible
When the user clicks the main window's **close button** (close intercepted via `setPreventClose` + `hide()` in the real backend; modelled in the mock)
Then the window-state model becomes `{ mainVisible: false, pipVisible: false, isClosedToTray: true, processAlive: true }` — the main window is **hidden, not destroyed**, the process **stays alive**, the tray icon remains present, and the journey **keeps accruing** (`distanceKm` continues to advance while `active`); closing the window does **not** stop tracking

**Notes:** Integration test (`src/integration_test`, mock window + scriptable Bloc) asserting (a) main hidden / process alive / tray present after close, (b) `distanceKm` advances across post-close ticks while `active`. The **real** close-intercept-keeps-process-alive-with-tray-updating is the [REAL-OS] spike-gate TC-M3 manual leg. Pairs with TC-018 (PiP not auto-shown) and TC-016 (restore).

---

### Case: First-run close shows a one-time hide-to-tray hint; it does not reappear
**ID:** TC-015
**Priority:** P1
**Type:** edge
**Covers:** AC-17

Given the user clicks the main window's close button for the **first** time (no prior hide-to-tray hint flag in the settings fake)
When the window hides to tray
Then a one-time in-app hint ("Still running in the menu bar / system tray") is shown so the user understands the app is still alive, and a "hint shown" flag is **persisted**; on a **subsequent** close (flag present) the hint is **not** shown again

**Notes:** Widget/integration test (`src/test/`, `src/integration_test`) with the in-memory `shared_preferences` fake: leg (a) no-flag close → hint shown + flag saved; leg (b) flag-present close → no hint. The hint is an **in-app** one-time hint, NOT an OS notification (no `local_notifier` in this slice). Persisted flag round-trips like other settings.

---

### Case: Restore from tray via Show app gives continuous state; full exit only via Quit
**ID:** TC-016
**Priority:** P0
**Type:** happy-path
**Covers:** AC-16

Given the main window has been hidden to tray (TC-014) with the journey mid-state
When the user invokes **Show app** from the tray menu, then later invokes **Quit**
Then **Show app** restores/foregrounds the main window (`mainVisible: true`) with **continuous** journey state — no reset, **no** second engine (the same shared Bloc/`JourneyGame`, TC-009/TC-013) — and the process exits fully **only** on **Quit** (`processAlive: false`); no other path (close button) fully terminates the app

**Notes:** Integration test (`src/integration_test`) asserting (a) post-restore `distanceKm`/`state` continuous with pre-hide values and same game identity, (b) close button never sets `processAlive: false`, only Quit does. Pairs with TC-012 (menu actions), TC-014 (close-to-tray), TC-017 (Quit flush).

---

### Case: Quit flushes the latest journey state before exiting
**ID:** TC-017
**Priority:** P0
**Type:** edge
**Covers:** AC-15/AC-16 (Quit-flushes-state resolved decision)

Given the app running with accrued journey state not yet persisted, via the in-memory persistence fake
When the user invokes **Quit** from the tray menu
Then the latest journey state (e.g. `distanceKm` / day totals) is **persisted** as part of the Quit path — like a normal shutdown — **before** the process exits (`processAlive: false`), so accrued distance is not lost

**Notes:** Integration test (`src/integration_test`) asserting the persistence fake received a write of the current state on the Quit path and that the write happened **before** exit. Encodes the spec's "Quit flushes state" resolved decision. Pairs with TC-016 (Quit-only exit).

---

### Case: Close-to-tray does NOT auto-show the PiP
**ID:** TC-018
**Priority:** P0
**Type:** edge
**Covers:** AC-18

Given the user clicks the main window's close button while tracking continues in the background
When the window hides and the journey keeps accruing
Then the PiP is **not** auto-shown — the window-state model is `{ mainVisible: false, pipVisible: false }` (neither window visible; `isClosedToTray: true`) — only the menu-bar / system-tray icon remains, updating state; the PiP appears **only** when explicitly invoked (TC-006 / TC-012)

**Notes:** Integration test (`src/integration_test`, mock window path) asserting `pipVisible` stays false after a close-to-tray. Encodes the resolved decision (main and PiP mutually exclusive, PiP user-invoked, close leaves neither visible). Pairs with TC-008 (invariant) and TC-014.

---

### Case: Fixed-size PiP position is persisted and restored across a full restart
**ID:** TC-019-POS
**Priority:** P0
**Type:** happy-path
**Covers:** AC-8

Given the PiP at the fixed compact size dragged to a known on-screen position, persisted via the in-memory `shared_preferences` fake
When the app is fully quit and relaunched (fresh Bloc/window-controller restores from the saved blob)
Then the PiP reappears at the **last position** restored from local persistence — only the **position** is persisted/restored (size is the constant fixed compact size, never persisted), and that position is where the next session opens the compact view

**Notes:** Integration test (`src/integration_test`, mock window path) asserting the saved blob holds only a position (no size), and a fresh controller restores the compact view to that position. The **real** frameless drag that produces the new position is the [REAL-OS] TC-M1 manual leg; here the position is set programmatically through the mock. Pairs with TC-019-CLAMP.

---

### Case: Off-screen / invalid saved position is clamped onto a visible display on restore
**ID:** TC-019-CLAMP
**Priority:** P0
**Type:** edge
**Covers:** AC-8 (clamp clause)

Given a saved PiP position that is **off-screen / invalid** for the current display set (e.g. a monitor was unplugged or the resolution changed — display geometry supplied via the mock `screen_retriever` path)
When the app relaunches and restores the compact view
Then the position is **clamped back onto a visible display** so the PiP is fully visible — it is never restored partly or wholly off every screen; a valid in-bounds saved position is left unchanged

**Notes:** Widget/integration test (`src/test/`) feeding the clamp function (a) an off-screen saved position with a mock display layout → assert the result lies fully within a visible display, (b) an in-bounds position → assert unchanged. Uses the mock display-geometry path (`screen_retriever`, already cleared as transitive in activity-detection). Pure-ish clamp logic is unit-testable.

---

### Case: NFR-1 — compact animation/update loop paused (not just hidden) when idle/paused or not visible
**ID:** TC-020
**Priority:** P0
**Type:** edge
**Covers:** NFR-1

Given the compact scene running while `active` and visible
When (a) the Bloc emits `state = idle`/`paused`, or (b) the compact view becomes not-visible (full mode active, or closed-to-tray)
Then in each condition the compact scene's animation and update loop are **paused** (consume no per-frame work — `pauseEngine()` / loop suspended), not merely rendered off-screen: its motion quantities do not advance and no per-frame update runs; on returning to `active`+visible it resumes from the correct state. Two always-on-top surfaces must not both spin the CPU when nothing is moving

**Notes:** Widget/integration test toggling (a) state and (b) visibility/mode and asserting `update(dt)` no longer advances motion and the engine is paused (e.g. a paused-state flag / no-tick spy), then resumes on return. Mirrors `journey-view`'s "suspended when not visible" NFR; trivial with one game loop per ADR-0003. On-device CPU/fps is the [REAL-OS] perf leg TC-M-NF2 (deferred per NFR-2).

---

### Case: NFR-3 — reduce-motion preference honoured in the compact scene, still conveys state
**ID:** TC-021-RM
**Priority:** P1
**Type:** edge
**Covers:** NFR-3

Given the OS/app "reduce motion" preference is ON (injected via the platform/accessibility flag)
When the Bloc emits `state = active` and then `state = idle`/`paused` while the compact view is visible
Then the compact scene reduces or replaces the scrolling motion with a static/minimal-motion presentation (no full scroll) while **still** clearly conveying active vs stopped — a motion-sensitive user can still tell whether the journey is travelling or parked, exactly as `journey-view` does

**Notes:** Widget test with `MediaQuery.disableAnimations` / reduce-motion flag true on the compact subtree. Assert (a) full scrolling suppressed when active, (b) active-vs-stopped distinction still observable. Inherits `journey-view`'s resolved reduce-motion behaviour.

---

### Case: NFR-6 — readout text in semantics tree; tray menu actions keyboard/screen-reader reachable
**ID:** TC-021
**Priority:** P1
**Type:** edge
**Covers:** NFR-6

Given the compact view showing its distance + active/idle readout, and the tray menu
When the semantics tree is queried and the tray menu is navigated via keyboard / screen reader
Then the readout text is exposed to the accessibility tree **as text** (not baked into a sprite/bitmap), and the tray menu items (**Show app**, **Enter compact / PiP**, **Quit**) are **reachable and operable** via the per-OS keyboard / screen-reader conventions

**Notes:** Two legs: (a) widget test querying the semantics tree for the readout string (`find.bySemanticsLabel`/`find.text`) — automatable headlessly; (b) tray-menu keyboard/screen-reader reachability — **[REAL-OS] partly manual** (real menu-bar/tray a11y is OS-driven), recorded as the TC-M4 manual leg per OS. Mirrors `journey-view`'s message-readability NFR.

---

### Case: Tray menu items reflect the current mode (full vs compact)
**ID:** TC-022
**Priority:** P2
**Type:** edge
**Covers:** AC-14

Given the app in **full** mode and (sibling run) in **compact** mode
When the tray menu opens
Then the items reflect the action they will perform for the current mode — e.g. **Enter compact / PiP** is offered while in **full** mode and **Show app** is the way back while in **compact** mode — so the next action is unambiguous

**Notes:** Widget/integration test (mock tray + mock window) asserting the menu-item set/labels differ by `mode`. P2 nicety. Pairs with TC-012 (actions work) and TC-007/TC-006 (the transitions those items trigger).

---

### Case: Cross-platform parity — one interface, macOS + Windows backends, no OS-only capability
**ID:** TC-023
**Priority:** P0
**Type:** regression
**Covers:** NFR-7

Given the window + tray implementation source
When inspected statically
Then both **macOS (menu-bar)** and **Windows (system tray)** are implemented to **equivalent observable behaviour** for: always-on-top toggle, frameless drag, remembered geometry, hide-to-tray-and-keep-tracking, tray icon state, and the three menu actions — via **one** Dart interface with two platform backends plus the mock (the v1 native-plugin pattern); **no** capability is coded macOS-only or Windows-only for this slice

**Notes:** Static-inspection / dependency-direction case (grep + source review): one Dart interface, a macOS backend, a Windows backend, a mock backend; assert each behaviour has both platform paths and that calling code is platform-agnostic. The **on-device Windows runtime** verification is **DEFERRED** per NFR-9 → recorded as the deferred Windows legs in the manual checklist. Pairs with TC-024 (mock path) and TC-009 (single interface).

---

### Case: NFR-8 — mock window+tray path enables deterministic headless tests; swap requires no caller change
**ID:** TC-024
**Priority:** P0
**Type:** regression
**Covers:** NFR-8

Given the app/tests select the **mock** window+tray path (injected, analogous to `--mock-activity`, e.g. `mock-window=true`)
When tests drive PiP visibility, mode transitions, always-on-top, geometry persistence/clamp, tray icon state, and menu actions
Then they run **deterministically** with **no real OS window, no real tray, no real dock, no real idle/OS access**, and swapping between the **real** and **mock** backends requires **no** change to calling code (the interface is identical) — the calls land on the mock model that the other cases assert against

**Notes:** Integration test + static inspection: assert the mock backend is selected by the flag and that calling code (PiP/tray controllers) is unchanged between real and mock (factory/DI seam). This case is the foundation the deterministic cases (TC-006/007/008/011/012/014/016/017/018/019-POS/019-CLAMP/020) depend on. Precedent: `activity-detection` AC-6 / testability NFR.

---

### Case: NFR-5 — no disqualifying new dependency introduced by the slice
**ID:** TC-025
**Priority:** P0
**Type:** regression
**Covers:** NFR-5

Given the dependencies this slice introduces (`window_manager`, `tray_manager`, any transitive package such as `screen_retriever`, plus native libraries)
When `privacy-guardian` reviews the dependency set
Then **no** added dependency is **capable** of capturing input content, screen, clipboard, files, mouse-position history, or other apps' window titles; any such dependency is rejected (precedent: `screen_retriever` already cleared as transitive via `window_manager`, reading display geometry only)

**Notes:** Dependency review — partly static (grep `pubspec.yaml` / lockfile for the dep set + capability check) and folded into the manual `/privacy-audit` (TC-019/TC-M-PRIV). Re-run on any dependency change. A disqualifying dep blocks ship.

---

### Case: Privacy audit — mini-window + tray add zero new user-data surface; passes /privacy-audit
**ID:** TC-019-PRIV
**Priority:** P0
**Type:** negative
**Covers:** NFR-4 (headline), NFR-5

Given all mini-window + tray code (Dart + macOS/Windows backends + mock) and the dependencies it adds
When `privacy-guardian` runs `/privacy-audit`
Then it confirms the window + tray APIs touch **only the app's own window** (geometry, visibility, always-on-top, frameless drag) and **a status icon/menu** — and access **NONE** of: keystrokes, key contents, screen/display contents, clipboard, files, mouse-position history/coordinates, or **other apps'** window titles — and the audit **passes**

**Notes:** **Manual audit case, NOT an automated assertion** (mirrors `journey-view` TC-026 / `local-stats` TC-022 / `activity-detection` TC-018). A fail here **blocks ship** regardless of all other passes. Reinforced by the static-inspection cases TC-010/TC-023 and the dependency case TC-025. Run as the TC-M-PRIV leg in the manual checklist. Re-run on any change to the slice's source or dependency set.

---

### Case: End-to-end smoke — mock-driven journey is glanceable in the compact view and survives close-to-tray
**ID:** TC-026
**Priority:** P1
**Type:** regression
**Covers:** AC-1, AC-2, AC-3, AC-6, AC-15, AC-18

Given the app launched with the mock activity + mock window/tray path, in full mode
When the mock drives `active`, the user enters compact (main hides, PiP scrolls), the mock drives `idle` (PiP parks) then `active` again (PiP resumes within one tick), the user opens main via Show app (PiP dismissed), then clicks close (hides to tray, keeps accruing, PiP not auto-shown)
Then the whole flow holds end to end: compact scene scrolls/parks/resumes mirroring the Bloc, mutual exclusion holds at every step, close-to-tray keeps the process alive + tracking with neither window visible — confirming the full Bloc↔compact↔window/tray wiring

**Notes:** `integration_test` (`src/integration_test/`) on the real widget tree with the **mock** activity + window/tray path (deterministic, no real OS). This is the slice's headline "observable success" check, the mock-path twin of the [REAL-OS] manual triad. Advances state via the mock, frames via the harness.

---

## Coverage table (AC / NFR → covering case IDs)

| Item | Description | Covered by |
|---|---|---|
| AC-1 | PiP mirrors same Bloc; embeds compact journey-view scene; scrolls + readout while active | TC-001, TC-026 |
| AC-2 | PiP parks when Bloc says idle/paused (no idle≠paused distinction) | TC-002, TC-026 |
| AC-3 | PiP starts/stops within one tick, no jump/jank | TC-003, TC-026 |
| AC-4 | distance + active/idle readout equals the Bloc's values | TC-004 |
| AC-5 | first-frame / pre-state / unrecognised → parked, never auto-scrolls | TC-005 |
| AC-6 | user-invoked PiP collapse, mutually exclusive with main, frameless, draggable | TC-006, TC-007, TC-008, TC-026; **[REAL-OS]** TC-M1, TC-M2 |
| AC-7 (P2) | optional always-on-top off/on toggle changes stacking | TC-014-AOT; **[REAL-OS]** TC-M2-AOT |
| AC-8 | fixed-size; position persisted across restart; off-screen clamp | TC-019-POS, TC-019-CLAMP; **[REAL-OS]** TC-M1 (drag) |
| AC-9 | exactly one engine/ticker/scene shared by both modes; no second instance | TC-009, TC-013 |
| AC-10 | PiP reads only state/mode/distanceKm; no OS-user signal; mutates no state | TC-010 (reinforced by TC-019-PRIV) |
| AC-11 | tray icon present + reflects state (static, variant/tooltip) | TC-011; **[REAL-OS]** TC-M3 |
| AC-12 | tray menu Show app / Enter compact-PiP / Quit exist + work | TC-012, TC-006, TC-007; **[REAL-OS]** TC-M3 |
| AC-13 (P1) | tray status line reflects journey state (if cheap) | TC-013-STATUS |
| AC-14 (P2) | tray menu items reflect current mode | TC-022 |
| AC-15 | main-window close hides to tray + keeps tracking | TC-014, TC-026, TC-017 (flush); **[REAL-OS]** TC-M3 |
| AC-16 | restore via Show app continuous; full exit only via Quit | TC-016, TC-012, TC-013 |
| AC-17 (P1) | first-run one-time hide-to-tray hint, not repeated | TC-015 |
| AC-18 | PiP not auto-shown on close-to-tray | TC-018, TC-008, TC-026 |
| NFR-1 | animation paused (not just hidden) when idle/paused or not visible | TC-020 |
| NFR-2 (P1) | smooth compact scene, no added jank | **[REAL-OS / DEFERRED]** TC-M-NF2 (unit no-jank within TC-003) |
| NFR-3 (P1) | reduce motion honoured in PiP | TC-021-RM |
| NFR-4 (P0, headline) | zero new user-data surface; passes /privacy-audit | TC-019-PRIV (reinforced by TC-010, TC-023) |
| NFR-5 (P0) | no disqualifying new dependency | TC-025, TC-019-PRIV |
| NFR-6 (P1) | tray menu actions + readout keyboard/screen-reader reachable | TC-021; **[REAL-OS]** TC-M4 (tray a11y leg) |
| NFR-7 (P0) | macOS + Windows parity via one interface + two backends | TC-023, TC-009; **[REAL-OS / DEFERRED]** Windows legs in checklist |
| NFR-8 (P0) | mock window+tray path → deterministic headless tests; swap needs no caller change | TC-024 |
| NFR-9 (P1) | on-device Windows verification deferred; parity authored now | TC-023; **[DEFERRED]** Windows legs in checklist |

Every AC (AC-1..AC-18) and every NFR (NFR-1..NFR-9) maps to at least one case. No AC/NFR is orphaned.

### Coverage notes / flagged gaps

- **AC-6, AC-7, AC-8 (drag), AC-11, AC-12, AC-15 — partial automation.** The *logic* (mutual exclusion,
  hide-to-tray, geometry persistence/clamp, menu wiring, tray-state model) is fully automatable via the
  **mock** window/tray path (TC-006..TC-008, TC-011, TC-012, TC-014, TC-018, TC-019-POS/CLAMP). What is
  **NOT** mechanically assertable headlessly — real OS-level **always-on-top stacking over a different
  focused app**, **frameless body drag**, **dock hide**, **real tray icon/menu rendering and clicking** —
  is the macOS spike-gate triad (ADR-0003) and lands in the manual checklist (TC-M1/TC-M2/TC-M3). This is
  intentional: the mock path cannot prove OS stacking.
- **NFR-2 (smooth / no added jank) — DEFERRED to on-device.** Like `journey-view`'s fps NFR, sustained
  frame rate / no-stutter is measured by on-device frame-timing instrumentation, not a deterministic unit;
  the unit-level no-jank-on-toggle property is asserted within TC-003. Recorded as deferred TC-M-NF2.
- **NFR-9 (Windows on-device) — DEFERRED by design.** The Windows backend + parity are authored and
  reviewed now (TC-023), but the Windows **runtime** legs (always-on-top, frameless drag, tray,
  hide-to-tray, geometry restore on Windows) are recorded as **DEFERRED — required before any Windows
  release** in the manual checklist (precedent: `activity-detection` L3, `journey-view` fps).
- **NFR-6 — split.** The readout-as-text-in-semantics half is automatable (TC-021 leg a); real tray-menu
  keyboard/screen-reader reachability is OS-driven and is the manual TC-M4 leg.
- No AC could not be given a **meaningful** case — every functional AC has at least one deterministic
  mock-path automated case; the only AC clauses without a *fully* automated case (real OS stacking / drag /
  dock / tray rendering, real Windows runtime, on-device fps) are explicitly captured in the manual
  checklist with the activity-detection / journey-view deferral precedent, not silently dropped.
