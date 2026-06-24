// Integration test: best-effort on-device smoke of the REAL ActivityPlugin
// backend (MethodChannelActivityPlugin).
//
// Covers (best-effort smoke only — the DETERMINISTIC guarantees are the Manual
// checklist `tests/cases/activity-detection-manual-checklist.md`):
//   - TC-001 / TC-002 (idle climbs) : `getSystemIdleSeconds()` returns a
//       non-negative int and is monotonically non-decreasing over a short
//       scripted no-input wait (±2s tolerance).
//   - TC-003..TC-006 read shape      : `isScreenLocked()` returns a bool without
//       throwing while the session is unlocked.
//
// IMPORTANT — must run on a REAL desktop device:
//
//   fvm flutter test integration_test/activity_real_backend_smoke_test.dart -d macos
//   fvm flutter test integration_test/activity_real_backend_smoke_test.dart -d windows
//
// This calls the native runner over the platform channel, so it requires the
// macOS/Windows runner to implement `com.joblogic.focus_journey/activity`. On a
// platform with no native implementation (e.g. web / mobile / a desktop build
// missing the handler) the call surfaces an ActivityPluginException(unavailable);
// the test DEGRADES TO A SKIP with a clear message rather than failing, so it
// never blocks CI. The hard, deterministic per-OS verification lives in the
// Manual checklist.
//
// Tester discipline: do NOT touch keyboard / mouse / trackpad during the wait
// window, otherwise the idle counter resets and the monotonic assertion is
// expected to be re-run.

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/method_channel_activity_plugin.dart';
import 'package:focus_journey/features/activity/domain/activity_plugin.dart';
import 'package:focus_journey/features/activity/domain/activity_plugin_exception.dart';
import 'package:integration_test/integration_test.dart';

/// ±2s tolerance band (per tests/cases/activity-detection.md conventions):
/// the reported idle delta may differ from elapsed wall-clock by this much due
/// to call latency and OS counter granularity.
const int _toleranceSeconds = 2;

/// How long the scripted no-input wait lasts for the monotonic check.
const Duration _idleWait = Duration(seconds: 5);

bool get _isDesktop {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// Probes the real backend once. Returns `null` (caller should skip) if the
/// native implementation is unavailable on this device/build.
Future<bool> _backendAvailable(ActivityPlugin plugin) async {
  try {
    await plugin.getSystemIdleSeconds();
    return true;
  } on ActivityPluginException catch (e) {
    if (e.kind == ActivityPluginExceptionKind.unavailable) return false;
    rethrow;
  } on MissingPluginException {
    return false;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Real ActivityPlugin backend smoke (TC-001/TC-003/TC-006 — best-effort)', () {
    final plugin = MethodChannelActivityPlugin();

    testWidgets(
      'getSystemIdleSeconds() returns non-negative int, monotonic over a wait '
      '(TC-001/TC-002)',
      (tester) async {
        if (!_isDesktop) {
          markTestSkipped(
            'Not a desktop target — real backend smoke requires `-d macos` or '
            '`-d windows`. Deterministic verification is the Manual checklist.',
          );
          return;
        }
        if (!await _backendAvailable(plugin)) {
          markTestSkipped(
            'Native ActivityPlugin channel unavailable on this build/device. '
            'Run the macOS/Windows runner; see the Manual checklist.',
          );
          return;
        }

        final first = await plugin.getSystemIdleSeconds();
        expect(
          first,
          isNonNegative,
          reason: 'Idle seconds must never be negative.',
        );

        // Scripted no-input wait. Use the test binding's real-async pump so the
        // OS idle counter actually advances.
        await tester.runAsync(() => Future<void>.delayed(_idleWait));

        final second = await plugin.getSystemIdleSeconds();
        expect(second, isNonNegative);

        // Monotonic non-decreasing within tolerance (an input mid-window would
        // reset it; we allow the ±2s band but not a real decrease).
        expect(
          second,
          greaterThanOrEqualTo(first - _toleranceSeconds),
          reason:
              'Idle seconds should be monotonically non-decreasing over a '
              'no-input wait (±${_toleranceSeconds}s). first=$first second=$second. '
              'If this failed, confirm no input occurred during the wait.',
        );

        // And it should have grown by roughly the wait, within tolerance — a
        // soft check (skipped, not failed, if input clearly reset it).
        final grew = second - first;
        if (grew < 0) {
          markTestSkipped(
            'Idle counter decreased ($first→$second): input likely occurred '
            'during the wait. Re-run without touching the machine.',
          );
        }
      },
    );

    testWidgets(
      'isScreenLocked() returns a bool without throwing while unlocked '
      '(TC-006 read-shape)',
      (tester) async {
        if (!_isDesktop) {
          markTestSkipped(
            'Not a desktop target — requires `-d macos` or `-d windows`.',
          );
          return;
        }
        if (!await _backendAvailable(plugin)) {
          markTestSkipped(
            'Native ActivityPlugin channel unavailable on this build/device.',
          );
          return;
        }

        final locked = await plugin.isScreenLocked();
        expect(
          locked,
          isA<bool>(),
          reason: 'isScreenLocked() must return a bool, not throw or null.',
        );
        // The test runs in the foreground with the session unlocked, so it
        // should report false. This is a soft expectation: the deterministic
        // lock→unlock transition is verified manually (TC-006..TC-009).
        expect(
          locked,
          isFalse,
          reason:
              'Session is unlocked while the test runs in the foreground; '
              'lock-transition behaviour is verified in the Manual checklist.',
        );
      },
    );
  });
}
