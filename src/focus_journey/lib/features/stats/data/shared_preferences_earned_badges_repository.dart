/// Data layer — imports `shared_preferences`. Persists [EarnedBadges] as a
/// single JSON object under one key. Privacy: serialises only badge id flags +
/// a date — never any raw signal (TC-027).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../reset/domain/local_data_store.dart';
import '../domain/earned_badges.dart';
import '../domain/stats_repositories.dart';

/// An [EarnedBadgesRepository] backed by `shared_preferences` + JSON.
class SharedPreferencesEarnedBadgesRepository
    implements EarnedBadgesRepository, LocalDataStore {
  /// Creates the repository over an existing [SharedPreferences] instance.
  SharedPreferencesEarnedBadgesRepository(this._prefs);

  /// The single key holding the JSON-encoded earned-badge state (new key,
  /// existing namespace — no new store type, AC-13).
  static const String storageKey = 'earned_badges_v1';

  final SharedPreferences _prefs;

  @override
  Future<EarnedBadges?> load() async {
    final raw = _prefs.getString(storageKey);
    if (raw == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return EarnedBadges.fromJson(decoded);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> save(EarnedBadges earned) async {
    await _prefs.setString(storageKey, jsonEncode(earned.toJson()));
  }

  // --- LocalDataStore (journey-reset AC-3) ---

  @override
  Set<String> get ownedKeys => const <String>{storageKey};

  @override
  Future<void> clear() async {
    await _prefs.remove(storageKey);
  }
}
