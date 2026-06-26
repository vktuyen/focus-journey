#include "flutter_window.h"

#include <wtsapi32.h>

#include <optional>

#include "activity_channel.h"
#include "flutter/generated_plugin_registrant.h"
#include "window_visibility_channel.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  // Register the privacy-scoped activity channel (idle seconds + lock state)
  // and subscribe this window to session lock/unlock notifications.
  ActivityChannel::Register(flutter_controller_->engine(), GetHandle());

  // Register the per-surface window-visibility (occlusion) channel
  // (journey-scene-v2 #5). Reads ONLY this window's own minimized/hidden/cloaked
  // state - no other-app or input data (NFR-2). On Windows this is the
  // minimized/hidden fallback (no reliable arbitrary-window occlusion API).
  WindowVisibilityChannel::Register(flutter_controller_->engine(), GetHandle());

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  ActivityChannel::Unregister(GetHandle());
  WindowVisibilityChannel::Unregister();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_WTSSESSION_CHANGE:
      // Update the cached session-lock state. wparam carries the WTS_SESSION_*
      // code only; no input content is read. We intentionally do NOT return
      // here — falling through to Win32Window::MessageHandler below keeps
      // default window processing for this message intact (N2).
      ActivityChannel::HandleSessionChange(wparam);
      break;
    case WM_SIZE:
      // SIZE_MINIMIZED / SIZE_RESTORED / SIZE_MAXIMIZED change whether the
      // window has pixels on screen. We only READ our own window state; no
      // input or other-app data (NFR-2). Do NOT return - fall through to
      // Win32Window so the child surface still gets resized.
      WindowVisibilityChannel::HandleVisibilityMessage();
      break;
    case WM_SHOWWINDOW:
    case WM_WINDOWPOSCHANGED:
      // Shown/hidden (e.g. window_manager hide()/show()) or moved/cloaked.
      WindowVisibilityChannel::HandleVisibilityMessage();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
