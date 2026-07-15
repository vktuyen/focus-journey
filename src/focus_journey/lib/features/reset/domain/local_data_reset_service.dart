/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O type.
///
/// journey-reset (AC-3/AC-4). THE single aggregating reset seam. There is no one
/// owner of "clear all local data" in the app — each repository owns its own
/// key(s) — so this service holds the injected [LocalDataStore]s and clears ALL
/// of them. It is the ENFORCED point through which Factory reset runs, so no key
/// is missed (a half-reset that looks whole until the next launch is the bug this
/// prevents — TC-704/TC-705).
///
/// PRIVACY (NFR-2 / BR-1): this only DELETES local data. It performs no new read
/// of any OS/idle/screen/clipboard/file/location signal and no network call.
library;

import 'local_data_store.dart';

/// Clears every registered [LocalDataStore] — the whole-app Factory-reset seam.
///
/// Depends on the [LocalDataStore] abstraction (dependency inversion), never on
/// `shared_preferences`, so it is unit-testable against fakes and a drift-guard
/// test can assert [registeredKeys] equals the canonical persisted-key set
/// (TC-705). Prefer this over `prefs.clear()`: keeping each key private to its
/// owning repo lets the registry be enumerated and asserted, and lets a later
/// wave's new key fail the drift guard unless it is wired in here.
class LocalDataResetService {
  /// Creates the service over the ordered list of [stores] to clear. The order
  /// is irrelevant to correctness (each store owns a disjoint key set); it is
  /// stable only so the wipe is deterministic.
  const LocalDataResetService(this._stores);

  final List<LocalDataStore> _stores;

  /// The canonical set of every persisted key the app writes, unioned across all
  /// registered stores. The single source of truth a drift-guard test asserts
  /// against (TC-705) — NOT a hand-copied literal.
  Set<String> get registeredKeys => <String>{
    for (final store in _stores) ...store.ownedKeys,
  };

  /// The registered stores (read-only view) — exposed so a coverage test can
  /// enumerate what the seam will clear.
  List<LocalDataStore> get stores => List<LocalDataStore>.unmodifiable(_stores);

  /// Clears EVERY registered store's keys — the full local-data wipe (AC-3).
  ///
  /// Deletes only; introduces no read/network surface (NFR-2). Awaits each store
  /// so the wipe is complete before the caller re-initialises in-memory state
  /// (AC-4): the caller must reconstruct the engine/ticker/Blocs to zero AFTER
  /// this returns so the next autosave cannot re-persist stale values (TC-706).
  ///
  /// FAULT ISOLATION: every store is attempted even if an earlier one throws —
  /// so a single failing store can never SKIP the stores after it (a half-reset
  /// is the exact bug this feature prevents). Any failures are collected and, if
  /// non-empty, surfaced together as a [LocalDataResetException] AFTER the wipe
  /// has been attempted across all stores, so the caller can report the partial
  /// wipe rather than leave it silent.
  Future<void> clear() async {
    final List<Object> failures = <Object>[];
    for (final store in _stores) {
      try {
        await store.clear();
      } catch (error) {
        // Record and keep going: never let one store's failure skip the rest.
        failures.add(error);
      }
    }
    if (failures.isNotEmpty) {
      throw LocalDataResetException(failures);
    }
  }
}

/// Thrown by [LocalDataResetService.clear] when one or more stores failed to
/// clear. Every OTHER store is still cleared first (max data wiped; no store is
/// skipped because an earlier one threw), then the collected [failures] are
/// surfaced together so the caller can report the partial wipe rather than
/// leaving a silent half-reset.
class LocalDataResetException implements Exception {
  /// Creates the aggregate over the per-store [failures] (in store order).
  LocalDataResetException(this.failures);

  /// The errors thrown by individual stores while clearing, in store order.
  final List<Object> failures;

  @override
  String toString() =>
      'LocalDataResetException: ${failures.length} store(s) failed to clear: '
      '$failures';
}
