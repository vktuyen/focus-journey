/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'window_position.dart';

/// Persistence seam for the compact (PiP) window's last position.
///
/// Mirrors the v1 `shared_preferences`-backed repository style (one small
/// interface, one backing store). Only POSITION is persisted — the compact
/// view is a fixed size (AC-8). Off-screen / invalid restore is clamped by the
/// [WindowModeController], not here (a repository persists, it does not know
/// about displays).
abstract interface class CompactWindowPositionRepository {
  /// Loads the last saved compact position, or `null` if none was saved (a
  /// fresh install). A `null` result asks the controller to use a default
  /// corner.
  Future<WindowPosition?> load();

  /// Persists [position] as the compact window's last position. Must never
  /// throw out to the caller — a failed save degrades gracefully (the next
  /// launch falls back to default), consistent with the v1 repositories.
  Future<void> save(WindowPosition position);
}
