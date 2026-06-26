// Widget tests for the route-start vehicle-pick surfacing on the
// RouteReviewScreen confirm step. Authored by test-script-author from
// tests/cases/vehicle-picker.md. Drives the REAL review screen over the fixture
// chain with the SKIPPABLE vehiclePicker bound to a single in-memory
// SettingsCubit (cosmetic-only — the route is untouched). Pure: no engine, no
// timers, no network.
//
//   TC-613 (AC-13) — route-start surfaces the skippable, pre-seeded picker;
//                  picking a vehicle m' and confirming WRITES m' back to the same
//                  vehiclePreference (survives per AC-5/AC-6) and the route still
//                  confirms with the chosen candidate; the SKIP leg — confirming
//                  WITHOUT touching the picker — leaves the preference unchanged
//                  and still confirms the route (not a mandatory step). The route
//                  resolver/candidate never stores the vehicle (ADR-0007 dec 4).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_planner.dart';
import 'package:focus_journey/features/route/presentation/route_review_screen.dart';
import 'package:focus_journey/features/stats/domain/app_settings.dart';
import 'package:focus_journey/features/stats/presentation/settings_cubit.dart';
import 'package:focus_journey/features/stats/presentation/vehicle_picker.dart';

import '../../stats/stats_test_fixtures.dart';
import '../map_test_fixtures.dart';

void main() {
  late ProvinceChain chain;
  late ProvinceGeography geography;

  setUp(() {
    chain = buildFixtureChain();
    geography = buildFixtureGeography(chain);
  });

  SettingsCubit settingsCubit({AppSettings? initial}) => SettingsCubit(
        repository: InMemorySettingsRepository(),
        startupController: FakeStartupController(),
        applyIdleThreshold: (_) {},
        initialSettings: initial,
      );

  ResolvedRoute resolve(String startId, String endId) => RoutePlanner.resolve(
        fullChain: chain,
        fullGeography: geography,
        start: nodeById(chain, startId),
        end: nodeById(chain, endId),
      );

  /// Mounts the RouteReviewScreen with the route-start vehicle control wired to
  /// [settings] (pre-seeded from the saved preference, writing back via setVehicle).
  /// [onConfirm] captures the confirmed candidate when the user taps "Start".
  Future<void> pumpReview(
    WidgetTester tester, {
    required SettingsCubit settings,
    required ResolvedRoute initial,
    required void Function(ResolvedRoute) onConfirm,
  }) async {
    final start = initial.orderedNodes.first;
    final end = initial.orderedNodes.last;
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<SettingsCubit>.value(
          value: settings,
          child: Scaffold(
            body: SingleChildScrollView(
              child: BlocBuilder<SettingsCubit, AppSettings>(
                builder: (context, s) => RouteReviewScreen(
                  chain: chain,
                  geography: geography,
                  start: start,
                  end: end,
                  initial: initial,
                  onConfirm: onConfirm,
                  onCancel: () {},
                  vehiclePicker: VehiclePicker(
                    key: const Key('route-start-vehicle-picker'),
                    selected: s.vehiclePreference ?? TravelMode.motorbike,
                    onSelected: settings.setVehicle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool chipSelected(WidgetTester tester, TravelMode mode) {
    final matches = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((s) => s.properties.label == vehicleLabel(mode))
        .toList();
    expect(matches, isNotEmpty, reason: 'a labelled chip for $mode must exist');
    return matches.any((s) => s.properties.selected == true);
  }

  group('TC-613 route-start surfaces the skippable, pre-seeded picker (AC-13)', () {
    testWidgets('pickVehicle_thenConfirm_writesBackThePick_andRouteConfirms', (
      tester,
    ) async {
      final settings = settingsCubit(); // null → motorbike display
      addTearDown(settings.close);
      final initial = resolve('mui', 'da_nang');
      ResolvedRoute? confirmed;
      await pumpReview(
        tester,
        settings: settings,
        initial: initial,
        onConfirm: (r) => confirmed = r,
      );

      // The control surfaced on the review/confirm step.
      expect(find.byKey(const Key('route-start-vehicle-picker')), findsOneWidget);
      expect(find.text('Vehicle for this journey'), findsOneWidget);

      // Pick a vehicle m' = ship on the route-start step.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('route-start-vehicle-picker')),
          matching: find.byKey(const Key('vehicle-chip-ship')),
        ),
      );
      await tester.pumpAndSettle();

      // The pick is written back to the SAME preference (survives per AC-5/AC-6).
      expect(settings.state.vehiclePreference, TravelMode.ship);

      // Confirming the route still fires onConfirm with the candidate.
      await tester.tap(find.byKey(const Key('route_review_confirm')));
      await tester.pumpAndSettle();
      expect(confirmed, isNotNull,
          reason: 'confirming the route must still fire onConfirm');
      // The pick was NOT discarded by confirming.
      expect(settings.state.vehiclePreference, TravelMode.ship);
      // The route candidate carries the route only — never the vehicle.
      expect(confirmed!.orderedNodes.first.id, 'mui');
      expect(confirmed!.orderedNodes.last.id, 'da_nang');
    });

    testWidgets('skipLeg_confirmWithoutTouchingThePicker_keepsTheCurrentVehicle', (
      tester,
    ) async {
      // A saved car preference; the user does NOT touch the picker, just confirms.
      final settings = settingsCubit(
        initial: const AppSettings(vehiclePreference: TravelMode.car),
      );
      addTearDown(settings.close);
      final initial = resolve('mui', 'da_nang');
      ResolvedRoute? confirmed;
      await pumpReview(
        tester,
        settings: settings,
        initial: initial,
        onConfirm: (r) => confirmed = r,
      );

      // Pre-seeded to the saved car pick (AC-12 leg surfaced here too).
      expect(chipSelected(tester, TravelMode.car), isTrue);

      // Confirm WITHOUT touching the picker.
      await tester.tap(find.byKey(const Key('route_review_confirm')));
      await tester.pumpAndSettle();

      // The current vehicle is unchanged (skippable — not a mandatory step) and
      // the route still confirms.
      expect(settings.state.vehiclePreference, TravelMode.car);
      expect(confirmed, isNotNull);
    });
  });
}
