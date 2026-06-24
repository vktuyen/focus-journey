/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'activity_plugin_exception.dart';

/// The domain contract for reading **raw** activity signals from the OS.
///
/// This is a "thermometer", not a "thermostat": it reports facts and makes no
/// active/idle judgment (no threshold, grace, or pause/resume — that lives in
/// `journey-engine`). The observable behaviour is implementation-independent
/// (AC-11): the real native backend and the deterministic mock are
/// interchangeable behind this interface (AC-6 / TC-014).
///
/// ## Privacy (headline, P0)
/// Implementations must read ONLY an aggregate idle duration and the
/// screen-lock boolean. They must never read keystrokes, key contents, screen
/// contents, clipboard, files, mouse coordinates/history, or window titles.
///
/// Reads should be cheap and non-blocking — a single call returns a current
/// reading without sleeping or polling internally (Performance NFR), so the
/// engine can poll it on a tick.
abstract interface class ActivityPlugin {
  /// Seconds since the last aggregate user input (any key/mouse/pointer
  /// activity), as reported by the OS idle counter.
  ///
  /// Climbs while the machine is untouched and resets to ~0 on real input
  /// (AC-1..AC-3). After a sleep/wake cycle this naturally returns a large
  /// value (AC-9). Throws [ActivityPluginException] (as a `Future` error) if
  /// the underlying signal is unavailable/denied (AC-10).
  Future<int> getSystemIdleSeconds();

  /// Whether the OS **session** is currently locked (login/lock screen
  /// engaged). A merely sleeping/dimmed display whose session is not locked
  /// reports `false`.
  ///
  /// Reflects the current state at call time, not a value cached at startup
  /// (AC-4 / AC-5 / TC-008). Throws [ActivityPluginException] (as a `Future`
  /// error) if the signal is unavailable/denied (AC-10).
  Future<bool> isScreenLocked();
}
