// Asset cross-check + graceful-degradation tests for the journey-view scene.
//
// Covers:
//   TC-011 — every asset the scene actually ships has a CREDITS.md entry, and
//            the intentionally-absent procedural cockpit shapes are documented
//            as known gaps (degrade gracefully — not a failure).
//   TC-014 — a missing/failed asset (the 3 procedural cockpit shapes) degrades
//            to a placeholder; the scene loads, does not crash, and the other
//            curated assets still load.
//
// journey-scene-art-v3 churn-repair (Part A): the wholesale re-source SHIPPED
// vehicles/ship.png (was the long-standing absent fixture) and RETIRED the four
// v1 objects/* roadside paths (they are no longer in JourneyAssets at all). So:
//   * the "absent path" fixture is re-pointed to the 3 genuinely-procedural
//     cockpit shapes (the only manifest paths still left unfilled on disk);
//   * ship is now asserted PRESENT + credited (it ships);
//   * the manifest count assertion is updated 31 -> 32 (ship + 4 animals + the
//     coast band added; the 4 v1 objects/* paths removed; net per
//     journey_assets.dart's `all`).
//
// TC-011 reads the manifest (JourneyAssets.all), the shipped files on disk, and
// CREDITS.md from disk. TC-014 loads the real game via the harness (which
// swallows ONLY Flame's expected orphan rejection for the absent procedural
// cockpit shapes).

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

      // Sanity: most of the manifest ships. After journey-scene-art-v3's
      // wholesale re-source the ONLY documented intentional gaps are the 3
      // journey-pov cockpit shapes the painter draws PROCEDURALLY (car
      // dashboard, motorbike handlebar + fuel tank) — intentionally not
      // sourced; they degrade to original flat-shape fallbacks (AC-13).
      // vehicles/ship.png NOW SHIPS (art-v3 closed the gap), so it is no longer
      // in the absent set. (/source-assets DID populate the 4 cockpit glyph
      // primitives + every scene/vehicle/animal/beach asset.)
      expect(shipped, isNotEmpty);
      final Set<String> documentedAbsent = <String>{
        JourneyAssets.cockpitCarDashboard,
        JourneyAssets.cockpitMotorbikeHandlebar,
        JourneyAssets.cockpitMotorbikeFuelTank,
      };
      expect(
        absent.toSet(),
        documentedAbsent,
        reason:
            'only the 3 intentionally-procedural cockpit shapes may be absent '
            'after the art-v3 re-source (ship.png now ships); any other '
            'missing asset is a regression',
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

    test('shipNowShips_andIsCredited_afterArtV3Resource', () {
      // journey-scene-art-v3 churn-repair: ship.png was the historical "absent /
      // not-yet-filled gap" fixture; the wholesale re-source now SHIPS it. Assert
      // the file is present on disk AND credited (replacing the old "documented
      // as a known gap" assertion — there is no longer a ship gap).
      final assetDir = '${root.path}/${JourneyAssets.assetPrefix}';
      final ship = File('$assetDir${JourneyAssets.vehicleShip}');
      expect(
        ship.existsSync(),
        isTrue,
        reason: 'art-v3 closed the ship gap — vehicles/ship.png now ships',
      );
      expect(
        creditsText.contains('vehicles/ship.png'),
        isTrue,
        reason: 'shipped ship.png must have a CREDITS row',
      );
    });

    test('absentProceduralCockpitShape_isDocumentedAsAKnownGap_notAFailure', () {
      // The genuinely-absent fixture is now a procedural cockpit shape (the only
      // manifest paths left unfilled on disk by design — they degrade to the
      // painter's original flat-shape fallbacks, AC-13). It is documented in
      // CREDITS as an intentional unfilled/procedural entry, not a failure.
      final assetDir = '${root.path}/${JourneyAssets.assetPrefix}';
      final shape = File('$assetDir${JourneyAssets.cockpitCarDashboard}');
      expect(
        shape.existsSync(),
        isFalse,
        reason: 'cockpit/car/dashboard.png is intentionally unfilled',
      );
      expect(creditsText.contains('cockpit/car/dashboard.png'), isTrue);
      expect(
        creditsText.toLowerCase().contains('procedural') ||
            creditsText.toLowerCase().contains('unfilled') ||
            creditsText.toLowerCase().contains('original'),
        isTrue,
        reason:
            'the procedural cockpit shape must be recorded as an intentional '
            'original/procedural (unfilled) entry',
      );
    });

    test('credits_referencesEveryShippedAsset_noOrphanLoad', () {
      // The scene loads ONLY JourneyAssets.all; assert that list is the source
      // of truth and has the expected count (regression guard). journey-scene-v2
      // #11 / AC-8 expanded the manifest; journey-pov added 7 cockpit glyphs.
      // journey-scene-art-v3 / AC-3 then re-sourced WHOLESALE:
      //   * RETIRED the four v1 objects/* roadside kinds (tree/house/
      //     street_light/sign) — removed from JourneyAssets entirely;
      //   * the six vehicle skins (incl. the now-SHIPPED ship) + man/man_point
      //     people were REPLACED in place;
      //   * NET-NEW: scenery/beach/coast_band.png (AC-5) + the four side-view
      //     animals (AC-6: water_buffalo/dog/chicken/bird).
      // Current manifest = 6 vehicles + 17 scenery/people pooled kinds + 5
      // highland far bands (mountain_range + hills + hills_large + 3 peaks) +
      // 1 coast band + 4 animals + 7 cockpit glyphs = 41 total.
      //
      // P1 dead-weight fix: +9 net-new variety paths that were bundled + credited
      // but unmanifested — now wired so they actually render. As POOLED kinds:
      // forest/palm, city/house_gable_alt, city/house_small_alt, people/woman,
      // people/woman_point. As HIGHLAND far BANDS (theme 0, scroll-phase only):
      // mountains/hills_large, peak_a, peak_b, peak_c. (32 -> 41.)
      //
      // P1 dead-weight fix (sky layer): +5 net-new scenery/sky/* paths that were
      // bundled + credited but unmanifested — now drawn as the FURTHEST layer
      // (sun/moon placed by the cosmetic timeOfDayHours, clouds drifting by
      // scroll phase only). sun, moon, cloud_1, cloud_2, cloud_3. (41 -> 46.)
      expect(JourneyAssets.all.length, 46);
      expect(
        JourneyAssets.all.toSet().length,
        46,
        reason: 'no duplicate paths',
      );
      // The retired v1 objects/* paths must NOT survive in the manifest (AC-3
      // wholesale-replacement: no prior mixed-pack roadside path remains).
      for (final retired in const <String>[
        'objects/tree.png',
        'objects/house.png',
        'objects/street_light.png',
        'objects/sign.png',
      ]) {
        expect(
          JourneyAssets.all.contains(retired),
          isFalse,
          reason: 'retired v1 roadside path "$retired" must be gone (AC-3)',
        );
      }
    });
  });

  group('TC-009 reverse guard — every bundled journey PNG is CREDITS-recorded', () {
    // AC-8: "the scene loads no asset absent from CREDITS." The existing TC-011
    // checks manifest → CREDITS (forward). This guards the REVERSE: every PNG
    // actually bundled under assets/journey/** (via the pubspec asset dirs) must
    // appear in CREDITS.md — so a future-added bundled file can't ship
    // uncredited even if it is added to the bundle without a CREDITS row.
    test('everyBundledJourneyPng_appearsInCredits', () {
      final journeyDir = Directory('${root.path}/assets/journey');
      expect(
        journeyDir.existsSync(),
        isTrue,
        reason: 'assets/journey must exist under the package root',
      );

      // Enumerate every bundled PNG under assets/journey/** (the pubspec asset
      // directory entries bundle every file in these dirs).
      final List<String> bundledPngs =
          journeyDir
              .listSync(recursive: true)
              .whereType<File>()
              .map((f) => f.path)
              .where((p) => p.toLowerCase().endsWith('.png'))
              .toList()
            ..sort();

      // Sanity: there really are bundled PNGs to guard.
      expect(
        bundledPngs,
        isNotEmpty,
        reason: 'expected bundled journey PNGs under assets/journey/',
      );

      // Each bundled file's path relative to assets/journey/ must appear
      // verbatim in CREDITS.md (the table rows list paths under that root).
      final String prefix = '${journeyDir.path}/';
      final List<String> uncredited = <String>[];
      for (final String abs in bundledPngs) {
        final String rel = abs.startsWith(prefix)
            ? abs.substring(prefix.length)
            : abs;
        if (!creditsText.contains(rel)) {
          uncredited.add(rel);
        }
      }
      expect(
        uncredited,
        isEmpty,
        reason:
            'these bundled journey assets are NOT in assets/CREDITS.md '
            '(would ship uncredited): $uncredited',
      );
    });
  });

  group('TC-219 every cockpit asset is CREDITS-recorded (journey-pov AC-17)', () {
    // The cockpit ships 7 manifest paths: 4 sourced CC BY 3.0 glyphs (steering
    // wheel, speedometer, fuel gauge, motorbike gauge pod) + 3 intentionally-
    // procedural ORIGINAL flat shapes (car dashboard, motorbike handlebar +
    // fuel tank). AC-17: EVERY cockpit path has a matching CREDITS entry, the
    // CC BY glyphs carry source + licence, and the scene loads NO cockpit asset
    // absent from CREDITS.

    final cockpitPaths = <String>[
      ...JourneyAssets.cockpitCar,
      ...JourneyAssets.cockpitMotorbike,
    ];

    // The CC BY 3.0 sourced glyphs (attribution REQUIRED — stronger than CC0).
    const ccByGlyphs = <String>[
      JourneyAssets.cockpitCarSteeringWheel,
      JourneyAssets.cockpitCarSpeedometer,
      JourneyAssets.cockpitCarFuelGauge,
      JourneyAssets.cockpitMotorbikeGaugePod,
    ];

    // The original procedural flat shapes (own work, no licence / no file).
    const proceduralShapes = <String>[
      JourneyAssets.cockpitCarDashboard,
      JourneyAssets.cockpitMotorbikeHandlebar,
      JourneyAssets.cockpitMotorbikeFuelTank,
    ];

    test('everyCockpitManifestPath_hasACreditsEntry', () {
      // Sanity: car ∪ motorbike covers exactly the 7 cockpit glyph paths.
      expect(cockpitPaths.toSet(), {...ccByGlyphs, ...proceduralShapes});
      for (final path in cockpitPaths) {
        expect(
          creditsText.contains(path),
          isTrue,
          reason: 'cockpit asset "$path" has no CREDITS.md entry (AC-17)',
        );
      }
    });

    test('everyCcByGlyph_recordsSourceAndLicence', () {
      // CC BY REQUIRES the attribution to be present: each glyph's CREDITS line
      // must name its source (game-icons.net) AND its licence (CC BY 3.0).
      for (final glyph in ccByGlyphs) {
        // Find the CREDITS row mentioning this path and assert it carries the
        // source + licence on the same line (the table row).
        final row = creditsText
            .split('\n')
            .firstWhere((l) => l.contains(glyph), orElse: () => '');
        expect(row, isNotEmpty, reason: 'no CREDITS row for "$glyph"');
        expect(
          row.contains('CC BY 3.0'),
          isTrue,
          reason: '"$glyph" must record its CC BY 3.0 licence (AC-17)',
        );
        expect(
          row.toLowerCase().contains('game-icons.net'),
          isTrue,
          reason: '"$glyph" must record its game-icons.net source (AC-17)',
        );
      }
    });

    test('everyProceduralShape_recordsAsOriginalOwnWork', () {
      // The original flat shapes are recorded as procedurally-drawn originals
      // (license-clean by construction — no external source to attribute).
      for (final shape in proceduralShapes) {
        final row = creditsText
            .split('\n')
            .firstWhere((l) => l.contains(shape), orElse: () => '');
        expect(row, isNotEmpty, reason: 'no CREDITS row for "$shape"');
        expect(
          row.toLowerCase().contains('procedural') ||
              row.toLowerCase().contains('original'),
          isTrue,
          reason: '"$shape" must be recorded as an original procedural shape',
        );
      }
    });

    test('sceneLoadsNoCockpitAssetAbsentFromCredits', () {
      // The scene's cockpit asset set (cockpitCar ∪ cockpitMotorbike) is the
      // ONLY thing it can request for a cockpit mode — and every member is in
      // CREDITS. So there is no loadable cockpit asset absent from CREDITS.
      final uncredited = cockpitPaths
          .where((p) => !creditsText.contains(p))
          .toList();
      expect(
        uncredited,
        isEmpty,
        reason: 'cockpit assets loaded but absent from CREDITS: $uncredited',
      );
    });
  });

  group('TC-014 missing/failed asset degrades gracefully (no crash)', () {
    // Load the sprite-backed game ONCE for the group. (loadJourneyGame runs
    // Flame's real asset load and swallows only the expected orphan ship.png
    // rejection; loading once keeps the suite fast and avoids repeated
    // zone-guard setup.)
    late final game = loadJourneyGame();

    test(
      'onLoad_completesWithoutThrowing_proceduralShapesBecomePlaceholders',
      () async {
        final g = await game;
        // The scene loaded and recorded the failures as placeholders.
        expect(g.hasPlaceholderAssets, isTrue);
        // journey-scene-art-v3 churn-repair: ship.png NOW SHIPS, so it loaded and
        // is NOT a placeholder. The ONLY documented gaps that degrade are the 3
        // intentionally-procedural cockpit shapes (AC-13 — the cockpit then draws
        // its original flat-shape fallbacks). Every OTHER curated asset (all 6
        // vehicles incl. ship, scenery, the coast band, the 4 animals, the 4
        // sourced cockpit glyphs) loaded fine.
        expect(
          g.failedAssetPaths,
          isNot(contains(JourneyAssets.vehicleShip)),
          reason: 'ship.png now ships (art-v3) — it must NOT be a placeholder',
        );
        expect(g.failedAssetPaths, <String>{
          JourneyAssets.cockpitCarDashboard,
          JourneyAssets.cockpitMotorbikeHandlebar,
          JourneyAssets.cockpitMotorbikeFuelTank,
        });
      },
    );

    test('shipModeRendersFromRealAsset_andSceneStillPumps_noCrash', () async {
      final g = await game;
      // Drive + render with the ship skin selected — now a REAL loaded asset.
      g.applyState(
        moving: true,
        mode: TravelMode.ship,
        reduceMotion: false,
        timeOfDayHours: 12,
      );
      // Pumping must not throw, and motion still works.
      expect(() => pump(g, frames: 30), returnsNormally);
      expect(g.roadScrollOffset, greaterThan(0));
    });
  });
}
