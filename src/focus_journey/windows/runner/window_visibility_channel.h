#ifndef RUNNER_WINDOW_VISIBILITY_CHANNEL_H_
#define RUNNER_WINDOW_VISIBILITY_CHANNEL_H_

// Native Windows backend for the `WindowVisibilityController` Dart contract
// (journey-scene-v2 #5: animate when visible, pause when not).
//
// PRIVACY (headline, P0 - NFR-2): this reads ONLY the app's OWN window
// visibility state - whether THIS window currently has pixels on screen. It
// uses own-window signals only:
//   1. IsWindowVisible(hwnd)  - WS_VISIBLE style (false when hidden-to-tray),
//   2. IsIconic(hwnd)         - minimized to the taskbar, and
//   3. DWMWA_CLOAKED (DWM)    - cloaked (e.g. on another virtual desktop).
// It installs NO input hook and reads NO keystrokes, screen pixels, clipboard,
// files, mouse coordinates/history, OTHER apps' focus, or any window titles.
// It deliberately does NOT use focus: the scene must keep animating while
// visible-but-unfocused (AC-3).
//
// PERMISSIONS: none. These calls need no special privilege and show no prompt.
//
// FALLBACK / LIMITATION (Decision (b)): Windows exposes NO reliable public API
// to detect that an arbitrary window is fully OCCLUDED by other windows' pixels
// (the closest, DwmGetDxSharedSurface / monitor occlusion, is unavailable for a
// normal frameless always-on-top PiP). So on Windows this is a "minimized /
// hidden / cloaked" fallback - i.e. the existing pause-when-hidden behaviour,
// which is exactly the relaxed mini-window NFR-1 baseline. A PiP that is
// covered by another maximized window keeps animating on Windows. This is the
// documented, accepted fallback per the spec; see the feature README.

#include <flutter/flutter_view_controller.h>
#include <windows.h>

class WindowVisibilityChannel {
 public:
  // Wires the method channel (start + snapshot) and the event channel
  // (visibility change stream) onto the Flutter |engine| for |window|.
  static void Register(flutter::FlutterEngine* engine, HWND window);

  // Forwarded from the window's message handler for messages that can change
  // visibility (WM_SIZE minimize/restore, WM_SHOWWINDOW, WM_WINDOWPOSCHANGED).
  // Recomputes and emits a de-duplicated visibility event if it changed.
  static void HandleVisibilityMessage();

  // Releases the event sink. Call on window destroy.
  static void Unregister();
};

#endif  // RUNNER_WINDOW_VISIBILITY_CHANNEL_H_
