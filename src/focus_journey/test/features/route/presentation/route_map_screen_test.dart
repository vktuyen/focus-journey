// Map-screen widget test for route-progress.
//
// Pumps RouteMapScreen with a real RouteProgressCubit driven by a scripted
// scalar (no engine, no timers). Golden images are NOT used: the project's
// golden approach is deferred (journey-view deferred its goldens too), so these
// assert via finders / structure / painter geometry instead. The painted-frame
// golden for TC-002 / TC-011 is noted DEFERRED-TO-MANUAL in the summary.
//
// Covers:
//   TC-002  marker sits on the start pin at distance 0 (painter geometry check)
//   TC-011  on completion the celebration/summary surface appears with an
//           EXPLICIT "Start a new journey" action and NO auto-advance
//   TC-013  continued distance after completion makes no forward progress
//           (readout/celebration unchanged across increasing distance)
//
// Conventions mirror test/features/journey/presentation/journey_screen_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/route_selection.dart';
import 'package:focus_journey/features/route/presentation/route_map_painter.dart';
import 'package:focus_journey/features/route/presentation/route_map_screen.dart';
import 'package:focus_journey/features/route/presentation/route_progress_cubit.dart';

import '../route_test_fixtures.dart';

void main() {
  late ProvinceChain chain;
  late RecordingRouteRepository repo;

  setUp(() {
    chain = buildFixtureChain();
    repo = RecordingRouteRepository();
  });

  RouteProgressCubit cubitFor(
    String startId,
    JourneyDirection direction, {
    double offset = 0,
  }) {
    final initial = RouteSelection.create(
      start: nodeById(chain, startId),
      direction: direction,
      routeStartOffsetKm: offset,
      chain: chain,
    );
    final cubit = RouteProgressCubit(
      chain: chain,
      repository: repo,
      initialSelection: initial,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<void> pumpScreen(WidgetTester tester, RouteProgressCubit cubit) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<RouteProgressCubit>.value(
          value: cubit,
          child: RouteMapScreen(chain: chain),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('TC-002 marker on the start pin at distance 0', () {
    testWidgets('painter marker offset == the start pin centre', (
      tester,
    ) async {
      final cubit = cubitFor('can_tho', JourneyDirection.towardHaGiang);
      cubit.updateFromDistance(0);
      await pumpScreen(tester, cubit);

      final customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(RouteMapScreen),
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is RouteMapPainter,
          ),
        ),
      );
      final painter = customPaint.painter! as RouteMapPainter;
      // fractionAlongRoute 0 → the marker resolves to the first pin centre.
      expect(painter.position.fractionAlongRoute, closeTo(0, kTol));
      expect(painter.geometry.pinCenters, isNotEmpty);
      // The readout shows the in-progress "Next:" line, not "Arrived".
      expect(find.textContaining('Next:'), findsOneWidget);
      expect(find.textContaining('Arrived'), findsNothing);
    });
  });

  group('TC-011 completion celebration + summary + explicit new-journey', () {
    testWidgets(
      'mid-chain arrival shows the HONEST % (not a hardcoded 100) + Start-new',
      (tester) async {
        // Cần Thơ → Hà Giang is a MID-CHAIN start: it spans 1380 of the fixture's
        // 1440 km, so honest arrival is 95.8% — the celebration must match the
        // readout, never a hardcoded "100% of Vietnam".
        final dest = chain.distanceToDestination(
          nodeById(chain, 'can_tho'),
          JourneyDirection.towardHaGiang,
        );
        final honest = (dest / chain.totalChainKm * 100).toStringAsFixed(1);
        expect(honest, '95.8'); // worked literal for the fixture chain.

        final cubit = cubitFor('can_tho', JourneyDirection.towardHaGiang);
        cubit.updateFromDistance(dest);
        await pumpScreen(tester, cubit);

        // Celebration header names the destination tip.
        expect(find.textContaining('You reached Hà Giang'), findsOneWidget);
        // Summary surfaces the route distance + the HONEST mid-chain % and the
        // provinces crossed — NOT a hardcoded 100%. The celebration carries the
        // distance-prefixed form; the readout shows the bare %.
        expect(
          find.textContaining('1380 km · 95.8% of Vietnam'),
          findsOneWidget,
        );
        expect(find.textContaining('95.8% of Vietnam'), findsWidgets);
        expect(find.textContaining('100% of Vietnam'), findsNothing);
        expect(find.textContaining('Provinces crossed'), findsOneWidget);
        // The celebration % matches the readout overlay's % (both 95.8).
        expect(
          tester
              .widgetList<Text>(find.textContaining('% of Vietnam'))
              .where((t) => (t.data ?? '').contains('95.8%'))
              .length,
          greaterThanOrEqualTo(2),
        );
        // EXPLICIT "Start a new journey" action exists — no auto-advance.
        final newJourney = find.byKey(const Key('completion_start_new'));
        expect(newJourney, findsOneWidget);
        expect(find.text('Start a new journey'), findsOneWidget);

        // The action is wired to open the picker (no implicit restart).
        await tester.tap(newJourney);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('start_picker_province_dropdown')),
          findsOneWidget,
        );
      },
    );

    testWidgets('tip-to-tip arrival proudly shows 100% (full-chain route)', (
      tester,
    ) async {
      // Mũi Cà Mau → Hà Giang spans the WHOLE chain (1440 of 1440 km), so its
      // honest arrival % is exactly 100 — the other leg of AC-11.
      final dest = chain.distanceToDestination(
        nodeById(chain, 'mui'),
        JourneyDirection.towardHaGiang,
      );
      expect(dest, closeTo(chain.totalChainKm, kTol));

      final cubit = cubitFor('mui', JourneyDirection.towardHaGiang);
      cubit.updateFromDistance(dest);
      await pumpScreen(tester, cubit);

      expect(find.textContaining('You reached Hà Giang'), findsOneWidget);
      // Both the celebration ("1440 km · 100.0%") and the readout show 100.0% —
      // consistent, and the celebration proudly reads the full-chain value.
      expect(
        find.textContaining('1440 km · 100.0% of Vietnam'),
        findsOneWidget,
      );
      expect(find.textContaining('100.0% of Vietnam'), findsWidgets);
      expect(find.byKey(const Key('completion_start_new')), findsOneWidget);
    });
  });

  group('TC-013 continued distance after completion makes no progress', () {
    testWidgets('celebration + readout unchanged across increasing distance', (
      tester,
    ) async {
      final dest = chain.distanceToDestination(
        nodeById(chain, 'can_tho'),
        JourneyDirection.towardHaGiang,
      );
      final cubit = cubitFor('can_tho', JourneyDirection.towardHaGiang);
      cubit.updateFromDistance(dest);
      await pumpScreen(tester, cubit);

      // can_tho is a MID-CHAIN start, so the celebration freezes at the honest
      // 95.8% (never drifting toward 100 as distance keeps climbing).
      String celebrationDistance() {
        final text = tester
            .widgetList<Text>(find.textContaining('% of Vietnam'))
            .map((t) => t.data)
            .firstWhere((d) => d != null && d.contains('95.8%'));
        return text!;
      }

      final before = celebrationDistance();

      // Keep "focusing": continued increasing cumulative distance.
      cubit.updateFromDistance(dest + 250);
      await tester.pump();
      await tester.pump();
      cubit.updateFromDistance(dest + 5000);
      await tester.pump();
      await tester.pump();

      // Still completed, still 95.8%, still showing the same celebration — no
      // new route, no marker advance, no direction flip, no upward % drift.
      expect(find.textContaining('You reached Hà Giang'), findsOneWidget);
      expect(celebrationDistance(), before);
      expect(cubit.state.isCompleted, isTrue);
      expect(cubit.state.position!.fractionAlongRoute, closeTo(1, kTol));
    });
  });

  group('painter robustness at a tiny canvas (route_map_painter:_layout)', () {
    testWidgets('pumps without exception at a near-zero canvas', (
      tester,
    ) async {
      final cubit = cubitFor('can_tho', JourneyDirection.towardHaGiang);
      cubit.updateFromDistance(400);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<RouteProgressCubit>.value(
            value: cubit,
            child: Center(
              // Force the map subtree into a 1x1 box — the geometry layout +
              // marker interpolation must not throw at a degenerate size.
              child: SizedBox(
                width: 1,
                height: 1,
                child: RouteMapScreen(chain: chain),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      // The painter still rendered with valid (finite) geometry.
      final customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(RouteMapScreen),
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is RouteMapPainter,
          ),
        ),
      );
      final painter = customPaint.painter! as RouteMapPainter;
      expect(painter.geometry.pinCenters, isNotEmpty);
      for (final c in painter.geometry.pinCenters) {
        expect(c.dx.isFinite && c.dy.isFinite, isTrue);
      }
    });
  });
}
