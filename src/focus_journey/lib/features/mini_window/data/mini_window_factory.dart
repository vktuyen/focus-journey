/// Data layer — DI seam selecting the [WindowModeController] + [TrayController]
/// implementations (real `window_manager`/`tray_manager` vs deterministic mock).
///
/// Privacy: when the mock is selected the app never touches a real OS window or
/// tray (mirrors `--mock-activity`).
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/hide_to_tray_hint_repository.dart';
import '../domain/tray_controller.dart';
import '../domain/window_mode_controller.dart';
import 'mock_tray_controller.dart';
import 'mock_window_mode_controller.dart';
import 'shared_preferences_compact_window_position_repository.dart';
import 'shared_preferences_hide_to_tray_hint_repository.dart';
import 'tray_manager_tray_controller.dart';
import 'window_manager_mode_controller.dart';

/// Selects the mini-window native backends for the app.
///
/// With `--dart-define=mock-window=true` the deterministic
/// [MockWindowModeController] / [MockTrayController] are returned; otherwise the
/// real `window_manager` / `tray_manager` backends are returned. Swapping
/// real↔mock requires no change to calling code (NFR-8): both satisfy the same
/// [WindowModeController] / [TrayController] interfaces. Tests inject either
/// directly without going through this factory.
///
/// Selection mechanism (analogous to `--mock-activity`):
/// ```
/// fvm flutter run -d macos   --dart-define=mock-window=true
/// fvm flutter test integration_test/ -d macos --dart-define=mock-window=true
/// ```
abstract final class MiniWindowFactory {
  /// Compile-time flag read via `const bool.fromEnvironment`. Pass it with
  /// `--dart-define=mock-window=true`.
  static const bool useMock = bool.fromEnvironment('mock-window');

  /// Returns the configured [WindowModeController]. [prefs] backs the real
  /// position persistence (and, when [seedPosition] tests want it, the mock's).
  static WindowModeController createWindowModeController(
    SharedPreferences prefs,
  ) {
    final repository = SharedPreferencesCompactWindowPositionRepository(prefs);
    if (useMock) {
      return MockWindowModeController(positionRepository: repository);
    }
    return WindowManagerModeController(positionRepository: repository);
  }

  /// Returns the configured [TrayController].
  static TrayController createTrayController() {
    if (useMock) {
      return MockTrayController();
    }
    return TrayManagerTrayController();
  }

  /// Returns the one-time hide-to-tray hint persistence seam (AC-17), backed by
  /// the same [prefs] used elsewhere (no new store type — the v1 approach).
  static HideToTrayHintRepository createHideToTrayHintRepository(
    SharedPreferences prefs,
  ) {
    return SharedPreferencesHideToTrayHintRepository(prefs);
  }
}
