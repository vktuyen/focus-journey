# mini_window — native window + tray plumbing (PiP + menu-bar/tray)

Implements the **native window + tray** layer for the `mini-window` slice (Wave 2 / v2): the highest-
risk, OS-specific foundation the two-mode UI/Bloc builds on. Spec:
[`specs/mini-window/`](../../../../../specs/mini-window/) · Decision:
[ADR-0003](../../../../../docs/architecture/decisions/0003-mini-window-single-window-two-mode.md).

This layer manipulates **only the app's OWN window and a tray icon**. It owns **no** journey logic and
reads **no** OS signals about the user (no idle/lock/input — that is `activity-detection`). It mirrors
the v1 `ActivityPlugin` pattern: a pure-Dart **domain interface**, a **real** package-backed `data`
impl, a deterministic **mock**, and a **factory** DI seam with a `--mock-window` define.

## Privacy promise (headline, P0 — NFR-4/5)

The code touches ONLY:

- the app's **own window** — size, position, frameless / title-bar style, always-on-top level,
  visibility, and the close intercept (`window_manager`),
- a **status icon + tooltip + context menu** (`tray_manager`), and
- **display BOUNDS** (visible-area geometry) to clamp the compact window back onto a visible screen
  (`screen_retriever` — geometry only, never display contents).

It NEVER reads keystrokes, key contents, screen/display pixels, clipboard, files, mouse-position
history/coordinates, or **other apps'** window titles. There are no input hooks, no event taps, no
screen capture, no network. `screen_retriever` was already privacy-cleared as a transitive dependency
in `activity-detection` (display geometry only).

## Layers (Clean Architecture)

```
domain/   window_mode.dart                      enum {full, compact}
          window_position.dart                  the app's own persisted top-left (POSITION only — AC-8)
          compact_geometry.dart                 fixed compact size + pure off-screen clamp math (AC-6/8)
          tray_state.dart                        enums {TrayActivityState, TrayAction}
          compact_window_position_repository.dart  persistence seam (interface)
          window_mode_controller.dart            the window contract (full⇄compact, hide-to-tray, quit)
          tray_controller.dart                   the tray contract (icon/tooltip/menu, action stream)
data/     window_manager_mode_controller.dart    real window_manager + screen_retriever backend
          tray_manager_tray_controller.dart      real tray_manager backend (STATIC icon, graceful fallback)
          shared_preferences_compact_window_position_repository.dart  shared_preferences position store
          mock_window_mode_controller.dart       deterministic in-memory window controller (NFR-8)
          mock_tray_controller.dart              deterministic in-memory tray controller (NFR-8)
          mini_window_factory.dart               DI seam: --mock-window → mocks, else real
```

`domain/` has zero `window_manager`/`tray_manager`/channel imports. Callers depend only on
`WindowModeController` / `TrayController`; swapping real↔mock needs no caller change (NFR-7/8).

## Packages, not a custom channel

Unlike `activity-detection` (a custom MethodChannel), this layer is backed by the named, audited
packages `window_manager` ^0.5.1 + `tray_manager` ^0.5.3 (+ `screen_retriever` for clamp geometry).
No custom platform channel and no new native runner code is required: the packages register
themselves via the generated plugin registrants on both macOS and Windows. The existing macOS
`MainFlutterWindow` (which also registers the v1 `ActivityChannel`) and the Windows runner are
unchanged and compatible — confirmed by the ADR-0003 build spike.

## Selecting the mock (`mock-window`)

Mirrors `--mock-activity`: a compile-time define read via
`const bool.fromEnvironment('mock-window')`, passed through `--dart-define`:

```
fvm flutter run  -d macos                     # real window + tray
fvm flutter run  -d macos --dart-define=mock-window=true   # mock (no real OS window/tray)
fvm flutter test integration_test/ -d macos --dart-define=mock-window=true --dart-define=mock-activity=true
```

With the define set, `MiniWindowFactory` returns `MockWindowModeController` / `MockTrayController` and
the app NEVER touches a real OS window or tray (NFR-8). Tests inject the mocks directly (no define
needed).

## Tray icon assets (TODO for ui-asset-curator)

The real `TrayManagerTrayController` references two STATIC icon variants (no animation — resolved
decision). Provide these as license-clean (CC0) PNGs under `assets/tray/`, register them in
`pubspec.yaml` (`flutter: assets: - assets/tray/`), and credit them in `assets/CREDITS.md`:

- `assets/tray/tray_active.png`  — travelling / active variant
- `assets/tray/tray_paused.png`  — paused / idle (parked) variant

Until present, the tray degrades **gracefully** to a tooltip (+ menu-bar title on macOS) that still
distinguishes active vs paused (AC-11 "distinguishable from the tray surface" holds via tooltip).

## What the app-dev (flutter-app-developer) wires

This layer exposes the controllers; it wires **no** app logic. The composition root should:

1. `await SharedPreferences.getInstance()` (already done in `main.dart`).
2. `final window = MiniWindowFactory.createWindowModeController(prefs);` then `await window.setup();`
   **before** `runApp` (registers `setPreventClose(true)` + min sizes so close→hide-to-tray works).
3. `final tray = MiniWindowFactory.createTrayController();` then `await tray.init(...);`.
4. Map the journey Bloc's `state` → `tray.setState(...)` and (optional, AC-13) `tray.setStatusLine(...)`.
5. Subscribe to `tray.actions` and route each `TrayAction` to the window controller:
   - `TrayAction.showApp` → `window.showApp()`
   - `TrayAction.enterCompact` → `window.enterCompact()`
   - `TrayAction.quit` → `window.quit()`
6. On mode change, `tray.setMode(window.mode)` (AC-14, P2) — `window.modeChanges` provides the stream.
7. Register the Quit flush hook (AC-16): `window.onBeforeQuit(() => /* persist journey/stats */)`.
   This layer does NOT persist journey data — it only guarantees the hook runs before destroy.
8. After a drag settles in compact mode, call `window.persistCompactPosition()` (AC-8).
9. Build the full vs compact widget subtrees and lift the shared `JourneyGame` (AC-9) — **app-dev's
   job**, not this layer's.
```
```
