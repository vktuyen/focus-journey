#include "window_visibility_channel.h"

#include <dwmapi.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <optional>
#include <string>

// PRIVACY: see window_visibility_channel.h. Only the app's own
// minimized/hidden/cloaked state is read - never input or other-app data.

namespace {

constexpr char kMethodChannelName[] =
    "com.joblogic.focus_journey/window_visibility";
constexpr char kEventChannelName[] =
    "com.joblogic.focus_journey/window_visibility/events";
constexpr char kMethodStart[] = "start";
constexpr char kKeySurface[] = "surface";
constexpr char kKeyVisible[] = "visible";
// Single window (ADR-0003); reported as the main surface. The Dart seam stays
// per-surface-ready - a future second OS window would report "pip".
constexpr char kSurfaceMain[] = "main";

HWND g_window = nullptr;
std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> g_sink;
// Last emitted value, to de-duplicate redundant pause/resume churn (NFR-1).
std::optional<bool> g_last_visible;

// Whether THIS window currently has pixels on screen: shown (WS_VISIBLE) AND
// not minimized AND not DWM-cloaked. Returns true while another app holds
// focus (no focus check), so visible-but-unfocused keeps animating (AC-3).
bool IsSurfaceVisible() {
  if (g_window == nullptr) {
    return false;
  }
  if (!IsWindowVisible(g_window)) {
    return false;
  }
  if (IsIconic(g_window)) {
    return false;
  }
  DWORD cloaked = 0;
  if (SUCCEEDED(DwmGetWindowAttribute(g_window, DWMWA_CLOAKED, &cloaked,
                                      sizeof(cloaked))) &&
      cloaked != 0) {
    return false;
  }
  return true;
}

flutter::EncodableValue CurrentReading() {
  return flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue(kKeySurface),
       flutter::EncodableValue(kSurfaceMain)},
      {flutter::EncodableValue(kKeyVisible),
       flutter::EncodableValue(IsSurfaceVisible())},
  });
}

void EmitIfChanged(bool force) {
  bool visible = IsSurfaceVisible();
  if (!force && g_last_visible.has_value() && *g_last_visible == visible) {
    return;
  }
  g_last_visible = visible;
  if (g_sink) {
    g_sink->Success(CurrentReading());
  }
}

}  // namespace

void WindowVisibilityChannel::Register(flutter::FlutterEngine* engine,
                                       HWND window) {
  g_window = window;

  auto method_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          engine->messenger(), kMethodChannelName,
          &flutter::StandardMethodCodec::GetInstance());
  method_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() == kMethodStart) {
          // Return the current per-surface snapshot as a one-element list.
          result->Success(flutter::EncodableValue(
              flutter::EncodableList{CurrentReading()}));
        } else {
          result->NotImplemented();
        }
      });

  auto event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          engine->messenger(), kEventChannelName,
          &flutter::StandardMethodCodec::GetInstance());
  event_channel->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [](const flutter::EncodableValue* arguments,
             std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
              -> std::unique_ptr<flutter::StreamHandlerError<
                  flutter::EncodableValue>> {
            g_sink = std::move(events);
            g_last_visible.reset();
            EmitIfChanged(/*force=*/true);  // immediate sync for new listener.
            return nullptr;
          },
          [](const flutter::EncodableValue* arguments)
              -> std::unique_ptr<flutter::StreamHandlerError<
                  flutter::EncodableValue>> {
            g_sink.reset();
            return nullptr;
          }));

  // Channels must outlive this call; intentionally leak for the app's lifetime
  // (one per process, matching the engine lifetime), mirroring ActivityChannel.
  method_channel.release();
  event_channel.release();
}

void WindowVisibilityChannel::HandleVisibilityMessage() {
  EmitIfChanged(/*force=*/false);
}

void WindowVisibilityChannel::Unregister() {
  g_sink.reset();
  g_window = nullptr;
}
