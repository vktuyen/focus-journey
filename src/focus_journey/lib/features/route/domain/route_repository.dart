/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'route_selection.dart';

/// The persistence seam for the user's [RouteSelection] (start + direction +
/// offset + completed flag).
///
/// Mirrors `JourneyRepository`: callers depend ONLY on this interface (dependency
/// inversion), never on `shared_preferences` directly — the concrete
/// `SharedPreferencesRouteRepository` lives in `data/`. Swapping a real ↔
/// in-memory fake repository requires no presentation change (AC-9/AC-10 /
/// TC-009/TC-010 use an in-memory fake).
abstract interface class RouteRepository {
  /// Loads the last persisted selection, or `null` if none has been saved yet
  /// (or the stored blob was unreadable — corrupt-safe load).
  Future<RouteSelection?> load();

  /// Persists [selection], overwriting any previous one.
  Future<void> save(RouteSelection selection);
}
