/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

/// A persisted top-left screen position for the compact (PiP) window.
///
/// PRIVACY: this is the app's OWN window geometry — it is not mouse-position
/// history, not pointer tracking, and reveals nothing about the user's input.
/// Only position is persisted (the compact view is a FIXED size — AC-8).
class WindowPosition {
  /// Creates a position from logical screen coordinates (top-left origin).
  const WindowPosition({required this.x, required this.y});

  /// Logical x of the window's top-left, in screen coordinates.
  final double x;

  /// Logical y of the window's top-left, in screen coordinates.
  final double y;

  @override
  bool operator ==(Object other) =>
      other is WindowPosition && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'WindowPosition($x, $y)';
}
