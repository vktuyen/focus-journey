/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'tray_state.dart';
import 'window_mode.dart';

/// The domain contract for the always-present menu-bar / system-tray icon
/// (AC-11/12/13/14). The UI/Bloc layer calls this and listens to [actions]; it
/// never touches `tray_manager` directly. A real `tray_manager`-backed impl and
/// a deterministic mock are interchangeable behind this interface (NFR-7/8).
///
/// ## Privacy (headline, P0 — NFR-4/5)
/// Implementations touch ONLY a status icon, its tooltip, and a context menu.
/// They read NO user data of any kind. The icon art comes from bundled app
/// assets; a missing asset degrades to tooltip-only (graceful).
abstract interface class TrayController {
  /// Initialises the tray with a STATIC icon for [initialState] and the context
  /// menu (Show app · Enter compact / PiP · Quit). Call once at startup. If the
  /// icon asset is missing, falls back to a tooltip-only presence (graceful).
  Future<void> init({
    TrayActivityState initialState = TrayActivityState.paused,
    WindowMode initialMode = WindowMode.full,
  });

  /// Updates the tray to reflect the current journey state (AC-11): swaps to the
  /// state's static icon variant and/or updates the tooltip so an observer can
  /// distinguish active from idle/paused from the tray surface alone.
  Future<void> setState(TrayActivityState state);

  /// Updates the menu so its items reflect the current window mode (AC-14, P2):
  /// e.g. "Enter compact / PiP" while [WindowMode.full], "Show app" emphasised
  /// while [WindowMode.compact]. The action set is stable; this only adjusts
  /// labels/enablement for clarity.
  Future<void> setMode(WindowMode mode);

  /// Optional status line reflecting journey state (AC-13, P1) — e.g.
  /// "Travelling — 1,240 km". Folded into the tooltip and/or a disabled menu
  /// header. A `null` clears it. In scope only if cheap; the icon/tooltip
  /// state-reflection (AC-11) holds regardless.
  Future<void> setStatusLine(String? statusLine);

  /// Stream of menu actions the user invoked (AC-12). The app-dev subscribes and
  /// maps each [TrayAction] to a `WindowModeController` call — the tray contains
  /// no app/window logic itself.
  Stream<TrayAction> get actions;

  /// Tears down the tray icon and releases listeners (called on Quit / dispose).
  Future<void> dispose();
}
