// Widget + unit tests for the VehiclePicker (vehicle-picker AC-14 / NFR-3 /
// AC-15 mapping, TC-614 / TC-617). Deterministic — no engine, no OS, no
// shared_preferences. The picker is a Wrap of icon chips (one per
// TravelMode.values), each a keyboard-reachable InkWell carrying a per-mode
// Semantics button+selected label. These tests pin:
//   * a distinct chip per all six modes — icon-based, NOT a DropdownButton (AC-14);
//   * the current mode is marked selected and tapping a chip reports it (AC-14);
//   * each chip exposes a per-mode screen-reader label and is focus-reachable
//     (NFR-3 widget leg);
//   * vehicleIconAsset returns a distinct vehicle_icons/*.png path per mode and
//     these picker-UI paths are deliberately NOT in JourneyAssets.all (the
//     scene-asset manifest stays scoped).
//
// The chips render Image.asset over the (test-time absent) icon files; the
// orphan "Unable to load asset" rejection is drained via takeException so it
// does not mask real failures, matching the journey_screen_test harness.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_assets.dart';
import 'package:focus_journey/features/stats/presentation/vehicle_picker.dart';

/// Drains Flame/Flutter's expected orphan missing-asset rejection (the icon
/// PNGs are not bundled in the test harness), rethrowing anything else.
void _drainAssetException(WidgetTester tester) {
  final ex = tester.takeException();
  if (ex != null && !ex.toString().contains('Unable to load asset')) {
    throw ex as Object;
  }
}

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
  await tester.pump();
  _drainAssetException(tester);
}

