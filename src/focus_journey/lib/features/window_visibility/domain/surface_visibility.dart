/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

/// Which of the app's two surfaces a visibility reading is about
/// (journey-scene-v2 #5, AC-5). Both surfaces share ONE `JourneyGame` instance
/// (ADR-0003), so visibility is evaluated **per-surface** — the PiP can be on
/// screen while the main window is hidden, and vice versa.
///
/// NOTE: the app is currently single-window two-mode (ADR-0003), so at runtime
/// only one of these is "live" at a time (the window is either in full or
/// compact mode). The enum is kept per-surface so the scene/Bloc seam is stable
/// if the model ever splits into two real OS windows, and so tests can drive the
/// two cases independently.
enum WindowSurface {
  /// The normal, framed main window (full mode).
  main,

  /// The frameless, always-on-top compact Picture-in-Picture window.
  pip,
}

/// A single, **aggregate** visibility reading for one [surface] (#5).
///
/// ## Privacy (headline, P0 — NFR-2)
/// This describes ONLY whether the app's OWN window has pixels on screen. It is
/// derived purely from the window's own occlusion / minimized / hidden state.
/// It reads NO keystrokes, screen/display contents, clipboard, files,
/// mouse-position history, focus of OTHER apps, or any other app's window
/// titles. `visible == true` while another application holds keyboard focus —
/// the trigger is **occlusion / visibility, not focus** (AC-3).
class SurfaceVisibility {
  /// Creates a reading for [surface].
  const SurfaceVisibility({required this.surface, required this.visible});

  /// A convenience visible reading.
  const SurfaceVisibility.visible(WindowSurface surface)
    : this(surface: surface, visible: true);

  /// A convenience hidden reading.
  const SurfaceVisibility.hidden(WindowSurface surface)
    : this(surface: surface, visible: false);

  /// The surface this reading is about.
  final WindowSurface surface;

  /// Whether ANY pixels of this surface are currently on screen.
  ///
  /// `true` when the window is on screen — INCLUDING when it is fully or
  /// partially visible but another application holds keyboard focus (AC-3:
  /// keep animating). `false` ONLY when the surface has no pixels on screen:
  /// minimized, hidden (hidden-to-tray / app-hidden), or fully occluded by
  /// other windows where the OS reports that reliably (AC-4: pause).
  final bool visible;

  /// A copy with [visible] overridden.
  SurfaceVisibility copyWith({bool? visible}) {
    return SurfaceVisibility(
      surface: surface,
      visible: visible ?? this.visible,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SurfaceVisibility &&
      other.surface == surface &&
      other.visible == visible;

  @override
  int get hashCode => Object.hash(surface, visible);

  @override
  String toString() => 'SurfaceVisibility(${surface.name}, visible: $visible)';
}
