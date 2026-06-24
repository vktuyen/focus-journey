// Implementation-independence contract tests (AC-11, secondary unit / TC-011).
//
// A single shared test body asserts the observable ActivityPlugin contract and
// is parametrized over each implementation. Both the deterministic mock and the
// MethodChannel-backed real backend (driven via the test binary messenger, no
// real OS) must satisfy the same assertions — proving the contract does not
// depend on which implementation was chosen.
//
// Note: the real-OS behaviours (idle climbs / resets, live lock transitions —
// TC-001..TC-010) cannot run as deterministic Dart unit tests; those are left
// to the test-script-author's per-OS integration/manual checklist. Here we
// exercise only the parts of the contract that are observable without a real
// platform: a value read returns the configured value, and an unavailable
// signal surfaces a typed ActivityPluginException.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/method_channel_activity_plugin.dart';
import 'package:focus_journey/features/activity/data/mock_activity_source.dart';
import 'package:focus_journey/features/activity/domain/activity_plugin.dart';
import 'package:focus_journey/features/activity/domain/activity_plugin_exception.dart';

/// A way to build an [ActivityPlugin] under test plus drive its underlying
/// signal, so the shared contract body is implementation-agnostic.
class _Harness {
  _Harness({
    required this.name,
    required this.build,
    required this.driveValues,
    required this.driveUnavailable,
    required this.dispose,
  });

  /// Human-readable implementation label for the test group name.
  final String name;

  /// Returns the plugin under test (a fresh instance per case).
  final ActivityPlugin Function() build;

  /// Makes the plugin report [idleSeconds] / [locked] on the next reads.
  final void Function(int idleSeconds, bool locked) driveValues;

  /// Makes the plugin's next reads fail as if the OS signal were unavailable.
  final void Function() driveUnavailable;

  /// Tears down any installed test doubles.
  final void Function() dispose;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(MethodChannelActivityPlugin.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // Shared state for the MethodChannel harness so driveValues/driveUnavailable
  // can reconfigure responses between calls within one case.
  int channelIdle = 0;
  bool channelLocked = false;
  bool channelUnavailable = false;

  final harnesses = <_Harness>[];

  // --- Mock harness (captures the instance it created so setters can drive it) ---
  MockActivitySource? mock;
  harnesses.add(
    _Harness(
      name: 'MockActivitySource',
      build: () => mock = MockActivitySource(),
      driveValues: (idle, locked) {
        mock!
          ..idleSeconds = idle
          ..idleError = null
          ..screenLocked = locked
          ..lockError = null;
      },
      driveUnavailable: () {
        mock!
          ..idleError = const ActivityPluginException.unavailable()
          ..lockError = const ActivityPluginException.unavailable();
      },
      dispose: () => mock = null,
    ),
  );

  // --- MethodChannel harness (real backend, faked transport) ---
  harnesses.add(
    _Harness(
      name: 'MethodChannelActivityPlugin',
      build: () {
        channelIdle = 0;
        channelLocked = false;
        channelUnavailable = false;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (channelUnavailable) {
            throw PlatformException(code: 'UNAVAILABLE', message: 'no signal');
          }
          switch (call.method) {
            case MethodChannelActivityPlugin.methodGetSystemIdleSeconds:
              return channelIdle;
            case MethodChannelActivityPlugin.methodIsScreenLocked:
              return channelLocked;
          }
          return null;
        });
        return MethodChannelActivityPlugin();
      },
      driveValues: (idle, locked) {
        channelUnavailable = false;
        channelIdle = idle;
        channelLocked = locked;
      },
      driveUnavailable: () => channelUnavailable = true,
      dispose: () => messenger.setMockMethodCallHandler(channel, null),
    ),
  );

  for (final h in harnesses) {
    group('ActivityPlugin contract — ${h.name}', () {
      tearDown(h.dispose);

      // AC-11: a configured read returns exactly the configured signal.
      test('reads_returnDrivenValues', () async {
        final plugin = h.build();
        h.driveValues(55, true);

        expect(await plugin.getSystemIdleSeconds(), 55);
        expect(await plugin.isScreenLocked(), isTrue);
      });

      // AC-11 / AC-10: an unavailable signal surfaces a typed
      // ActivityPluginException from both methods, regardless of implementation.
      test('unavailableSignal_surfacesTypedException', () async {
        final plugin = h.build();
        h.driveUnavailable();

        await expectLater(
          plugin.getSystemIdleSeconds(),
          throwsA(isA<ActivityPluginException>()),
        );
        await expectLater(
          plugin.isScreenLocked(),
          throwsA(isA<ActivityPluginException>()),
        );
      });

      // AC-11: the surface is the interface — every implementation is an
      // ActivityPlugin, so callers depend only on the contract.
      test('isA_ActivityPlugin', () {
        expect(h.build(), isA<ActivityPlugin>());
      });
    });
  }
}
