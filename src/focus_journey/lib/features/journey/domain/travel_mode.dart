/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

/// The cosmetic travel "skin" the traveller is using.
///
/// **v1 is speed-only: `mode` is purely cosmetic and does NOT affect
/// `kmPerActiveHour` or any accrual (AC-13 / TC-013).** All modes share the one
/// injected `kmPerActiveHour`. Per-mode speeds and the energy/fuel model arrive
/// in v2 (`journey-energy-model`). The set matches the v1 plan §20:
/// walk / run / bicycle / motorbike / car / ship, with [motorbike] the default.
enum TravelMode {
  /// On foot.
  walk,

  /// Running.
  run,

  /// Bicycle.
  bicycle,

  /// Motorbike — the v1 default skin (plan §20).
  motorbike,

  /// Car.
  car,

  /// Ship.
  ship,
}
