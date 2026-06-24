/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

/// The two mutually-exclusive presentation modes of the single app window
/// (ADR-0003): the normal framed main window and the compact frameless PiP.
///
/// These are window *shapes*, not journey state — the journey `state`
/// (active/idle/paused) is owned by the journey Bloc and is unrelated.
enum WindowMode {
  /// The normal, framed, resizable main window (full app UI).
  full,

  /// The small, frameless, always-on-top compact Picture-in-Picture view.
  /// Entering it hides the main window to the dock (mutually exclusive).
  compact,
}
