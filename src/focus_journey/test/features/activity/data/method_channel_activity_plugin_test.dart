// Deterministic unit tests for the typed-failure mapping of the real backend.
//
// Scope: AC-10 (graceful, typed failure when the native signal is
// unavailable/denied). Covers TC-016 (idle read) and TC-017 (lock read).
// Drives the MethodChannel via the test binary messenger so no real OS is
// touched — see tests/cases/activity-detection.md.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/method_channel_activity_plugin.dart';
import 'package:focus_journey/features/activity/domain/activity_plugin_exception.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(MethodChannelActivityPlugin.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late MethodChannelActivityPlugin plugin;

  setUp(() {
    plugin = MethodChannelActivityPlugin();
  });

  tearDown(() {
    // Always detach the handler so cases do not leak across tests.
    messenger.setMockMethodCallHandler(channel, null);
  });

  /// Installs a handler that responds to channel calls with [respond].
  void handleWith(Future<Object?>? Function(MethodCall call) respond) {
    messenger.setMockMethodCallHandler(channel, respond);
  }

  group('MethodChannelActivityPlugin happy path', () {
    test('getSystemIdleSeconds_nativeReturnsInt_returnsThatInt', () async {
      handleWith((call) async {
        expect(
          call.method,
          MethodChannelActivityPlugin.methodGetSystemIdleSeconds,
        );
        // Privacy: backend must send no arguments on the read.
        expect(call.arguments, isNull);
        return 17;
      });

      expect(await plugin.getSystemIdleSeconds(), 17);
    });

    test('isScreenLocked_nativeReturnsBool_returnsThatBool', () async {
      handleWith((call) async {
        expect(call.method, MethodChannelActivityPlugin.methodIsScreenLocked);
        expect(call.arguments, isNull);
        return true;
      });

      expect(await plugin.isScreenLocked(), isTrue);
    });
  });

  group('MethodChannelActivityPlugin typed failure', () {
    // TC-016: idle read with a PlatformException carrying a non-DENIED code
    // maps to ActivityPluginException(kind: unavailable).
    test(
      'getSystemIdleSeconds_platformExceptionUnavailableCode_throwsUnavailable',
      () async {
        handleWith((call) async {
          throw PlatformException(
            code: 'UNAVAILABLE',
            message: 'idle counter not available',
          );
        });

        await expectLater(
          plugin.getSystemIdleSeconds(),
          throwsA(
            isA<ActivityPluginException>().having(
              (e) => e.kind,
              'kind',
              ActivityPluginExceptionKind.unavailable,
            ),
          ),
        );
      },
    );

    // TC-016: idle read with the DENIED code maps to kind: denied, and the
    // original PlatformException is retained as the cause.
    test(
      'getSystemIdleSeconds_platformExceptionDeniedCode_throwsDenied',
      () async {
        handleWith((call) async {
          throw PlatformException(
            code: 'DENIED',
            message: 'permission refused',
          );
        });

        await expectLater(
          plugin.getSystemIdleSeconds(),
          throwsA(
            isA<ActivityPluginException>()
                .having(
                  (e) => e.kind,
                  'kind',
                  ActivityPluginExceptionKind.denied,
                )
                .having((e) => e.cause, 'cause', isA<PlatformException>()),
          ),
        );
      },
    );

    // TC-016: a missing native implementation maps to unavailable.
    test(
      'getSystemIdleSeconds_missingPluginException_throwsUnavailable',
      () async {
        // No handler installed → the channel reports MissingPluginException.
        messenger.setMockMethodCallHandler(channel, null);

        await expectLater(
          plugin.getSystemIdleSeconds(),
          throwsA(
            isA<ActivityPluginException>().having(
              (e) => e.kind,
              'kind',
              ActivityPluginExceptionKind.unavailable,
            ),
          ),
        );
      },
    );

    // TC-016: a null native result is treated as unavailable, never returned
    // as a silently-wrong value.
    test('getSystemIdleSeconds_nativeReturnsNull_throwsUnavailable', () async {
      handleWith((call) async => null);

      await expectLater(
        plugin.getSystemIdleSeconds(),
        throwsA(
          isA<ActivityPluginException>().having(
            (e) => e.kind,
            'kind',
            ActivityPluginExceptionKind.unavailable,
          ),
        ),
      );
    });

    // TC-017: lock read with a non-DENIED PlatformException maps to unavailable.
    test(
      'isScreenLocked_platformExceptionUnavailableCode_throwsUnavailable',
      () async {
        handleWith((call) async {
          throw PlatformException(
            code: 'UNAVAILABLE',
            message: 'no session api',
          );
        });

        await expectLater(
          plugin.isScreenLocked(),
          throwsA(
            isA<ActivityPluginException>().having(
              (e) => e.kind,
              'kind',
              ActivityPluginExceptionKind.unavailable,
            ),
          ),
        );
      },
    );

    // TC-017: lock read with the DENIED code maps to denied.
    test('isScreenLocked_platformExceptionDeniedCode_throwsDenied', () async {
      handleWith((call) async {
        throw PlatformException(code: 'DENIED', message: 'permission refused');
      });

      await expectLater(
        plugin.isScreenLocked(),
        throwsA(
          isA<ActivityPluginException>().having(
            (e) => e.kind,
            'kind',
            ActivityPluginExceptionKind.denied,
          ),
        ),
      );
    });

    // TC-017: missing native implementation for the lock read → unavailable.
    test('isScreenLocked_missingPluginException_throwsUnavailable', () async {
      messenger.setMockMethodCallHandler(channel, null);

      await expectLater(
        plugin.isScreenLocked(),
        throwsA(
          isA<ActivityPluginException>().having(
            (e) => e.kind,
            'kind',
            ActivityPluginExceptionKind.unavailable,
          ),
        ),
      );
    });

    // TC-017: a null native lock result is treated as unavailable.
    test('isScreenLocked_nativeReturnsNull_throwsUnavailable', () async {
      handleWith((call) async => null);

      await expectLater(
        plugin.isScreenLocked(),
        throwsA(
          isA<ActivityPluginException>().having(
            (e) => e.kind,
            'kind',
            ActivityPluginExceptionKind.unavailable,
          ),
        ),
      );
    });
  });

  group('MethodChannelActivityPlugin payload coercion (B2)', () {
    // TC-016: a double payload (e.g. codec deserialization yields 17.0) is
    // truncated to an int rather than escaping as a TypeError.
    test('getSystemIdleSeconds_nativeReturnsDouble_truncatesToInt', () async {
      handleWith((call) async => 17.0);

      expect(await plugin.getSystemIdleSeconds(), 17);
    });

    // TC-016: a String payload is non-numeric → unavailable, and crucially is
    // NOT a raw TypeError escaping the coercion.
    test(
      'getSystemIdleSeconds_nativeReturnsString_throwsUnavailableNotTypeError',
      () async {
        handleWith((call) async => 'oops');

        await expectLater(
          plugin.getSystemIdleSeconds(),
          throwsA(
            allOf(
              isA<ActivityPluginException>().having(
                (e) => e.kind,
                'kind',
                ActivityPluginExceptionKind.unavailable,
              ),
              isNot(isA<TypeError>()),
            ),
          ),
        );
      },
    );

    // TC-016: a bool payload is non-numeric for the idle reader → unavailable.
    test('getSystemIdleSeconds_nativeReturnsBool_throwsUnavailable', () async {
      handleWith((call) async => true);

      await expectLater(
        plugin.getSystemIdleSeconds(),
        throwsA(
          isA<ActivityPluginException>().having(
            (e) => e.kind,
            'kind',
            ActivityPluginExceptionKind.unavailable,
          ),
        ),
      );
    });

    // TC-017: an int payload for the lock reader is non-bool → unavailable,
    // never a raw TypeError.
    test(
      'isScreenLocked_nativeReturnsInt_throwsUnavailableNotTypeError',
      () async {
        handleWith((call) async => 1);

        await expectLater(
          plugin.isScreenLocked(),
          throwsA(
            allOf(
              isA<ActivityPluginException>().having(
                (e) => e.kind,
                'kind',
                ActivityPluginExceptionKind.unavailable,
              ),
              isNot(isA<TypeError>()),
            ),
          ),
        );
      },
    );

    // TC-017: a double payload for the lock reader is non-bool → unavailable.
    test('isScreenLocked_nativeReturnsDouble_throwsUnavailable', () async {
      handleWith((call) async => 17.0);

      await expectLater(
        plugin.isScreenLocked(),
        throwsA(
          isA<ActivityPluginException>().having(
            (e) => e.kind,
            'kind',
            ActivityPluginExceptionKind.unavailable,
          ),
        ),
      );
    });

    // TC-017: a String payload for the lock reader is non-bool → unavailable.
    test('isScreenLocked_nativeReturnsString_throwsUnavailable', () async {
      handleWith((call) async => 'locked');

      await expectLater(
        plugin.isScreenLocked(),
        throwsA(
          isA<ActivityPluginException>().having(
            (e) => e.kind,
            'kind',
            ActivityPluginExceptionKind.unavailable,
          ),
        ),
      );
    });
  });
}
