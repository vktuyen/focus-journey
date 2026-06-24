// Picker widget test for route-progress.
//
// Covers TC-015 (chain-tip off-direction blocked in the picker + model guard):
//   - For a north tip (Hà Giang), the "north" (towardHaGiang) direction tile is
//     DISABLED / unavailable, so the off-chain direction can never be committed.
//   - For a south tip (Mũi Cà Mau), the "south" (towardMuiCaMau) tile is disabled.
//   - A valid (mid-chain) start + direction confirms and fires onConfirm.
//   - Negative model leg: RouteSelection.create rejects an off-direction tip pair
//     (the implementer added the model-level guard, so we assert it rather than
//     relaxing to picker-only).
//
// Conventions mirror test/features/journey/presentation/journey_screen_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/route_selection.dart';
import 'package:focus_journey/features/route/presentation/start_picker.dart';

import '../route_test_fixtures.dart';

void main() {
  late ProvinceChain chain;

  setUp(() {
    chain = buildFixtureChain();
  });

  Future<void> pumpPicker(
    WidgetTester tester, {
    Province? initialStart,
    JourneyDirection? initialDirection,
    void Function(Province, JourneyDirection)? onConfirm,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StartPicker(
              chain: chain,
              initialStart: initialStart,
              initialDirection: initialDirection,
              onConfirm: onConfirm ?? (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Reads the `enabled` flag of the RadioListTile under [tileKey].
  bool tileEnabled(WidgetTester tester, Key tileKey) {
    final tile = tester.widget<RadioListTile<JourneyDirection>>(
      find.descendant(
        of: find.byKey(tileKey),
        matching: find.byType(RadioListTile<JourneyDirection>),
      ),
    );
    return tile.enabled ?? true;
  }

  group('TC-015 off-direction tip blocked in the picker', () {
    testWidgets('north tip (Hà Giang) → north direction tile is disabled', (
      tester,
    ) async {
      await pumpPicker(tester, initialStart: nodeById(chain, 'ha_giang'));
      // Off-chain for the north tip: towardHaGiang is unavailable.
      expect(
        tileEnabled(tester, const Key('direction_toward_ha_giang')),
        isFalse,
      );
      // The on-chain direction stays available.
      expect(
        tileEnabled(tester, const Key('direction_toward_mui_ca_mau')),
        isTrue,
      );
      expect(find.textContaining('unavailable from this start'), findsWidgets);
    });

    testWidgets('south tip (Mũi Cà Mau) → south direction tile is disabled', (
      tester,
    ) async {
      await pumpPicker(tester, initialStart: nodeById(chain, 'mui'));
      expect(
        tileEnabled(tester, const Key('direction_toward_mui_ca_mau')),
        isFalse,
      );
      expect(
        tileEnabled(tester, const Key('direction_toward_ha_giang')),
        isTrue,
      );
    });

    testWidgets('confirm is disabled until a valid direction is chosen', (
      tester,
    ) async {
      await pumpPicker(tester, initialStart: nodeById(chain, 'can_tho'));
      // No direction selected yet ⇒ the confirm button is disabled.
      final before = tester.widget<FilledButton>(
        find.byKey(const Key('start_picker_confirm')),
      );
      expect(before.onPressed, isNull);
    });

    testWidgets(
      'changing start to a tip that invalidates the chosen direction clears it '
      'and re-gates confirm',
      (tester) async {
        Province? gotStart;
        JourneyDirection? gotDir;
        // Start mid-chain (Cần Thơ) with north pre-selected — confirm enabled.
        await pumpPicker(
          tester,
          initialStart: nodeById(chain, 'can_tho'),
          initialDirection: JourneyDirection.towardHaGiang,
          onConfirm: (s, d) {
            gotStart = s;
            gotDir = d;
          },
        );
        expect(
          tileEnabled(tester, const Key('direction_toward_ha_giang')),
          isTrue,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('start_picker_confirm')),
              )
              .onPressed,
          isNotNull,
        );

        // Switch the start to the NORTH TIP (Hà Giang): north now points off the
        // chain, so the north tile must disable and the chosen direction clears.
        await tester.tap(
          find.byKey(const Key('start_picker_province_dropdown')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hà Giang').last);
        await tester.pumpAndSettle();

        expect(
          tileEnabled(tester, const Key('direction_toward_ha_giang')),
          isFalse,
        );
        // The previously-valid selection was coerced away ⇒ confirm re-gated.
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('start_picker_confirm')),
              )
              .onPressed,
          isNull,
        );

        // Tapping confirm now does nothing (it is disabled) — no invalid commit.
        await tester.tap(
          find.byKey(const Key('start_picker_confirm')),
          warnIfMissed: false,
        );
        await tester.pump();
        expect(gotStart, isNull);
        expect(gotDir, isNull);
      },
    );

    testWidgets('a valid mid-chain start+direction confirms', (tester) async {
      Province? gotStart;
      JourneyDirection? gotDir;
      await pumpPicker(
        tester,
        initialStart: nodeById(chain, 'can_tho'),
        initialDirection: JourneyDirection.towardHaGiang,
        onConfirm: (s, d) {
          gotStart = s;
          gotDir = d;
        },
      );
      await tester.tap(find.byKey(const Key('start_picker_confirm')));
      await tester.pump();
      expect(gotStart?.id, 'can_tho');
      expect(gotDir, JourneyDirection.towardHaGiang);
    });
  });

  group(
    'TC-015 negative model leg — RouteSelection.create guards the pair',
    () {
      test(
        'rejects north tip + north direction (off-chain → would finish at 0)',
        () {
          expect(
            () => RouteSelection.create(
              start: nodeById(chain, 'ha_giang'),
              direction: JourneyDirection.towardHaGiang,
              routeStartOffsetKm: 0,
              chain: chain,
            ),
            throwsArgumentError,
          );
        },
      );

      test('rejects south tip + south direction', () {
        expect(
          () => RouteSelection.create(
            start: nodeById(chain, 'mui'),
            direction: JourneyDirection.towardMuiCaMau,
            routeStartOffsetKm: 0,
            chain: chain,
          ),
          throwsArgumentError,
        );
      });

      test('accepts a tip pointed back along the chain (Hà Giang south)', () {
        final sel = RouteSelection.create(
          start: nodeById(chain, 'ha_giang'),
          direction: JourneyDirection.towardMuiCaMau,
          routeStartOffsetKm: 0,
          chain: chain,
        );
        expect(sel.start.id, 'ha_giang');
        expect(sel.direction, JourneyDirection.towardMuiCaMau);
      });
    },
  );
}
