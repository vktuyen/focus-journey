// Widget tests for the route-planner-v2 abandon confirm guard (ADR-0005
// decision 5 / AC-9). Drives the REAL `confirmAbandon` dialog helper from
// route_planner_flow.dart. Pure: no engine, no timers, no network.
//
// Traceability (one test ↔ one case; TC + AC ids in each description):
//   TC-324 (AC-9)  starting a new route WITH progress shows the abandon guard
//   TC-325 (AC-9)  cancelling the guard returns "false" (caller does nothing —
//                  the inert path; the data-side untouched assertion is the cubit
//                  test TC-325 and integration TC-314)
//   TC-326 (AC-9)  NO guard appears when there is no progress to lose
//                  (km == 0 OR completed) — proceeds directly (returns true)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/presentation/route_planner_flow.dart';

void main() {
  // Pumps a host with a button that invokes confirmAbandon(hasProgressToLose:)
  // and records the returned decision.
  Future<bool?> runGuard(
    WidgetTester tester, {
    required bool hasProgressToLose,
  }) async {
    bool? decision;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  decision = await confirmAbandon(
                    context,
                    hasProgressToLose: hasProgressToLose,
                  );
                },
                child: const Text('start new'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('start new'));
    await tester.pumpAndSettle();
    return decision;
  }

  group('TC-324 (AC-9) abandon guard shown when there is progress to lose', () {
    testWidgets(
      'the confirm guard dialog appears before anything is abandoned',
      (tester) async {
        await runGuard(tester, hasProgressToLose: true);

        // The "you'll lose progress" confirm guard is shown (AC-9).
        expect(find.byKey(const Key('abandon_confirm_dialog')), findsOneWidget);
        expect(find.textContaining("lose progress"), findsOneWidget);
        // Both actions present: keep going (cancel) + start new route (confirm).
        expect(find.byKey(const Key('abandon_confirm_cancel')), findsOneWidget);
        expect(find.byKey(const Key('abandon_confirm_ok')), findsOneWidget);
      },
    );

    testWidgets('confirming the guard resolves to true (proceed to abandon)', (
      tester,
    ) async {
      // We re-run with a captured decision so we can assert the boolean result.
      bool? decision;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    decision = await confirmAbandon(
                      context,
                      hasProgressToLose: true,
                    );
                  },
                  child: const Text('start new'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('start new'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('abandon_confirm_ok')));
      await tester.pumpAndSettle();
      expect(decision, isTrue);
    });
  });

  group('TC-325 (AC-9) cancelling the guard is inert (returns false)', () {
    testWidgets(
      'cancelling ("Keep going") dismisses the dialog and returns false so the '
      'caller leaves the current route untouched',
      (tester) async {
        bool? decision;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      decision = await confirmAbandon(
                        context,
                        hasProgressToLose: true,
                      );
                    },
                    child: const Text('start new'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('start new'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('abandon_confirm_cancel')));
        await tester.pumpAndSettle();

        // The dialog is gone and the decision is "do not abandon" — the caller
        // never calls abandonAndStartNew, so the route stays untouched.
        expect(find.byKey(const Key('abandon_confirm_dialog')), findsNothing);
        expect(decision, isFalse);
      },
    );
  });

  group('TC-326 (AC-9) no guard when there is no progress to lose', () {
    testWidgets(
      'no guard dialog is shown and the flow proceeds directly (returns true)',
      (tester) async {
        final decision = await runGuard(tester, hasProgressToLose: false);

        // The guard is gated strictly on routeDistanceKm > 0 && !completed; with
        // nothing to lose it is skipped entirely (no needless warning).
        expect(find.byKey(const Key('abandon_confirm_dialog')), findsNothing);
        // Proceeds directly to the new-route flow.
        expect(decision, isTrue);
      },
    );
  });
}
