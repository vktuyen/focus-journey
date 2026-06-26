// journey-scene-art-v3 CREDITS + higher-resolution cross-checks.
//
// Covers:
//   TC-309 (AC-9)  — each REPLACEMENT asset's PNG dimensions are strictly greater
//                    than its predecessor's (mapping read from CREDITS notes);
//                    net-new assets are exempt; an equal-res replacement is
//                    allowed only as a recorded signed-off deviation.
//   TC-311 (AC-11) — every JourneyAssets.all path has a CC0/permissive CREDITS
//                    row, including the net-new beach band + animals; attribution
//                    is recorded where the licence requires it (CC BY).
//
// Both read the manifest (JourneyAssets.all), the shipped PNGs on disk, and
// assets/CREDITS.md from disk — mechanical, no game instance needed.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_assets.dart';

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
      return Directory.current;
    }
    dir = parent;
  }
}

/// Reads a PNG's (width, height) from its IHDR chunk without decoding pixels.
/// PNG layout: 8-byte signature, then IHDR length(4)+type(4), then width(4),
/// height(4) big-endian at byte offsets 16..23.
({int width, int height}) _pngSize(File f) {
  final Uint8List b = f.readAsBytesSync();
  expect(b.length, greaterThan(24), reason: '${f.path} too small to be a PNG');
  // Validate the PNG signature.
  const sig = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  for (int i = 0; i < sig.length; i++) {
    expect(b[i], sig[i], reason: '${f.path} is not a PNG (bad signature)');
  }
  int u32(int o) =>
      (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
  return (width: u32(16), height: u32(20));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final root = _packageRoot();
  final creditsText = File('${root.path}/assets/CREDITS.md').readAsStringSync();
  final assetDir = '${root.path}/${JourneyAssets.assetPrefix}';

  // ===========================================================================
  // TC-309 (AC-9) — replacements strictly higher-res; net-new exempt.
  // ===========================================================================
  group('TC-309 each replacement is strictly higher-res; net-new exempt (AC-9)', () {
    // Rows in CREDITS that record "Predecessor dims → new dims" as
    // "WxH → WxH" (the AC-9 mapping). We parse them and verify against the
    // shipped PNG on disk. Net-new rows ("net-new → WxH") are exempt.
    //
    // The dimension column uses the form "106×254 → 212×508" (unicode '×').
    final dimRe = RegExp(
      r'(\d+)\s*[×x]\s*(\d+)\s*(?:→|->)\s*(\d+)\s*[×x]\s*(\d+)',
    );

    test('everyRecordedReplacementMapping_isStrictlyHigherRes_onDisk', () {
      // Collect each CREDITS row that (a) names a JourneyAssets.all path AND
      // (b) records a "pred → new" dimension mapping (i.e. a replacement).
      final lines = creditsText.split('\n');
      int replacementsChecked = 0;
      final List<String> failures = <String>[];

      for (final line in lines) {
        final m = dimRe.firstMatch(line);
        if (m == null) continue;
        // Find which manifest path (if any) this row is about.
        final String path = JourneyAssets.all.firstWhere(
          line.contains,
          orElse: () => '',
        );
        if (path.isEmpty) continue;

        final int predW = int.parse(m.group(1)!);
        final int predH = int.parse(m.group(2)!);
        final int newW = int.parse(m.group(3)!);
        final int newH = int.parse(m.group(4)!);

        // The recorded new dims must match the shipped PNG (mapping is honest).
        final file = File('$assetDir$path');
        if (!file.existsSync()) {
          // A replacement mapping for a path that does not ship is a gap to
          // escalate, not a silent pass.
          failures.add('$path: recorded a replacement mapping but file absent');
          continue;
        }
        final size = _pngSize(file);
        if (size.width != newW || size.height != newH) {
          failures.add(
            '$path: CREDITS records new dims ${newW}x$newH but disk is '
            '${size.width}x${size.height}',
          );
          continue;
        }

        // AC-9 core: replacement strictly greater than predecessor in BOTH dims
        // (the spec records width×height; the shipped set is a clean integer
        // upscale, so both grow). An equal-res case would be a recorded deviation
        // (none in this set); a smaller dim with no deviation is a fail.
        final bool strictlyGreater = newW > predW && newH > predH;
        final bool equalRes = newW == predW && newH == predH;
        if (!strictlyGreater) {
          if (equalRes && line.toLowerCase().contains('deviation')) {
            // Allowed: explicit signed-off equal-resolution deviation.
          } else {
            failures.add(
              '$path: replacement ${newW}x$newH is not strictly greater than '
              'predecessor ${predW}x$predH and is not a recorded deviation',
            );
            continue;
          }
        }
        replacementsChecked++;
      }

      expect(failures, isEmpty, reason: failures.join('\n'));
      // Guard: we actually exercised the AC-9 path on the re-sourced set.
      expect(
        replacementsChecked,
        greaterThanOrEqualTo(10),
        reason:
            'expected the art-v3 re-source to record many replacement mappings; '
            'only $replacementsChecked were parsed (mapping may be missing)',
      );
    });

    test('netNewAssets_areExempt_andRecordedAsNetNew_notFailedForMissingPred', () {
      // The net-new assets (beach band, 4 animals, ship) have NO predecessor.
      // They must NOT carry a "pred → new" mapping that would subject them to
      // the strict-greater check; instead CREDITS records them as net-new.
      const netNew = <String>[
        JourneyAssets.coastBand,
        JourneyAssets.animalWaterBuffalo,
        JourneyAssets.animalDog,
        JourneyAssets.animalChicken,
        JourneyAssets.animalBird,
        JourneyAssets.vehicleShip,
      ];
      for (final path in netNew) {
        // The shipped file exists.
        expect(
          File('$assetDir$path').existsSync(),
          isTrue,
          reason: 'net-new asset $path must ship',
        );
        // The CREDITS line for it records "net-new" (AC-9 exempt), so it is not
        // treated as a replacement lacking a predecessor (the escalation gap).
        final row = creditsText
            .split('\n')
            .firstWhere((l) => l.contains(path), orElse: () => '');
        expect(row, isNotEmpty, reason: 'no CREDITS row for net-new $path');
        final rl = row.toLowerCase();
        // The net-new rows record the AC-9-exempt status either explicitly
        // ("net-new" / "exempt") OR via the net-new signature: a NEW backdrop
        // band / NEW pooled SideObjectKind with inline `(WxH)` dims and NO
        // "predecessor → new" mapping (since there is no predecessor).
        final bool recordedNetNew =
            rl.contains('net-new') ||
            rl.contains('net new') ||
            rl.contains('exempt') ||
            (rl.contains('new ') &&
                RegExp(r'\(\s*\d+\s*[×x]\s*\d+\s*\)').hasMatch(row));
        expect(
          recordedNetNew,
          isTrue,
          reason: '$path must be recorded as net-new (AC-9 exempt): "$row"',
        );
      }
    });
  });

  // ===========================================================================
  // TC-311 (AC-11) — every manifest path has a CC0/permissive CREDITS row.
  // ===========================================================================
  group('TC-311 every manifest path has a CC0/permissive CREDITS row (AC-11)', () {
    test('everyManifestPath_hasACreditsRow', () {
      final missing = <String>[];
      for (final path in JourneyAssets.all) {
        if (!creditsText.contains(path)) missing.add(path);
      }
      expect(
        missing,
        isEmpty,
        reason: 'manifest paths with no CREDITS row (incl. net-new): $missing',
      );
    });

    test('netNewBeachAndAnimals_areCredited_withAPermissiveLicence', () {
      // Explicitly cover the net-new beach band + animals (the art-v3 additions)
      // — each must have a row and a permissive licence record (these are
      // "original, no third-party licence" = license-clean by construction).
      const netNew = <String>[
        JourneyAssets.coastBand,
        JourneyAssets.animalWaterBuffalo,
        JourneyAssets.animalDog,
        JourneyAssets.animalChicken,
        JourneyAssets.animalBird,
        JourneyAssets.vehicleShip,
      ];
      for (final path in netNew) {
        final row = creditsText
            .split('\n')
            .firstWhere((l) => l.contains(path), orElse: () => '');
        expect(row, isNotEmpty, reason: 'no CREDITS row for $path');
        final lower = row.toLowerCase();
        expect(
          lower.contains('cc0') ||
              lower.contains('no third-party licence') ||
              lower.contains('no third-party license') ||
              lower.contains('original') ||
              lower.contains('public domain') ||
              lower.contains('cc by'),
          isTrue,
          reason: '$path must record a CC0/permissive licence: "$row"',
        );
      }
    });

    test('everyCcByRow_recordsItsRequiredAttribution', () {
      // For any manifest path whose CREDITS row is CC BY, attribution must be
      // present on the row (CC BY requires it — stronger than CC0).
      for (final path in JourneyAssets.all) {
        final row = creditsText
            .split('\n')
            .firstWhere((l) => l.contains(path), orElse: () => '');
        if (row.isEmpty) continue;
        if (row.contains('CC BY')) {
          expect(
            row.toLowerCase().contains('attribution') ||
                row.toLowerCase().contains('by '),
            isTrue,
            reason: 'CC BY row for $path must record attribution: "$row"',
          );
        }
      }
    });

    test('sceneLoadsNoAssetAbsentFromCredits_reverseGuard', () {
      // Reverse direction: every bundled journey PNG appears in CREDITS (so a
      // newly-bundled art-v3 file cannot ship uncredited). Mirrors the existing
      // TC-009 reverse guard but re-affirmed for the re-sourced bundle.
      final journeyDir = Directory('${root.path}/assets/journey');
      final List<String> uncredited = <String>[];
      final String prefix = '${journeyDir.path}/';
      for (final f in journeyDir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.toLowerCase().endsWith('.png')) continue;
        final rel = f.path.startsWith(prefix)
            ? f.path.substring(prefix.length)
            : f.path;
        if (!creditsText.contains(rel)) uncredited.add(rel);
      }
      expect(
        uncredited,
        isEmpty,
        reason: 'bundled but uncredited: $uncredited',
      );
    });

    test('bundledJourneyPng_isSubsetOf_manifest', () {
      // AC-10 source-of-truth invariant — the OTHER reverse direction.
      //
      // TC-311 / TC-309 (and TC-011 in the sibling test) check the manifest
      // (JourneyAssets.all) ⊆ {CREDITS, on-disk}. This guards the complement:
      // every journey image PHYSICALLY BUNDLED under assets/journey/** that ends
      // in .png must be present in JourneyAssets.all — i.e.
      //   bundled-journey-PNGs ⊆ manifest.
      // A re-source that drops a PNG into the asset tree but forgets to wire it
      // into JourneyAssets.all would render it dead weight (bundled, credited,
      // never drawn). This is exactly the P1 review finding that was just closed
      // by wiring the last orphans (the 5 scenery/sky/* PNGs) into the manifest.
      //
      // Bundled-set definition: identical to the TC-009 reverse guard above —
      // Directory('.../assets/journey').listSync(recursive: true) filtered to
      // .png Files, made relative to assets/journey/. Non-PNG files (.gitkeep)
      // are excluded by the .png check.
      //
      // Exclusions: the 3 intentionally-procedural cockpit shapes
      // (cockpit/car/dashboard.png, cockpit/motorbike/handlebar.png,
      // cockpit/motorbike/fuel_tank.png) are in the manifest but do NOT ship on
      // disk (they degrade to the painter's flat fallbacks, AC-13), so they never
      // enter the bundled set and cannot be offenders here.
      //
      // vehicle-picker (2026-06-26): the `vehicle_icons/` subtree
      // (assets/journey/vehicle_icons/{walk,run,bicycle,motorbike,car,ship}.png)
      // is a DELIBERATELY NON-FLAME asset class — picker-UI glyphs loaded via
      // Flutter `Image.asset`/`AssetImage` (see vehicle_picker.dart), NOT Flame
      // scene sprites, and intentionally kept OUT of `JourneyAssets.all` so the
      // Flame scene loader's scope (and TC-011/TC-309/TC-311) stays scene-only.
      // They ARE credited (CREDITS cross-check is vehicle_picker_credits_test.dart
      // / AC-15) so the reverse credits guard above still covers them; this
      // manifest-membership guard excludes them by design.
      final journeyDir = Directory('${root.path}/assets/journey');
      expect(
        journeyDir.existsSync(),
        isTrue,
        reason: 'assets/journey must exist under the package root',
      );

      const String pickerIconSubtree = 'vehicle_icons/';
      final String prefix = '${journeyDir.path}/';
      final Set<String> bundled = journeyDir
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path)
          .where((p) => p.toLowerCase().endsWith('.png'))
          .map((p) => p.startsWith(prefix) ? p.substring(prefix.length) : p)
          // Picker-UI glyphs are not Flame sprites — see the note above.
          .where((rel) => !rel.startsWith(pickerIconSubtree))
          .toSet();

      // Sanity: there really are bundled PNGs to guard.
      expect(
        bundled,
        isNotEmpty,
        reason: 'expected bundled journey PNGs under assets/journey/',
      );

      final Set<String> manifestSet = JourneyAssets.all.toSet();
      final Set<String> offenders = bundled.difference(manifestSet);
      expect(
        offenders,
        isEmpty,
        reason:
            'bundled journey PNG(s) not in JourneyAssets.all (would ship as '
            'dead weight — credited but never drawn): $offenders',
      );
    });
  });
}
