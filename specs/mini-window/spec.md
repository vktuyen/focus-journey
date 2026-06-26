# Mini-Window (always-on-top PiP + tray/menu-bar)

**Status:** shipped (2026-06-24, macOS-verified; Windows tray-icon authoring [review Medium #1] + Windows runtime deferred — see acceptance-criteria.md verification-status block / NFR-9)
**Owner:** Kevin (Tuyen Vo)
**Last updated:** 2026-06-24

## Problem
Vietnam Focus Journey only motivates while it is **on screen**. But the whole premise — "I travel
because I am focused" — happens *while the user is working in another app* (an IDE, a browser, a
document). The shipped v1 lives in a single main window that the user must keep foregrounded or lose
sight of; the moment they switch to real work, the journey disappears and the emotional feedback loop
breaks. There is also no lightweight, always-available presence: closing the window today implies the
app (and tracking) is gone.

This slice (Wave 2 / v2) gives the journey a **persistent, glanceable presence** on the desktop while
the user works elsewhere, via two coordinated surfaces:

1. **A user-invoked Picture-in-Picture (PiP) compact mode** — like YouTube's PiP. The user presses a
   "compact / PiP" control; the main window **collapses into a small, frameless, always-on-top** view
   (the shipped `journey-view` scene rendered small + a tiny distance / active-idle readout) that floats
   above other apps, while the **main window hides to the dock**. The two are **mutually exclusive** —
   re-opening the main window from the dock (or "Show app") dismisses the PiP. The compact view is
   draggable and reopens at its last position.
2. **An always-present menu-bar / system-tray icon** — like the Wi-Fi / battery items, the app keeps a
   small status-bar icon whenever it runs (including after the main window is closed). It **reflects the
   current journey state** and, when clicked, shows a little status + quick actions (Show app · Enter
   compact / PiP · Quit). Clicking the main window's **close button hides it and keeps tracking** in the
   background — only **Quit** (from the menu-bar icon) fully exits.

Like every slice, the mini-window is a **pure mirror of journey state** — it renders the same `state`
/ `mode` / `distanceKm` the journey Bloc already exposes and **owns no activity logic**. It reads no
new OS signals about the user (it only manipulates *its own* window and a tray icon). This keeps the
privacy promise intact: a glance at the code shows the PiP consumes engine state, nothing about the
user's input.

The high-risk, OS-specific work here is the **native window + tray plumbing** (always-on-top,
frameless drag, multi-window, tray/menu-bar, hide-to-tray, persisted geometry) across macOS and
Windows — the domain of `flutter-native-plugin-engineer`, using `window_manager` + `tray_manager`
(already named in `docs/architecture/overview.md` as arriving with the v2 mini-window).

## User & outcome
- **The focused individual** (developer / student / remote worker) — the primary beneficiary. They
  pin the mini-window in a corner, switch to their real work, and still see the road scroll while they
  focus and park when they step away — with no need to keep the main app foregrounded. Success = the
  journey stays *felt* during real work, and the app keeps tracking after the main window is closed.
- **The privacy-skeptical teammate** — benefits indirectly: the PiP and tray add **zero** new
  user-data surface. They observe the app's *own* window state and render journey state; they never
  read keystrokes, screen, clipboard, window titles, or anything about *other* apps.

**Observable success:** with the app driven by a mock activity source, the mini-window floats above a
**different focused application**, shows the compact scene scrolling while `active` and parked while
`idle`, can be **dragged** to a new position and **reappears there after restart**; its always-on-top
behavior can be **toggled off/on**; the tray icon **reflects state** and its menu can show the app,
toggle the mini-window, and quit; and clicking the main window's **close button hides it to the tray
while the journey keeps accruing**. Verified on macOS (menu-bar) — Windows (system tray) authored to
parity and verified on-device before any Windows release.

## Scope
### In
- **User-invoked PiP compact mode (mutually exclusive with the main window):**
  - The user presses a **compact / PiP control** (in the main window and/or the menu-bar menu); the app
    enters a **small, frameless, always-on-top** compact view and the **main window hides to the dock**.
    Re-opening the main window (from the dock or the "Show app" menu action) **dismisses the PiP** — the
    two are never shown at the same time (YouTube-style).
  - The compact view renders a **compact instance of the shipped `journey-view` Flame scene** (reused,
    sized down) plus a small **distance + active/idle** readout, reflecting the **same journey state /
    engine** as the main window (one source of truth) — no second engine or ticker, no forked scene.
  - **Draggable / frameless** — no OS title bar; the user drags the body to reposition it. **Always-on-top
    by nature**; an explicit off/on toggle is a secondary nicety (P2).
  - **Remembered position** — the compact view reopens at its **last position** (and size, if resizable),
    persisted via `shared_preferences`; an off-screen / invalid saved position is **clamped back onto a
    visible display**.
- **Always-present menu-bar / system-tray icon:**
  - A **status-bar icon** (menu-bar item on macOS, system-tray icon on Windows), present **whenever the
    app runs** — including after the main window is closed — that **reflects journey state** (active vs
    idle/paused) via a **static** icon and/or tooltip (no animated icon).
  - A **menu** with quick actions: **Show app** (restore the main window), **Enter compact / PiP**, and
    **Quit** (the only full-exit path). A status line (e.g. "Travelling — 1,240 km") is in scope if cheap.
- **Hide-to-tray close behavior:** clicking the **main window's close button hides it** (window hidden,
  process kept alive) and **tracking continues**, leaving only the menu-bar icon updating; the PiP is
  **not** auto-shown on close. The app is restored via **Show app** and fully exited only via **Quit**.
