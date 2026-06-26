/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'window_mode.dart';

/// The domain contract for manipulating the app's OWN single OS window
/// (ADR-0003: one window, two modes). The UI/Bloc layer calls this; it never
/// touches `window_manager` directly. A real `window_manager`-backed impl and a
/// deterministic mock are interchangeable behind this interface (NFR-7 / NFR-8).
///
/// ## Privacy (headline, P0 — NFR-4/5)
/// Implementations manipulate ONLY this app's own window — size, position,
/// frameless/title-bar, always-on-top level, visibility, and close intercept.
/// They read NO keystrokes, screen/display contents, clipboard, files,
/// mouse-position history, or OTHER apps' window titles. The only OS read is
/// the app's own window position (to persist it) and display geometry (to clamp
/// an off-screen position back onto a visible screen — via `screen_retriever`,
/// already cleared as a transitive dependency in activity-detection).
abstract interface class WindowModeController {
  /// Registers window options once at startup (min sizes, and
  /// `setPreventClose(true)` so the close button can be intercepted into a
  /// hide-to-tray — AC-15/AC-16). Call once from the composition root before
  /// `runApp`. Idempotent.
  Future<void> setup();

  /// The current window mode. Starts in [WindowMode.full] (first launch opens
  /// the main window normally — resolved decision).
  WindowMode get mode;

  /// Stream of mode transitions, so the tray and UI can reflect the current
  /// mode (AC-14). Emits the new [WindowMode] after each successful transition.
  Stream<WindowMode> get modeChanges;

  /// Whether ANY app window is currently on screen. This is the ONE source of
  /// truth the shell uses to pause the shared `JourneyGame` when nothing is
  /// visible (NFR-1): `windowManager.hide()` does NOT reliably change
  /// `AppLifecycleState` on desktop, so the scene would otherwise keep spinning
  /// with no window shown. `false` while hidden-to-tray; `true` whenever the
  /// full or compact window is shown/foregrounded. Reports a window-visibility
  /// fact only — no user data (NFR-4).
  bool get isWindowVisible;

  /// De-duplicated stream of [isWindowVisible] transitions (no identical
  /// consecutive emissions). Emits `true` on the initial show ([setup]),
  /// [showApp], [enterCompact], [exitFull]; `false` on [hideToTray] / the
  /// close-button intercept. The shell subscribes to drive
  /// `pauseEngine()`/`resumeEngine()` on the single game loop (NFR-1).
  Stream<bool> get windowVisibilityChanges;

  /// Enters the compact PiP (AC-6): resize to the FIXED compact size, make the
  /// window frameless / hidden title bar, set always-on-top, reposition to the
  /// persisted compact position (clamped onto a visible display; falls back to
  /// a sensible default corner if missing/invalid), then show. The main window
  /// "hides to the dock" as a property transition on this one window.
  Future<void> enterCompact();

  /// Exits the compact PiP back to the full framed main window (AC-6 / AC-16):
  /// restore the full framed size, turn always-on-top off, restore a normal
  /// title bar, then show + focus. Dismisses the PiP (mutually exclusive).
  Future<void> exitFull();

  /// Hides the window to the tray WITHOUT terminating the process (AC-15): the
  /// process stays alive (tracking continues), only the tray icon remains. The
  /// PiP is NOT auto-shown (AC-18). Relies on the close intercept registered in
  /// [setup].
  Future<void> hideToTray();

  /// A stream that emits once each time the window is hidden to the tray
  /// (whether via the close-button intercept or [hideToTray]). The app-dev
  /// listens to surface the one-time first-run hide-to-tray hint (AC-17). It
  /// reports a window-visibility transition only — no user data (NFR-4).
  Stream<void> get hiddenToTray;

  /// Restores + foregrounds the FULL main window (AC-12 "Show app" / AC-16),
  /// dismissing the compact PiP if it was active (mutually exclusive).
  Future<void> showApp();

  /// Toggles always-on-top on the current window (AC-7, P2 nicety). The compact
  /// view is always-on-top by nature; this lets it be temporarily demoted.
  Future<void> setAlwaysOnTop(bool enabled);

  /// Begins an OS window-move drag from the current pointer (AC-6 "repositioned
  /// by dragging its body"). The frameless compact view has no title bar to
  /// drag, so the body itself starts the move. A no-op for a non-draggable
  /// window. This keeps `window_manager` out of the presentation layer: the
  /// compact view's drag region calls this seam rather than the package.
  Future<void> startDragging();

  /// Persists the current window position as the compact position so the PiP
  /// reopens there next launch (AC-8). Typically called after a drag settles.
  Future<void> persistCompactPosition();

  /// Registers a flush callback invoked just before the process is destroyed on
  /// Quit (AC-16 "Quit flushes state"). The app-dev wires this to journey/stats
  /// persistence — this layer NEVER persists journey data itself, it only
  /// guarantees the hook runs before destroy. Replaces any previously
  /// registered hook.
  void onBeforeQuit(Future<void> Function() flush);

  /// Fully exits the app (AC-12 "Quit" — the only full-exit path). Runs the
  /// [onBeforeQuit] flush hook (if any), tears down the tray, lifts the close
  /// prevention, and destroys the window/process.
  Future<void> quit();

  /// Registers the window-close listener and tears it down. Call from the UI
  /// layer once a [BuildContext] / lifecycle owner exists, or rely on [setup].
  /// Releases any platform listeners.
  Future<void> dispose();
}
