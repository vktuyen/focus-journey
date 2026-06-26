// Widget tests for the icon-based VehiclePicker + its two entry points binding
// the single SettingsCubit preference. Authored by test-script-author from
// tests/cases/vehicle-picker.md. One group per case; each carries its TC-id +
// AC-id. No real OS / timers / shared_preferences — an in-memory SettingsCubit.
//
//   TC-614 (AC-14) — a DISTINCT icon per all six TravelMode.values; an icon-based
//                  picker (a tappable icon chip per mode), NOT a bare text
//                  DropdownButton<TravelMode>.
//   TC-617 (NFR-3 / AC-14) — each of the six options carries a per-mode Semantics
//                  label naming the mode ("Walk".."Ship"), is focus-reachable
//                  (a real focusable control in the tree), and the picker does not
//                  trap focus (focus can leave it).
//   TC-611 (AC-11) — both entry points bind the SAME SettingsCubit.setVehicle:
//                  the persistent (settings) picker and the route-start picker
//                  read/write one AppSettings.vehiclePreference — a change in one
//                  is reflected in the other (no second store).
//   TC-612 (AC-12) — the route-start picker is PRE-SEEDED from the saved
//                  preference (initial selection == saved value); with no
//                  preference it pre-seeds to the engine-default display (motorbike).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/stats/domain/app_settings.dart';
import 'package:focus_journey/features/stats/presentation/settings_cubit.dart';
import 'package:focus_journey/features/stats/presentation/vehicle_picker.dart';

import '../stats_test_fixtures.dart';

/// Whether the chip Semantics for [mode] (the one carrying the per-mode label)
/// is marked `selected`. Matches the explicit `Semantics(label: vehicleLabel,
/// selected: ...)` on `_VehicleChip` (not the container or Tooltip semantics).
bool _modeSelected(WidgetTester tester, TravelMode mode) {
  final matches = tester
      .widgetList<Semantics>(find.byType(Semantics))
      .where((s) => s.properties.label == vehicleLabel(mode))
      .toList();
  expect(matches, isNotEmpty,
      reason: 'a labelled chip Semantics for $mode must exist');
  return matches.any((s) => s.properties.selected == true);
}

SettingsCubit _settings({AppSettings? initial}) {
  return SettingsCubit(
    repository: InMemorySettingsRepository(),
    startupController: FakeStartupController(),
    applyIdleThreshold: (_) {},
    initialSettings: initial,
  );
}

/// Mounts a bare [VehiclePicker] with the given [selected] + an onSelected sink.
Future<void> _pumpPicker(
  WidgetTester tester, {
  required TravelMode selected,
  required ValueChanged<TravelMode> onSelected,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: VehiclePicker(selected: selected, onSelected: onSelected),
      ),
    ),
  );
}

