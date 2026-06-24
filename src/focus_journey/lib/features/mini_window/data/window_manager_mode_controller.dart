/// Data layer — real [WindowModeController] backed by `window_manager` +
/// `screen_retriever` (display geometry for the off-screen clamp only).
///
/// Privacy (NFR-4/5): this backend manipulates ONLY the app's own window
/// (size, position, frameless/title-bar, always-on-top level, visibility,
/// close intercept) and reads ONLY the app's own window position + display
/// BOUNDS (never display contents). No keystrokes, screen pixels, clipboard,
/// files, mouse-position history, or other apps' window titles.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/compact_geometry.dart';
import '../domain/compact_window_position_repository.dart';
import '../domain/window_mode.dart';
import '../domain/window_mode_controller.dart';
import '../domain/window_position.dart';

/// `window_manager`-backed [WindowModeController]. Single window, two modes
/// (ADR-0003). The full-mode framed size is captured at [setup] so [exitFull]
/// restores it.
class WindowManagerModeController
    with WindowListener
    implements WindowModeController {
  /// Creates the controller. [positionRepository] persists/restores the compact
  /// position. [fullSize] / [minSize] default to sensible desktop values.
  WindowManagerModeController({
    required CompactWindowPositionRepository positionRepository,
    Size fullSize = const Size(900, 700),
    Size minSize = const Size(640, 480),
  }) : _positionRepository = positionRepository,
       _fullSize = fullSize,
       _minSize = minSize;

  final CompactWindowPositionRepository _positionRepository;
  final Size _fullSize;
  final Size _minSize;

  final _modeController = StreamController<WindowMode>.broadcast();
  final _hiddenController = StreamController<void>.broadcast();
  WindowMode _mode = WindowMode.full;
  Future<void> Function()? _flush;
  bool _listening = false;

  @override
  WindowMode get mode => _mode;

  @override
  Stream<WindowMode> get modeChanges => _modeController.stream;

  @override
  Stream<void> get hiddenToTray => _hiddenController.stream;

  @override
  Future<void> setup() async {
    await windowManager.ensureInitialized();
    // Intercept the close button so it can hide-to-tray instead of quitting
    // (AC-15/AC-16). Min sizes prevent an unusable full window.
    final options = WindowOptions(
      size: _fullSize,
      minimumSize: _minSize,
      center: true,
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    });
    if (!_listening) {
      windowManager.addListener(this);
      _listening = true;
    }
  }

  @override
  Future<void> enterCompact() async {
    final target = await _resolveCompactPosition();
    await windowManager.setAsFrameless();
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setResizable(false);
    await windowManager.setSize(
      const Size(CompactGeometry.width, CompactGeometry.height),
    );
    await windowManager.setPosition(Offset(target.x, target.y));
    await windowManager.show();
    _setMode(WindowMode.compact);
  }

  @override
  Future<void> exitFull() async {
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setResizable(true);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setSize(_fullSize);
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
    _setMode(WindowMode.full);
  }

  @override
  Future<void> hideToTray() async {
    await windowManager.hide();
    // PiP is NOT auto-shown on close-to-tray (AC-18): no mode change, just hide.
    if (!_hiddenController.isClosed) {
      _hiddenController.add(null); // surface for the AC-17 one-time hint.
    }
  }

  @override
  Future<void> showApp() async {
    if (_mode == WindowMode.compact) {
      await exitFull();
      return;
    }
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> setAlwaysOnTop(bool enabled) {
    return windowManager.setAlwaysOnTop(enabled);
  }

  @override
  Future<void> startDragging() {
    // OS window-move drag — only meaningful for the frameless compact view
    // (AC-6). Manipulates ONLY this app's own window position (NFR-4).
    return windowManager.startDragging();
  }

  @override
  Future<void> persistCompactPosition() async {
    final offset = await windowManager.getPosition();
    await _positionRepository.save(WindowPosition(x: offset.dx, y: offset.dy));
  }

  @override
  void onBeforeQuit(Future<void> Function() flush) {
    _flush = flush;
  }

  @override
  Future<void> quit() async {
    final flush = _flush;
    if (flush != null) {
      try {
        await flush(); // AC-16: persist latest journey state before destroy.
      } catch (_) {
        // Never let a flush failure block the user's Quit.
      }
    }
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  /// Close button → hide-to-tray (AC-15). The process stays alive; only the
  /// tray remains. Full exit is solely via [quit] (AC-16).
  @override
  void onWindowClose() async {
    if (await windowManager.isPreventClose()) {
      await hideToTray();
    }
  }

  @override
  Future<void> dispose() async {
    if (_listening) {
      windowManager.removeListener(this);
      _listening = false;
    }
    await _modeController.close();
    await _hiddenController.close();
  }

  // --- internals ---

  void _setMode(WindowMode next) {
    if (_mode == next) return;
    _mode = next;
    if (!_modeController.isClosed) {
      _modeController.add(next);
    }
  }

  /// Resolves the compact target position: load the persisted position, then
  /// clamp it onto a visible display (falling back to a default corner if it is
  /// missing/off-screen) using display geometry only (AC-8).
  Future<WindowPosition> _resolveCompactPosition() async {
    final saved = await _positionRepository.load();
    final displays = await _readVisibleDisplays();
    return CompactGeometry.clampOntoVisible(desired: saved, displays: displays);
  }

  /// Reads display BOUNDS only (never contents) via `screen_retriever`. Returns
  /// an empty list on any failure so the clamp falls back gracefully.
  Future<List<VisibleDisplay>> _readVisibleDisplays() async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      return <VisibleDisplay>[
        for (final d in displays)
          VisibleDisplay(
            left: (d.visiblePosition ?? Offset.zero).dx,
            top: (d.visiblePosition ?? Offset.zero).dy,
            width: (d.visibleSize ?? d.size).width,
            height: (d.visibleSize ?? d.size).height,
          ),
      ];
    } catch (_) {
      return const <VisibleDisplay>[];
    }
  }
}
