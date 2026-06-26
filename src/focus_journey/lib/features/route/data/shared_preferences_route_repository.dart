/// Data layer — the ONLY route-feature file that imports `shared_preferences`.
/// Persists the user's authored route as a single JSON string under one key.
///
/// **route-planner-v2 (ADR-0005 decision 4):** the v2 authored route persists as
/// a [RoutePlan] under [planStorageKey] (ordered node-id list + offset + 3-state
/// lifecycle). The shipped v1 [RouteSelection] key ([storageKey]) is RETAINED for
/// backward-compatibility — [loadPlan] migrates a legacy `RouteSelection` blob
/// forward to a [RoutePlan] (full start→tip sub-path; `completed → completed`)
/// when no new-shape blob exists (AC-12 migration rule). No new persistence store
/// is introduced (AC-12) — both keys live in the existing `shared_preferences`
/// namespace.
///
/// Privacy: serialises only the authored route (province ids + offset + lifecycle
/// name) — no raw signal, no OS data, no device location. Mirrors
/// `SharedPreferencesJourneyRepository` (corrupt-blob-safe `load() → null`).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/province_chain.dart';
import '../domain/province_geography.dart';
import '../domain/route_plan.dart';
import '../domain/route_planner.dart';
import '../domain/route_repository.dart';
import '../domain/route_selection.dart';

/// A [RouteRepository] backed by `shared_preferences` + JSON.
///
/// Needs the [ProvinceChain] (to resolve a persisted province id back to a
/// `Province` for the legacy seam) and the [ProvinceGeography] (to rebuild a
/// migrated legacy selection's sub-path — ADR-0005 decision 4). The pure
/// resolver/cubit never sees this class — they depend only on [RouteRepository]
/// (AC-9/AC-10), so tests substitute an in-memory fake without touching real
/// preferences.
class SharedPreferencesRouteRepository implements RouteRepository {
  /// Creates the repository over an existing [SharedPreferences] instance, the
  /// [chain] used to rehydrate a persisted province id, and the [geography] used
  /// to rebuild a migrated legacy selection's sub-path. [geography] defaults to
  /// the production `vietnamProvinceGeography` for the (chain == its chain) case;
  /// callers wiring a custom chain must pass the matching geography.
  SharedPreferencesRouteRepository(
    this._prefs,
    this._chain, [
    ProvinceGeography? geography,
  ]) : _geography = geography ?? vietnamProvinceGeography;

  /// The shipped v1 preferences key holding the JSON-encoded [RouteSelection].
  /// Retained for backward-compatible reads + the legacy `load`/`save` seam.
  static const String storageKey = 'route_selection_v1';

  /// The v2 preferences key holding the JSON-encoded [RoutePlan] (ADR-0005). A
  /// new key in the EXISTING namespace — no new persistence store (AC-12).
  static const String planStorageKey = 'route_plan_v1';

  final SharedPreferences _prefs;
  final ProvinceChain _chain;
  final ProvinceGeography _geography;

  @override
  Future<RouteSelection?> load() async {
    final raw = _prefs.getString(storageKey);
    if (raw == null) {
      return null;
    }
    // Any unreadable/corrupt persisted value is treated as "no saved selection"
    // (fresh start) — never thrown out of load(). Mirrors the journey repo.
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

  @override
  Future<RoutePlan?> loadPlan() async {
    // Prefer the v2 plan blob when present.
    final rawPlan = _prefs.getString(planStorageKey);
    if (rawPlan != null) {
      final plan = _tryDecodePlan(rawPlan);
      // A corrupt v2 blob falls through to "no saved route" (null) per the
      // FormatException → null contract — it does NOT fall back to the legacy
      // key (a written v2 blob supersedes any legacy one).
      return plan;
    }
    // No v2 blob: migrate a legacy RouteSelection blob forward (ADR-0005
    // decision 4). An in-flight v1 route is preserved across the upgrade.
    return _migrateLegacy();
  }

  @override
  Future<void> savePlan(RoutePlan plan) async {
    await _prefs.setString(planStorageKey, jsonEncode(plan.toJson()));
    // Clear any stale legacy blob so a later loadPlan never re-migrates an old
    // selection over a freshly-saved plan (the v2 plan is authoritative).
    await _prefs.remove(storageKey);
  }

  /// Decodes a v2 [RoutePlan] blob, returning `null` on any corrupt/unreadable
  /// data (the FormatException → null contract, mirrors [load]).
  RoutePlan? _tryDecodePlan(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final plan = RoutePlan.fromJson(decoded);
      // Validate the ids rebuild a real sub-path against the chain (a plan whose
      // ids are no longer in the chain is unreadable → "no saved route").
      plan.toResolved(_chain, _geography);
      return plan;
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Migrates a legacy [RouteSelection] blob forward to a [RoutePlan] (ADR-0005
  /// decision 4): rebuild the FULL sub-path from the selection's start to its
  /// direction's tip (the shipped semantics) and synthesise the ordered ids, with
  /// `completed:true → lifecycle:completed`, else `active`. A blob that is neither
  /// a valid plan nor a valid legacy selection is "no saved route" (`null`).
  Future<RoutePlan?> _migrateLegacy() async {
    final legacy = await load();
    if (legacy == null) {
      return null;
    }
    try {
      // The full sub-path from the legacy start to its direction's destination
      // tip — exactly the shipped fixed-start + direction route.
      final end = _chain.destinationOf(legacy.start, legacy.direction);
      // Defensive: an off-direction tip legacy blob (start already at the tip)
      // would be zero-length — treat it as "no saved route" rather than crash.
      if (end == legacy.start) {
        return null;
      }
      final resolved = RoutePlanner.resolve(
        fullChain: _chain,
        fullGeography: _geography,
        start: legacy.start,
        end: end,
      );
      return RoutePlan.fromResolved(
        resolved,
        routeStartOffsetKm: legacy.routeStartOffsetKm,
        lifecycle: legacy.completed
            ? RouteLifecycle.completed
            : RouteLifecycle.active,
      );
    } on ArgumentError {
      return null;
    }
  }
}
