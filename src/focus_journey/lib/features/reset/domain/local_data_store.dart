/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O type.
///
/// journey-reset (AC-3/AC-4). The single abstraction the Factory-reset seam
/// depends on so it can clear EVERY persisted key without knowing about
/// `shared_preferences`. Each concrete `shared_preferences`-backed repository
/// implements this in addition to its own persistence interface, so:
///   * the aggregating [LocalDataResetService] can wipe them all uniformly, and
///   * a drift-guard test can enumerate [ownedKeys] across the registered
///     stores and assert the canonical key set is covered (TC-705).
library;

/// A store of persisted local data that can enumerate the keys it owns and
/// clear them.
///
/// [ownedKeys] is the SET of `shared_preferences` keys this store writes — the
/// building block of the canonical reset registry. `clear()` removes exactly
/// those keys (no more, no less), keeping every key private to its owning repo
/// (no blunt `prefs.clear()`), so a new key added in a later wave is only wiped
/// if its repo is wired into the reset service (guarded by TC-705).
abstract interface class LocalDataStore {
  /// The `shared_preferences` keys this store owns. Stable, side-effect free.
  Set<String> get ownedKeys;

  /// Clears every key this store owns. Deletes local data ONLY — never reads a
  /// new signal, never touches the network (NFR-2 / BR-1).
  Future<void> clear();
}
