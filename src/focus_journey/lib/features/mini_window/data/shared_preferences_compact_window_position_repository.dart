/// Data layer — `shared_preferences`-backed [CompactWindowPositionRepository].
///
/// Privacy: persists ONLY the app's own compact-window top-left coordinates
/// (two doubles). No user data, no input history.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../../reset/domain/local_data_store.dart';
import '../domain/compact_window_position_repository.dart';
import '../domain/window_position.dart';

/// Stores the compact (PiP) window position in `shared_preferences`, mirroring
/// the v1 repository style (`SharedPreferences*Repository`). Only position is
/// persisted (fixed size — AC-8).
class SharedPreferencesCompactWindowPositionRepository
    implements CompactWindowPositionRepository, LocalDataStore {
  /// Creates the repository over an existing [SharedPreferences] instance
  /// (built once at startup, as the v1 repositories are).
  const SharedPreferencesCompactWindowPositionRepository(this._prefs);

  /// Preference key for the persisted compact-window x (logical pixels).
  static const String keyX = 'mini_window.compact_position.x';

  /// Preference key for the persisted compact-window y (logical pixels).
  static const String keyY = 'mini_window.compact_position.y';

  final SharedPreferences _prefs;

  @override
  Future<WindowPosition?> load() async {
    final x = _prefs.getDouble(keyX);
    final y = _prefs.getDouble(keyY);
    if (x == null || y == null) {
      return null;
    }
    return WindowPosition(x: x, y: y);
  }

  @override
  Future<void> save(WindowPosition position) async {
    // Degrade gracefully: a failed save must not crash the app (the next launch
    // falls back to the default corner), consistent with v1 repositories.
    try {
      await _prefs.setDouble(keyX, position.x);
      await _prefs.setDouble(keyY, position.y);
    } catch (_) {
      // Swallow — persistence is best-effort for a window position.
    }
  }

  // --- LocalDataStore (journey-reset AC-3 / AC-5 / TC-707) ---

  @override
  Set<String> get ownedKeys => const <String>{keyX, keyY};

  @override
  Future<void> clear() async {
    // Both coordinate keys — so the compact window returns to its first-run
    // default corner after a Factory reset (TC-707), not a stale position.
    await _prefs.remove(keyX);
    await _prefs.remove(keyY);
  }
}