- **Cross-platform parity:** macOS (menu-bar) **and** Windows (system tray) implementations authored
  via `window_manager` + `tray_manager`, mirroring the v1 native-plugin pattern (one interface, two
  platform backends, a mock/dev path for headless UI testing).

### Out
- **Any activity/idle logic, distance accrual, or persistence of journey data** — owned by
  `journey-engine` (consumed) and the app-layer activity ticker. The mini-window and tray only *read*
  journey state and manipulate their own window/icon.
- **Launch-at-startup / auto-start on login** — **owned by `local-stats`** (it already ships a
  launch-at-startup setting behind an interface). This slice does **not** add a second one; if a
  "start in tray on login" behavior is wanted, it reuses/extends that setting in a later edit. *(Flag:
  confirm with `local-stats` owner.)*
- **Per-mode speeds / energy / fuel, geographic map, stats/badges/settings/onboarding screens** — those
  are `journey-energy-model`, `map-geographic`, and the shipped `local-stats`/`route-progress`. The PiP
  shows the same generic forward-travel scene as `journey-view`.
- **A bespoke lightweight (non-Flame) PiP renderer** — decided against; the PiP reuses the Flame scene.
  (Performance is handled by rendering small + pausing animation when not visible, per `journey-view`'s
  constraints — see Open questions on battery/perf.)
- **Click-through / transparent overlay, multi-monitor snapping, resize handles, PiP-only "compact
  HUD" stats** — deferred polish; not v1 of this slice unless trivially free.
- **New visual assets drawn from scratch** — the PiP reuses `journey-view`'s curated CC0 assets; any
  new icon (tray icon states) is sourced via `/source-assets` and recorded in `assets/CREDITS.md`.

## Constraints & assumptions
- **Pure view; one source of truth.** The mini-window binds to the **same journey Bloc** as the main
  window; it owns no journey logic and reads no OS signals *about the user*. If the Bloc says stopped,
  the PiP stops. (It does manipulate its *own* window geometry and a tray icon — neither is user-data.)
- **Privacy unchanged.** No new user-data surface. The `/privacy-audit` gate must still PASS: window
  management and tray APIs touch only the app's own window and a status icon — never keystrokes,
  screen capture, clipboard, files, mouse-position history, or *other* apps' window titles.
- **Native, OS-specific, cross-platform.** Always-on-top + frameless + multi-window + tray is the
  highest-risk work. Authored for **macOS + Windows** via `window_manager` + `tray_manager` (named for
  v2 in `docs/architecture/overview.md`), following the v1 plugin pattern: a Dart interface, platform
  backends, and a mock/dev path so widget/headless tests don't require a real OS window. **Spike first:
  confirm these packages deliver frameless-draggable + reliable always-on-top + hide-to-tray on both
  OSes before committing.**
- **Reuse, don't rebuild.** The PiP embeds the shipped `journey-view` Flame scene and binds to the
  shipped journey Bloc; it must not fork a second engine, ticker, or scene implementation.
- **Smooth + battery-aware on desktop.** Rendering a live scene always-on-top must not spin the CPU
  when nothing moves: animation **paused (not just hidden)** while `idle`/paused and/or while the PiP
  is not visible, honoring `journey-view`'s existing performance constraints.
- **Stack per `docs/architecture/overview.md`:** Flutter desktop, Bloc, Clean Architecture, Flame
  (ADR-0002). Window/tray native code is *presentation/platform*; it depends inward via the Bloc.
- **Accessibility:** honour the OS/app "reduce motion" preference in the PiP as the main scene does;
  ensure tray menu actions are keyboard/screen-reader reachable per-OS conventions.

## Resolved decisions
> Resolved by Kevin on 2026-06-24 (spec review). Two items remain open below.

