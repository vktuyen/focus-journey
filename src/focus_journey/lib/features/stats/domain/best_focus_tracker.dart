/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

/// Tracks the **longest continuous raw-active stretch** of the local day (AC-3 /
/// the "best focus period") incrementally from consecutive per-tick snapshots.
///
/// **Derivation (resolved OQ default).** The engine exposes no per-event data —
/// only the aggregate `rawActiveTime` counter. A tick is "raw-active" **iff**
/// `rawActiveTime` increased since the previous snapshot; such a tick **extends**
/// the current run by the increase, and **any non-increase** (grace / idle /
/// paused / locked / sleep) **breaks** the run. We track the maximum run seen.
/// Grace breaks the stretch because grace does not advance `rawActiveTime`
/// (raw-active-only, for honesty). With no raw-active time the result is zero.
///
/// Pure and deterministic: it owns no clock and reads no OS signal — it is fed
/// the engine's `rawActiveTime` once per tick by the app-service sink, and is
/// reset by the caller at the local-midnight boundary (consistent with the
/// engine's daily reset). Identical snapshot sequences yield identical results
/// (Determinism NFR / TC-NF1).
class BestFocusTracker {
  /// Creates a tracker at the start of a day (no run, zero best).
  BestFocusTracker();

  Duration _lastRawActive = Duration.zero;
  bool _hasPrevious = false;
  Duration _currentRun = Duration.zero;
  Duration _best = Duration.zero;

  /// The longest continuous raw-active stretch observed so far today.
  Duration get bestFocusPeriod => _best;

  /// Observes the engine's current cumulative-for-today `rawActiveTime`.
  ///
  /// On the first observation of a day there is no previous sample, so no run is
  /// extended (we only learn the baseline). On each subsequent tick: if
  /// `rawActiveTime` increased, the current run grows by that increase and the
  /// best is bumped if it overtakes; otherwise the run breaks (resets to zero).
  void observe(Duration rawActiveTime) {
    if (!_hasPrevious) {
      _lastRawActive = rawActiveTime;
      _hasPrevious = true;
      return;
    }
    if (rawActiveTime > _lastRawActive) {
      _currentRun += rawActiveTime - _lastRawActive;
      if (_currentRun > _best) {
        _best = _currentRun;
      }
    } else {
      // Grace / idle / paused / no advance — the raw-active run is broken.
      _currentRun = Duration.zero;
    }
    _lastRawActive = rawActiveTime;
  }

  /// Resets to the start-of-day state — call on the local-midnight rollover so a
  /// new day's best focus period starts at zero (AC-19), seeding the baseline
  /// with the new day's starting `rawActiveTime` (normally zero after the
  /// engine's daily reset).
  void resetForNewDay(Duration rawActiveTimeAtDayStart) {
    _lastRawActive = rawActiveTimeAtDayStart;
    _hasPrevious = true;
    _currentRun = Duration.zero;
    _best = Duration.zero;
  }
}
