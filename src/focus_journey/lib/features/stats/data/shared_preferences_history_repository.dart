/// Data layer — imports `shared_preferences`. Persists the bounded per-day
/// history as a single JSON array under one key. Privacy: serialises only
/// aggregate day counters + dates — never any raw signal (TC-027).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../reset/domain/local_data_store.dart';
import '../domain/day_stats.dart';
import '../domain/stats_repositories.dart';

/// A [HistoryRepository] backed by `shared_preferences` + JSON.
///
/// The list is stored as a JSON array of [DayStats] maps under [storageKey]. A
/// corrupt entry is dropped (degrade-safe) rather than crashing the whole load;
/// a wholly-unreadable blob yields an empty history (fresh start), mirroring the
/// established corrupt-blob-safe pattern (B-4).
class SharedPreferencesHistoryRepository
    implements HistoryRepository, LocalDataStore {
  /// Creates the repository over an existing [SharedPreferences] instance.
  SharedPreferencesHistoryRepository(this._prefs);

  /// The single key holding the JSON-encoded history array (new key, existing
  /// namespace — no new store type, AC-7/TC-007).
  static const String storageKey = 'stats_history_v1';

  final SharedPreferences _prefs;

  @override
  Future<List<DayStats>> load() async {
    final raw = _prefs.getString(storageKey);
    if (raw == null) {
      return <DayStats>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <DayStats>[];
      }
      final out = <DayStats>[];
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) {
          continue;
        }
        try {
          out.add(DayStats.fromJson(entry));
        } on FormatException {
          // Drop a single corrupt day rather than losing the whole history.
          continue;
        } on TypeError {
          continue;
        }
      }
      return out;
    } on FormatException {
      return <DayStats>[];
    } on TypeError {
      return <DayStats>[];
    }
  }

  @override
  Future<void> save(List<DayStats> history) async {
    final encoded = jsonEncode(
      history.map((d) => d.toJson()).toList(growable: false),
    );
    await _prefs.setString(storageKey, encoded);
  }

  // --- LocalDataStore (journey-reset AC-3) ---

  @override
  Set<String> get ownedKeys => const <String>{storageKey};

  @override
  Future<void> clear() async {
    await _prefs.remove(storageKey);
  }
}
