// Widget tests for the route-planner-v2 picker + review-before-start screen
// (ADR-0005). Drive the REAL RoutePicker / RouteReviewScreen / RoutePlannerFlow
// over the fixture chain + geography. Pure: no engine, no timers, no network.
//
// Traceability (one test ↔ one case; TC + AC ids in each description):
//   TC-303 (AC-2)  start == end disabled in the picker; 2-checkpoint minimum
//   TC-304 (AC-1)  picker offers free start+end choices; no N/S direction toggle
//   TC-309 (AC-4)  review reflects the AC-4-extended endpoints (widget half)
//   TC-310 (AC-5)  review shows the ordered route + total distance
//   TC-311 (AC-5)  removing an intermediate re-resolves the list + total distance
//   TC-312 (AC-2/AC-5) endpoints are not removable below the 2-checkpoint minimum
//   TC-313 (AC-5)  cancelling the review returns to the picker (navigation only)
//   TC-339 (NFR-3) picker + review controls are semantically labelled + keyboard
//                  reachable (deterministic half)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_planner.dart';
import 'package:focus_journey/features/route/presentation/route_picker.dart';
import 'package:focus_journey/features/route/presentation/route_planner_flow.dart';
import 'package:focus_journey/features/route/presentation/route_review_screen.dart';

import '../map_test_fixtures.dart';

