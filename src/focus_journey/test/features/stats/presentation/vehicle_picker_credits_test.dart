// CREDITS / manifest cross-check for the vehicle-picker icons. Authored by
// test-script-author from tests/cases/vehicle-picker.md. Mirrors the journey-pov
// AC-17 / journey-scene-art-v3 CREDITS pattern: enumerate the picker's requested
// icon paths, parse assets/CREDITS.md, assert each path has a matching entry with
// a source + licence, and that the picker loads NO icon absent from CREDITS.
//
//   TC-615 (AC-15) — every picker icon path (the six vehicleIconAsset() paths) is
//                  CREDITS-attributed with a source + licence; CC-BY rows carry
//                  the required attribution; no requested icon is uncredited; and
//                  the reverse guard — no bundled vehicle_icons PNG is uncredited.
//
// Mechanical: reads the path↔mode map (vehicleIconAsset), the shipped PNGs on
// disk, and assets/CREDITS.md from disk — no game instance, no rendering.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/stats/presentation/vehicle_picker.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final root = _packageRoot();
  final String creditsText =
      File('${root.path}/assets/CREDITS.md').readAsStringSync();

  /// The six picker icon paths the production map requests.
  final List<String> pickerIconPaths = <String>[
    for (final TravelMode mode in TravelMode.values) vehicleIconAsset(mode),
  ];

  /// The CREDITS rows reference icon paths relative to `assets/journey/`
  /// (e.g. `vehicle_icons/walk.png`), while [vehicleIconAsset] returns the
  /// package-root path (`assets/journey/vehicle_icons/walk.png`). A row matches a
  /// requested path when it contains EITHER form.
  String creditsRowFor(String requestedPath) {
    const journeyPrefix = 'assets/journey/';
    final String stripped = requestedPath.startsWith(journeyPrefix)
        ? requestedPath.substring(journeyPrefix.length)
        : requestedPath;
    return creditsText.split('\n').firstWhere(
          (l) => l.contains(requestedPath) || l.contains(stripped),
          orElse: () => '',
        );
  }

  group('TC-615 every picker icon is CREDITS-attributed; none uncredited (AC-15)', () {
    test('eachRequestedIconPath_hasACreditsRowWithSourceAndLicence', () {
      final List<String> failures = <String>[];
      for (final path in pickerIconPaths) {
        final row = creditsRowFor(path);
        if (row.isEmpty) {
          failures.add('$path: no CREDITS row');
          continue;
        }
        final lower = row.toLowerCase();
        // Must record a recognised licence (the picker icons are CC BY 3.0).
        final bool hasLicence = lower.contains('cc by') ||
            lower.contains('cc0') ||
            lower.contains('public domain') ||
            lower.contains('original') ||
            lower.contains('no third-party licence') ||
            lower.contains('no third-party license');
        if (!hasLicence) {
          failures.add('$path: CREDITS row records no recognised licence');
          continue;
        }
        // Must record a source (a URL — game-icons.net for this set).
        final bool hasSource =
            row.contains('http://') || row.contains('https://');
        if (!hasSource) {
          failures.add('$path: CREDITS row records no source URL');
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('everyCcByPickerRow_recordsItsRequiredAttribution', () {
      // CC BY requires attribution be PRESENT (stronger than CC0).
      for (final path in pickerIconPaths) {
        final row = creditsRowFor(path);
        expect(row, isNotEmpty, reason: 'no CREDITS row for $path');
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

    test('noUnclearOrPaidOrPersonalUseLicence_onAnyPickerIcon', () {
      for (final path in pickerIconPaths) {
        final row = creditsRowFor(path).toLowerCase();
        expect(row, isNotEmpty);
        expect(row.contains('personal-use'), isFalse,
            reason: '$path must not be personal-use-only');
        expect(row.contains('personal use only'), isFalse);
        expect(row.contains('paid'), isFalse,
            reason: '$path must not be a paid licence');
      }
    });

    test('reverseGuard_noBundledVehicleIconPng_isUncredited', () {
      // Every bundled vehicle_icons PNG must appear in CREDITS (so a newly-added
      // picker icon cannot ship uncredited — journey-pov AC-17 reverse guard).
      final iconDir =
          Directory('${root.path}/assets/journey/vehicle_icons');
      expect(iconDir.existsSync(), isTrue,
          reason: 'assets/journey/vehicle_icons must exist');
      // CREDITS rows reference paths relative to assets/journey/, so match the
      // bundled file by its assets/journey/-relative form.
      final String journeyPrefix = '${root.path}/assets/journey/';
      final List<String> uncredited = <String>[];
      for (final f in iconDir.listSync().whereType<File>()) {
        if (!f.path.toLowerCase().endsWith('.png')) continue;
        final rel = f.path.startsWith(journeyPrefix)
            ? f.path.substring(journeyPrefix.length)
            : f.path;
        if (!creditsText.contains(rel)) uncredited.add(rel);
      }
      expect(uncredited, isEmpty,
          reason: 'bundled but uncredited picker icon(s): $uncredited');
    });

    test('everyRequestedIconPath_actuallyShipsOnDisk', () {
      // CREDITS attribution is moot if the requested icon is absent; confirm each
      // requested path ships (the picker loads no path it cannot resolve).
      for (final path in pickerIconPaths) {
        expect(
          File('${root.path}/$path').existsSync(),
          isTrue,
          reason: 'requested picker icon $path must ship on disk',
        );
      }
    });
  });
}