void main() {
  // ===========================================================================
  // TC-614 (AC-14) — distinct icon per all six modes; not a text dropdown.
  // ===========================================================================
  group('TC-614 distinct icon per all six modes; not a text dropdown (AC-14)', () {
    testWidgets('everyModeHasAChip_andNoTwoModesShareAnIconPath', (tester) async {
      await _pumpPicker(
        tester,
        selected: TravelMode.motorbike,
        onSelected: (_) {},
      );

      // One tappable icon chip per mode (by stable key), for all six modes.
      for (final TravelMode mode in TravelMode.values) {
        expect(
          find.byKey(Key('vehicle-chip-${mode.name}')),
          findsOneWidget,
          reason: 'a chip must exist for $mode',
        );
      }

      // The six requested icon paths are DISTINCT (a distinct glyph per mode).
      final Set<String> paths = <String>{
        for (final TravelMode mode in TravelMode.values) vehicleIconAsset(mode),
      };
      expect(
        paths.length,
        TravelMode.values.length,
        reason: 'each of the six modes must map to a distinct icon path',
      );

      // It is an ICON-based picker, not a bare text dropdown.
      expect(
        find.byType(DropdownButton<TravelMode>),
        findsNothing,
        reason: 'the picker must be icon-based, not a DropdownButton<TravelMode>',
      );
      // The chips render their per-mode glyph as an image (not just text labels).
      expect(find.byType(Image), findsNWidgets(TravelMode.values.length));
    });
  });

  // ===========================================================================
  // TC-617 (NFR-3 / AC-14) — per-mode semantics labels + focus reach, no trap.
  // ===========================================================================
  group('TC-617 per-mode semantics labels + focus reach, no focus trap (NFR-3)', () {
    testWidgets('eachOption_carriesASemanticsLabelNamingTheMode', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPicker(
        tester,
        selected: TravelMode.motorbike,
        onSelected: (_) {},
      );

      // Each of the six modes exposes a Semantics label naming the mode.
      for (final TravelMode mode in TravelMode.values) {
        expect(
          find.bySemanticsLabel(vehicleLabel(mode)),
          findsOneWidget,
          reason: 'option $mode must carry the semantics label '
              '"${vehicleLabel(mode)}"',
        );
      }
      // The labels are the human mode names (not colour / index).
      expect(vehicleLabel(TravelMode.car), 'Car');
      expect(vehicleLabel(TravelMode.motorbike), 'Motorbike');
      handle.dispose();
    });

    testWidgets('everyChipIsAFocusableTappableControl', (tester) async {
      await _pumpPicker(
        tester,
        selected: TravelMode.walk,
        onSelected: (_) {},
      );
      // Each chip is an InkWell (keyboard/pointer operable, in focus traversal).
      expect(find.byType(InkWell), findsNWidgets(TravelMode.values.length));
    });

    testWidgets('pickerDoesNotTrapFocus_focusCanReachAControlAfterIt', (
      tester,
    ) async {
      // Place a focusable control AFTER the picker; tab/focus must be able to
      // reach it (the picker does not trap focus).
      final after = FocusNode();
      addTearDown(after.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                VehiclePicker(selected: TravelMode.car, onSelected: (_) {}),
                TextButton(
                  focusNode: after,
                  onPressed: () {},
                  child: const Text('After'),
                ),
              ],
            ),
          ),
        ),
      );
      after.requestFocus();
      await tester.pump();
      expect(
        after.hasFocus,
        isTrue,
        reason: 'focus must be able to land beyond the picker (no trap)',
      );
    });
  });

  // ===========================================================================
  // TC-611 (AC-11) — both entry points bind the SAME SettingsCubit preference.
  // ===========================================================================
  group('TC-611 two entry points, one source — no divergence (AC-11)', () {
    testWidgets('changeViaOnePicker_isReflectedInTheOther_oneCubit', (
      tester,
    ) async {
      // ONE SettingsCubit drives BOTH pickers (persistent + route-start). They
      // both write through setVehicle and both read state.vehiclePreference.
      final settings = _settings();
      addTearDown(settings.close);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<SettingsCubit>.value(
            value: settings,
            child: Scaffold(
              body: BlocBuilder<SettingsCubit, AppSettings>(
                builder: (context, s) {
                  final TravelMode selected =
                      s.vehiclePreference ?? TravelMode.motorbike;
                  return Column(
                    children: <Widget>[
                      // "persistent" picker
                      VehiclePicker(
                        key: const Key('persistent-picker'),
                        selected: selected,
                        onSelected: settings.setVehicle,
                      ),
                      // "route-start" picker — SAME cubit, SAME preference
                      VehiclePicker(
                        key: const Key('routestart-picker'),
                        selected: selected,
                        onSelected: settings.setVehicle,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Change via the PERSISTENT picker → both pickers + the preference read m1.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('persistent-picker')),
          matching: find.byKey(const Key('vehicle-chip-bicycle')),
        ),
      );
      await tester.pumpAndSettle();
      expect(settings.state.vehiclePreference, TravelMode.bicycle);

      // Change via the ROUTE-START picker → the single preference reads m2.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('routestart-picker')),
          matching: find.byKey(const Key('vehicle-chip-ship')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        settings.state.vehiclePreference,
        TravelMode.ship,
        reason: 'both pickers write the ONE AppSettings.vehiclePreference',
      );
    });
  });

  // ===========================================================================
  // TC-612 (AC-12) — route-start picker is pre-seeded from the saved preference.
  // ===========================================================================
  group('TC-612 route-start picker pre-seeded from the saved preference (AC-12)', () {
    testWidgets('savedPreference_seedsTheInitialSelection', (tester) async {
      // The host pre-seeds `selected` from the saved value (settings_screen /
      // journey affordance pattern: vehiclePreference ?? motorbike).
      final settings = _settings(
        initial: const AppSettings(vehiclePreference: TravelMode.car),
      );
      addTearDown(settings.close);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<SettingsCubit>.value(
            value: settings,
            child: Scaffold(
              body: BlocBuilder<SettingsCubit, AppSettings>(
                builder: (context, s) => VehiclePicker(
                  selected: s.vehiclePreference ?? TravelMode.motorbike,
                  onSelected: settings.setVehicle,
                ),
              ),
            ),
          ),
        ),
      );

      // The car chip is the SELECTED one (pre-seeded), not a blank/default.
      expect(
        _modeSelected(tester, TravelMode.car),
        isTrue,
        reason: 'the route-start picker opens pre-seeded to the saved car pick',
      );
    });

    testWidgets('noPreference_preSeedsToMotorbike', (tester) async {
      final settings = _settings(); // vehiclePreference == null
      addTearDown(settings.close);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<SettingsCubit>.value(
            value: settings,
            child: Scaffold(
              body: BlocBuilder<SettingsCubit, AppSettings>(
                builder: (context, s) => VehiclePicker(
                  selected: s.vehiclePreference ?? TravelMode.motorbike,
                  onSelected: settings.setVehicle,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        _modeSelected(tester, TravelMode.motorbike),
        isTrue,
        reason: 'with no preference the route-start picker pre-seeds to motorbike',
      );
    });
  });
}
