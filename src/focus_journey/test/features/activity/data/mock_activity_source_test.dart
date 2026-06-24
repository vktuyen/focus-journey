// Deterministic unit tests for the caller-driven mock ActivityPlugin source.
//
// Scope: AC-6 (mock injectable + deterministic). Covers TC-012 (idle seconds),
// TC-013 (lock state), plus determinism/independence/no-real-time assertions.
// No real timers, no real waits, no real OS — see tests/cases/activity-detection.md.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/mock_activity_source.dart';
import 'package:focus_journey/features/activity/domain/activity_plugin.dart';
import 'package:focus_journey/features/activity/domain/activity_plugin_exception.dart';

void main() {
  group('MockActivitySource', () {
    // TC-012: mock returns exactly the caller-driven idle seconds.
    test(
      'getSystemIdleSeconds_callerSetsValues_returnsExactlyThoseValues',
      () async {
        final source = MockActivitySource();

        source.idleSeconds = 0;
        expect(await source.getSystemIdleSeconds(), 0);

        source.idleSeconds = 42;
        expect(await source.getSystemIdleSeconds(), 42);

        source.idleSeconds = 9000;
        expect(await source.getSystemIdleSeconds(), 9000);
      },
    );

    // TC-013: mock returns exactly the caller-driven lock state.
    test('isScreenLocked_callerSetsValues_returnsExactlyThoseValues', () async {
      final source = MockActivitySource();

      source.screenLocked = true;
      expect(await source.isScreenLocked(), isTrue);

      source.screenLocked = false;
      expect(await source.isScreenLocked(), isFalse);
    });

    // TC-012/TC-013: constructor seed values are honoured.
    test('constructor_withSeedValues_returnsSeededValues', () async {
      final source = MockActivitySource(idleSeconds: 123, screenLocked: true);

      expect(await source.getSystemIdleSeconds(), 123);
      expect(await source.isScreenLocked(), isTrue);
    });

    // AC-6: idle and lock are independently settable — changing one does not
    // perturb the other.
    test(
      'setters_idleAndLockAreIndependent_eachReflectsOnlyItsOwnValue',
      () async {
        final source = MockActivitySource();

        source.idleSeconds = 77;
        source.screenLocked = true;

        expect(await source.getSystemIdleSeconds(), 77);
        expect(await source.isScreenLocked(), isTrue);

        // Mutate only the lock; idle must be untouched.
        source.screenLocked = false;
        expect(await source.getSystemIdleSeconds(), 77);
        expect(await source.isScreenLocked(), isFalse);

        // Mutate only idle; lock must be untouched.
        source.idleSeconds = 5;
        expect(await source.getSystemIdleSeconds(), 5);
        expect(await source.isScreenLocked(), isFalse);
      },
    );

    // TC-012/TC-013: repeated reads with no setter change are stable and equal
    // — proving no real time passes (no internal idle counter ticking).
    test('repeatedReads_withNoSetterChange_areStableAndEqual', () async {
      final source = MockActivitySource(idleSeconds: 30, screenLocked: true);

      final firstIdle = await source.getSystemIdleSeconds();
      final secondIdle = await source.getSystemIdleSeconds();
      final firstLock = await source.isScreenLocked();
      final secondLock = await source.isScreenLocked();

      expect(secondIdle, firstIdle);
      expect(secondIdle, 30);
      expect(secondLock, firstLock);
      expect(secondLock, isTrue);
    });

    // AC-6: queued idle error surfaces as a Future error and persists across
    // reads until cleared.
    test('idleError_whenQueued_surfacesThenClearsWhenReset', () async {
      final source = MockActivitySource(idleSeconds: 10);

      source.idleError = const ActivityPluginException.unavailable();
      await expectLater(
        source.getSystemIdleSeconds(),
        throwsA(isA<ActivityPluginException>()),
      );
      // Persists on subsequent calls.
      await expectLater(
        source.getSystemIdleSeconds(),
        throwsA(isA<ActivityPluginException>()),
      );

      // Clearing restores the driven value.
      source.idleError = null;
      expect(await source.getSystemIdleSeconds(), 10);
    });

    // AC-6: queued lock error surfaces independently of the idle path.
    test('lockError_whenQueued_failsLockButNotIdle', () async {
      final source = MockActivitySource(idleSeconds: 8, screenLocked: false);

      source.lockError = const ActivityPluginException.denied();

      await expectLater(
        source.isScreenLocked(),
        throwsA(isA<ActivityPluginException>()),
      );
      // Idle path is unaffected by the lock error.
      expect(await source.getSystemIdleSeconds(), 8);

      source.lockError = null;
      expect(await source.isScreenLocked(), isFalse);
    });

    // TC-014 (DI shape, Dart half): the mock IS an ActivityPlugin, so it is a
    // type-compatible swap-in for any consumer depending on the interface.
    test('typeShape_isActivityPlugin_swapInForInterface', () {
      final ActivityPlugin plugin = MockActivitySource();
      expect(plugin, isA<ActivityPlugin>());
    });
  });
}
