/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

/// A minimal, injectable source of "the current local time".
///
/// The [JourneyEngine] depends only on this abstraction and **never** calls
/// `DateTime.now()` directly, so it is fully deterministic and unit-testable
/// with a scripted test clock — no real timers, no wall-clock waits
/// (Determinism NFR / AC-7 / AC-12). The engine uses the clock solely to read
/// the current **local calendar date** for the day-boundary reset (AC-9/AC-10);
/// it does not use it to measure elapsed time — that comes from the
/// caller-supplied `tick(delta)` (AC-7).
abstract interface class Clock {
  /// The current local date-and-time. Implementations in the app layer return
  /// `DateTime.now()`; tests inject a fixed/scripted value.
  DateTime now();
}

/// The production [Clock] backed by the real wall clock. Lives here (pure Dart,
/// no Flutter import) for app-layer wiring; the engine never instantiates it.
class SystemClock implements Clock {
  /// Creates a system clock.
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
