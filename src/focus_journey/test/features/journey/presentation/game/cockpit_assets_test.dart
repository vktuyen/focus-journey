// Unit tests for the journey-pov cockpit additions to the asset manifest.
//
// Covers (code-level, deterministic; no I/O, no Canvas):
//   * The 7 cockpit glyph paths are all present in JourneyAssets.all.
//   * JourneyAssets.cockpitCar / .cockpitMotorbike contain EXACTLY the expected
//     paths, in draw order (journey-pov AC-1/AC-3/AC-17 seam).
//   * JourneyAssets.all has no duplicate paths.
//
// These pin the manifest contract the CockpitPainter + JourneyGame seams read.
// Disk/CREDITS cross-checks (TC-011) live in journey_assets_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_assets.dart';

void main() {
  group('JourneyAssets cockpit manifest (journey-pov)', () {
    // The 7 cockpit glyph paths the painter may request.
    const List<String> cockpitGlyphs = <String>[
      JourneyAssets.cockpitCarSteeringWheel,
      JourneyAssets.cockpitCarDashboard,
      JourneyAssets.cockpitCarSpeedometer,
      JourneyAssets.cockpitCarFuelGauge,
      JourneyAssets.cockpitMotorbikeHandlebar,
      JourneyAssets.cockpitMotorbikeGaugePod,
      JourneyAssets.cockpitMotorbikeFuelTank,
    ];

    test('all_sevenCockpitGlyphs_appearInAll', () {
      for (final String path in cockpitGlyphs) {
        expect(
          JourneyAssets.all,
          contains(path),
          reason: 'cockpit glyph "$path" must be in JourneyAssets.all',
        );
      }
    });

    test('all_containsNoDuplicatePaths', () {
      expect(
        JourneyAssets.all.toSet().length,
        JourneyAssets.all.length,
        reason: 'JourneyAssets.all must have no duplicate paths',
      );
    });

    test('cockpitCar_isExactlyTheFourCarPaths_inDrawOrder', () {
      expect(
        JourneyAssets.cockpitCar,
        orderedEquals(<String>[
          JourneyAssets.cockpitCarDashboard,
          JourneyAssets.cockpitCarSpeedometer,
          JourneyAssets.cockpitCarFuelGauge,
          JourneyAssets.cockpitCarSteeringWheel,
        ]),
      );
    });

    test('cockpitMotorbike_isExactlyTheThreeMotorbikePaths_inDrawOrder', () {
      expect(
        JourneyAssets.cockpitMotorbike,
        orderedEquals(<String>[
          JourneyAssets.cockpitMotorbikeFuelTank,
          JourneyAssets.cockpitMotorbikeGaugePod,
          JourneyAssets.cockpitMotorbikeHandlebar,
        ]),
      );
    });

    test('cockpitCar_hasNoDuplicates', () {
      expect(
        JourneyAssets.cockpitCar.toSet().length,
        JourneyAssets.cockpitCar.length,
      );
    });

    test('cockpitMotorbike_hasNoDuplicates', () {
      expect(
        JourneyAssets.cockpitMotorbike.toSet().length,
        JourneyAssets.cockpitMotorbike.length,
      );
    });

    test('cockpitCarAndMotorbike_areDisjoint', () {
      final overlap = JourneyAssets.cockpitCar.toSet().intersection(
        JourneyAssets.cockpitMotorbike.toSet(),
      );
      expect(
        overlap,
        isEmpty,
        reason: 'car and motorbike cockpit glyphs must not share paths',
      );
    });

    test('everyCockpitListPath_isAlsoInAll', () {
      for (final String path in <String>[
        ...JourneyAssets.cockpitCar,
        ...JourneyAssets.cockpitMotorbike,
      ]) {
        expect(
          JourneyAssets.all,
          contains(path),
          reason: 'cockpit list path "$path" must be in JourneyAssets.all',
        );
      }
    });

    test('cockpitPaths_liveUnderTheCockpitDirectory', () {
      for (final String path in cockpitGlyphs) {
        expect(
          path,
          startsWith('cockpit/'),
          reason: 'cockpit glyph paths must live under cockpit/',
        );
      }
    });
  });
}
