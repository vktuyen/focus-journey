/// Data layer — the ONLY file that imports `shared_preferences`. Persists the
/// engine's daily progress as a single JSON string under one key.
///
/// Privacy: serialises only the [JourneyProgress] snapshot (aggregate counters +
/// position + date) — never any raw idle/lock signal.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/journey_progress.dart';
import '../domain/journey_repository.dart';

/// A [JourneyRepository] backed by `shared_preferences` + JSON.
///
/// Stores the whole snapshot under [storageKey] as a JSON object (the data is
/// tiny). The pure [JourneyEngine] never sees this class — it depends only on
/// the [JourneyRepository] interface (AC-11 / TC-018), so tests substitute an
/// in-memory fake without touching real preferences.
class SharedPreferencesJourneyRepository implements JourneyRepository {
  /// Creates the repository over an existing [SharedPreferences] instance
  /// (inject it from app startup so loading is done once).
  SharedPreferencesJourneyRepository(this._prefs);

  /// The single preferences key holding the JSON-encoded snapshot.
  static const String storageKey = 'journey_progress_v1';

  final SharedPreferences _prefs;

  @override
  Future<JourneyProgress?> load() async {
    final raw = _prefs.getString(storageKey);
    if (raw == null) {
      return null;
    }
    // Any unreadable/corrupt persisted value is treated as "no saved progress"
    // (fresh start) — never thrown out of load(), so a corrupt, partial,
    // wrong-typed, non-object, or malformed-date blob can't crash startup and
    // silently lose all progress (B-4). FormatException covers bad JSON + the
    // field-by-field guards in fromJson; TypeError/RangeError are caught as a
    // belt-and-braces fallback for any unchecked cast.
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return JourneyProgress.fromJson(decoded);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> save(JourneyProgress progress) async {
    await _prefs.setString(storageKey, jsonEncode(progress.toJson()));
  }
}
