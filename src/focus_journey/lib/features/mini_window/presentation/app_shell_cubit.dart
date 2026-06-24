/// Presentation layer. The Cubit that owns the app's WINDOW MODE (full ⇄
/// compact PiP) for the single-window two-mode shell (ADR-0003 / AC-6).
///
/// SEPARATION INVARIANT (AC-9/AC-10): this Cubit holds ONLY the [WindowMode]
/// (a window *shape*, not journey state) and a one-time first-run hide-to-tray
/// hint flag (AC-17). It drives the journey scene NOT AT ALL — it never reads
/// `ActivityPlugin`, never accrues distance, never decides active-vs-idle.
///
/// It is the single seam between the mode UI and the pure-Dart
/// [WindowModeController] (no `window_manager`/`tray_manager` import leaks into
/// presentation): it subscribes to `controller.modeChanges` to mirror the real
/// window state, and calls `enterCompact()` / `showApp()` to drive it. Mutual
/// exclusion of full vs compact is structural — there is one window — so this
/// cubit just reflects whichever single mode the controller reports.
library;

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/window_mode.dart';
import '../domain/window_mode_controller.dart';

/// The immutable shell state: the current window [mode] and whether the
/// one-time hide-to-tray hint should currently be shown (AC-17).
class AppShellState {
  /// Creates a shell state.
  const AppShellState({required this.mode, this.showHideToTrayHint = false});

  /// The current window mode (full or compact). Mirrors the controller.
  final WindowMode mode;

  /// Whether the one-time "still running in the tray" hint should be shown now.
  /// Set once on the FIRST close-to-tray, cleared after the user dismisses it.
  final bool showHideToTrayHint;

  /// Returns a copy with selected fields overridden.
  AppShellState copyWith({WindowMode? mode, bool? showHideToTrayHint}) {
    return AppShellState(
      mode: mode ?? this.mode,
      showHideToTrayHint: showHideToTrayHint ?? this.showHideToTrayHint,
    );
  }
}

/// Owns the window mode and the first-run hide-to-tray hint. Pure presentation
/// glue over [WindowModeController]; constructs no second engine/ticker/scene.
class AppShellCubit extends Cubit<AppShellState> {
  /// Creates the cubit bound to [controller]. [hintAlreadyShown] seeds the
  /// AC-17 one-time hint from persistence (true → never show it again).
  AppShellCubit({
    required WindowModeController controller,
    bool hintAlreadyShown = false,
  }) : _controller = controller,
       _hintAlreadyShown = hintAlreadyShown,
       super(AppShellState(mode: controller.mode)) {
    _modeSub = _controller.modeChanges.listen((WindowMode mode) {
      emit(state.copyWith(mode: mode));
    });
  }

  final WindowModeController _controller;
  late final StreamSubscription<WindowMode> _modeSub;
  bool _hintAlreadyShown;

  /// Enters the compact PiP (AC-6): the controller resizes + makes the single
  /// window frameless/always-on-top and hides the main window to the dock. The
  /// mode is then reflected via the controller's `modeChanges` stream.
  Future<void> enterCompact() => _controller.enterCompact();

  /// Returns to / shows the full main window (AC-6/AC-12 "Show app"),
  /// dismissing the PiP if it was active (mutually exclusive — one window).
  Future<void> showApp() => _controller.showApp();

  /// Records that the main window was just closed-to-tray. On the FIRST close
  /// only (per persisted [hintAlreadyShown]) this surfaces the one-time hint
  /// (AC-17). Returns `true` iff the hint should now be persisted as shown.
  bool onHiddenToTray() {
    if (_hintAlreadyShown) {
      return false;
    }
    _hintAlreadyShown = true;
    emit(state.copyWith(showHideToTrayHint: true));
    return true;
  }

  /// Dismisses the one-time hide-to-tray hint after the user has seen it.
  void dismissHideToTrayHint() {
    if (state.showHideToTrayHint) {
      emit(state.copyWith(showHideToTrayHint: false));
    }
  }

  @override
  Future<void> close() async {
    await _modeSub.cancel();
    return super.close();
  }
}
