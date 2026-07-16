/// Data layer — imports `shared_preferences`. Persists [AppSettings] as a single
/// JSON string under one key. Privacy: serialises only config values + the
/// onboarding flag — never any raw signal (TC-027).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../reset/domain/local_data_store.dart';
import '../domain/app_settings.dart';
import '../domain/stats_repositories.dart';

/// A [SettingsRepository] backed by `shared_preferences` + JSON.
class SharedPreferencesSettingsRepository
    implements SettingsRepository, LocalDataStore {
  /// Creates the repository over an existing [SharedPreferences] instance.
  SharedPreferencesSettingsRepository(this._prefs);

  /// The single key holding the JSON-encoded settings (new key, existing
  /// namespace — no new store type, AC-9/TC-007).
  static const String storageKey = 'app_settings_v1';

  final SharedPreferences _prefs;

  @override
  Future<AppSettings?> load() async {
    final raw = _prefs.getString(storageKey);
    if (raw == null) {
      return null;
    }
    // Corrupt-blob-safe: a malformed value is treated as "no saved settings"
    // (fresh defaults), mirroring SharedPreferencesJourneyRepository (B-4).
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return AppSettings.fromJson(decoded);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _prefs.setString(storageKey, jsonEncode(settings.toJson()));
  }

  // --- LocalDataStore (journey-reset AC-3) ---

  @override
  Set<String> get ownedKeys => const <String>{storageKey};

  @override
  Future<void> clear() async {
    await _prefs.remove(storageKey);
  }
}
