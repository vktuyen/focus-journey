// Widget tests for the route-planner-v2 picker + review-before-start screen,
// updated for the real-road model (route-real-road). Drive the REAL RoutePicker
// / RouteReviewScreen / RoutePlannerFlow over the fixture chain + geography.
// Pure: no engine, no timers, no network.
//
// The review now lists ONLY the anchors — the start, any user-marked stops (in
// travel order), and the end. Pass-through provinces are implicit road geometry
// and are NOT listed; the old remove/skip-intermediate affordance is GONE.
//
// Traceability (one test ↔ one case; TC + AC ids in each description):
//   TC-303 (AC-2)  start == end disabled in the picker; 2-checkpoint minimum
//   TC-304 (AC-1)  picker offers free start+end choices; no N/S direction toggle
//   TC-309 (AC-4)  review reflects the AC-4-extended endpoints; marked stops are
//                  anchors, pass-through provinces are NOT listed
//   TC-310 (AC-5)  review shows ONLY the anchors + the route distance
//   TC-311 (route-real-road) pass-through provinces are implicit — not listed,
//                  no remove/skip controls exist
//   TC-312 (AC-2)  endpoints are shown locked; no remove controls anywhere
//   TC-313 (AC-5)  cancelling the review returns to the picker (navigation only)
//   TC-340 (route-real-road) the distance readout uses the REAL road length when
//                  a RoadPath is provided; falls back to subPathKm when it isn't
//   TC-339 (NFR-3) picker + review controls are semantically labelled + keyboard
//                  reachable (deterministic half)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/road_path.dart';
import 'package:focus_journey/features/route/domain/road_route.dart';
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

  /// A fixture "national road" built from the ordered canonical coordinates so
  /// [RoadRoute] can snap the anchors + measure a real great-circle length.
  RoadPath fixtureRoad() => RoadPath(geography.canonicalCoordinates);

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
    RoadPath? road,
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
              road: road,
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
        // The internal sub-chain still carries every province (the geometry
        // needs it); only the DISPLAYED review list is trimmed to anchors.
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
      'a stop outside [start,end] extends the span; review shows the new end and '
      'omits the pass-through provinces',
      (tester) async {
        // start=Cần Thơ, end=Đà Lạt, stop=Hà Nội (beyond Đà Lạt) → extends to
        // Hà Nội: can_tho → da_lat → da_nang → ha_noi. Anchors = {can_tho,
        // ha_noi} (da_lat/da_nang are pass-through, not marked).
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
          find.byKey(const Key('route_review_stop_can_tho')),
          findsOneWidget,
        );
        // Pass-through provinces are implicit road geometry — NOT listed.
        expect(find.byKey(const Key('route_review_stop_da_lat')), findsNothing);
        expect(find.byKey(const Key('route_review_stop_da_nang')), findsNothing);
        expect(
          find.byKey(const Key('route_review_total_distance')),
          findsOneWidget,
        );
        // The readout names the extended start → end pair.
        expect(find.textContaining('Cần Thơ → Hà Nội'), findsOneWidget);
      },
    );

    testWidgets(
      'a marked in-span stop is shown as an anchor in travel order; a non-marked '
      'pass-through province is NOT listed',
      (tester) async {
        // start=Cần Thơ, end=Hà Nội, mark Đà Nẵng (an IN-span stop). Resolved:
        // can_tho → da_lat → da_nang → ha_noi. Anchors = {can_tho, da_nang,
        // ha_noi}; da_lat is a plain pass-through and is omitted.
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
          markedStops: <Province>[nodeById(chain, 'da_nang')],
          onConfirm: (_) {},
          onCancel: () {},
        );

        // The marked in-span stop appears as an anchor.
        expect(
          find.byKey(const Key('route_review_stop_da_nang')),
          findsOneWidget,
        );
        // The non-marked pass-through province is NOT listed.
        expect(find.byKey(const Key('route_review_stop_da_lat')), findsNothing);
        // No remove/skip controls exist for anything (the feature is gone).
        expect(find.byKey(const Key('route_review_remove_da_lat')), findsNothing);
        expect(
          find.byKey(const Key('route_review_remove_da_nang')),
          findsNothing,
        );
        expect(find.text('Skipped (tap to add back)'), findsNothing);
      },
    );
  });

  group('TC-310 (AC-5) review shows ONLY the anchors + the route distance', () {
    testWidgets('only start + end are listed; pass-through provinces are omitted', (
      tester,
    ) async {
      // Cần Thơ → (Đà Lạt) → (Đà Nẵng) → Hà Nội. No marked stops → anchors are
      // just the endpoints. subPathKm = 170+300+310 = 780 (road == null fallback).
      final route = resolve('can_tho', 'ha_noi');
      await pumpReview(
        tester,
        initial: route,
        onConfirm: (_) {},
        onCancel: () {},
      );

      // Only the two endpoints are listed.
      expect(find.byKey(const Key('route_review_stop_can_tho')), findsOneWidget);
      expect(find.byKey(const Key('route_review_stop_ha_noi')), findsOneWidget);
      // The pass-through provinces are implicit and NOT listed.
      expect(find.byKey(const Key('route_review_stop_da_lat')), findsNothing);
      expect(find.byKey(const Key('route_review_stop_da_nang')), findsNothing);
      // With no RoadPath supplied, the readout falls back to subPathKm (780).
      expect(route.subPathKm, closeTo(780, kTol));
      expect(find.textContaining('780 km'), findsOneWidget);
    });
  });

  group('TC-311 (route-real-road) pass-through provinces are implicit', () {
    testWidgets(
      'no remove/skip controls exist and no "Skipped" section is rendered',
      (tester) async {
        // Cần Thơ → Hà Nội (two pass-through provinces internally).
        final route = resolve('can_tho', 'ha_noi');
        await pumpReview(
          tester,
          initial: route,
          onConfirm: (_) {},
          onCancel: () {},
        );

        // No remove control for ANY province (endpoints or pass-through).
        expect(find.byKey(const Key('route_review_remove_can_tho')), findsNothing);
        expect(find.byKey(const Key('route_review_remove_da_lat')), findsNothing);
        expect(find.byKey(const Key('route_review_remove_da_nang')), findsNothing);
        expect(find.byKey(const Key('route_review_remove_ha_noi')), findsNothing);
        expect(find.byType(IconButton), findsNothing);
        // No removed/"Skipped" section survives.
        expect(find.text('Skipped (tap to add back)'), findsNothing);
        expect(
          find.byKey(const Key('route_review_removed_da_nang')),
          findsNothing,
        );
      },
    );
  });

  group('TC-312 (AC-2) endpoints are shown locked; no remove controls', () {
    testWidgets(
      'an adjacent 2-checkpoint route lists both endpoints, neither removable',
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

        // Both endpoints are rendered as locked anchors — no remove controls.
        expect(find.byKey(const Key('route_review_stop_mui')), findsOneWidget);
        expect(
          find.byKey(const Key('route_review_stop_can_tho')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('route_review_remove_mui')), findsNothing);
        expect(
          find.byKey(const Key('route_review_remove_can_tho')),
          findsNothing,
        );
        // The locked cue is present on the anchor rows.
        expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
      },
    );
  });

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

  group('TC-340 (route-real-road) distance readout uses the real road length', () {
    testWidgets(
      'with a RoadPath, the readout shows the road length (not subPathKm)',
      (tester) async {
        final route = resolve('can_tho', 'ha_noi'); // subPathKm 780
        final road = fixtureRoad();
        // The real road length between the anchors — the same axis the map draws.
        final roadKm = RoadRoute.build(
          road: road,
          waypoints: <GeoCoordinate>[
            geography.coordinateOf(nodeById(chain, 'can_tho')),
            geography.coordinateOf(nodeById(chain, 'ha_noi')),
          ],
        ).routeLengthKm;
        // The road length differs from the chain-km fallback (proves the axis).
        expect(roadKm.round(), isNot(route.subPathKm.round()));

        await pumpReview(
          tester,
          initial: route,
          road: road,
          onConfirm: (_) {},
          onCancel: () {},
        );

        expect(find.textContaining('${roadKm.round()} km'), findsOneWidget);
        // The old chain-km value is NOT shown when a road is provided.
        expect(find.textContaining('780 km'), findsNothing);
      },
    );

    testWidgets(
      'without a RoadPath, the readout falls back to subPathKm',
      (tester) async {
        final route = resolve('can_tho', 'ha_noi'); // subPathKm 780
        await pumpReview(
          tester,
          initial: route,
          onConfirm: (_) {},
          onCancel: () {},
        );
        expect(find.textContaining('780 km'), findsOneWidget);
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
        final route = resolve('can_tho', 'ha_noi'); // 780 km fallback
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
        // The anchor rows carry a screen-reader "kept" cue (no remove controls).
        expect(semanticsLabelled(tester, 'Stop — kept'), isTrue);
      },
    );
  });
}
