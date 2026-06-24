// Manual-testing dev-harness: logs successive REAL-backend readings on a timer.
//
// This is NOT a pass/fail assertion test — it is the logging harness the
// test-plan recommends (Risks §) so a human can drive OS state (lock/unlock,
// sleep/wake, leave-untouched) WITHOUT the foreground app occupying the screen,
// and read the captured idle/lock values from the test log afterwards.
//
// Use it to support the Manual checklist cases TC-001..TC-010:
//   - Start the harness, then perform the OS action (e.g. Ctrl-Cmd-Q to lock on
//     macOS, Win+L on Windows, leave untouched, or sleep the machine).
//   - Each sample line is timestamped: `t=<s>  idle=<n>s  locked=<bool>`.
//   - Read the log to confirm idle climbs / resets and lock tracks the state.
//
// Run (desktop only):
//   fvm flutter test integration_test/activity_logging_harness_test.dart -d macos
//   fvm flutter test integration_test/activity_logging_harness_test.dart -d windows
//
// Tune the window/interval with --dart-define:
//   --dart-define=harness-seconds=60   (total run length, default 30)
//   --dart-define=harness-interval=2   (seconds between samples, default 2)
//
// Off-desktop or with no native implementation, it skips with a clear message.

import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/method_channel_activity_plugin.dart';
import 'package:focus_journey/features/activity/domain/activity_plugin_exception.dart';
import 'package:integration_test/integration_test.dart';

const int _totalSeconds = int.fromEnvironment(
  'harness-seconds',
  defaultValue: 30,
);
const int _intervalSeconds = int.fromEnvironment(
  'harness-interval',
  defaultValue: 2,
);

bool get _isDesktop {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('logs idle + lock readings on a timer (manual harness)', (
    tester,
  ) async {
    if (!_isDesktop) {
      markTestSkipped(
        'Not a desktop target — logging harness requires `-d macos`/`-d windows`.',
      );
      return;
    }

    final plugin = MethodChannelActivityPlugin();

    // Availability probe — degrade to skip if no native handler.
    try {
      await plugin.getSystemIdleSeconds();
    } on ActivityPluginException catch (e) {
      if (e.kind == ActivityPluginExceptionKind.unavailable) {
        markTestSkipped(
          'Native ActivityPlugin channel unavailable on this build/device.',
        );
        return;
      }
      rethrow;
    } on MissingPluginException {
      markTestSkipped(
        'No native ActivityPlugin implementation on this device.',
      );
      return;
    }

    final samples = (_totalSeconds / _intervalSeconds).ceil();
    debugPrint(
      '[activity-harness] start: $samples samples, every '
      '${_intervalSeconds}s, for ~${_totalSeconds}s. Drive OS state now.',
    );

    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < samples; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(Duration(seconds: _intervalSeconds)),
      );
      final t = stopwatch.elapsed.inSeconds;
      int? idle;
      bool? locked;
      String? note;
      try {
        idle = await plugin.getSystemIdleSeconds();
      } on ActivityPluginException catch (e) {
        note = 'idle error: ${e.kind.name}';
      }
      try {
        locked = await plugin.isScreenLocked();
      } on ActivityPluginException catch (e) {
        note = '${note ?? ''} lock error: ${e.kind.name}';
      }
      debugPrint(
        '[activity-harness] t=${t}s  idle=${idle ?? '-'}s  '
        'locked=${locked ?? '-'}${note == null ? '' : '  ($note)'}',
      );
    }
    debugPrint('[activity-harness] done.');

    // This harness never fails on the readings themselves; reaching the end is
    // the only assertion (it ran without throwing). Interpretation is manual.
    expect(stopwatch.elapsed.inSeconds, greaterThanOrEqualTo(0));
  });
}