- [x] **Main / PiP relationship — mutually exclusive, YouTube-style.** The PiP is **user-invoked**;
      entering it collapses the main window into the compact view and **hides the main window to the
      dock**; re-opening the main window dismisses the PiP. They are **never both visible**. (Overrides
      the earlier "independent / both visible" recommendation.)
- [x] **PiP on close-to-tray — not auto-shown.** Closing the main window leaves only the menu-bar icon
      updating in the background; the PiP appears only when explicitly invoked.
- [x] **First-launch behaviour.** The main window opens normally; the PiP is **hidden until invoked**;
      one menu-bar icon is present from launch.
- [x] **Always-on-top.** The PiP is **always-on-top by nature**; an explicit off/on toggle is demoted to
      a **P2** nicety (not required to ship the slice).
- [x] **Off-screen / invalid saved geometry — clamp** the compact view back onto a visible display on
      restore (monitor unplugged / resolution change).
- [x] **Quit flushes state.** Quit (the new exit route) **persists** the latest journey state, like a
      normal shutdown, so accrued distance isn't lost.
- [x] **Tray icon — static** (no animated icon), reflecting state via icon variant and/or tooltip.
- [x] **First-run hide-to-tray hint — show a one-time hint** ("Still running in the menu bar / system
      tray") so the user understands the app keeps running after close; it does not reappear.
- [x] **Launch-at-startup — OUT.** Owned by shipped `local-stats`; reuse that setting if "start to tray
      on login" is ever wanted. No second mechanism here.

### Resolved by architecture (system-architect, 2026-06-24)
- [x] **Single-engine wiring — Option A: single window, two modes.** ONE FlutterEngine / one Bloc graph
      / one Flame `JourneyGame`; the single OS window transforms between **full** and **compact**
      (resize + frameless + always-on-top window level) via `window_manager`, and "hide main to dock" is
      a window-property transition on that one window. Full and compact are two widget subtrees under the
      existing `MultiBlocProvider` — both consume the **same** `JourneyCubit`, so AC-9 holds
      *structurally*, not by cross-isolate sync. **Refinement (required):** lift the `JourneyGame`
      instance to a shared owner so the full screen and the compact view render the **same** game via
      `GameWidget(game: sharedGame)` (no forked scene; reuses the existing `pauseEngine()`/`resumeEngine()`
      lifecycle for NFR-1). Option B (minimize main + a *second* window) is **rejected** — a second
      Flutter window means a second isolate + a forked scene, paying full multi-window cost for a
      co-visibility the spec forbids.
- [x] **ADR warranted.** `ADR-0003: Mini-window as single-window two-mode (full ⇄ compact PiP), not
      multi-window` — extends (does not supersede) ADR-0002. To be written via `/add-adr` after Kevin
      agrees; `docs/architecture/overview.md` updated at the same time.
- [x] **Build-spike gate (before `/implement`).** Prove the **macOS** triad on one window with the real
      backend (mock path can't prove OS stacking): (a) `startDragging` works after `setAsFrameless` /
      hidden title bar; (b) the window stays **above a different focused app** (macOS `NSWindow` level /
      Spaces are finicky vs full-screen apps); (c) close-button intercept (`setPreventClose` + `hide()`)
      keeps the process alive with the tray icon still updating. Secondary: the lifted shared `JourneyGame`
      survives re-parenting between subtrees without re-init (hold via `IndexedStack`/`Offstage`/keep-alive).

## Open questions
- [x] **PiP resizable vs fixed-size? — FIXED.** The compact view is a **fixed compact size**; only its
      **position** is persisted/restored (size is constant). (Resolved by Kevin, 2026-06-24.)

_All open questions resolved — spec is ready for `Status: approved` once Kevin sets it._

## Related
- Epic: [planning/backlog/vietnam-focus-journey.md](../../planning/backlog/vietnam-focus-journey.md) · **Wave 2 (v2)**
- Upstream (shipped): [specs/journey-view/spec.md](../journey-view/spec.md) — the Flame scene reused, sized down · **[blocked by: journey-view ✅]**
- Upstream (shipped): [specs/journey-engine/spec.md](../journey-engine/spec.md) — provides `state`, `mode`, `distanceKm` via the journey Bloc
- Related (shipped): [specs/local-stats/spec.md](../local-stats/spec.md) — **owns launch-at-startup**; do not duplicate
- Architecture: [docs/architecture/overview.md](../../docs/architecture/overview.md) — v2 window model · ADR-0002 (stack)
- **Decision: [ADR-0003](../../docs/architecture/decisions/0003-mini-window-single-window-two-mode.md)** — single-window two-mode (full ⇄ compact PiP), not multi-window (extends ADR-0002)
- Native pattern precedent (shipped): [specs/activity-detection/spec.md](../activity-detection/spec.md) — interface + macOS/Windows backends + mock
- Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md)
