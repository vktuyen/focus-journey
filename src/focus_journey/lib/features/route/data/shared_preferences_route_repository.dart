/// Data layer — the ONLY route-feature file that imports `shared_preferences`.
/// Persists the user's [RouteSelection] as a single JSON string under one key.
///
/// Privacy: serialises only the selection (start id + direction + offset +
/// completed flag) — no raw signal, no OS data. Mirrors
/// `SharedPreferencesJourneyRepository` exactly (single key, corrupt-blob-safe
/// `load() → null`).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/province_chain.dart';
import '../domain/route_repository.dart';
import '../domain/route_selection.dart';

/// A [RouteRepository] backed by `shared_preferences` + JSON.
///
/// Needs the [ProvinceChain] to resolve a persisted province id back to a
/// `Province` on load. The pure resolver/cubit never sees this class — they
/// depend only on [RouteRepository] (AC-9/AC-10), so tests substitute an
/// in-memory fake without touching real preferences.
class SharedPreferencesRouteRepository implements RouteRepository {
  /// Creates the repository over an existing [SharedPreferences] instance and
  /// the [chain] used to rehydrate the persisted province id.
  SharedPreferencesRouteRepository(this._prefs, this._chain);

  /// The single preferences key holding the JSON-encoded selection. A new key
  /// in the existing namespace — no new persistence store is introduced (AC-9).
  static const String storageKey = 'route_selection_v1';

  final SharedPreferences _prefs;
  final ProvinceChain _chain;

  @override
  Future<RouteSelection?> load() async {
    final raw = _prefs.getString(storageKey);
    if (raw == null) {
      return null;
    }
    // Any unreadable/corrupt persisted value is treated as "no saved selection"
    // (fresh start) — never thrown out of load(), so a corrupt/partial/
    // wrong-typed blob (or an id no longer in the chain) can't crash startup and
    // silently lose the selection. Mirrors SharedPreferencesJourneyRepository.
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return RouteSelection.fromJson(decoded, _chain);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> save(RouteSelection selection) async {
    await _prefs.setString(storageKey, jsonEncode(selection.toJson()));
  }
}
