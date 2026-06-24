/// Data layer — `shared_preferences`-backed [HideToTrayHintRepository] (AC-17).
///
/// PRIVACY: persists ONLY a single boolean UI flag (the v1 `shared_preferences`
/// approach) — no user data (NFR-4).
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/hide_to_tray_hint_repository.dart';

/// Stores the one-time hide-to-tray hint flag under a single key.
class SharedPreferencesHideToTrayHintRepository
    implements HideToTrayHintRepository {
  /// Creates the repository over an existing [SharedPreferences] instance.
  SharedPreferencesHideToTrayHintRepository(this._prefs);

  /// The single key holding the "hint shown" flag.
  static const String storageKey = 'mini_window_hide_to_tray_hint_shown_v1';

  final SharedPreferences _prefs;

  @override
  Future<bool> hasShownHint() async => _prefs.getBool(storageKey) ?? false;

  @override
  Future<void> markHintShown() async => _prefs.setBool(storageKey, true);
}
