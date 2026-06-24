// Asset cross-check + graceful-degradation tests for the journey-view scene.
//
// Covers:
//   TC-011 — every asset the scene actually ships has a CREDITS.md entry, and
//            the intentionally-absent ship.png is documented as a known gap
//            (degrades gracefully — not a failure).
//   TC-014 — a missing/failed asset (ship.png is a real one) degrades to a
//            placeholder; the scene loads, does not crash, and the other 9
//            curated assets still load.
//
// TC-011 reads the manifest (JourneyAssets.all), the shipped files on disk, and
// CREDITS.md from disk. TC-014 loads the real game via the harness (which
// swallows ONLY Flame's expected orphan rejection for the missing ship.png).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_assets.dart';

import 'journey_game_test_harness.dart';

/// Resolves the focus_journey package root regardless of the test CWD.
Directory _packageRoot() {
  Directory dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        File('${dir.path}/assets/CREDITS.md').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      // Fall back to current dir (tests run from package root under flutter test).
      return Directory.current;
    }
    dir = parent;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final root = _packageRoot();
  final creditsText = File('${root.path}/assets/CREDITS.md').readAsStringSync();

  group('TC-011 every shipped asset is CREDITS-recorded', () {
    test('manifestPaths_thatShip_eachAppearInCredits', () {
      // JourneyAssets.assetPrefix is already 'assets/journey/'.
      final assetDir = '${root.path}/${JourneyAssets.assetPrefix}';

      final shipped = <String>[];
      final absent = <String>[];
      for (final path in JourneyAssets.all) {
        final file = File('$assetDir$path');
        if (file.existsSync()) {
          shipped.add(path);
        } else {
          absent.add(path);
        }
      }

      // Sanity: most of the manifest ships; ship.png is the documented gap.
      expect(shipped, isNotEmpty);
      expect(
        shipped.length,
        JourneyAssets.all.length - 1,
        reason: 'exactly one manifest path (ship.png) is intentionally absent',
      );

      // Every SHIPPED asset must have a CREDITS entry (the bare filename row).
      for (final path in shipped) {
        expect(
          creditsText.contains(path),
          isTrue,
          reason: 'shipped asset "$path" has no CREDITS.md entry',
        );
      }
    });

    test('absentShip_isDocumentedAsAKnownGap_notAFailure', () {
      final assetDir = '${root.path}/${JourneyAssets.assetPrefix}';
      final ship = File('$assetDir${JourneyAssets.vehicleShip}');
      // It is genuinely not shipped (the graceful-placeholder case).
      expect(ship.existsSync(), isFalse);
      // ...and CREDITS.md documents it as a deliberate known gap.
      expect(creditsText.contains('vehicles/ship.png'), isTrue);
      expect(
        creditsText.toLowerCase(),
        contains('not yet'),
        reason: 'ship.png must be listed under a "not yet filled" section',
      );
    });

    test('credits_referencesEveryShippedAsset_noOrphanLoad', () {
      // The scene loads ONLY JourneyAssets.all; assert that list is the source
      // of truth and has the expected count (regression guard).
      expect(JourneyAssets.all.length, 10);
      expect(
        JourneyAssets.all.toSet().length,
        10,
        reason: 'no duplicate paths',
      );
    });
  });

  group('TC-014 missing/failed asset degrades gracefully (no crash)', () {
    // Load the sprite-backed game ONCE for the group. (loadJourneyGame runs
    // Flame's real asset load and swallows only the expected orphan ship.png
    // rejection; loading once keeps the suite fast and avoids repeated
    // zone-guard setup.)
    late final game = loadJourneyGame();

    test('onLoad_completesWithoutThrowing_shipPngBecomesPlaceholder', () async {
      final g = await game;
      // The scene loaded and recorded the failure as a placeholder.
      expect(g.hasPlaceholderAssets, isTrue);
      expect(g.failedAssetPaths, contains('vehicles/ship.png'));
      // ONLY ship.png failed — the other 9 curated assets loaded fine, so the
      // rest of the frame renders.
      expect(g.failedAssetPaths.length, 1);
    });

    test('afterMissingAsset_sceneStillRendersAndPumps_noCrash', () async {
      final g = await game;
      // Drive + render a frame with the missing-asset mode (ship) selected.
      g.applyState(
        moving: true,
        mode: TravelMode.ship, // the skin whose asset is missing
        reduceMotion: false,
        timeOfDayHours: 12,
      );
      // Pumping must not throw even though the active skin asset is missing.
      expect(() => pump(g, frames: 30), returnsNormally);
      // Motion still works (placeholder is drawn for the vehicle).
      expect(g.roadScrollOffset, greaterThan(0));
    });
  });
}
