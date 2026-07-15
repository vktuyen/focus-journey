// Deterministic unit tests for FactoryResetCubit.confirmReset — the post-confirm
// Factory-reset action (journey-reset AC-4, TC-706 ordering side).
//
// Scope: the correctness-critical ORDERING (quiesce -> clear -> re-initialise)
// and the state transitions. A shared call-order recorder captures the sequence
// across the injected onQuiesce/onReinitialise seams and the seam's store
// clear(), so we prove NOTHING clears before the live graph is quiesced (which
// is what prevents a stale autosave re-persisting a phantom journey). No timers,
// no clock, no I/O — all seams are injected fakes.
//
// Conventions mirror test/features/journey/presentation/journey_cubit_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/reset/domain/local_data_reset_service.dart';
import 'package:focus_journey/features/reset/domain/local_data_store.dart';
import 'package:focus_journey/features/reset/presentation/factory_reset_cubit.dart';

/// A store whose clear() appends to a shared ordered [log], so the seam's wipe
/// step is visible in the same timeline as quiesce / re-init.
class RecordingStore implements LocalDataStore {
  RecordingStore(this.log, this.label);

  final List<String> log;
  final String label;

  @override
  Set<String> get ownedKeys => <String>{label};

  @override
  Future<void> clear() async {
    log.add('clear:$label');
  }
}

/// A store whose clear() throws — used to prove a wipe failure does NOT wedge
/// the app: re-init must still run and the cubit must land in `failed`.
class ThrowingStore implements LocalDataStore {
  ThrowingStore(this.log, this.label);

  final List<String> log;
  final String label;

  @override
  Set<String> get ownedKeys => <String>{label};

  @override
  Future<void> clear() async {
    log.add('clear-attempt:$label');
    throw StateError('clear failed: $label');
  }
}

void main() {
  group('FactoryResetCubit.confirmReset — ordering (TC-706, AC-4)', () {
    test('callsQuiesceThenClearThenReinitialise_inThatOrder', () async {
      final log = <String>[];
      final service = LocalDataResetService(<LocalDataStore>[
        RecordingStore(log, 'store_a'),
        RecordingStore(log, 'store_b'),
      ]);
      final cubit = FactoryResetCubit(
        service: service,
        onQuiesce: () async => log.add('quiesce'),
        onReinitialise: () async => log.add('reinit'),
      );

      await cubit.confirmReset();

      expect(log, <String>[
        'quiesce',
        'clear:store_a',
        'clear:store_b',
        'reinit',
      ]);
      await cubit.close();
    });

    test('nothingClearsBeforeQuiesce', () async {
      final log = <String>[];
      final service = LocalDataResetService(<LocalDataStore>[
        RecordingStore(log, 'store_a'),
      ]);
      final cubit = FactoryResetCubit(
        service: service,
        onQuiesce: () async => log.add('quiesce'),
        onReinitialise: () async => log.add('reinit'),
      );

      await cubit.confirmReset();

      final quiesceIndex = log.indexOf('quiesce');
      final firstClearIndex = log.indexWhere((e) => e.startsWith('clear:'));
      expect(quiesceIndex, greaterThanOrEqualTo(0));
      expect(firstClearIndex, greaterThan(quiesceIndex));
      await cubit.close();
    });

    test('reinitialiseRunsOnlyAfterEveryClearCompletes', () async {
      final log = <String>[];
      final service = LocalDataResetService(<LocalDataStore>[
        RecordingStore(log, 'store_a'),
        RecordingStore(log, 'store_b'),
      ]);
      final cubit = FactoryResetCubit(
        service: service,
        onQuiesce: () async => log.add('quiesce'),
        onReinitialise: () async => log.add('reinit'),
      );

      await cubit.confirmReset();

      final reinitIndex = log.indexOf('reinit');
      final lastClearIndex = log.lastIndexWhere((e) => e.startsWith('clear:'));
      expect(reinitIndex, greaterThan(lastClearIndex));
      await cubit.close();
    });
  });

  group('FactoryResetCubit.confirmReset — status transitions', () {
    test('emitsResettingThenIdle', () async {
      final service = LocalDataResetService(<LocalDataStore>[]);
      final emitted = <FactoryResetStatus>[];
      final cubit = FactoryResetCubit(
        service: service,
        onQuiesce: () async {},
        onReinitialise: () async {},
      );
      cubit.stream.listen(emitted.add);

      expect(cubit.state, FactoryResetStatus.idle);
      await cubit.confirmReset();
      // Let the broadcast stream deliver the trailing idle event.
      await Future<void>.delayed(Duration.zero);

      expect(emitted, <FactoryResetStatus>[
        FactoryResetStatus.resetting,
        FactoryResetStatus.idle,
      ]);
      expect(cubit.state, FactoryResetStatus.idle);
      await cubit.close();
    });
  });

  group('FactoryResetCubit.confirmReset — wipe failure never wedges the app', () {
    test(
      'onClearThrow_reinitStillRuns_andStateIsFailed_notStuckOnResetting',
      () async {
        // The store's clear() throws (e.g. a platform-channel failure) — the
        // exact case that previously left re-init un-run and froze the splash.
        final log = <String>[];
        final service = LocalDataResetService(<LocalDataStore>[
          ThrowingStore(log, 'boom'),
        ]);
        final cubit = FactoryResetCubit(
          service: service,
          onQuiesce: () async => log.add('quiesce'),
          onReinitialise: () async => log.add('reinit'),
        );
        final emitted = <FactoryResetStatus>[];
        cubit.stream.listen(emitted.add);

        // confirmReset must NOT rethrow — it isolates the failure internally.
        await cubit.confirmReset();
        await Future<void>.delayed(Duration.zero);

        // Re-init RAN despite the wipe throwing (app not wedged), and it ran
        // after the (failed) clear attempt, preserving the ordering contract.
        expect(log, containsAllInOrder(<String>['quiesce', 'reinit']));
        expect(log, contains('clear-attempt:boom'));

        // The cubit surfaces a terminal failure (never stuck on resetting).
        expect(emitted, <FactoryResetStatus>[
          FactoryResetStatus.resetting,
          FactoryResetStatus.failed,
        ]);
        expect(cubit.state, FactoryResetStatus.failed);
        await cubit.close();
      },
    );

    test('onReinitThrow_doesNotWedge_reinitAttemptedInFinally', () async {
      // Even if re-init itself throws, confirmReset must not hang; the finally
      // still attempted it and the failure is surfaced.
      final service = LocalDataResetService(<LocalDataStore>[]);
      final cubit = FactoryResetCubit(
        service: service,
        onQuiesce: () async {},
        onReinitialise: () async => throw StateError('reinit failed'),
      );

      await expectLater(cubit.confirmReset(), completes);
      await cubit.close();
    });
  });
}
