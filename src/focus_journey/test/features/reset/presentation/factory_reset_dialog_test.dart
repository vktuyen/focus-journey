// Widget tests for the destructive Factory-reset confirmation (journey-reset).
//
// Drives the REAL FactoryResetTile + FactoryResetDialog with a write-recording
// fake LocalDataStore behind a REAL FactoryResetCubit, so the "no data touched
// until an affirmative confirm" gate is asserted against the actual wiring.
// Pure: no engine, no ticker, no timers, no network, no shared_preferences.
//
// Traceability (one test group ↔ one case; TC + AC ids in each description):
//   TC-701  (AC-1)        opening the dialog touches NO data (zero clears)
//   TC-701  (AC-1)        confirming runs the wipe callback exactly once
//   TC-702  (AC-2)        Cancel is inert — dialog closes, zero clears
//   TC-702b (AC-2)        Esc / scrim dismiss is inert — zero clears
//   TC-703  (AC-1, NFR-3) labelled irreversible, destructive, distinct from
//                         Start over
//   TC-722  (AC-12, AC-1) copy names the lifetime-data loss (BR-8 carve-out)
//   TC-725  (NFR-3)       keyboard-reachable + screen-reader labelled;
//                         destructive action distinguished, non-destructive
//                         default focus
//
// Run: fvm flutter test test/features/reset/presentation/factory_reset_dialog_test.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/reset/domain/local_data_reset_service.dart';
import 'package:focus_journey/features/reset/domain/local_data_store.dart';
import 'package:focus_journey/features/reset/presentation/factory_reset_cubit.dart';
import 'package:focus_journey/features/reset/presentation/factory_reset_dialog.dart';
import 'package:focus_journey/features/reset/presentation/reset_copy.dart';

/// A write-recording [LocalDataStore]: records every `clear()` call so a test
/// can assert the wipe fired zero times while merely browsing the dialog and
/// exactly once on an affirmative confirm. Deletes nothing real.
class _RecordingStore implements LocalDataStore {
  int clearCount = 0;

  @override
  Set<String> get ownedKeys => const <String>{'recording_store_key_v1'};

  @override
  Future<void> clear() async {
    clearCount++;
  }
}

