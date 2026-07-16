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

import '../../reset/domain/local_data_store.dart';
import '../domain/coastal_corridor.dart';
import '../domain/journey_direction.dart';
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
class SharedPreferencesRouteRepository
    implements RouteRepository, LocalDataStore {
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
  Future<RoutePlan?> loadPlan({double currentCumulativeKm = 0}) async {
    // Prefer the v2 plan blob when present.
    final rawPlan = _prefs.getString(planStorageKey);
    if (rawPlan != null) {
      // A corrupt v2 blob → "no saved route" (null); a structurally-valid plan
      // whose ids are RETIRED (no longer in the 34-unit chain) → migrate by
      // reset (AC-9); an in-chain plan → return as-is. It does NOT fall back to
      // the legacy key (a written v2 blob supersedes any legacy one).
      return await _decodePlanOrMigrate(rawPlan, currentCumulativeKm);
    }
    // No v2 blob: migrate a legacy RouteSelection blob forward (ADR-0005
    // decision 4). An in-flight v1 route is preserved across the upgrade; a
    // legacy blob with retired ids migrates by reset (AC-9).
    return _migrateLegacy(currentCumulativeKm);
  }

  @override
  Future<void> savePlan(RoutePlan plan) async {
    await _prefs.setString(planStorageKey, jsonEncode(plan.toJson()));
    // Clear any stale legacy blob so a later loadPlan never re-migrates an old
    // selection over a freshly-saved plan (the v2 plan is authoritative).
    await _prefs.remove(storageKey);
  }

  // --- LocalDataStore (journey-reset AC-3) ---

  @override
  Set<String> get ownedKeys => const <String>{planStorageKey, storageKey};

  @override
  Future<void> clear() async {
    // Clear BOTH the v2 plan key AND the legacy v1 selection key (AC-3): the
    // legacy key is the one most likely to be forgotten, so it is wiped
    // explicitly here alongside the current one.
    await _prefs.remove(planStorageKey);
    await _prefs.remove(storageKey);
  }

  /// Decodes a v2 [RoutePlan] blob and, when its ids are retired, migrates it by
  /// reset (AC-9). Returns:
  ///   - the decoded plan when its ids resolve against the current chain;
  ///   - a fresh coastal-corridor reset plan (stamped at [currentCumulativeKm]) when
  ///     the blob is a STRUCTURALLY-valid plan whose ids are RETIRED (no longer
  ///     in the 34-unit chain) — the `toResolved` `ArgumentError` is the
  ///     "retired-but-recognisable" signal;
  ///   - `null` when the blob is genuinely corrupt/undecodable (the
  ///     FormatException → null contract, mirrors [load]).
  Future<RoutePlan?> _decodePlanOrMigrate(
    String raw,
    double currentCumulativeKm,
  ) async {
    final RoutePlan plan;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      // A structurally-valid plan (right shape, ≥2 string ids, numeric offset,
      // known lifecycle). Corrupt structure throws FormatException/TypeError.
      plan = RoutePlan.fromJson(decoded);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
    // A RETIRED id (structurally valid, but the id is no longer a node of the
    // current 34-unit chain) is the "recognisable → reset" signal (AC-9). This
    // is checked BEFORE toResolved so a plan whose ids ARE all in the chain but
    // are otherwise malformed (e.g. non-monotonic) still degrades to null
    // (corrupt), not a reset.
    final chainIds = <String>{for (final node in _chain.nodes) node.id};
    final hasRetiredId = plan.orderedNodeIds.any(
      (id) => !chainIds.contains(id),
    );
    if (hasRetiredId) {
      return _resetAndPersist(currentCumulativeKm);
    }
    try {
      // Ids all resolve; they must also rebuild a real monotonic sub-path.
      plan.toResolved(_chain, _geography);
      return plan;
    } on ArgumentError {
      // In-chain ids but not a valid sub-path (e.g. non-monotonic) → corrupt →
      // "no saved route" (null), NOT a reset.
      return null;
    }
  }

  /// Migrates a legacy [RouteSelection] blob forward (ADR-0005 decision 4 / AC-9).
  ///
  /// - A legacy blob whose `startId` still resolves against the current chain is
  ///   rebuilt as the full start→tip sub-path (the shipped semantics), with
  ///   `completed:true → lifecycle:completed`, else `active`.
  /// - A STRUCTURALLY-valid legacy blob whose `startId` is RETIRED (not in the
  ///   34-unit chain) is forward-migrated **by reset** to a fresh coastal-corridor
  ///   active plan stamped at [currentCumulativeKm] (AC-9) — not dropped.
  /// - A blob that is neither → "no saved route" (`null`).
  Future<RoutePlan?> _migrateLegacy(double currentCumulativeKm) async {
    final raw = _prefs.getString(storageKey);
    if (raw == null) {
      return null;
    }
    // Decode the raw legacy blob independently of the chain so a RETIRED-id
    // selection is distinguishable from a corrupt one (`load()` folds both into
    // null via FormatException). A blob that is a well-formed selection whose id
    // is simply not in the current chain is "recognisable → reset".
    final Map<String, dynamic> decoded;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        return null;
      }
      decoded = json;
    } on FormatException {
      return null;
    }
    if (!_isRecognisableLegacySelection(decoded)) {
      return null; // genuinely corrupt/unrecognisable → no saved route.
    }
    final startId = decoded['startId'] as String;
    final startMatches = _chain.nodes.where((p) => p.id == startId);
    if (startMatches.isEmpty) {
      // Recognisable legacy selection but a retired start id → reset (AC-9).
      return _resetAndPersist(currentCumulativeKm);
    }

    // The start still exists in the current chain: rebuild the shipped full
    // start→tip sub-path (the pre-existing migration path).
    final legacy = RouteSelection.fromJson(decoded, _chain);
    try {
      final end = _chain.destinationOf(legacy.start, legacy.direction);
      // Defensive: an off-direction tip legacy blob (start already at the tip)
      // would be zero-length — treat it as "no saved route" (the start still
      // exists in the current chain, so this is not the retired-id reset case).
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

  /// Whether [decoded] is a STRUCTURALLY-valid legacy `RouteSelection` blob
  /// (the shipped `RouteSelection.toJson` shape): a string `startId`, a known
  /// [JourneyDirection] name, a numeric offset, and a bool `completed`. Used to
  /// tell a retired-id selection (→ reset) from a corrupt blob (→ null) — the
  /// chain membership of `startId` is checked separately by the caller.
  bool _isRecognisableLegacySelection(Map<String, dynamic> decoded) {
    final startId = decoded['startId'];
    if (startId is! String || startId.isEmpty) {
      return false;
    }
    final directionName = decoded['direction'];
    final knownDirection = JourneyDirection.values.any(
      (d) => d.name == directionName,
    );
    if (!knownDirection) {
      return false;
    }
    if (decoded['routeStartOffsetKm'] is! num) {
      return false;
    }
    if (decoded['completed'] is! bool) {
      return false;
    }
    return true;
  }

  /// A fresh **coastal-corridor active** [RoutePlan] — the default route (route-
  /// real-road / AC-1): the south→north coastal sweep from Cà Mau to Cao Bằng
  /// with the deep-inland units removed ([coastalCorridorNodeIds]), NOT the all-34
  /// tour. Stamped at [currentCumulativeKm] (the engine's current never-reset
  /// cumulative — BR-8). This is the migration-by-reset target (AC-9): the
  /// traveller resumes at the same lifetime distance, only re-based onto the
  /// default corridor — never an id-remap.
  RoutePlan _resetPlan(double currentCumulativeKm) {
    return RoutePlan(
      orderedNodeIds: coastalCorridorNodeIds(_chain),
      routeStartOffsetKm: currentCumulativeKm < 0 ? 0 : currentCumulativeKm,
      lifecycle: RouteLifecycle.active,
    );
  }

  /// Builds the migration-by-reset plan AND persists it (S3 — deterministic
  /// startup): [savePlan] writes the fresh coastal-corridor plan under [planStorageKey]
  /// (overwriting the retired/legacy blob that triggered the reset) and clears
  /// the stale [storageKey], so a SUBSEQUENT [loadPlan] reads the migrated
  /// in-chain plan directly and the reset runs exactly ONCE — not on every launch
  /// until the user next saves. Idempotent (re-running yields the same plan) and
  /// crash-safe (a failed/partial write just re-triggers the same reset next
  /// launch — never corruption). Does NOT touch the never-reset cumulative store
  /// (BR-8): [currentCumulativeKm] is only read, never written here.
  Future<RoutePlan> _resetAndPersist(double currentCumulativeKm) async {
    final plan = _resetPlan(currentCumulativeKm);
    await savePlan(plan);
    return plan;
  }
}
