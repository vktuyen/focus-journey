/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'journey_progress.dart';

/// The persistence seam for the [JourneyEngine]'s daily progress.
///
/// The engine depends ONLY on this interface (DI / dependency inversion), never
/// on `shared_preferences` directly — that concrete implementation lives in the
/// `data/` layer (`SharedPreferencesJourneyRepository`). Swapping a real ↔
/// in-memory fake repository requires no engine change (AC-11 / TC-018).
abstract interface class JourneyRepository {
  /// Loads the last persisted snapshot, or `null` if none has been saved yet.
  Future<JourneyProgress?> load();

  /// Persists [progress], overwriting any previous snapshot.
  Future<void> save(JourneyProgress progress);
}
