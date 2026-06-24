/// Data layer — DI seam selecting the [ActivityPlugin] implementation.
///
/// Privacy: when the mock is selected the app never touches real OS idle/lock
/// APIs (TC-015).
library;

import '../domain/activity_plugin.dart';
import 'method_channel_activity_plugin.dart';
import 'mock_activity_source.dart';

/// Selects the [ActivityPlugin] backend for the app.
///
/// With `--dart-define=mock-activity=true` the deterministic [MockActivitySource]
/// is returned; otherwise the real [MethodChannelActivityPlugin] is returned.
/// Swapping real↔mock requires no change to calling code (AC-6 / TC-014): both
/// satisfy the same [ActivityPlugin] interface. Tests inject either directly
/// without going through this factory.
abstract final class ActivityPluginFactory {
  /// Compile-time flag read via `const bool.fromEnvironment`. Pass it with
  /// `--dart-define=mock-activity=true` (see `lib/features/activity/README.md`).
  static const bool useMock = bool.fromEnvironment('mock-activity');

  /// Returns the configured backend. Provide [mockSeed] to start the mock with
  /// specific values when the flag is on.
  static ActivityPlugin create({MockActivitySource? mockSeed}) {
    if (useMock) {
      return mockSeed ?? MockActivitySource();
    }
    return MethodChannelActivityPlugin();
  }
}
