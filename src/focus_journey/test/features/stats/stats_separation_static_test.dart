// Static-inspection tests for the local-stats slice's privacy / layering /
// no-network invariants. These read the slice's own SOURCE files and assert on
// their imports + content — the automatable half of the privacy cases (the
// authoritative release gate is the MANUAL `/privacy-audit`, TC-022, see
// tests/cases/local-stats-manual-checklist.md).
//
// Covers (static / grep leg):
//   TC-026  read-only consumer: NO ActivityPlugin / getSystemIdleSeconds /
//           isScreenLocked / idle-lock MethodChannel anywhere in the slice; no
//           active-vs-idle decision or distance-accrual logic.
//   TC-027  persists only aggregate counters / settings / earned-badge flags —
//           the JSON shapes carry no raw per-event signal; no network call.
//   TC-NF2  Clean-Architecture layering: domain/ imports neither Flutter nor
//           shared_preferences; the data/ stores are the only shared_preferences
//           importers; OS packages are confined to their single wrapper files.
//   TC-NF3  no-network (static half): no networking package import anywhere in
//           the slice.
//
// Mirrors test/features/journey/presentation/journey_separation_static_test.dart
// and route_separation_static_test.dart. Run with: fvm flutter test.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The slice's source root (relative to the package root the test runs from).
const String _statsLib = 'lib/features/stats';

/// Network packages that must NEVER appear in this offline-only slice.
const List<String> _networkImports = <String>[
  "import 'dart:io'", // Socket/HttpClient live here; the slice must not need it
  'package:http',
  'package:dio',
  'package:web_socket',
  'package:grpc',
  'package:firebase',
  'HttpClient(',
  'Socket.connect',
];

/// OS / activity surface that the slice must NOT touch directly (TC-026).
const List<String> _forbiddenActivitySurface = <String>[
  'ActivityPlugin',
  'getSystemIdleSeconds',
  'isScreenLocked',
  'MethodChannel',
  'platform_channel',
];

