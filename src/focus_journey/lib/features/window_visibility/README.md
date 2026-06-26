# window_visibility — per-surface window occlusion/visibility signal

Implements the **`WindowVisibilityController`** seam for journey-scene-v2 **#5**: the scene **keeps
animating while its surface is visible but another app holds focus**, and **pauses only when the
surface has no pixels on screen** (minimized / hidden-to-tray / occluded). Evaluated **per-surface**
(main window vs the frameless always-on-top PiP). Spec:
[`specs/journey-scene-v2/`](../../../../../specs/journey-scene-v2/) — Decision (b), AC-3/AC-4/AC-5.

The trigger is **occlusion / visibility, NOT focus**. This is the dedicated signal that lets us
relax the shipped mini-window NFR-1 ("pause when not visible *or unfocused*") to "pause only when
**not visible**" without losing the pause-when-hidden battery guarantee.

## Why this is separate from `WindowModeController.isWindowVisible`

`WindowModeController` already exposes an `isWindowVisible` flag, but that is an **app-state** signal
(it flips on `hideToTray()` / `showApp()`), wired for the old "pause when hidden OR unfocused" rule.
#5 needs a **true OS occlusion** read (covered/uncovered, minimized) which app state cannot provide.
Hence a focused, separate controller that downstream `flame-game-developer` + `flutter-app-developer`
wire to. Keep the Dart interface stable.

## Spike findings (Decision (b) — does a reliable signal exist for the frameless always-on-top PiP?)

| OS | API | Frameless always-on-top PiP? | Verdict |
|----|-----|------------------------------|---------|
| **macOS** | `NSWindow.occlusionState` (`.visible`) + `isMiniaturized` + `NSApp.isHidden`, observed via `NSWindowDidChangeOcclusionStateNotification` | **Yes** — `occlusionState` is a per-window property independent of window style/level, so it works for the frameless, always-on-top PiP. | **TRUE occlusion signal.** A PiP covered by another window correctly reports `visible: false`. |
| **Windows** | `IsWindowVisible` + `IsIconic` + `DWMWA_CLOAKED`, hooked off `WM_SIZE` / `WM_SHOWWINDOW` / `WM_WINDOWPOSCHANGED` | Detects minimized / hidden / cloaked only. | **FALLBACK.** No reliable public API detects an arbitrary window being fully covered by *other* windows' pixels. So a PiP **covered** by another maximized window **keeps animating** on Windows. |

### Windows fallback (flagged, per the spec)

Per Decision (b): *"If the spike finds no reliable signal on a given OS, fall back to the existing
pause-when-hidden behaviour there and flag it."* On **Windows** we pause on **minimized / hidden /
cloaked** only — i.e. exactly the relaxed mini-window NFR-1 baseline. We do **not** pause on pure
occlusion. This is the documented, accepted behaviour, not a defect. macOS gets the full #5 behaviour.

The Dart side is identical for both OSes (same channel payload, same `SurfaceVisibility` events); the
difference is purely in *what the native side can detect*.

## Privacy promise (headline, P0 — NFR-2)

Reads ONLY the app's **own** window visibility state (occlusion / minimized / hidden / cloaked). It
installs **no** input hook and reads **no** keystrokes, screen pixels, clipboard, files,
mouse-position history, **other-app focus**, or any window titles. It deliberately does **not** read
focus (`isKeyWindow` / `GetForegroundWindow`) — visible-but-unfocused must keep animating (AC-3).

No new entitlement, no `Info.plist` usage string, no Windows capability, and **no permission prompt**:
observing your own window's visibility needs none. `/privacy-audit` stays **PASS** — this adds no new
sensitive signal beyond own-window visibility (the same class the mini-window already cleared).

## Channels

- MethodChannel `com.joblogic.focus_journey/window_visibility` — `start` returns the initial
  per-surface snapshot as a `List` of `{ surface, visible }` maps.
- EventChannel `com.joblogic.focus_journey/window_visibility/events` — emits one
  `{ surface: 'main' | 'pip', visible: bool }` map per de-duplicated transition.

## Dart seam (stable)

- `WindowVisibilityController` (domain) — `start()`, `visibilityOf(surface)`, `isVisible(surface)`,
  `Stream<SurfaceVisibility> changes`, `dispose()`.
- `SurfaceVisibility` / `WindowSurface` (domain) — the per-surface reading.
- `MethodChannelWindowVisibilityController` (data) — real backend over the two channels.
- `MockWindowVisibilityController` (data) — deterministic; `setVisible(surface, bool)` drives
  AC-3/AC-4/AC-5 in widget/unit tests with no real OS window.
- `WindowVisibilityFactory` — DI seam; the `--dart-define=mock-window=true` flag selects the mock
  (same switch as the mini-window mock, since a mocked window has no real OS occlusion either).

## Native files

- macOS: `macos/Runner/WindowVisibilityChannel.swift`, wired in `macos/Runner/MainFlutterWindow.swift`.
- Windows: `windows/runner/window_visibility_channel.{h,cpp}`, wired in `windows/runner/flutter_window.cpp`.