void main() {
  // Fixture chain: mui/can_tho/da_lat/da_nang/ha_noi/ha_giang,
  // segments [60,170,300,310,600], total 1440. Cumulative-from-mui:
  // 0/60/230/530/840/1440.
  late ProvinceChain chain;
  late ProvinceGeography geography;

  setUp(() {
    chain = buildFixtureChain();
    geography = buildFixtureGeography(chain);
  });

  /// Whether any explicit [Semantics] widget in the tree carries [label] — a
  /// robust check for screen-reader labels on `Semantics(label: ...)` widgets
  /// without depending on the merged semantics-tree finder.
  bool semanticsLabelled(WidgetTester tester, String label) => tester
      .widgetList<Semantics>(find.byType(Semantics))
      .any((s) => s.properties.label == label);

  Future<void> pumpPicker(
    WidgetTester tester, {
    required void Function(ResolvedRoute, List<Province>) onResolved,
    VoidCallback? onCancel,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RoutePicker(
              chain: chain,
              geography: geography,
              onResolved: onResolved,
              onCancel: onCancel,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ResolvedRoute resolve(
    String startId,
    String endId, {
    List<String> stops = const <String>[],
  }) => RoutePlanner.resolve(
    fullChain: chain,
    fullGeography: geography,
    start: nodeById(chain, startId),
    end: nodeById(chain, endId),
    markedStops: <Province>[for (final s in stops) nodeById(chain, s)],
  );

  Future<void> pumpReview(
    WidgetTester tester, {
    required ResolvedRoute initial,
    required void Function(ResolvedRoute) onConfirm,
    required VoidCallback onCancel,
    List<Province> markedStops = const <Province>[],
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RouteReviewScreen(
              chain: chain,
              geography: geography,
              start: initial.orderedNodes.first,
              end: initial.orderedNodes.last,
              markedStops: markedStops,
              initial: initial,
              onConfirm: onConfirm,
              onCancel: onCancel,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('TC-303 (AC-2) start == end disabled in the picker', () {
    testWidgets(
      'the end option matching the chosen start is disabled (cannot be picked)',
      (tester) async {
        await pumpPicker(tester, onResolved: (_, _) {});

        // Open the END dropdown and inspect its items. The item whose value is
        // the chosen start (default first node, mui) is disabled (AC-2).
        final dropdown = tester.widget<DropdownButton<Province>>(
          find.byKey(const Key('route_picker_end_dropdown')),
        );
        final startProvince = chain.nodes.first; // default start
        final sameAsStart = dropdown.items!.firstWhere(
          (item) => item.value!.id == startProvince.id,
        );
        expect(
          sameAsStart.enabled,
          isFalse,
          reason: 'the end option equal to the start must be disabled (AC-2)',
        );
        // Every other option (a different checkpoint) is selectable.
        for (final item in dropdown.items!) {
          if (item.value!.id != startProvince.id) {
            expect(item.enabled, isTrue);
          }
        }
      },
    );

    testWidgets(
      'the picker opens valid (start != end) so review is reachable without a '
      'zero-length route',
      (tester) async {
        ResolvedRoute? resolved;
        await pumpPicker(tester, onResolved: (r, _) => resolved = r);

        // Continue with the defaults (first != last) → a valid >= 2-checkpoint
        // route resolves; the model never enters a start==end state.
        await tester.tap(find.byKey(const Key('route_picker_continue')));
        await tester.pump();
        expect(resolved, isNotNull);
        expect(resolved!.orderedNodes.length, greaterThanOrEqualTo(2));
        expect(
          resolved!.orderedNodes.first.id,
          isNot(resolved!.orderedNodes.last.id),
        );
      },
    );
  });

  group('TC-304 (AC-1) picker offers free start+end, no N/S direction toggle', () {
    testWidgets(
      'two free checkpoint dropdowns are present and no direction toggle remains',
      (tester) async {
        await pumpPicker(tester, onResolved: (_, _) {});

        // Two free checkpoint choosers (start + end).
        expect(
          find.byKey(const Key('route_picker_start_dropdown')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('route_picker_end_dropdown')),
          findsOneWidget,
        );
        // The shipped route-progress N/S direction toggle is GONE (regression).
        expect(
          find.byKey(const Key('direction_toward_ha_giang')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('direction_toward_mui_ca_mau')),
          findsNothing,
        );
        // A start + end selection alone is sufficient to reach review.
        expect(find.byKey(const Key('route_picker_continue')), findsOneWidget);
      },
    );

    testWidgets(
      'continue resolves the contiguous sub-path for the chosen endpoints',
      (tester) async {
        ResolvedRoute? resolved;
        await pumpPicker(tester, onResolved: (r, _) => resolved = r);

        // Choose start = Cần Thơ, end = Đà Nẵng via the dropdowns.
        await tester.tap(find.byKey(const Key('route_picker_start_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cần Thơ').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('route_picker_end_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Đà Nẵng').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('route_picker_continue')));
        await tester.pump();
        expect(resolved!.orderedNodeIds, <String>[
          'can_tho',
          'da_lat',
          'da_nang',
        ]);
      },
    );
  });

  group('TC-309 (AC-4) review reflects the AC-4-extended endpoints', () {
    testWidgets(
      'a stop outside [start,end] extends the span; review shows the new end',
      (tester) async {
        // start=Cần Thơ, end=Đà Lạt, stop=Hà Nội (beyond Đà Lạt) → extends to
        // Hà Nội: can_tho → da_lat → da_nang → ha_noi.
        final extended = resolve(
          'can_tho',
          'da_lat',
          stops: <String>['ha_noi'],
        );
        expect(extended.orderedNodeIds, <String>[
          'can_tho',
          'da_lat',
          'da_nang',
          'ha_noi',
        ]);

        await pumpReview(
          tester,
          initial: extended,
          markedStops: <Province>[nodeById(chain, 'ha_noi')],
          onConfirm: (_) {},
          onCancel: () {},
        );

        // The review reflects the EXTENDED endpoints (ha_noi is the new extreme).
        expect(
          find.byKey(const Key('route_review_stop_ha_noi')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('route_review_total_distance')),
          findsOneWidget,
        );
        // The readout names the extended start → end pair.
        expect(find.textContaining('Cần Thơ → Hà Nội'), findsOneWidget);
      },
    );

    testWidgets(
      'B1: an IN-span marked stop is NOT removable on review (AC-4 — a marked '
      'stop must stay in the route); endpoints + the in-span marked stop are '
      'both protected, while a non-marked auto-inserted intermediate stays '
      'removable',
      (tester) async {
        // start=Cần Thơ, end=Hà Nội, mark Đà Nẵng (an IN-span stop). Resolved:
        // can_tho → da_lat → da_nang → ha_noi. da_nang is a MARKED in-span stop;
        // da_lat is a plain auto-inserted intermediate.
        final route = resolve('can_tho', 'ha_noi', stops: <String>['da_nang']);
        expect(route.orderedNodeIds, <String>[
          'can_tho',
          'da_lat',
          'da_nang',
          'ha_noi',
        ]);

        await pumpReview(
          tester,
          initial: route,
          // The real marked-stop list is threaded through (B1 fix) — without it
          // da_nang would wrongly expose a remove control.
          markedStops: <Province>[nodeById(chain, 'da_nang')],
          onConfirm: (_) {},
          onCancel: () {},
        );

        // Endpoints are protected (no remove control).
        expect(
          find.byKey(const Key('route_review_remove_can_tho')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('route_review_remove_ha_noi')),
          findsNothing,
        );
        // The IN-span MARKED stop (da_nang) is ALSO protected — it must stay in
        // the route (AC-4). This is the B1 regression assertion.
        expect(
          find.byKey(const Key('route_review_remove_da_nang')),
          findsNothing,
        );
        // A plain (non-marked) auto-inserted intermediate stays removable (AC-5).
        expect(
          find.byKey(const Key('route_review_remove_da_lat')),
          findsOneWidget,
        );
      },
    );
  });

  group('TC-310 (AC-5) review shows the ordered route + total distance', () {
    testWidgets('full ordered list and total subPathKm are rendered', (
      tester,
    ) async {
      // Cần Thơ → Đà Lạt → Đà Nẵng → Hà Nội (170+300+310 = 780 km).
      final route = resolve('can_tho', 'ha_noi');
      await pumpReview(
        tester,
        initial: route,
        onConfirm: (_) {},
        onCancel: () {},
      );

      // Every checkpoint in the ordered list is rendered, in order.
      for (final id in route.orderedNodeIds) {
        expect(find.byKey(Key('route_review_stop_$id')), findsOneWidget);
      }
      // Total route distance == subPathKm (780), within display rounding.
      expect(route.subPathKm, closeTo(780, kTol));
      expect(find.textContaining('780 km'), findsOneWidget);
    });
  });

  group('TC-311 (AC-5) removing an intermediate re-resolves the route', () {
    testWidgets(
      'removing Đà Nẵng drops it from the list and updates the total distance',
      (tester) async {
        // Cần Thơ → Đà Lạt → Đà Nẵng → Hà Nội (780 km).
        final route = resolve('can_tho', 'ha_noi');
        await pumpReview(
          tester,
          initial: route,
          onConfirm: (_) {},
          onCancel: () {},
        );
        expect(find.textContaining('780 km'), findsOneWidget);

        // Remove the auto-inserted intermediate Đà Nẵng.
        await tester.tap(find.byKey(const Key('route_review_remove_da_nang')));
        await tester.pumpAndSettle();

        // It disappears from the ordered list (moves to "skipped").
        expect(
          find.byKey(const Key('route_review_stop_da_nang')),
          findsNothing,
        );
        // The remaining list is can_tho → da_lat → ha_noi; the merged total is
        // still 780 km (segments merge — the canonical axis is preserved).
        expect(
          find.byKey(const Key('route_review_stop_can_tho')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('route_review_stop_da_lat')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('route_review_stop_ha_noi')),
          findsOneWidget,
        );
        expect(find.textContaining('780 km'), findsOneWidget);
        // The removal is reversible (offered back under "Skipped").
        expect(
          find.byKey(const Key('route_review_removed_da_nang')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'removing a Đà Lạt intermediate from a 3-node route changes the readout '
      'list while preserving subPathKm',
      (tester) async {
        // can_tho → da_lat → da_nang (470 km).
        final route = resolve('can_tho', 'da_nang');
        await pumpReview(
          tester,
          initial: route,
          onConfirm: (_) {},
          onCancel: () {},
        );
        await tester.tap(find.byKey(const Key('route_review_remove_da_lat')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('route_review_stop_da_lat')), findsNothing);
        // Merged: 170 + 300 = 470; still shown.
        expect(find.textContaining('470 km'), findsOneWidget);
      },
    );
  });

  group(
    'TC-312 (AC-2/AC-5) endpoints not removable below the 2-checkpoint min',
    () {
      testWidgets(
        'with two checkpoints remaining the endpoints have no remove control',
        (tester) async {
          // Adjacent endpoints — a 2-checkpoint route with no intermediates.
          final route = resolve('mui', 'can_tho');
          expect(route.orderedNodeIds, <String>['mui', 'can_tho']);
          await pumpReview(
            tester,
            initial: route,
            onConfirm: (_) {},
            onCancel: () {},
          );

          // Both endpoints are rendered, but neither exposes a remove button —
          // they are protected (the 2-checkpoint minimum holds; AC-2).
          expect(
            find.byKey(const Key('route_review_stop_mui')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('route_review_stop_can_tho')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('route_review_remove_mui')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('route_review_remove_can_tho')),
            findsNothing,
          );
        },
      );

      testWidgets(
        'after removing the only intermediate, the two endpoints stay non-removable',
        (tester) async {
          // can_tho → da_lat → da_nang; remove da_lat → endpoints only remain.
          final route = resolve('can_tho', 'da_nang');
          await pumpReview(
            tester,
            initial: route,
            onConfirm: (_) {},
            onCancel: () {},
          );
          await tester.tap(find.byKey(const Key('route_review_remove_da_lat')));
          await tester.pumpAndSettle();

          // Only the two endpoints remain, neither removable (cannot collapse).
          expect(
            find.byKey(const Key('route_review_remove_can_tho')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('route_review_remove_da_nang')),
            findsNothing,
          );
        },
      );
    },
  );

  group('TC-313 (AC-5) cancelling the review returns to the picker', () {
    testWidgets(
      'cancel in the full flow pops the review and shows the picker again',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RoutePlannerFlow(
                  chain: chain,
                  geography: geography,
                  onConfirmed: (_) {},
                  onCancelled: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1: the picker. Continue to review.
        expect(find.byType(RoutePicker), findsOneWidget);
        await tester.tap(find.byKey(const Key('route_picker_continue')));
        await tester.pumpAndSettle();
        // Step 2: the review screen.
        expect(find.byType(RouteReviewScreen), findsOneWidget);

        // Cancel → back to the picker; the review is discarded from the UI.
        await tester.tap(find.byKey(const Key('route_review_cancel')));
        await tester.pumpAndSettle();
        expect(find.byType(RoutePicker), findsOneWidget);
        expect(find.byType(RouteReviewScreen), findsNothing);
      },
    );
  });

  group('TC-339 (NFR-3) picker + review are labelled + keyboard-reachable', () {
    testWidgets('picker exposes accessible names for both endpoint choosers', (
      tester,
    ) async {
      await pumpPicker(tester, onResolved: (_, _) {});
      // Semantic labels for the start + end choosers (not visual-only cues).
      expect(semanticsLabelled(tester, 'Start checkpoint'), isTrue);
      expect(semanticsLabelled(tester, 'End checkpoint'), isTrue);
      // The continue action is a focusable, activatable button.
      final continueBtn = tester.widget<FilledButton>(
        find.byKey(const Key('route_picker_continue')),
      );
      expect(continueBtn.onPressed, isNotNull);
    });

    testWidgets(
      'review exposes a labelled distance readout + activatable confirm/cancel',
      (tester) async {
        final route = resolve('can_tho', 'ha_noi'); // 780 km
        await pumpReview(
          tester,
          initial: route,
          onConfirm: (_) {},
          onCancel: () {},
        );
        // The total-distance readout carries a screen-reader label.
        expect(
          semanticsLabelled(tester, 'Total route distance 780 kilometres'),
          isTrue,
        );
        // Confirm + cancel are real, activatable buttons (keyboard-operable).
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('route_review_confirm')),
              )
              .onPressed,
          isNotNull,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const Key('route_review_cancel')),
              )
              .onPressed,
          isNotNull,
        );
        // Each removable intermediate's remove control has a tooltip label.
        final removeBtn = tester.widget<IconButton>(
          find.byKey(const Key('route_review_remove_da_lat')),
        );
        expect(removeBtn.tooltip, isNotNull);
      },
    );
  });
}
