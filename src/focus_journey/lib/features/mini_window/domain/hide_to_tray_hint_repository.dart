/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O type.
library;

/// Persistence seam for the one-time hide-to-tray hint flag (AC-17). Stores a
/// single boolean: whether the first-run hint has already been shown. The
/// composition root reads it at startup and writes it once the hint fires, so
/// the hint never reappears on subsequent closes.
///
/// PRIVACY: stores ONLY this UI flag — no user data of any kind (NFR-4).
abstract interface class HideToTrayHintRepository {
  /// Whether the one-time hint has already been shown in a previous session.
  Future<bool> hasShownHint();

  /// Records that the one-time hint has now been shown.
  Future<void> markHintShown();
}
