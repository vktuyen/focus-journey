/// Data layer — deterministic, in-memory [WindowModeController] for dev/tests.
///
/// Privacy: touches NO real OS window. It records calls and flips an in-memory
/// mode/position so widget/headless tests can drive PiP visibility,
/// always-on-top, geometry persistence, and the close-to-tray model with NO
/// real OS window (NFR-8).
library;

import 'dart:async';

import '../domain/compact_geometry.dart';
import '../domain/compact_window_position_repository.dart';
import '../domain/window_mode.dart';
import '../domain/window_mode_controller.dart';
import '../domain/window_position.dart';

/// A fully deterministic [WindowModeController]. Exposes recorded calls and
/// in-memory state for assertions; runs no real OS window.
class MockWindowModeController implements WindowModeController {
  /// Creates the mock. [positionRepository] is optional — when provided,
  /// [enterCompact] loads/clamps from it (using [displays]) and
  /// [persistCompactPosition] saves [currentPosition] to it, exercising the
  /// real persistence/clamp seam without a real window.
  MockWindowModeController({
    CompactWindowPositionRepository? positionRepository,
    List<VisibleDisplay> displays = const <VisibleDisplay>[],
    this.currentPosition = const WindowPosition(x: 0, y: 0),
  }) : _positionRepository = positionRepository,
       _displays = displays;

  final CompactWindowPositionRepository? _positionRepository;
  final List<VisibleDisplay> _displays;
  final _modeController = StreamController<WindowMode>.broadcast();
  final _hiddenController = StreamController<void>.broadcast();
  final _visibilityController = StreamController<bool>.broadcast();

  /// Ordered log of method names invoked — for test assertions.
  final List<String> calls = <String>[];

  WindowMode _mode = WindowMode.full;

  /// Whether the window is currently visible (false after [hideToTray]). Tests
  /// read this directly; the production-equivalent seam is [isWindowVisible] /
  /// [windowVisibilityChanges] (NFR-1) — both reflect this same bool.
  bool visible = true;

  /// The current always-on-top flag.
  bool alwaysOnTop = false;

  /// The in-memory window position the PiP would occupy (set by [enterCompact],
  /// read by [persistCompactPosition]). Tests may mutate it to simulate a drag.
  WindowPosition currentPosition;

  /// Whether [setup] registered the close-intercept (AC-15 precondition).
  bool didSetup = false;

  /// Whether [quit] ran (and flushed). Tests assert full-exit only via Quit.
  bool didQuit = false;

  Future<void> Function()? _flush;

  @override
  WindowMode get mode => _mode;

  @override
  Stream<WindowMode> get modeChanges => _modeController.stream;

  @override
  bool get isWindowVisible => visible;

  @override
  Stream<bool> get windowVisibilityChanges => _visibilityController.stream;

  @override
  Stream<void> get hiddenToTray => _hiddenController.stream;

  @override
  Future<void> setup() async {
    calls.add('setup');
    didSetup = true;
    _setVisible(true); // initial show (de-duped — no-op if already visible).
  }

  @override
  Future<void> enterCompact() async {
    calls.add('enterCompact');
    final saved = _positionRepository == null
        ? null
        : await _positionRepository.load();
    currentPosition = CompactGeometry.clampOntoVisible(
      desired: saved,
      displays: _displays,
    );
    alwaysOnTop = true;
    _setMode(WindowMode.compact);
    _setVisible(true);
  }

  @override
  Future<void> exitFull() async {
    calls.add('exitFull');
    alwaysOnTop = false;
    _setMode(WindowMode.full);
    _setVisible(true);
  }

  @override
  Future<void> hideToTray() async {
    calls.add('hideToTray');
    // process stays alive; PiP not auto-shown (AC-18). ONE source of truth for
    // the NFR-1 pause: emit visibility=false via the same seam as production.
    _setVisible(false);
    if (!_hiddenController.isClosed) {
      _hiddenController.add(null); // surface for the AC-17 one-time hint.
    }
  }

  @override
  Future<void> showApp() async {
    calls.add('showApp');
    if (_mode == WindowMode.compact) {
      await exitFull();
      return;
    }
    _setVisible(true);
  }

  @override
  Future<void> setAlwaysOnTop(bool enabled) async {
    calls.add('setAlwaysOnTop($enabled)');
    alwaysOnTop = enabled;
  }

  @override
  Future<void> startDragging() async {
    calls.add('startDragging');
  }

  @override
  Future<void> persistCompactPosition() async {
    calls.add('persistCompactPosition');
    await _positionRepository?.save(currentPosition);
  }

  @override
  void onBeforeQuit(Future<void> Function() flush) {
    _flush = flush;
  }

  @override
  Future<void> quit() async {
    calls.add('quit');
    await _flush?.call();
    didQuit = true;
  }

  @override
  Future<void> dispose() async {
    await _modeController.close();
    await _hiddenController.close();
    await _visibilityController.close();
  }

  void _setMode(WindowMode next) {
    if (_mode == next) return;
    _mode = next;
    if (!_modeController.isClosed) {
      _modeController.add(next);
    }
  }

  /// De-duplicated visibility emission — mirrors the production backend so tests
  /// assert against the same seam (NFR-1). Never emits identical consecutive
  /// values.
  void _setVisible(bool next) {
    if (visible == next) return;
    visible = next;
    if (!_visibilityController.isClosed) {
      _visibilityController.add(next);
    }
  }
}
