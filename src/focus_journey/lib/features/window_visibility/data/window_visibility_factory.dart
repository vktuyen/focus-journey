/// Data layer — DI seam selecting the [WindowVisibilityController]
/// implementation (real occlusion-backed channel vs deterministic mock).
///
/// Privacy: when the mock is selected the app never touches real OS window
/// occlusion APIs (mirrors `--mock-activity` / `--mock-window`).
library;

import '../domain/window_visibility_controller.dart';
import 'method_channel_window_visibility_controller.dart';
import 'mock_window_visibility_controller.dart';

/// Selects the per-surface window-visibility backend for the app.
///
/// With `--dart-define=mock-window=true` (the SAME flag the mini-window mock
/// uses — a mocked window has no real OS occlusion either) the deterministic
/// [MockWindowVisibilityController] is returned; otherwise the real
/// [MethodChannelWindowVisibilityController] is returned. Swapping real↔mock
/// requires no change to calling code: both satisfy [WindowVisibilityController].
/// Tests inject either directly without going through this factory.
abstract final class WindowVisibilityFactory {
  /// Compile-time flag read via `const bool.fromEnvironment`. Reuses the
  /// mini-window `mock-window` flag so the mocked-window dev/test path also gets
  /// the mocked visibility source (one switch for the whole window stack).
  static const bool useMock = bool.fromEnvironment('mock-window');

  /// Returns the configured backend.
  static WindowVisibilityController create() {
    if (useMock) {
      return MockWindowVisibilityController();
    }
    return MethodChannelWindowVisibilityController();
  }
}
