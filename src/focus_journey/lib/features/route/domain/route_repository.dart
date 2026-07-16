/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'route_plan.dart';
import 'route_selection.dart';

/// The persistence seam for the user's authored route.
///
/// Mirrors `JourneyRepository`: callers depend ONLY on this interface (dependency
/// inversion), never on `shared_preferences` directly — the concrete
/// `SharedPreferencesRouteRepository` lives in `data/`. Swapping a real ↔
/// in-memory fake repository requires no presentation change (AC-9/AC-10 /
/// TC-009/TC-010 use an in-memory fake).
///
/// **route-planner-v2 (ADR-0005 decision 4):** the authored route persists as a
/// [RoutePlan] (ordered node-id list + offset + 3-state lifecycle) via the SAME
/// seam — no new store (AC-12). The legacy [RouteSelection] `load`/`save` pair is
/// RETAINED for backward-compatibility (the shipped route-progress tests + any
/// caller that still holds a `RouteSelection`); [loadPlan] migrates a legacy
/// `RouteSelection` blob forward to a [RoutePlan] when no new-shape blob exists.
abstract interface class RouteRepository {
  /// Loads the last persisted selection, or `null` if none has been saved yet
  /// (or the stored blob was unreadable — corrupt-safe load). Legacy seam.
  Future<RouteSelection?> load();

  /// Persists [selection], overwriting any previous one. Legacy seam.
  Future<void> save(RouteSelection selection);

  /// Loads the last persisted authored [RoutePlan], or `null` if none has been
  /// saved (or the stored blob was unreadable — corrupt-safe load). When the
  /// stored blob is a LEGACY `RouteSelection` (an in-flight v1 route written by
  /// the shipped build), it is **migrated forward** to a [RoutePlan] rather than
  /// discarded (ADR-0005 decision 4 migration rule / AC-12).
  ///
  /// **province-chain-2026 migration-by-reset (AC-9).** When a persisted plan or
  /// legacy selection references RETIRED pre-2025 province ids that no longer
  /// resolve against the current 34-unit chain, it is forward-migrated **by
  /// reset**: a fresh full-spine active plan (all 34 units, south→north) stamped
  /// at [currentCumulativeKm] — the engine's current cumulative distance (BR-8's
  /// separate never-reset store, read by the caller and threaded in). This is a
  /// reset, NOT an id-remap: the topology + total km changed wholesale, so the
  /// traveller is re-based onto the new spine at the same lifetime distance
  /// rather than dropped at an arbitrary remapped unit. A genuinely
  /// corrupt/undecodable blob still degrades to `null` (no crash).
  Future<RoutePlan?> loadPlan({double currentCumulativeKm = 0});

  /// Persists [plan], overwriting any previous route (selection or plan). The
  /// single seam for the v2 authored-route lifecycle (AC-12).
  Future<void> savePlan(RoutePlan plan);
}
