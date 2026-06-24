/// Data layer — deterministic, caller-driven [ActivityPlugin] for dev/tests.
///
/// Privacy: touches NO real OS API. It returns exactly the values a caller
/// sets — no idle counter, no lock query, no input access whatsoever.
library;

import '../domain/activity_plugin.dart';
import '../domain/activity_plugin_exception.dart';

/// A fully deterministic [ActivityPlugin]: returns exactly the values the
/// caller sets, with no real OS access, no real timers, and no real idle waits
/// (AC-6 / TC-012..TC-015). This is what lets `journey-engine` and unit tests
/// drive any signal synchronously.
class MockActivitySource implements ActivityPlugin {
  /// Creates the mock with optional initial values.
  MockActivitySource({int idleSeconds = 0, bool screenLocked = false})
    : _idleSeconds = idleSeconds,
      _screenLocked = screenLocked;

  int _idleSeconds;
  bool _screenLocked;
  ActivityPluginException? _idleError;
  ActivityPluginException? _lockError;

  /// The idle-seconds value returned by [getSystemIdleSeconds].
  set idleSeconds(int value) => _idleSeconds = value;

  /// The lock value returned by [isScreenLocked].
  set screenLocked(bool value) => _screenLocked = value;

  /// Queue an exception so the next (and subsequent) [getSystemIdleSeconds]
  /// calls fail, to exercise the typed-failure contract (AC-10 / TC-016).
  /// Set to `null` to clear.
  set idleError(ActivityPluginException? error) => _idleError = error;

  /// Queue an exception so the next (and subsequent) [isScreenLocked] calls
  /// fail (AC-10 / TC-017). Set to `null` to clear.
  set lockError(ActivityPluginException? error) => _lockError = error;

  @override
  Future<int> getSystemIdleSeconds() async {
    final error = _idleError;
    if (error != null) {
      throw error;
    }
    return _idleSeconds;
  }

  @override
  Future<bool> isScreenLocked() async {
    final error = _lockError;
    if (error != null) {
      throw error;
    }
    return _screenLocked;
  }
}