void main() {
  group('VehiclePicker — distinct chip per all six modes, not a dropdown (AC-14)', () {
    testWidgets('rendersOneChipPerTravelModeValue', (tester) async {
      await _pumpPicker(
        tester,
        selected: TravelMode.motorbike,
        onSelected: (_) {},
      );

      // One keyed InkWell chip per mode — all six present and distinct.
      for (final TravelMode mode in TravelMode.values) {
        expect(
          find.byKey(Key('vehicle-chip-${mode.name}')),
          findsOneWidget,
          reason: 'a chip for ${mode.name} must render',
        );
      }
      expect(
        find.byType(InkWell),
        findsNWidgets(TravelMode.values.length),
      );
    });

    testWidgets('isIconBased_notATextDropdown', (tester) async {
      await _pumpPicker(
        tester,
        selected: TravelMode.car,
        onSelected: (_) {},
      );
      // Visual icon-based picker — NOT a DropdownButton of text labels.
      expect(find.byType(DropdownButton<TravelMode>), findsNothing);
      expect(find.byType(DropdownButton), findsNothing);
      // Each chip carries an icon glyph (Image), not just a text row.
      expect(find.byType(Image), findsNWidgets(TravelMode.values.length));
    });
  });

  group('VehiclePicker — selection + tap callback (AC-14)', () {
    testWidgets('marksTheCurrentModeAsSelectedViaSemantics', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpPicker(
        tester,
        selected: TravelMode.car,
        onSelected: (_) {},
      );

      // The selected chip carries the Semantics selected flag; others do not.
      expect(
        tester.getSemantics(find.byKey(const Key('vehicle-chip-car'))),
        containsSemantics(isSelected: true),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('vehicle-chip-walk'))),
        containsSemantics(isSelected: false),
      );
      semantics.dispose();
    });

    testWidgets('tappingAChip_invokesOnSelectedWithThatMode', (tester) async {
      TravelMode? picked;
      await _pumpPicker(
        tester,
        selected: TravelMode.motorbike,
        onSelected: (mode) => picked = mode,
      );

      await tester.tap(find.byKey(const Key('vehicle-chip-ship')));
      await tester.pump();
      _drainAssetException(tester);

      expect(picked, TravelMode.ship);
    });

    testWidgets('tappingEachChip_reportsItsOwnMode', (tester) async {
      final List<TravelMode> picks = <TravelMode>[];
      await _pumpPicker(
        tester,
        selected: TravelMode.motorbike,
        onSelected: picks.add,
      );

      for (final TravelMode mode in TravelMode.values) {
        await tester.tap(find.byKey(Key('vehicle-chip-${mode.name}')));
        await tester.pump();
        _drainAssetException(tester);
      }
      expect(picks, TravelMode.values);
    });
  });

  group('VehiclePicker — per-mode label + focus-reachable (NFR-3 widget leg)', () {
    testWidgets('eachChipExposesAPerModeScreenReaderLabel', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpPicker(
        tester,
        selected: TravelMode.motorbike,
        onSelected: (_) {},
      );

      // Each mode is named in the semantics tree (e.g. "Walk", "Car", "Ship").
      for (final TravelMode mode in TravelMode.values) {
        expect(
          find.bySemanticsLabel(vehicleLabel(mode)),
          findsWidgets,
          reason: 'mode ${mode.name} must be named "${vehicleLabel(mode)}"',
        );
      }
      semantics.dispose();
    });

    testWidgets('eachChipIsAButtonInTheSemanticsTree', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpPicker(
        tester,
        selected: TravelMode.motorbike,
        onSelected: (_) {},
      );
      for (final TravelMode mode in TravelMode.values) {
        expect(
          tester.getSemantics(find.byKey(Key('vehicle-chip-${mode.name}'))),
          containsSemantics(isButton: true),
          reason: '${mode.name} chip must be an operable button',
        );
      }
      semantics.dispose();
    });

    testWidgets('eachChipIsFocusReachable_keyboardOperable', (tester) async {
      await _pumpPicker(
        tester,
        selected: TravelMode.motorbike,
        onSelected: (_) {},
      );
      // The chips are InkWells (focus nodes in the traversal) — they are
      // reachable without a pointer. Each InkWell declares an onTap, so it is
      // operable (activatable) by the keyboard, not pointer-only.
      final Iterable<InkWell> inkwells = tester
          .widgetList<InkWell>(find.byType(InkWell));
      expect(inkwells, hasLength(TravelMode.values.length));
      for (final InkWell w in inkwells) {
        expect(w.onTap, isNotNull, reason: 'chip must be keyboard-activatable');
      }
    });
  });

  group('vehicleIconAsset — distinct picker-UI path per mode (AC-14 / AC-15)', () {
    test('returnsAVehicleIconsPathForEachMode', () {
      for (final TravelMode mode in TravelMode.values) {
        final path = vehicleIconAsset(mode);
        expect(
          path,
          startsWith('assets/journey/vehicle_icons/'),
          reason: '$mode icon must live under the picker-icon folder',
        );
        expect(path, endsWith('.png'));
      }
    });

    test('everyModeMapsToADistinctIconPath', () {
      final paths = TravelMode.values.map(vehicleIconAsset).toList();
      expect(
        paths.toSet(),
        hasLength(TravelMode.values.length),
        reason: 'no two modes may share the same picker icon',
      );
    });

    test('pickerIconPaths_areNotInJourneyAssetsAll', () {
      // The picker-UI glyphs are SEPARATE from the in-scene Flame sprites — they
      // must not leak into the scene-asset manifest's cross-check scope.
      for (final TravelMode mode in TravelMode.values) {
        final path = vehicleIconAsset(mode);
        expect(
          JourneyAssets.all,
          isNot(contains(path)),
          reason: '$path must not be in the scene manifest',
        );
        // Nor the Flame-prefix-relative form.
        final relative = path.replaceFirst(JourneyAssets.assetPrefix, '');
        expect(JourneyAssets.all, isNot(contains(relative)));
      }
    });
  });

  group('vehicleLabel — human-readable name per mode (NFR-3)', () {
    test('namesEveryModeDistinctlyAndNonEmpty', () {
      final labels = TravelMode.values.map(vehicleLabel).toList();
      expect(labels.every((l) => l.isNotEmpty), isTrue);
      expect(labels.toSet(), hasLength(TravelMode.values.length));
    });
  });
}