void main() {
  late _RecordingStore store;
  late LocalDataResetService service;
  late FactoryResetCubit cubit;
  late int quiesceCount;
  late int reinitCount;

  setUp(() {
    store = _RecordingStore();
    service = LocalDataResetService(<LocalDataStore>[store]);
    quiesceCount = 0;
    reinitCount = 0;
    cubit = FactoryResetCubit(
      service: service,
      onQuiesce: () async => quiesceCount++,
      onReinitialise: () async => reinitCount++,
    );
  });

  tearDown(() => cubit.close());

  // Pumps the REAL Settings tile behind the REAL cubit. Tapping it opens the
  // REAL confirmation dialog — the whole gate under test.
  Future<void> pumpTile(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<FactoryResetCubit>.value(
            value: cubit,
            child: const FactoryResetTile(),
          ),
        ),
      ),
    );
  }

  // Pumps the dialog in isolation (stateless, pops a bool) for copy / a11y
  // assertions that need no cubit.
  Future<void> pumpDialogAlone(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FactoryResetDialog())),
    );
  }

  group('TC-701 (AC-1) opening Factory reset touches no data until confirm', () {
    testWidgets(
      'activating the tile shows the destructive dialog and clears NOTHING '
      'while it is merely open',
      (tester) async {
        await pumpTile(tester);

        await tester.tap(find.byKey(const Key('factory-reset-tile')));
        await tester.pumpAndSettle();

        // The explicit destructive confirmation is shown before anything is wiped.
        expect(find.byKey(const Key('factory-reset-dialog')), findsOneWidget);
        expect(find.byKey(const Key('factory-reset-confirm')), findsOneWidget);
        expect(find.byKey(const Key('factory-reset-cancel')), findsOneWidget);

        // The wipe is gated STRICTLY behind confirm: zero clears / re-inits so far.
        expect(store.clearCount, 0);
        expect(quiesceCount, 0);
        expect(reinitCount, 0);
      },
    );

    testWidgets(
      'confirming runs the wipe + re-init seam exactly once (the affirmative '
      'path is the ONLY path that touches data)',
      (tester) async {
        await pumpTile(tester);

        await tester.tap(find.byKey(const Key('factory-reset-tile')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('factory-reset-confirm')));
        await tester.pumpAndSettle();

        // The dialog is gone and the wipe ran once, in order (quiesce → clear →
        // re-init is enforced by the cubit; here we assert each fired once).
        expect(find.byKey(const Key('factory-reset-dialog')), findsNothing);
        expect(store.clearCount, 1);
        expect(quiesceCount, 1);
        expect(reinitCount, 1);
      },
    );
  });

  group('TC-702 (AC-2) cancelling the confirmation is inert', () {
    testWidgets(
      'Cancel closes the dialog and clears nothing — no data touched, app '
      'unchanged',
      (tester) async {
        await pumpTile(tester);

        await tester.tap(find.byKey(const Key('factory-reset-tile')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('factory-reset-cancel')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('factory-reset-dialog')), findsNothing);
        expect(store.clearCount, 0);
        expect(quiesceCount, 0);
        expect(reinitCount, 0);
      },
    );
  });

  group('TC-702b (AC-2) dismissing (Esc / scrim) is as safe as Cancel', () {
    testWidgets('pressing Esc dismisses without wiping anything', (
      tester,
    ) async {
      await pumpTile(tester);

      await tester.tap(find.byKey(const Key('factory-reset-tile')));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('factory-reset-dialog')), findsNothing);
      expect(store.clearCount, 0);
      expect(quiesceCount, 0);
      expect(reinitCount, 0);
    });

    testWidgets(
      'tapping the scrim (barrier) dismisses without wiping anything',
      (tester) async {
        await pumpTile(tester);

        await tester.tap(find.byKey(const Key('factory-reset-tile')));
        await tester.pumpAndSettle();

        // Tap well outside the dialog surface (the modal barrier).
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('factory-reset-dialog')), findsNothing);
        expect(store.clearCount, 0);
        expect(quiesceCount, 0);
        expect(reinitCount, 0);
      },
    );
  });

  group('TC-703 (AC-1, NFR-3) labelled irreversible + destructive + distinct', () {
    testWidgets(
      'the dialog states the irreversible outcome, styles confirm destructively, '
      'and reads as distinct from Start over',
      (tester) async {
        await pumpDialogAlone(tester);

        // Irreversible wording is present (clears all / cannot be undone / first-run).
        expect(find.textContaining('permanently erases'), findsOneWidget);
        expect(find.textContaining('cannot be'), findsOneWidget);
        expect(find.textContaining('first-run'), findsOneWidget);

        // The confirm affordance is the LOWER-emphasis, error-coloured
        // OutlinedButton (destructive styling) — deliberately NOT the filled
        // primary. The safe Cancel is the prominent FilledButton, so "erase" is
        // never the easy default (TC-703 note).
        final confirm = tester.widget<OutlinedButton>(
          find.byKey(const Key('factory-reset-confirm')),
        );
        final ColorScheme colors = Theme.of(
          tester.element(find.byType(FactoryResetDialog)),
        ).colorScheme;
        expect(
          confirm.style?.foregroundColor?.resolve(<WidgetState>{}),
          colors.error,
        );
        // The destructive action is NOT a FilledButton (not the primary), and
        // the safe Cancel IS the prominent FilledButton.
        expect(
          find.descendant(
            of: find.byKey(const Key('factory-reset-confirm')),
            matching: find.byType(FilledButton),
          ),
          findsNothing,
        );
        expect(
          tester.widget<FilledButton>(
            find.byKey(const Key('factory-reset-cancel')),
          ),
          isNotNull,
        );

        // The copy explicitly distinguishes this from Start over.
        expect(
          find.textContaining('different from Start over'),
          findsOneWidget,
        );
        // The destructive label is not a bland "OK" — it names the erasure.
        expect(find.text(FactoryResetCopy.confirmLabel), findsOneWidget);
      },
    );
  });

  group('TC-722 (AC-12, AC-1) asymmetry surfaced in-product', () {
    testWidgets(
      'the confirmation explicitly warns that lifetime distance/streaks/badges '
      'will be lost (unlike Start over) — the BR-8 carve-out',
      (tester) async {
        await pumpDialogAlone(tester);

        // Names the lifetime data that Factory reset (unlike Start over) clears.
        expect(
          find.textContaining('lifetime distance, streaks, and badges'),
          findsWidgets,
        );
        // And explicitly contrasts with Start over keeping them.
        expect(find.textContaining('Start over, which keeps'), findsOneWidget);
      },
    );
  });

  group('TC-725 (NFR-3) keyboard-reachable + screen-reader labelled', () {
    testWidgets(
      'both actions are focusable, the destructive action carries a distinct '
      'semantic label, and the non-destructive Cancel is the default focus',
      (tester) async {
        await pumpDialogAlone(tester);
        await tester.pumpAndSettle();

        // The destructive action exposes a meaningful accessible name that marks
        // it destructive/irreversible (not colour-only) and distinct from
        // Start over / Cancel.
        expect(
          find.bySemanticsLabel(FactoryResetCopy.confirmSemanticLabel),
          findsOneWidget,
        );

        // The default keyboard target is the NON-destructive Cancel (autofocus,
        // and the prominent FilledButton), so a destructive dialog never
        // defaults to "erase" (NFR-3).
        final cancel = tester.widget<FilledButton>(
          find.byKey(const Key('factory-reset-cancel')),
        );
        expect(cancel.autofocus, isTrue);

        // Both interactive elements are present and reachable (keyed buttons).
        expect(find.byKey(const Key('factory-reset-cancel')), findsOneWidget);
        expect(find.byKey(const Key('factory-reset-confirm')), findsOneWidget);
      },
    );
  });
}
