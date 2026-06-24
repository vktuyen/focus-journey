/// Domain layer — pure Dart helpers (geometry math only; no Flutter, no I/O).
library;

import 'window_position.dart';

/// A visible display rectangle, expressed in the same logical screen
/// coordinates as a [WindowPosition]. A plain value object so the off-screen
/// clamp (AC-8) is unit-testable WITHOUT a real display / `screen_retriever`.
///
/// PRIVACY: display geometry only — bounds of a screen, never its contents.
class VisibleDisplay {
  /// Creates a visible-area rectangle from its top-left and size.
  const VisibleDisplay({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// Left edge (logical x).
  final double left;

  /// Top edge (logical y).
  final double top;

  /// Visible width (logical pixels).
  final double width;

  /// Visible height (logical pixels).
  final double height;

  /// Right edge (logical x).
  double get right => left + width;

  /// Bottom edge (logical y).
  double get bottom => top + height;
}

/// The fixed compact (PiP) window size and clamp math (AC-6 fixed size, AC-8
/// clamp). Kept pure so it can be unit-tested with synthetic displays.
abstract final class CompactGeometry {
  /// The FIXED compact width (logical pixels) — resolved decision: fixed size.
  static const double width = 280;

  /// The FIXED compact height (logical pixels).
  static const double height = 180;

  /// Inset from the display edge used by the default-corner fallback.
  static const double _defaultInset = 24;

  /// Returns a position guaranteed to place the whole fixed-size compact window
  /// inside one of the [displays] (AC-8 clamp). If [desired] is `null`, no
  /// display fully contains it, or [displays] is empty, falls back to the
  /// bottom-right corner of the first/primary display (a sensible default).
  static WindowPosition clampOntoVisible({
    required WindowPosition? desired,
    required List<VisibleDisplay> displays,
  }) {
    if (displays.isEmpty) {
      // No display info — return the desired position unchanged or origin so
      // the window still appears; the OS will place it on the primary screen.
      return desired ??
          const WindowPosition(x: _defaultInset, y: _defaultInset);
    }

    if (desired != null) {
      // Is the desired top-left already on a display with room for the window?
      for (final d in displays) {
        if (desired.x >= d.left &&
            desired.y >= d.top &&
            desired.x + width <= d.right &&
            desired.y + height <= d.bottom) {
          return desired;
        }
      }
      // Off-screen / invalid: clamp into the nearest display (use the first).
      final d = displays.first;
      final maxX = d.right - width;
      final maxY = d.bottom - height;
      return WindowPosition(
        x: _clamp(desired.x, d.left, maxX < d.left ? d.left : maxX),
        y: _clamp(desired.y, d.top, maxY < d.top ? d.top : maxY),
      );
    }

    // No saved position — default to the bottom-right corner of the primary.
    final d = displays.first;
    return WindowPosition(
      x: d.right - width - _defaultInset,
      y: d.bottom - height - _defaultInset,
    );
  }

  static double _clamp(double v, double lo, double hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
  }
}
