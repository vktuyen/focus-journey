/// Data layer — deterministic, in-memory [TrayController] for dev/tests.
///
/// Privacy: touches NO real tray. It records state and exposes a sink so tests
/// can simulate a user clicking a tray menu item, with no real OS tray (NFR-8).
library;

import 'dart:async';

import '../domain/tray_controller.dart';
import '../domain/tray_state.dart';
import '../domain/window_mode.dart';

/// A fully deterministic [TrayController]. Records current icon state, mode,
/// tooltip/status, and lets tests push [TrayAction]s onto [actions] as if the
/// user clicked the menu.
class MockTrayController implements TrayController {
  final _actions = StreamController<TrayAction>.broadcast();

  /// Ordered log of method names invoked — for test assertions.
  final List<String> calls = <String>[];

  /// The current state the tray reflects (AC-11).
  TrayActivityState state = TrayActivityState.paused;

  /// The current mode the menu reflects (AC-14).
  WindowMode mode = WindowMode.full;

  /// The current status line, if any (AC-13).
  String? statusLine;

  /// Whether [init] ran.
  bool didInit = false;

  @override
  Stream<TrayAction> get actions => _actions.stream;

  @override
  Future<void> init({
    TrayActivityState initialState = TrayActivityState.paused,
    WindowMode initialMode = WindowMode.full,
  }) async {
    calls.add('init');
    state = initialState;
    mode = initialMode;
    didInit = true;
  }

  @override
  Future<void> setState(TrayActivityState state) async {
    calls.add('setState($state)');
    this.state = state;
  }

  @override
  Future<void> setMode(WindowMode mode) async {
    calls.add('setMode($mode)');
    this.mode = mode;
  }

  @override
  Future<void> setStatusLine(String? statusLine) async {
    calls.add('setStatusLine($statusLine)');
    this.statusLine = statusLine;
  }

  /// Test helper: simulate the user invoking a tray menu [action].
  void emitAction(TrayAction action) {
    if (!_actions.isClosed) {
      _actions.add(action);
    }
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    await _actions.close();
  }
}
