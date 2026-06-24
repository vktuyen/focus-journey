# ADR-0003: Mini-window as single-window two-mode (full ⇄ compact PiP), not multi-window

- Status: accepted
- Date: 2026-06-24
- Deciders: Kevin (Tuyen Vo) / system-architect

## Context

> This ADR **extends** ADR-0002 (Flutter desktop + Bloc + Flame); it does **not** supersede it.

v2's mini-window slice adds a user-invoked Picture-in-Picture (PiP) compact mode that is **mutually exclusive** with the main window: entering PiP collapses the main window into a small frameless always-on-top compact view and hides the main window to the dock; re-opening the main window dismisses the PiP. The two are never co-visible. The slice also adds an always-present menu-bar/system-tray icon (hide-to-tray, keep tracking after the main window is closed).

Acceptance criterion AC-9 (`specs/mini-window/acceptance-criteria.md`) requires exactly one `JourneyEngine` / journey Bloc / activity ticker / Flame scene — one source of truth. The composition root (`src/focus_journey/lib/main.dart`) already builds one DI graph and provides the cubits via `MultiBlocProvider`.

A second visible Flutter desktop window today implies a second `FlutterEngine` in its own Dart isolate (or the experimental, unstable multi-window path) — so the Bloc/engine/scene cannot be directly shared and would have to be mirrored across an isolate boundary, i.e. a forked scene / second source of truth.

## Decision

One `FlutterEngine`. The single OS window transforms between "full" and "compact" modes (resize + frameless + always-on-top window level, main hidden to dock) via `window_manager`; the always-present tray icon uses `tray_manager`.

- Full and compact are two widget subtrees under the existing `MultiBlocProvider`, both consuming the **same** `JourneyCubit`.
- The single Flame `JourneyGame` instance is lifted to a shared owner so the full screen and the compact view render the same game via `GameWidget(game: sharedGame)`, reusing the existing `pauseEngine()` / `resumeEngine()` lifecycle.
- No second window, no second engine, no second scene.
- The PiP compact view is a **fixed** compact size (only its position is persisted via `shared_preferences`; off-screen/invalid saved positions are clamped back onto a visible display via `screen_retriever`, already cleared as a transitive dependency in activity-detection).
- Launch-at-startup is **not** added here (owned by local-stats).

## Consequences

- **Easier:** AC-9 (single source of truth) holds structurally rather than via cross-isolate state sync; tray + hide-to-tray and geometry persistence are all single-window `window_manager` / `tray_manager` APIs; NFR-1 (pause animation when not visible) is trivial with exactly one game loop to pause.
- **Harder / obligations:** the full↔compact transition is a window-property change that must be jank-free. A build spike **before** `/implement` must prove the macOS triad on one real window (the mock path cannot prove OS stacking):
  - (a) `startDragging` works after `setAsFrameless` / hidden title bar,
  - (b) the window stays above a different focused app (macOS `NSWindow` level / Spaces vs full-screen apps is finicky),
  - (c) close-button intercept (`setPreventClose` + `hide()`) keeps the process alive with the tray still updating.
- Secondary: confirm the lifted shared `JourneyGame` survives re-parenting between subtrees without re-init (`IndexedStack` / `Offstage` / keep-alive).
- Windows parity is authored now; on-device Windows verification is deferred per NFR-9.

## Alternatives considered

### Option B — minimize main window + show a separate compact window
Rejected: a second Flutter window means a second `FlutterEngine` / isolate (or experimental multi-window), forcing cross-isolate Bloc state sync and a forked Flame scene — violating AC-9 and paying the full multi-window cost for a co-visibility the product explicitly forbids.

### Experimental Flutter multi-window
Rejected for v2: not a stable capability on macOS + Windows via `window_manager`; would need a much larger spike.
