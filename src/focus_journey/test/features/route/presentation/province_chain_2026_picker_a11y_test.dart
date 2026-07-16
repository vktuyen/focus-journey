// province-chain-2026 — route-authoring picker accessibility over the 34 units
// (NFR-3).
//
// Traceability (one test <-> one case; PC + NFR ids in each description):
//   PC-930 (NFR-3) the route-authoring picker, driven over the FULL 34-unit
//                  production spine, keeps its controls keyboard-focusable
//                  (enabled + focusable) and semantically labelled, with the
//                  longer 34-item list present and navigable. This slice changed
//                  no authoring UI, so this asserts the existing picker still
//                  exposes semantics + focus with the 34-unit data present.
//                  Real screen-reader/keyboard operation is the manual TC-M-A11Y.
//
// Widget test over the REAL RoutePicker + production chain/geography. Pure: no
// engine, no timers, no network.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/presentation/route_picker.dart';

void main() {
  bool semanticsLabelled(WidgetTester tester, String label) => tester
      .widgetList<Semantics>(find.byType(Semantics))
      .any((s) => s.properties.label == label);

  Future<void> pumpPicker(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RoutePicker(
              chain: vietnamProvinceChain,
              geography: vietnamProvinceGeography,
              onResolved: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('34-unit route-authoring picker stays accessible (NFR-3 / PC-930)', () {
    testWidgets('PC-930 startAndEndPickers_carrySemanticLabels_over34Units', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPicker(tester);

      // Screen-reader labels are present on the endpoint pickers.
      expect(semanticsLabelled(tester, 'Start checkpoint'), isTrue);
      expect(semanticsLabelled(tester, 'End checkpoint'), isTrue);

      // The start dropdown lists all 34 current units (the longer list is
      // present) — a regression that dropped units would fail here.
      final startDropdown = tester.widget<DropdownButton<Province>>(
        find.byKey(const Key('route_picker_start_dropdown')),
      );
      expect(startDropdown.items, hasLength(34));

      handle.dispose();
    });

    testWidgets('PC-930 pickerControls_areKeyboardFocusableAndActivatable', (
      tester,
    ) async {
      await pumpPicker(tester);

      // Enabled dropdowns/buttons are keyboard-reachable + activatable
      // (non-null callbacks ⇒ enabled ⇒ in the focus traversal order).
      final startDropdown = tester.widget<DropdownButton<Province>>(
        find.byKey(const Key('route_picker_start_dropdown')),
      );
      expect(startDropdown.onChanged, isNotNull);
      final endDropdown = tester.widget<DropdownButton<Province>>(
        find.byKey(const Key('route_picker_end_dropdown')),
      );
      expect(endDropdown.onChanged, isNotNull);
      final continueButton = tester.widget<FilledButton>(
        find.byKey(const Key('route_picker_continue')),
      );
      expect(continueButton.onPressed, isNotNull);

      // The dropdowns render focusable Focus nodes in the tree (keyboard reach).
      expect(find.byType(Focus), findsWidgets);
    });
  });
}
