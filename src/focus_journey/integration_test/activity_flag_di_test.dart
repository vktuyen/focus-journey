// Integration test: --mock-activity flag → DI wiring (TC-014 real-backend half / TC-015).
//
// This asserts which concrete ActivityPlugin implementation
// `ActivityPluginFactory.create()` resolves to, depending on the compile-time
// `--dart-define=mock-activity=...` flag. It is a *build-time wiring* assertion:
// it checks the SELECTED TYPE only and never calls the real native backend
// (which would talk to the OS and could hang/error off-device).
//
// Covers:
//   - TC-015 : with the flag ON, the factory binds the deterministic mock
//              (MockActivitySource) — the app never touches real OS APIs.
//   - TC-014 : the real-backend half of the injection seam — with the flag OFF
//              (default), the factory binds the real MethodChannelActivityPlugin.
//              Both branches satisfy the same ActivityPlugin interface, proving
//              the swap requires no calling-code change.
//
// Because the flag is a COMPILE-TIME constant (`const bool.fromEnvironment`),
// the value of `ActivityPluginFactory.useMock` is fixed at build time. A single
// run can therefore only see one branch. The test reads `useMock` and asserts
// the matching binding, so it is correct under EITHER invocation:
//
//   # TC-015 — flag ON: expect MockActivitySource
//   fvm flutter test integration_test/activity_flag_di_test.dart -d macos \
//       --dart-define=mock-activity=true
//
//   # TC-014 (real-backend half) — flag OFF (default): expect MethodChannelActivityPlugin
//   fvm flutter test integration_test/activity_flag_di_test.dart -d macos
//
// On Windows, swap `-d macos` for `-d windows`. To exercise BOTH branches for a
// full pass, run the command twice (once with, once without the flag).

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/activity_plugin_factory.dart';
import 'package:focus_journey/features/activity/data/method_channel_activity_plugin.dart';
import 'package:focus_journey/features/activity/data/mock_activity_source.dart';
import 'package:focus_journey/features/activity/domain/activity_plugin.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ActivityPluginFactory flag → DI wiring (TC-014 / TC-015)', () {
    // The factory's resolution must always match the compile-time flag.
    test('create() resolves the implementation selected by --mock-activity', () {
      final plugin = ActivityPluginFactory.create();

      // Whichever branch is built, the result is always the shared interface
      // type — proving callers depend only on ActivityPlugin (AC-6 / TC-014).
      expect(
        plugin,
        isA<ActivityPlugin>(),
        reason: 'Both branches must satisfy the ActivityPlugin contract.',
      );

      if (ActivityPluginFactory.useMock) {
        // TC-015: flag ON → deterministic mock, never the native backend.
        expect(
          plugin,
          isA<MockActivitySource>(),
          reason:
              'With --dart-define=mock-activity=true the factory must bind the '
              'deterministic MockActivitySource (TC-015).',
        );
        expect(
          plugin,
          isNot(isA<MethodChannelActivityPlugin>()),
          reason: 'The mock flag must NOT bind the real native backend.',
        );
      } else {
        // TC-014 (real-backend half): flag OFF → real MethodChannel backend.
        // Asserted by TYPE only; the real backend is intentionally not called
        // here (it would talk to the OS / could hang off a real desktop).
        expect(
          plugin,
          isA<MethodChannelActivityPlugin>(),
          reason:
              'Without the mock flag the factory must bind the real '
              'MethodChannelActivityPlugin (TC-014 real-backend half).',
        );
        expect(
          plugin,
          isNot(isA<MockActivitySource>()),
          reason: 'The default build must NOT bind the deterministic mock.',
        );
      }
    });

    // TC-015: an explicit mock seed is honoured when the flag is on; when the
    // flag is off the seed is ignored and the real backend is still returned.
    test('create(mockSeed:) is honoured only when the flag is on', () {
      final seed = MockActivitySource(idleSeconds: 4242);
      final plugin = ActivityPluginFactory.create(mockSeed: seed);

      if (ActivityPluginFactory.useMock) {
        expect(
          identical(plugin, seed),
          isTrue,
          reason: 'With the flag on, the provided mock seed must be returned.',
        );
      } else {
        expect(
          plugin,
          isA<MethodChannelActivityPlugin>(),
          reason: 'With the flag off, a mock seed must be ignored.',
        );
      }
    });
  });
}
