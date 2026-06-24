/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

/// The journey state the tray icon/tooltip reflects (AC-11). This MIRRORS the
/// journey Bloc's `state` — the tray makes no judgment of its own; the app-dev
/// maps the Bloc state onto this and calls `TrayController.setState`.
///
/// Resolved decision: the icon is STATIC (no animation); active vs idle/paused
/// is conveyed via a static icon variant and/or tooltip.
enum TrayActivityState {
  /// Travelling — the journey is accruing distance (Bloc `state == active`).
  active,

  /// Parked — idle or paused. The PiP draws no idle/paused distinction in v1,
  /// so the tray collapses both onto one "paused" variant (inherits
  /// journey-view's resolved behaviour).
  paused,
}

/// The quick actions offered by the tray context menu (AC-12). The
/// [TrayController] emits these on its action stream; the app-dev maps each to
/// a `WindowModeController` call. The tray hardcodes NO app logic.
enum TrayAction {
  /// "Show app" — restore/foreground the full main window (dismiss PiP).
  showApp,

  /// "Enter compact / PiP" — collapse to the compact view.
  enterCompact,

  /// "Quit" — fully exit the process (the only full-exit path).
  quit,
}
