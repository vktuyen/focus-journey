# activity — system idle + screen-lock signals

Implements the **`ActivityPlugin`** slice for the Vietnam Focus Journey app: the highest-risk,
privacy-critical foundation. It exposes **raw signals only** — `getSystemIdleSeconds()` and
`isScreenLocked()`. It does NOT decide active vs idle, apply any threshold/grace, or track distance;
that judgment lives in `journey-engine`. Spec: [`specs/activity-detection/`](../../../../../specs/activity-detection/).

## Spike decision: custom platform-channel plugin (NOT a pub.dev package)

The spec mandates checking pub.dev first. **Outcome: build custom.** No single, well-maintained,
license-clean package provides BOTH aggregate system idle seconds AND OS session-lock state on BOTH
macOS and Windows. The reliable idle packages are sparse/stale; packages that listen to global
keyboard/mouse input are **disqualified** — they are *capable* of capturing input content, which
violates the headline privacy promise (AC-8 / TC-019). A custom channel keeps the native surface
minimal, fully under our control, and auditable by construction (AC-7 / TC-018).

## Privacy promise (headline, P0)

This code reads ONLY:

- an **aggregate** system-idle duration in seconds (a single counter, no per-event data), and
- a **screen-lock boolean** (OS session-lock state).

It NEVER reads, buffers, logs, or persists: keystrokes, key contents, screen/display pixels,
clipboard, files, mouse coordinates or movement history, or window titles. There are no input event
hooks, no event taps, no screen capture. Each native file carries a privacy comment stating this.

## Native APIs (resolved in the spike)

| Signal | macOS (Swift) | Windows (C++/Win32) |
|---|---|---|
| idle seconds | `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .any)` — HID idle counter, **no Accessibility / Input-Monitoring permission required** | `GetLastInputInfo` + `GetTickCount64`, `(now - lastInput) / 1000` |
| screen locked | `CGSessionCopyCurrentDictionary()` → `CGSSessionScreenIsLocked` key | `WTSRegisterSessionNotification` + `WM_WTSSESSION_CHANGE`; we cache the last `WTS_SESSION_LOCK`/`WTS_SESSION_UNLOCK` and report it on demand |

**Windows lock choice:** session-notification tracking is preferred over `OpenInputDesktop`/
`SwitchDesktop` probing because the desktop-probe approach can require elevated rights and is less
robust under fast user switching. We register for notifications in the runner and read the cached
boolean on each call — the read itself is cheap and non-blocking (Performance NFR).

**Permissions / entitlements / prompts:** none. Both macOS APIs are unprivileged HID/session reads —
no Accessibility, no Input-Monitoring, no `Info.plist` usage strings, no entitlements, and **no
permission prompt** is shown to the user. Windows `GetLastInputInfo` and `WTSRegisterSessionNotification`
need no special privilege.

## Layers (Clean Architecture)

```
domain/   activity_plugin.dart            interface (the contract, AC-11) — pure Dart
          activity_plugin_exception.dart  typed failure with a kind enum (AC-10)
data/     method_channel_activity_plugin.dart  real backend over the MethodChannel
          mock_activity_source.dart            deterministic, caller-driven mock (AC-6)
          activity_plugin_factory.dart         DI seam: --mock-activity → mock, else real
```

`domain/` has zero Flutter/channel imports. Callers depend only on `ActivityPlugin`; swapping
real↔mock requires no caller change (AC-6 / TC-014).

## Platform channel

- **Channel name:** `com.joblogic.focus_journey/activity` (MethodChannel)
- **Methods:**
  - `getSystemIdleSeconds` → `int` (seconds since last input; large after sleep/wake — AC-9)
  - `isScreenLocked` → `bool`

On the native side an unavailable/failed read returns a `FlutterError` with code `UNAVAILABLE`
(or `DENIED`), which the Dart backend maps to a typed `ActivityPluginException` (AC-10).

## Selecting the mock (mock-activity)

**There is no bare `--mock-activity` flag.** The spec/plan use `--mock-activity` as shorthand; the
real mechanism is a compile-time define read via `const bool.fromEnvironment('mock-activity')`, so
you pass it through `--dart-define`:

```
fvm flutter run -d macos   --dart-define=mock-activity=true
fvm flutter run -d windows --dart-define=mock-activity=true
```

With the define set, `ActivityPluginFactory.create()` returns a `MockActivitySource` and the app
NEVER touches real OS idle/lock APIs (TC-015). Without it, the real `MethodChannelActivityPlugin`
resolves on macOS/Windows. Tests inject the mock directly (no define needed).