List<File> _dartFilesUnder(String dir) {
  final root = Directory(dir);
  if (!root.existsSync()) {
    return <File>[];
  }
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

/// Strips `//` line comments and `/* */` block comments so the surface grep
/// inspects CODE only — the slice's doc comments legitimately *mention* the
/// forbidden surface (e.g. "imports NO ActivityPlugin") to document the
/// invariant, and must not trip the check (TC-026).
String _stripComments(String source) {
  // Remove block comments first, then line comments.
  final noBlock = source.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  final lines = noBlock.split('\n').map((line) {
    final idx = line.indexOf('//');
    return idx >= 0 ? line.substring(0, idx) : line;
  }).toList();
  return lines.join('\n');
}

void main() {
  // The widget/integration tests run from the package root, so these relative
  // paths resolve. Guard so a CWD surprise fails loud rather than silently
  // passing on an empty file set.
  setUpAll(() {
    expect(
      Directory(_statsLib).existsSync(),
      isTrue,
      reason:
          'stats lib not found from CWD ${Directory.current.path} — run '
          'from the package root',
    );
    expect(
      _dartFilesUnder(_statsLib),
      isNotEmpty,
      reason: 'expected the stats slice to contain source files',
    );
  });

  group('TC-026 read-only consumer: no direct OS/activity surface', () {
    test('no stats source imports or names the activity/idle/lock surface', () {
      final offenders = <String>[];
      for (final file in _dartFilesUnder(_statsLib)) {
        final text = _stripComments(file.readAsStringSync());
        for (final needle in _forbiddenActivitySurface) {
          if (text.contains(needle)) {
            offenders.add('${file.path}: contains "$needle"');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'the slice must read the engine scalars only, never the OS '
            'activity surface directly:\n${offenders.join('\n')}',
      );
    });

    test('no active-vs-idle decision or distance accrual in the slice', () {
      // Heuristic structural guard: the slice must not RE-DERIVE activity. It
      // reads `state`/`distanceKm` but never compares idle seconds to a
      // threshold or accrues km from a rate.
      final offenders = <String>[];
      for (final file in _dartFilesUnder(_statsLib)) {
        final text = _stripComments(file.readAsStringSync());
        if (text.contains('kmPerActiveHour')) {
          offenders.add('${file.path}: references distance-accrual rate');
        }
        if (text.contains('idleSeconds >') || text.contains('idleSeconds <')) {
          offenders.add(
            '${file.path}: compares idle seconds (a classification)',
          );
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('TC-NF3 no network: the slice imports no networking package', () {
    test('no stats source imports a network package or dart:io', () {
      final offenders = <String>[];
      for (final file in _dartFilesUnder(_statsLib)) {
        final text = _stripComments(file.readAsStringSync());
        for (final needle in _networkImports) {
          if (text.contains(needle)) {
            offenders.add('${file.path}: contains "$needle"');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'the slice is fully local/offline; no network imports allowed:'
            '\n${offenders.join('\n')}',
      );
    });
  });

  group('TC-NF2 Clean-Architecture layering', () {
    test('domain/ imports neither Flutter nor shared_preferences', () {
      final offenders = <String>[];
      for (final file in _dartFilesUnder('$_statsLib/domain')) {
        final text = _stripComments(file.readAsStringSync());
        if (text.contains('package:flutter/')) {
          offenders.add('${file.path}: imports Flutter (domain must be pure)');
        }
        if (text.contains('package:shared_preferences')) {
          offenders.add('${file.path}: imports shared_preferences (data leak)');
        }
        if (text.contains('package:launch_at_startup') ||
            text.contains('package:local_notifier')) {
          offenders.add('${file.path}: imports an OS package (data leak)');
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('shared_preferences is confined to data/ store files', () {
      final leaks = <String>[];
      for (final file in _dartFilesUnder(_statsLib)) {
        if (file.path.contains(
          '${Platform.pathSeparator}data${Platform.pathSeparator}',
        )) {
          continue;
        }
        if (_stripComments(
          file.readAsStringSync(),
        ).contains('package:shared_preferences')) {
          leaks.add(file.path);
        }
      }
      expect(
        leaks,
        isEmpty,
        reason:
            'shared_preferences must live only in data/:\n${leaks.join('\n')}',
      );
    });

    test('the OS packages are each confined to a single wrapper file', () {
      String? startupImporter;
      String? notifierImporter;
      final extraStartup = <String>[];
      final extraNotifier = <String>[];
      for (final file in _dartFilesUnder(_statsLib)) {
        final text = _stripComments(file.readAsStringSync());
        if (text.contains('package:launch_at_startup')) {
          if (startupImporter == null) {
            startupImporter = file.path;
          } else {
            extraStartup.add(file.path);
          }
        }
        if (text.contains('package:local_notifier')) {
          if (notifierImporter == null) {
            notifierImporter = file.path;
          } else {
            extraNotifier.add(file.path);
          }
        }
      }
      expect(
        extraStartup,
        isEmpty,
        reason: 'launch_at_startup must be wrapped in one file',
      );
      expect(
        extraNotifier,
        isEmpty,
        reason: 'local_notifier must be wrapped in one file',
      );
    });
  });

  group('TC-027 persisted JSON shapes carry only aggregates', () {
    test(
      'the day-stats JSON keys are exactly the AC-5 aggregate field set',
      () {
        final dayStats = File(
          '$_statsLib/domain/day_stats.dart',
        ).readAsStringSync();
        // The serialised keys (TC-027): date + the five aggregate counters; no
        // raw-event field (keystrokes, idle samples, window titles).
        for (final key in <String>[
          "'date'",
          "'activeTimeMs'",
          "'rawActiveTimeMs'",
          "'distanceKmForDay'",
          "'idleTimeMs'",
          "'bestFocusPeriodMs'",
        ]) {
          expect(dayStats.contains(key), isTrue, reason: 'missing key $key');
        }
        // Negative: no raw-signal field names leak into the schema.
        for (final forbidden in <String>[
          'keystroke',
          'windowTitle',
          'clipboard',
          'idleSample',
          'mousePosition',
        ]) {
          expect(
            dayStats.toLowerCase().contains(forbidden.toLowerCase()),
            isFalse,
            reason: 'day-stats schema must not carry "$forbidden"',
          );
        }
      },
    );

    test('settings + earned-badge JSON carry only config / flags', () {
      final settings = File(
        '$_statsLib/domain/app_settings.dart',
      ).readAsStringSync();
      final earned = File(
        '$_statsLib/domain/earned_badges.dart',
      ).readAsStringSync();
      for (final blob in <String>[settings, earned]) {
        for (final forbidden in <String>[
          'keystroke',
          'windowTitle',
          'clipboard',
          'idleSample',
        ]) {
          expect(
            blob.toLowerCase().contains(forbidden.toLowerCase()),
            isFalse,
            reason: 'persisted blob must not carry "$forbidden"',
          );
        }
      }
    });
  });
}
