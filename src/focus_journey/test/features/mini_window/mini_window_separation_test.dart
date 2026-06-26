// Static-inspection guard tests for the mini-window slice separation/privacy
// invariants (TC-010 / TC-019-PRIV backbone — the manual /privacy-audit is the
// authoritative pass, this is the automatable static guard that re-runs on any
// change to the slice's source).
//
// These read the slice's Dart source files and assert, by source inspection,
// that the mini-window code:
//   * makes NO OS-user-signal call (ActivityPlugin, getSystemIdleSeconds,
//     isScreenLocked, idle/lock/input APIs) — AC-10 / NFR-4;
//   * never writes journey state fields (distanceKm/activeTimeToday/
//     rawActiveTime/idleTimeToday/state) — AC-10;
//   * keeps window_manager / tray_manager OUT of the presentation layer
//     (only the data-layer backends touch the packages) — AC-10 / NFR-7;
//   * constructs no second JourneyEngine/JourneyGame in the mode cubit/shell
//     wiring beyond the single shared instance — AC-9.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Resolves the absolute path to a lib/ file under the package root, regardless
/// of the cwd the test runner uses.
File _libFile(String relative) {
  // Tests run with the package root as cwd under `flutter test`.
  final candidate = File('lib/$relative');
  if (candidate.existsSync()) return candidate;
  // Fallback: walk up to find the package root containing pubspec.yaml.
  Directory dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync() &&
      dir.parent.path != dir.path) {
    dir = dir.parent;
  }
  return File('${dir.path}/lib/$relative');
}

/// Strips Dart line (`//`) and block (`/* */`) comments so the static guards
/// match real CODE usage, not the (deliberately explanatory) doc comments that
/// NAME the forbidden APIs to document that the slice does NOT use them.
String _stripComments(String src) {
  // Remove block comments (incl. /// is handled by the line pass below).
  final noBlock = src.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  final buffer = StringBuffer();
  for (final line in noBlock.split('\n')) {
    final idx = line.indexOf('//');
    buffer.writeln(idx >= 0 ? line.substring(0, idx) : line);
  }
  return buffer.toString();
}

List<File> _miniWindowDartFiles() {
  final root = _libFile('features/mini_window').path;
  final dir = Directory(root);
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

/// The presentation files (where window_manager/tray_manager must NOT leak).
const List<String> _presentationFiles = <String>[
  'features/mini_window/presentation/app_shell.dart',
  'features/mini_window/presentation/app_shell_cubit.dart',
  'features/mini_window/presentation/compact_view.dart',
  'features/mini_window/presentation/journey_tray_mapper.dart',
  'features/mini_window/presentation/hide_to_tray_hint.dart',
];

void main() {
  group('mini-window separation / privacy guards (TC-010 / TC-019-PRIV)', () {
    test('noOsUserSignalApiAnywhereInTheSlice', () {
      // AC-10 / NFR-4: zero idle/lock/input reads in the whole slice.
      const forbidden = <String>[
        'ActivityPlugin',
        'getSystemIdleSeconds',
        'isScreenLocked',
        'MethodChannel',
        'EventChannel',
      ];
      for (final file in _miniWindowDartFiles()) {
        final src = _stripComments(file.readAsStringSync());
        for (final needle in forbidden) {
          expect(
            src.contains(needle),
            isFalse,
            reason: '${file.path} must not reference $needle (AC-10/NFR-4)',
          );
        }
      }
    });

    test('mutatesNoJourneyStateFields', () {
      // AC-10: the slice never WRITES journey state (it only reads view state).
      // Guard against an assignment to any of the engine's owned fields.
      final writes = <RegExp>[
        RegExp(r'\.distanceKm\s*='),
        RegExp(r'\.activeTimeToday\s*='),
        RegExp(r'\.rawActiveTime\s*='),
        RegExp(r'\.idleTimeToday\s*='),
        RegExp(r'engine\.state\s*='),
      ];
      for (final file in _miniWindowDartFiles()) {
        final src = _stripComments(file.readAsStringSync());
        for (final re in writes) {
          expect(
            re.hasMatch(src),
            isFalse,
            reason: '${file.path} must not write journey state (AC-10)',
          );
        }
      }
    });

    test('presentationLayerDoesNotImportWindowOrTrayManager', () {
      // AC-10 / NFR-7: window_manager / tray_manager live ONLY behind the
      // data-layer backends; presentation talks to the domain interfaces.
      for (final relative in _presentationFiles) {
        final src = _stripComments(_libFile(relative).readAsStringSync());
        expect(
          src.contains("package:window_manager"),
          isFalse,
          reason: '$relative must not import window_manager',
        );
        expect(
          src.contains("package:tray_manager"),
          isFalse,
          reason: '$relative must not import tray_manager',
        );
        expect(
          src.contains("package:screen_retriever"),
          isFalse,
          reason: '$relative must not import screen_retriever',
        );
      }
    });

    test('modeCubitAndShellConstructNoSecondEngineOrGame', () {
      // AC-9: the mode cubit holds no JourneyEngine and constructs no game; the
      // shell creates at most ONE JourneyGame (via the injected factory).
      final cubitSrc = _stripComments(
        _libFile(
          'features/mini_window/presentation/app_shell_cubit.dart',
        ).readAsStringSync(),
      );
      expect(cubitSrc.contains('JourneyEngine'), isFalse);
      expect(cubitSrc.contains('JourneyGame('), isFalse);

      final shellSrc = _stripComments(
        _libFile(
          'features/mini_window/presentation/app_shell.dart',
        ).readAsStringSync(),
      );
      expect(
        cubitSrc.contains('JourneyEngine('),
        isFalse,
        reason: 'mode cubit must construct no engine (AC-9)',
      );
      // The shell may reference JourneyGame for the single shared instance, but
      // must not import the activity ticker / engine to drive a second one.
      expect(shellSrc.contains('JourneyEngine'), isFalse);
    });

    test('compactViewReadsOnlyViewStateForRendering', () {
      // AC-10: the compact view binds to JourneyCubit/JourneyViewState only —
      // no engine, no ticker, no OS signal.
      final src = _stripComments(
        _libFile(
          'features/mini_window/presentation/compact_view.dart',
        ).readAsStringSync(),
      );
      expect(src.contains('JourneyEngine'), isFalse);
      expect(src.contains('ActivityTicker'), isFalse);
      expect(src.contains('ActivityPlugin'), isFalse);
    });
  });
}
