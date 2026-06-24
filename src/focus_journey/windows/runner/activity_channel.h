#ifndef RUNNER_ACTIVITY_CHANNEL_H_
#define RUNNER_ACTIVITY_CHANNEL_H_

// Native Windows backend for the `ActivityPlugin` Dart contract.
//
// PRIVACY (headline, P0): this reads ONLY two aggregate signals:
//   1. seconds since the last input (GetLastInputInfo gives a tick count only,
//      never input content), and
//   2. the workstation session-lock boolean (tracked from WTS lock/unlock
//      session-change events).
// It installs NO input hook and reads NO keystrokes, key contents, screen
// pixels, clipboard, files, mouse coordinates/history, or window titles.
// Nothing is logged or persisted.
//
// PERMISSIONS: none. GetLastInputInfo and WTSRegisterSessionNotification need
// no special privilege and show no prompt.

#include <flutter/flutter_view_controller.h>
#include <windows.h>

// Registers the activity MethodChannel on the engine and subscribes to session
// lock/unlock notifications for the given window. Call once after the engine is
// created. The lock state is updated from WM_WTSSESSION_CHANGE messages routed
// through |ActivityChannel::HandleSessionChange|.
class ActivityChannel {
 public:
  // Wires the channel to the Flutter |engine|. |window| is the HWND that will
  // receive WTS session notifications.
  static void Register(flutter::FlutterEngine* engine, HWND window);

  // Forwarded from the window's message handler for WM_WTSSESSION_CHANGE.
  // |wparam| is the WTS_SESSION_* code.
  static void HandleSessionChange(WPARAM wparam);

  // Unregisters session notifications. Call on window destroy.
  static void Unregister(HWND window);
};

#endif  // RUNNER_ACTIVITY_CHANNEL_H_
