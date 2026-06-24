#include "activity_channel.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <wtsapi32.h>

#include <atomic>
#include <memory>
#include <string>

// PRIVACY: see activity_channel.h. Only an aggregate idle tick delta and a
// session-lock boolean are read here.

namespace {

constexpr char kChannelName[] = "com.joblogic.focus_journey/activity";
constexpr char kGetSystemIdleSeconds[] = "getSystemIdleSeconds";
constexpr char kIsScreenLocked[] = "isScreenLocked";

// Live workstation-lock state, updated from WTS session-change events on the
// UI thread and read on the channel handler thread, so it is atomic (S1).
// Initial value is unlocked. Launch-while-already-locked is out of scope: the
// app's interactive window is created during an unlocked, interactive session;
// the value then tracks every subsequent WTS_SESSION_LOCK/UNLOCK accurately.
std::atomic<bool> g_screen_locked{false};

// Aggregate idle seconds via GetLastInputInfo + GetTickCount64. This returns a
// tick count only; it carries NO information about what input occurred.
bool TryGetIdleSeconds(int64_t* out_seconds) {
  LASTINPUTINFO last_input = {};
  last_input.cbSize = sizeof(LASTINPUTINFO);
  if (!GetLastInputInfo(&last_input)) {
    return false;
  }
  ULONGLONG now = GetTickCount64();
  // last_input.dwTime is a 32-bit tick; widen against the 64-bit now. The low
  // 32 bits of |now| share the same wrap domain as dwTime.
  DWORD now_low = static_cast<DWORD>(now & 0xFFFFFFFFULL);
  // Unsigned wrap is intended for the normal case. NOTE: the rare edge of
  // >49.7 days of *continuous* idle (the 32-bit ms tick wrapping a full cycle)
  // is intentionally NOT handled — acceptable for this product (S3).
  DWORD idle_ms = now_low - last_input.dwTime;
  *out_seconds = static_cast<int64_t>(idle_ms / 1000U);
  return true;
}

}  // namespace

void ActivityChannel::Register(flutter::FlutterEngine* engine, HWND window) {
  // Subscribe to lock/unlock notifications for THIS session, read on demand.
  WTSRegisterSessionNotification(window, NOTIFY_FOR_THIS_SESSION);

  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          engine->messenger(), kChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() == kGetSystemIdleSeconds) {
          int64_t seconds = 0;
          if (TryGetIdleSeconds(&seconds)) {
            result->Success(flutter::EncodableValue(seconds));
          } else {
            result->Error("UNAVAILABLE",
                          "GetLastInputInfo failed to read the idle counter.");
          }
        } else if (call.method_name() == kIsScreenLocked) {
          result->Success(flutter::EncodableValue(g_screen_locked.load()));
        } else {
          result->NotImplemented();
        }
      });

  // The channel must outlive this call; intentionally leak it for the app's
  // lifetime (one channel per process, matching the engine lifetime).
  channel.release();
}

void ActivityChannel::HandleSessionChange(WPARAM wparam) {
  if (wparam == WTS_SESSION_LOCK) {
    g_screen_locked.store(true);
  } else if (wparam == WTS_SESSION_UNLOCK) {
    g_screen_locked.store(false);
  }
}

void ActivityChannel::Unregister(HWND window) {
  WTSUnRegisterSessionNotification(window);
}
