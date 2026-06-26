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
  final _visibilityController = StreamController<bool>.broadcast();
  WindowMode _mode = WindowMode.full;
  // Optimistic start: the window is not shown until setup() calls show(), so we
  // begin "not visible" and emit `true` from the initial show. This keeps the
  // first emission honest for the NFR-1 pause subscriber.
  bool _visible = false;
  Future<void> Function()? _flush;
  bool _listening = false;

  @override
  WindowMode get mode => _mode;

  @override
  Stream<WindowMode> get modeChanges => _modeController.stream;

  @override
  bool get isWindowVisible => _visible;

  @override
  Stream<bool> get windowVisibilityChanges => _visibilityController.stream;

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
    _setVisible(true); // initial show — the window is now on screen (NFR-1).
    if (!_listening) {
      windowManager.addListener(this);
      _listening = true;
    }
  }

  @override
  Future<void> enterCompact() async {
    // S1: resilient transition. The body may throw mid-sequence (a flaky
    // window_manager call), but we drive toward a known consistent end-state in
    // the `finally`: ensure the window is shown + visibility/mode reflect
    // compact, then rethrow so the caller can react. We must never leave a
    // hidden window with the scene believing it is visible (NFR-1).
    final target = await _resolveCompactPosition();
    Object? failure;
    try {
      await windowManager.setAsFrameless();
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setResizable(false);
      await windowManager.setSize(
        const Size(CompactGeometry.width, CompactGeometry.height),
      );
      await windowManager.setPosition(Offset(target.x, target.y));
    } catch (e, st) {
      failure = e;
      debugPrint(
        'WindowManagerModeController.enterCompact partial failure: $e\n$st',
      );
    } finally {
      // Always show + settle the consistent end-state: compact + visible.
      await _safeShowFocus(focus: false);
      _setMode(WindowMode.compact);
      _setVisible(true);
    }
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Future<void> exitFull() async {
    // S1: same resilience contract — end on (full, visible) regardless of a
    // mid-sequence failure, then rethrow.
    Object? failure;
    try {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setResizable(true);
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.setSize(_fullSize);
      await windowManager.center();
    } catch (e, st) {
      failure = e;
      debugPrint(
        'WindowManagerModeController.exitFull partial failure: $e\n$st',
      );
    } finally {
      await _safeShowFocus(focus: true);
      _setMode(WindowMode.full);
      _setVisible(true);
    }
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Future<void> hideToTray() async {
    await windowManager.hide();
    // PiP is NOT auto-shown on close-to-tray (AC-18): no mode change, just hide.
    _setVisible(false); // ONE source of truth: pause the scene (NFR-1).
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
    await _safeShowFocus(focus: true);
    _setVisible(true);
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
  ///
  /// N2: this is a `void async` framework callback, so any error inside it would
  /// otherwise become an UNHANDLED async error. Guard the whole body so a flaky
  /// hide/isPreventClose call can never crash the zone — at worst the close is a
  /// no-op and the user can retry / use the tray Quit.
  @override
  void onWindowClose() async {
    try {
      if (await windowManager.isPreventClose()) {
        await hideToTray();
      }
    } catch (e, st) {
      debugPrint('WindowManagerModeController.onWindowClose error: $e\n$st');
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
    await _visibilityController.close();
  }

  // --- internals ---

  void _setMode(WindowMode next) {
    if (_mode == next) return;
    _mode = next;
    if (!_modeController.isClosed) {
      _modeController.add(next);
    }
  }

  /// De-duplicated visibility emission (NFR-1 source of truth). Never emits an
  /// identical consecutive value.
  void _setVisible(bool next) {
    if (_visible == next) return;
    _visible = next;
    if (!_visibilityController.isClosed) {
      _visibilityController.add(next);
    }
  }

  /// Shows (and optionally focuses) the window without letting a transient
  /// platform error escape — used in the S1 `finally` blocks so the end-state
  /// "visible" is reached best-effort even after a partial transition failure.
  Future<void> _safeShowFocus({required bool focus}) async {
    try {
      await windowManager.show();
      if (focus) {
        await windowManager.focus();
      }
    } catch (e, st) {
      debugPrint('WindowManagerModeController._safeShowFocus error: $e\n$st');
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
