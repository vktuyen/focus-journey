/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'surface_visibility.dart';

/// The domain contract for the **per-surface window-visibility (occlusion)**
/// signal that drives journey-scene-v2 #5 (animate when visible, pause when
/// not). The scene/Bloc consume THIS — they never touch platform code or
/// `window_manager` directly. A native, occlusion-backed implementation and a
/// deterministic mock are interchangeable behind this interface, so widget /
/// unit tests can drive visibility deterministically.
///
/// This is the **stable seam** downstream `flame-game-developer` and
/// `flutter-app-developer` wire to. Keep it stable.
///
/// ## Why this is SEPARATE from `WindowModeController.isWindowVisible`
/// `WindowModeController` already exposes an `isWindowVisible` flag — but that
/// is an **app-state** signal: it flips on hide-to-tray / show, and was wired
/// for the mini-window's "pause when hidden OR unfocused" battery rule. #5
/// RELAXES that: the scene must keep animating while the surface is **visible
/// but unfocused**, and pause ONLY when there are no pixels on screen
/// (minimized / fully occluded / hidden). That requires a true **OS occlusion**
/// reading (macOS `NSWindow.occlusionState`), not an app-state flag, and it is
/// evaluated **per-surface** (AC-5). Hence a dedicated controller.
///
/// ## Privacy (headline, P0 — NFR-2)
/// Implementations read ONLY the app's OWN window occlusion / minimized /
/// hidden state. They install NO input hook and read NO keystrokes, screen
/// pixels, clipboard, files, mouse-position history, other-app focus, or other
/// apps' window titles. `/privacy-audit` must still PASS — this adds no new
/// sensitive signal beyond own-window visibility.
abstract interface class WindowVisibilityController {
  /// Begins observing OS visibility/occlusion changes for the app's
  /// window(s). Call once from the composition root after the window exists.
  /// Idempotent. After this resolves, [visibilityOf] returns a real reading and
  /// [changes] emits on each transition.
  Future<void> start();

  /// The latest visibility reading for [surface]. Defaults to `visible: true`
  /// for a surface not yet observed (a freshly-shown surface is assumed on
  /// screen until the OS says otherwise), so the scene errs toward animating.
  SurfaceVisibility visibilityOf(WindowSurface surface);

  /// Convenience: whether [surface] currently has pixels on screen.
  bool isVisible(WindowSurface surface) => visibilityOf(surface).visible;

  /// De-duplicated stream of per-surface visibility transitions (no identical
  /// consecutive emission for the same surface). Each event carries which
  /// [WindowSurface] changed and its new visibility, so a per-surface consumer
  /// (the shared `JourneyGame` driver) can pause/resume the right surface
  /// (AC-3/AC-4/AC-5). Broadcast — multiple listeners allowed.
  Stream<SurfaceVisibility> get changes;

  /// Releases native observers and closes [changes]. Safe to call more than
  /// once.
  Future<void> dispose();
}
