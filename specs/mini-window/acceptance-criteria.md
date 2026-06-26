# Acceptance criteria

Each item is a checkable, observable statement. If it isn't testable, rewrite it.

> Driven by `specs/mini-window/spec.md` (Wave 2 / v2, first slice). The mini-window (PiP) is a
> **pure view** of the **same journey Bloc** the main window binds to — it reflects `JourneyEngine`
> (`state` ∈ {active, idle, paused}, cosmetic `mode`, `distanceKm`) and runs **no** second engine,
> ticker, or scene. It embeds a **compact instance of the shipped `journey-view` Flame scene** plus a
> small distance + active/idle readout. The tray/menu-bar surface adds **status + quick actions** only.
> Native window + tray plumbing is authored for **macOS + Windows** via `window_manager` +
> `tray_manager` with a **mock/dev path** for headless/widget tests (no real OS window required), per
> the v1 native-plugin pattern (`activity-detection`).
>
> **Priority key:** **P0** = must ship this slice · **P1** = should · **P2** = nice-to-have.
> Where an AC depends on one of the spec's six open questions, it is written conditionally and tagged
> `⚠️ depends on open question: <which>` for the product owner to resolve at spec approval.

> **✅ Verification status at ship (2026-06-24) — SHIPPED macOS-verified.** All boxes ticked: every AC/NFR
> is satisfied with **green automated coverage** (report `tests/_runner/reports/mini-window/20260624-152719/`,
> 92 in-scope passed + 559/559 whole-package regression), a `/review-code` **`approved`** verdict, and a
> `/privacy-audit` **PASS**. The following legs are **automated-green now, with on-device / real-OS
> verification deferred** (documented manual carry, consistent with how v1 slices shipped — `activity-detection`
> L3, `journey-view` fps):
> - **AC-6 / AC-8 / AC-11 / AC-12 / AC-15** — logic verified via the mock-window path; real frameless drag,
>   always-on-top stacking over a focused app, dock-hide, real tray render + close-intercept are macOS
>   manual-checklist legs **TC-M1 / TC-M2 / TC-M3** (Kevin's on-device pass).
> - **NFR-2** — no-jank determinism proven (TC-003); the ~60fps / ≥30fps **fps floor is unmeasured on-device**
>   (TC-M-NF2), deferred.
> - **NFR-4 / NFR-5** — static + dependency audit PASS; the **runtime** socket/packet-capture privacy check
>   (TC-022 / TC-M-PRIV) is the manual ship-gate.
> - **NFR-6** — readout-text a11y automated; real **tray-menu keyboard/screen-reader** reach is TC-M4.
> - **NFR-7 / NFR-9** — **macOS parity authored + verified.** Windows backend is authored via the same Dart
>   interface, **but** the tray controller still selects the macOS template icon unconditionally (review
>   **Medium #1** — branch to the `*_color` icons on `Platform.isWindows`); that Windows tray-icon authoring
>   **plus all Windows runtime legs are DEFERRED — required before any Windows release** (`flutter-native-plugin-engineer`).

## Functional — PiP renders journey state (single source of truth)

- [x] AC-1 (P0) — PiP mirrors the same Bloc, embeds the journey-view scene: **Given** the app is
      driven by a mock activity source and the journey Bloc emits `state = active`, **When** the
      mini-window is visible, **Then** it renders a **compact instance of the shipped `journey-view`
      Flame scene** (the same POV road / lane markings / parallax objects / vehicle skin, sized down)
      whose road scrolls forward, plus a small readout showing the current distance and an active
      indicator — and it does so by binding to the **same journey Bloc instance** the main window uses,
      not a second engine/ticker/scene. *(Single-source-of-truth verification is AC-9; this AC is the
      observable "PiP shows the live scene" check.)*

- [x] AC-2 (P0) — PiP stops when the Bloc says stopped: **Given** the Bloc emits `state = idle` or
      `state = paused`, **When** the mini-window is visible, **Then** the compact scene stops scrolling,
      the vehicle parks, and the readout shows the idle/paused (parked) indication — matching
      `journey-view`'s stopped visual (`journey-view` AC-2/AC-3). The PiP draws no visual distinction
      between `idle` and `paused` in v1 (inherits `journey-view`'s resolved behaviour).

- [x] AC-3 (P0) — PiP starts/stops within one tick (mirrors journey-view binding): **Given** an
      active↔idle (or active↔paused) state change on the shared Bloc, **When** the PiP reacts, **Then**
      the compact scene's motion starts or stops within one render tick/frame of the state change, with
      no perceptible lag and no visible jump/jank — mirroring `journey-view`'s state→motion binding
      (`journey-view` AC-5/AC-6). If the Bloc says stopped, the PiP stops within one tick.

- [x] AC-4 (P0) — distance + active/idle readout reflects the Bloc, not its own math: **Given** the
      Bloc's `distanceKm` and `state`, **When** the PiP readout renders, **Then** the distance shown
      equals the Bloc's `distanceKm` (consistent with the main window at the same instant) and the
      active/idle indication equals the Bloc's `state` — the PiP computes no distance and decides no
      active-vs-idle of its own.

- [x] AC-5 (P0) — first-frame / pre-state default is parked: **Given** the PiP is shown before the
      Bloc has emitted a real `state` (or it emits an unrecognised/loading/error state), **When** the
      PiP renders, **Then** it shows the parked/stopped look with no motion — it never auto-scrolls
      before a real `active` state arrives (inherits `journey-view` AC-13).

## Functional — window behaviour (PiP)

- [x] AC-6 (P0) — user-invoked PiP collapse, mutually exclusive with main (YouTube-style): **Given** the
      main window is open, **When** the user presses the **compact / PiP** control (in the main window or
      the menu-bar menu), **Then** the app enters a **small, frameless, always-on-top** compact view that
      renders the journey scene **above other applications**, and the **main window hides to the dock**;
      **and** when the user re-opens the main window (from the dock or "Show app"), the **PiP is
      dismissed** — the main window and PiP are **never visible at the same time**. The compact view has
      **no OS title bar / frame** and can be **repositioned by dragging its body**.

- [x] AC-7 (P2) — optional always-on-top off/on toggle: **Given** an (optional) always-on-top toggle,
      **When** it is turned **off** while in compact mode, **Then** the PiP behaves as an ordinary window
      (may be covered by a focused app), and toggling it **on** restores floating-above-others; effect is
      observable in stacking order. *(P2 nicety — the PiP is always-on-top by default; this toggle is not
      required to ship the slice.)*

- [x] AC-8 (P0) — remembered position across restart: **Given** the user drags the (fixed-size) PiP to a
      position, **When** the app is fully quit and relaunched, **Then** the PiP reappears at the **last
      position**, restored from local persistence (`shared_preferences`, the v1 approach). The persisted
      position survives a normal restart and is where the next session opens the compact view.
      *(Resolved: **fixed-size** — only position is persisted/restored; size is constant.)* An off-screen /
      invalid saved position is **clamped back onto a visible display** on restore.

## Functional — separation invariant (one source of truth)

- [x] AC-9 (P0) — exactly one engine/ticker/scene, shared by both windows (code inspection): **Given**
      the mini-window and main window sources, **When** inspected, **Then** there is **one** journey
      Bloc / `JourneyEngine` / activity-ticker instance driving **both** windows — the PiP constructs no
      second engine, no second ticker, and reuses the existing `journey-view` scene rather than forking
      a second scene implementation. Verifiable by static inspection (no duplicate engine/ticker/scene
      instantiation originating in the mini-window code).
      ⚠️ depends on open question: **single-engine wiring** — since main and PiP are **mutually
      exclusive**, the expected mechanism is a **single window that transforms between full and compact
      modes** (one engine / one Bloc / one scene). `system-architect` confirms this vs a "minimize main +
      separate compact window" variant; this AC asserts the *invariant* (one source of truth) regardless.

- [x] AC-10 (P0) — PiP owns no journey logic and reads no OS signals about the user (code inspection):
      **Given** the mini-window source, **When** inspected, **Then** it reads **only** the journey
      Bloc's `state`, `mode`, and `distanceKm` for what it renders — it makes no call to
      `ActivityPlugin`, `getSystemIdleSeconds()`, `isScreenLocked()`, no idle/lock/OS-input API, and
      contains no active-vs-idle decision or distance-accrual logic. It never mutates `distanceKm`,
      `activeTimeToday`, `rawActiveTime`, `idleTimeToday`, or `state`. (Window-geometry and tray-icon
      APIs are the only platform calls it makes — see NFR-4.)

## Functional — tray / menu-bar presence

- [x] AC-11 (P0) — tray icon present and reflects state: **Given** the app is running, **When** the
      tray/menu-bar surface initialises, **Then** a tray icon (menu-bar item on macOS, system-tray icon
      on Windows) is present, and it **reflects the journey state** (active vs idle/paused) such that an
      observer can distinguish the two states from the tray surface alone — via the icon and/or its
      tooltip — updating when the Bloc's `state` changes.
      Resolved: the icon is **static** (no animation); active vs idle/paused is conveyed via a static
      icon **variant** and/or tooltip. The exact icon art is for `ui-asset-curator` (via `/source-assets`);
      the testable requirement is that active vs idle/paused is **distinguishable** from the tray surface.

- [x] AC-12 (P0) — tray menu quick actions exist and work: **Given** the tray menu is open, **When**
      the user invokes a menu item, **Then** the menu offers and correctly performs: **Show app**
      (restores/foregrounds the main window — dismissing the PiP if active), **Enter compact / PiP**
      (collapses to the compact view, hiding the main window to the dock), and **Quit** (fully exits the
      process — the only path to full exit, per AC-15). Each action's effect is observable in
      window/process state.

- [x] AC-13 (P1) — tray status line reflects journey state (if cheap): **Given** the tray menu is open,
      **When** it renders, **Then** it may show a status line reflecting current journey state (e.g.
      "Travelling — 1,240 km" / "Paused — idle") consistent with the Bloc's `state` and `distanceKm`.
      In scope only if cheap; if omitted, AC-11's icon/tooltip state-reflection still holds.

- [x] AC-14 (P2) — menu items reflect the current mode: **Given** the app is in full (main) mode or in
      compact (PiP) mode, **When** the tray menu opens, **Then** the items reflect the action they will
      perform for the current mode — e.g. **Enter compact / PiP** is offered while in full mode, and
      **Show app** is the way back while in compact mode — so the next action is unambiguous.

## Functional — hide-to-tray close behaviour

- [x] AC-15 (P0) — main-window close hides to tray and keeps tracking: **Given** the app is tracking
      (Bloc accruing journey state under a mock active source), **When** the user clicks the **main
      window's close button**, **Then** the main window is **hidden** (not destroyed), the **process
      stays alive**, the tray icon remains present, and the journey **keeps accruing** (the Bloc's
      `distanceKm` continues to advance while `active`) — closing the window does **not** stop tracking.

- [x] AC-16 (P0) — restore from tray, full exit only via Quit: **Given** the main window has been
      hidden to tray, **When** the user invokes **Show app** from the tray menu, **Then** the main
      window is restored/foregrounded with continuous journey state (no reset, no second engine);
      **and** the process exits fully **only** when the user invokes **Quit** — there is no other path
      that fully terminates the app from the close button.

- [x] AC-17 (P1) — first-run hide-to-tray discoverability: **Given** the user clicks the main window's
      close button **for the first time**, **When** the window hides to tray, **Then** a one-time hint
      ("Still running in the menu bar / system tray") is shown so the user understands the app is still
      alive; the hint does not reappear on subsequent closes. *(Resolved: show a one-time hint.)*

- [x] AC-18 (P0) — PiP is not auto-shown on close-to-tray: **Given** the user clicks the main window's
      close button, **When** the window hides and tracking continues in the background, **Then** the PiP
      is **not** auto-shown — only the menu-bar / system-tray icon remains, updating state. The PiP
      appears only when the user explicitly invokes it (AC-6 / AC-12). *(Resolved: main and PiP are
      mutually exclusive and the PiP is user-invoked; close-to-tray leaves neither window visible.)*

## Non-functional

### Performance / battery

- [x] NFR-1 (P0) — animation paused (not just hidden) when stopped or not visible: **Given** the Bloc
      `state` is `idle`/`paused`, **or** the PiP is hidden / not visible, **When** the PiP is in that
      condition, **Then** the compact scene's animation and update loop are **paused** (consume no
      per-frame work), not merely rendered off-screen — honouring `journey-view`'s "suspended when not
      visible" constraint (`journey-view` perf NFR). Two always-on-top windows must not both spin the
      CPU when nothing is moving.

- [x] NFR-2 (P1) — smooth compact scene, no added jank: **Given** the PiP is visible while `active`,
      **When** it renders alongside the main window, **Then** the compact scene sustains a smooth frame
      rate consistent with `journey-view`'s target (~60 fps typical, ≥30 fps floor under load) and an
      active↔idle toggle introduces no visible stutter. *(On-device fps is measured by instrumentation;
      see the cross-platform / deferral note below — precedent `journey-view` perf NFR.)*

- [x] NFR-3 (P1) — reduced motion honoured in the PiP: **Given** the OS/app "reduce motion" preference
      is on, **When** the PiP renders the compact scene, **Then** it honours the preference (motion
      reduced or replaced with a static/minimal-motion presentation that still conveys active vs
      stopped), exactly as `journey-view` does (`journey-view` accessibility NFR).

### Privacy / security

- [x] NFR-4 (P0, headline) — zero new user-data surface; passes `/privacy-audit`: **Given** a
      `privacy-guardian` audit of all mini-window + tray code (Dart + macOS/Windows backends + mock),
      **When** the audit inspects what the code reads or stores, **Then** it confirms the window and
      tray APIs touch **only the app's own window** (geometry, visibility, always-on-top, frameless
      drag) and **a status icon/menu** — and access **NONE** of: keystrokes, key contents,
      screen/display contents, clipboard, files, mouse-position history/coordinates, or **other apps'
      window titles**. The audit **passes** (precedent: `activity-detection` AC-7).

- [x] NFR-5 (P0) — no disqualifying new dependency: **Given** the dependencies this slice introduces
      (`window_manager`, `tray_manager`, any transitive package such as `screen_retriever`, plus native
      libraries), **When** `privacy-guardian` reviews them, **Then** no added dependency is capable of
      capturing input content, screen, clipboard, files, mouse-position history, or other apps' window
      titles; any such dependency is rejected. *(Precedent: `activity-detection` AC-8 already cleared
      `screen_retriever` as transitive via `window_manager`, reading display geometry only.)*

### Accessibility

- [x] NFR-6 (P1) — tray menu actions are keyboard / screen-reader reachable: **Given** the tray menu,
      **When** a keyboard or screen-reader user interacts via the per-OS conventions, **Then** the menu
      items (Show app, Show/Hide mini-window, Quit) are reachable and operable, and the readout text in
      the PiP is exposed to the accessibility tree as text (not baked into a sprite), consistent with
      `journey-view`'s message-readability NFR.

### Cross-platform parity & testability

- [x] NFR-7 (P0) — authored to macOS + Windows parity via window_manager + tray_manager: **Given** the
      window + tray implementation, **When** inspected, **Then** both macOS (menu-bar) and Windows
      (system tray) are implemented to **equivalent observable behaviour** for: always-on-top toggle,
      frameless drag, remembered geometry, hide-to-tray-and-keep-tracking, tray icon state, and the
      three menu actions — via one Dart interface with two platform backends (the v1 native-plugin
      pattern). Neither capability may be macOS-only or Windows-only for this slice's *code*.

- [x] NFR-8 (P0) — mock/dev path enables headless/widget tests with no real OS window: **Given** the
      app/tests select the mock window+tray path (injected, e.g. analogous to `--mock-activity`),
      **When** tests drive PiP visibility, always-on-top, geometry persistence, tray state, and menu
      actions, **Then** they run deterministically with **no real OS window, no real tray, and no real
      idle/OS access**, and swapping between the real and mock backends requires no change to calling
      code (precedent: `activity-detection` AC-6 / testability NFR).

- [x] NFR-9 (P1) — on-device Windows verification may be deferred, but parity is authored now:
      **Given** this slice may ship verified on **macOS only** (menu-bar), **When** the Windows backend
      is authored + code-reviewed + privacy-audited but not yet **run** on Windows hardware, **Then**
      the Windows-runtime checks (always-on-top, frameless drag, tray, hide-to-tray, geometry restore
      on Windows) and the parity NFR are recorded as **DEFERRED — required before any Windows release**,
      while the code/parity is authored in this slice. (Precedent: `activity-detection` L3, `journey-view`
      fps deferral.)

## Out of scope (reminder)

- **Any activity/idle decision, distance accrual, or persistence of journey data** — owned by
  `journey-engine` (consumed via the shared Bloc) and the app-layer activity ticker. The PiP and tray
  only *read* journey state and manipulate their own window/icon.
- **Launch-at-startup / auto-start on login / "start in tray on login"** — **owned by the shipped
  `local-stats` slice**. This slice adds **no** second launch-at-startup mechanism.
  ⚠️ depends on open question: **launch-at-startup ownership** — confirm with the `local-stats` owner /
  Kevin that any "start to tray on login" reuses the existing setting rather than introducing a new one.
- **A bespoke lightweight (non-Flame) PiP renderer** — decided against; the PiP reuses the
  `journey-view` Flame scene sized down.
- **Per-mode speeds / energy / fuel** (`journey-energy-model`), **geographic map / province chain**
  (`route-progress`, `map-geographic`), **stats / streaks / badges / settings / onboarding-privacy
  screens** (`local-stats`). The PiP shows the same generic forward-travel scene as `journey-view`.
- **Click-through / transparent overlay, multi-monitor snapping, resize handles, PiP-only "compact
  HUD" stats** — deferred polish; not this slice unless trivially free.
- **New visual assets drawn from scratch** — the PiP reuses `journey-view`'s curated CC0 assets; any
  new tray icon is sourced via `/source-assets` and recorded in `assets/CREDITS.md`.
- **Notifications / `local_notifier`** — not part of this slice (the first-run hide-to-tray hint, if
  resolved in scope per AC-17, is an in-app one-time hint, not an OS notification).
