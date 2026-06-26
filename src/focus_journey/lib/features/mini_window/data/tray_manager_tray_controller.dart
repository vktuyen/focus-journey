/// Data layer — real [TrayController] backed by `tray_manager`.
///
/// Privacy (NFR-4/5): this backend touches ONLY a status icon, its tooltip, and
/// a context menu. It reads NO user data of any kind — no keystrokes, screen,
/// clipboard, files, mouse-position history, or other apps' window titles.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

import '../domain/tray_controller.dart';
import '../domain/tray_state.dart';
import '../domain/window_mode.dart';

/// `tray_manager`-backed [TrayController]. STATIC icon variants (no animation —
/// resolved decision). If an icon asset is missing, falls back to tooltip-only
/// presence so the tray never fails to appear (graceful degradation).
class TrayManagerTrayController with TrayListener implements TrayController {
  /// Creates the controller with the asset paths for each static state icon.
  /// Defaults reference `assets/tray/` (provided by ui-asset-curator). The
  /// stable filenames the curator should provide are [defaultActiveIcon] /
  /// [defaultPausedIcon].
  TrayManagerTrayController({
    String activeIcon = defaultActiveIcon,
    String pausedIcon = defaultPausedIcon,
  }) : _activeIcon = activeIcon,
       _pausedIcon = pausedIcon;

  /// Expected Flutter-asset path for the ACTIVE (travelling) static tray icon.
  /// TODO(ui-asset-curator): provide this PNG (template-style, ~18pt) under
  /// `assets/tray/` and register it in pubspec `flutter: assets:`.
  static const String defaultActiveIcon = 'assets/tray/tray_active.png';

  /// Expected Flutter-asset path for the PAUSED (idle/parked) static tray icon.
  /// TODO(ui-asset-curator): provide this PNG under `assets/tray/`.
  static const String defaultPausedIcon = 'assets/tray/tray_paused.png';

  // Tray context-menu item keys (stable identifiers for click routing).
  static const String _keyShowApp = 'show_app';
  static const String _keyEnterCompact = 'enter_compact';
  static const String _keyQuit = 'quit';

  final String _activeIcon;
  final String _pausedIcon;

  final _actions = StreamController<TrayAction>.broadcast();

  TrayActivityState _state = TrayActivityState.paused;
  WindowMode _mode = WindowMode.full;
  String? _statusLine;
  bool _iconAvailable = false;

  @override
  Stream<TrayAction> get actions => _actions.stream;

  @override
  Future<void> init({
    TrayActivityState initialState = TrayActivityState.paused,
    WindowMode initialMode = WindowMode.full,
  }) async {
    _state = initialState;
    _mode = initialMode;
    trayManager.addListener(this);
    await _applyIcon();
    await _applyTooltip();
    await _applyMenu();
  }

  @override
  Future<void> setState(TrayActivityState state) async {
    if (_state == state) return;
    _state = state;
    await _applyIcon();
    await _applyTooltip();
  }

  @override
  Future<void> setMode(WindowMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    await _applyMenu();
  }

  @override
  Future<void> setStatusLine(String? statusLine) async {
    if (_statusLine == statusLine) return;
    _statusLine = statusLine;
    // IMPORTANT (macOS click-dispatch correctness): the status line is a
    // VOLATILE, per-tick value (the live "X.X km" readout). It is surfaced via
    // the tooltip ONLY — it must NOT rebuild the context menu. `tray_manager`'s
    // `setContextMenu` regenerates fresh menu-item ids on every call, while the
    // NATIVELY-displayed menu retains the ids it was built with; the Dart-side
    // click router (`_menu.getMenuItemById(id)`) then can't resolve the clicked
    // id and `onTrayMenuItemClick` silently no-ops. Rebuilding the menu only
    // when its STRUCTURE changes (mode → `setMode`) keeps the displayed menu's
    // ids in sync with the Dart map, so menu-item clicks reliably fire on macOS.
    await _applyTooltip();
  }

  // --- TrayListener ---

  @override
  void onTrayIconMouseDown() {
    // On macOS a left click should pop the menu; on Windows left-click is
    // typically restore — but to keep parity simple we pop the menu on click.
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _keyShowApp:
        _emit(TrayAction.showApp);
      case _keyEnterCompact:
        _emit(TrayAction.enterCompact);
      case _keyQuit:
        _emit(TrayAction.quit);
    }
  }

  @override
  Future<void> dispose() async {
    trayManager.removeListener(this);
    try {
      await trayManager.destroy();
    } catch (_) {
      // Tray may already be gone (e.g. during Quit) — ignore.
    }
    await _actions.close();
  }

  // --- internals ---

  void _emit(TrayAction action) {
    if (!_actions.isClosed) {
      _actions.add(action);
    }
  }

  Future<void> _applyIcon() async {
    final path = _state == TrayActivityState.active ? _activeIcon : _pausedIcon;
    try {
      await trayManager.setIcon(path, isTemplate: true);
      _iconAvailable = true;
    } catch (e) {
      // Graceful fallback: a missing icon asset must not break the tray — keep
      // a tooltip-only presence (AC-11 still distinguishes state via tooltip).
      _iconAvailable = false;
      debugPrint(
        'TrayManagerTrayController: icon "$path" unavailable, '
        'falling back to tooltip-only ($e)',
      );
    }
  }

  Future<void> _applyTooltip() async {
    final label = _state == TrayActivityState.active ? 'Travelling' : 'Paused';
    final tip = _statusLine ?? 'Vietnam Focus Journey — $label';
    try {
      await trayManager.setToolTip(tip);
    } catch (_) {
      // Tooltip is best-effort.
    }
    if (!_iconAvailable) {
      // No icon: surface state in the menu-bar title too so it is visible.
      try {
        await trayManager.setTitle(label);
      } catch (_) {}
    }
  }

  Future<void> _applyMenu() async {
    // Mode-aware labels/enablement (AC-14, P2). The action set is stable; we
    // only disable the action that is a no-op for the current mode. This menu is
    // rebuilt ONLY when its structure changes (init / `setMode`) — NEVER on the
    // per-tick status-line update — so the natively-displayed menu's item ids
    // stay in sync with `tray_manager`'s Dart-side id→item map and clicks fire
    // reliably on macOS (see `setStatusLine`). The live distance readout lives
    // in the tooltip, not as a churning menu item.
    final inCompact = _mode == WindowMode.compact;
    final items = <MenuItem>[
      MenuItem(key: _keyShowApp, label: 'Show app'),
      MenuItem(
        key: _keyEnterCompact,
        label: 'Enter compact / PiP',
        disabled: inCompact,
      ),
      MenuItem.separator(),
      MenuItem(key: _keyQuit, label: 'Quit'),
    ];
    try {
      await trayManager.setContextMenu(Menu(items: items));
    } catch (_) {
      // Menu set is best-effort during teardown.
    }
  }
}
