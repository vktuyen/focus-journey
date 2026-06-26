/// Data layer — deterministic, in-memory [WindowVisibilityController] for
/// dev/tests. Touches NO real OS window; lets widget/unit tests drive
/// per-surface visibility deterministically (the seam the Flame scene + Bloc
/// tests depend on).
library;

import 'dart:async';

import '../domain/surface_visibility.dart';
import '../domain/window_visibility_controller.dart';

/// A fully deterministic [WindowVisibilityController]. Tests call [setVisible]
/// to drive AC-3 (visible-but-unfocused → animate), AC-4 (hidden → pause), and
/// AC-5 (per-surface) without a real OS window.
class MockWindowVisibilityController implements WindowVisibilityController {
  /// Creates the mock with optional initial per-surface visibility (defaults to
  /// both surfaces visible).
  MockWindowVisibilityController({
    bool mainVisible = true,
    bool pipVisible = true,
  }) {
    _latest[WindowSurface.main] = SurfaceVisibility(
      surface: WindowSurface.main,
      visible: mainVisible,
    );
    _latest[WindowSurface.pip] = SurfaceVisibility(
      surface: WindowSurface.pip,
      visible: pipVisible,
    );
  }

  final _changes = StreamController<SurfaceVisibility>.broadcast();
  final Map<WindowSurface, SurfaceVisibility> _latest =
      <WindowSurface, SurfaceVisibility>{};

  /// Ordered log of method calls — for test assertions.
  final List<String> calls = <String>[];

  bool _started = false;

  /// Whether [start] has been called.
  bool get started => _started;

  @override
  Future<void> start() async {
    calls.add('start');
    _started = true;
  }

  @override
  SurfaceVisibility visibilityOf(WindowSurface surface) {
    return _latest[surface] ?? SurfaceVisibility.visible(surface);
  }

  @override
  bool isVisible(WindowSurface surface) => visibilityOf(surface).visible;

  @override
  Stream<SurfaceVisibility> get changes => _changes.stream;

  /// Test driver: sets [surface] visibility and emits a de-duplicated change
  /// (no-op if unchanged), exactly as the real backend would on an OS occlusion
  /// transition.
  void setVisible(WindowSurface surface, bool visible) {
    final prior = _latest[surface];
    if (prior != null && prior.visible == visible) return;
    final reading = SurfaceVisibility(surface: surface, visible: visible);
    _latest[surface] = reading;
    if (!_changes.isClosed) {
      _changes.add(reading);
    }
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    if (!_changes.isClosed) {
      await _changes.close();
    }
  }
}
