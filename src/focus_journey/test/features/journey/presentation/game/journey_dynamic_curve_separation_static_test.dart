// Static-inspection guards for journey-dynamic-curve.
//
// Authored by test-script-author from tests/cases/journey-dynamic-curve.md. One
// group per case; each carries its TC-ID + AC-ID for traceability.
//
//   TC-410 (AC-8)      — pure-view imports: the three curve sources
//                        (road_geometry / road_painter / side_object_pool)
//                        import ONLY `dart:*`, `package:flame/*`, and the
//                        pure-Dart domain `TravelMode` — no flutter_bloc,
//                        JourneyEngine, ActivityPlugin, MethodChannel / platform
//                        channel, OS idle/lock/screen/location read, or
//                        `package:flutter` / `package:meta`.
//   TC-403(d) (AC-3/4) — "scroll-phase only": the three sources read NO second
//                        clock — no `DateTime`, `Stopwatch`, `Random`, `Timer`,
//                        nor a second phase field. The only time-varying input
//                        threaded into the curve is `scrollOffset`/`worldDistance`.
//   TC-404 (AC-4)      — single shared phase (static half): no second motion
//                        source / independent clock anywhere in the curve sources.
//
// Mirrors test/features/route/route_separation_static_test.dart and
// test/features/journey/presentation/game/cockpit_separation_static_test.dart
// (comment-stripped CODE-only matching; positive import allowlist + negative
// forbidden-token scan).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The journey-dynamic-curve sources (the three files the slice touched).
/// road_geometry.dart: the winding centre-line + analytic slope.
/// road_painter.dart:   the rendered bend (amplitude / depth weighting).
/// side_object_pool.dart: the arc-length-aware spawn cadence (AC-6 fork).
const List<String> _curveFiles = <String>[
  'lib/features/journey/presentation/game/road_geometry.dart',
  'lib/features/journey/presentation/game/road_painter.dart',
  'lib/features/journey/presentation/game/side_object_pool.dart',
];

Directory _packageRoot() {
  Directory dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        Directory('${dir.path}/lib/features/journey').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      return Directory.current;
    }
    dir = parent;
  }
}

/// Strips `//` line, `///` doc, and `/* */` block comments so matches are
/// against CODE only — the files DELIBERATELY name the forbidden APIs in their
/// doc comments to document that they do NOT use them.
String _stripComments(String source) {
  final noBlock = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  final buffer = StringBuffer();
  for (final line in noBlock.split('\n')) {
    final idx = line.indexOf('//');
    buffer.writeln(idx >= 0 ? line.substring(0, idx) : line);
  }
  return buffer.toString();
}

/// All `import '...'` / `export '...'` targets in [source].
List<String> _importTargets(String source) {
  final re = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''');
  return re.allMatches(source).map((m) => m.group(1)!).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = _packageRoot();

  String code(String rel) {
    final file = File('${root.path}/$rel');
    expect(file.existsSync(), isTrue, reason: 'missing source: $rel');
    return _stripComments(file.readAsStringSync());
  }

  // ===========================================================================
  // TC-410 (AC-8) — pure-view import invariant for the three curve sources.
  // ===========================================================================
  group('TC-410 curve sources import only dart:*, flame, TravelMode (AC-8)', () {
    test('eachCurveSource_importsOnly_dart_flame_orPureSiblings', () {
      for (final rel in _curveFiles) {
        final imports = _importTargets(code(rel));
        for (final imp in imports) {
          final bool allowed =
              imp.startsWith('dart:') ||
              imp.startsWith('package:flame/') ||
              // The pure-Dart domain TravelMode is the only domain import.
              imp.endsWith('domain/travel_mode.dart') ||
              // Pure sibling presentation/game files (each itself under this
              // invariant): road_geometry / road_painter / side_object_pool
              // reference each other but no Flutter/Bloc/engine/OS surface.
              imp == 'road_geometry.dart' ||
              imp == 'road_painter.dart' ||
              imp == 'side_object_pool.dart';
          expect(
            allowed,
            isTrue,
            reason:
                '$rel imports a disallowed target "$imp" — AC-8 permits only '
                'dart:*, package:flame/*, TravelMode, and the pure sibling '
                'curve sources',
          );
        }
      }
    });

    test('noCurveSource_importsAnyFlutterOrMetaSurface', () {
      for (final rel in _curveFiles) {
        final imports = _importTargets(code(rel));
        for (final imp in imports) {
          expect(
            imp.startsWith('package:flutter/'),
            isFalse,
            reason: '$rel must not import any Flutter surface ("$imp")',
          );
          expect(
            imp == 'package:meta/meta.dart' || imp.startsWith('package:meta/'),
            isFalse,
            reason: '$rel must not import package:meta ("$imp")',
          );
        }
      }
    });

    test('noCurveSource_hasForbiddenOsBlocEngineOrChannelToken', () {
      const forbidden = <String>[
        'flutter_bloc',
        'JourneyEngine',
        'journey_engine',
        'ActivityPlugin',
        'getSystemIdleSeconds',
        'isScreenLocked',
        'MethodChannel',
        'EventChannel',
        'BasicMessageChannel',
        'package:flutter/services',
        'package:flutter/widgets',
        'package:flutter/material',
        'distanceKm',
      ];
      final violations = <String>[];
      for (final rel in _curveFiles) {
        final src = code(rel);
        for (final t in forbidden) {
          if (src.contains(t)) {
            violations.add('$rel contains forbidden token "$t"');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason:
            'curve sources breach the pure-view invariant (AC-8):\n'
            '${violations.join('\n')}',
      );
    });
  });

  // ===========================================================================
  // TC-403(d) / TC-404 (AC-3, AC-4 static) — scroll-phase ONLY, no second clock.
  // ===========================================================================
  group('TC-403/TC-404 single scroll phase — no second clock source (AC-3/4)', () {
    // The curve's ONLY time-varying input must be scrollOffset / worldDistance.
    // It must read NO wall-clock and spin up NO independent motion source. Any
    // of these in CODE would be a second phase the AC-4 single-phase invariant
    // forbids.
    const forbiddenClockTokens = <String>[
      'DateTime', // DateTime.now / any wall-clock read
      'Stopwatch',
      'Random', // any RNG (the heading table is a fixed const, no Random)
      'Timer', // dart:async timers
      'Future.delayed',
      'Ticker', // a Flutter/Flame ticker would be a second clock
    ];

    test('noCurveSource_readsAnyWallClockTimerOrRandom', () {
      final violations = <String>[];
      for (final rel in _curveFiles) {
        final src = code(rel);
        for (final t in forbiddenClockTokens) {
          if (src.contains(t)) {
            violations.add('$rel contains second-clock token "$t"');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason:
            'the curve must derive its sweep from the SINGLE shared scroll '
            'phase only — no second clock/timer/RNG (AC-4):\n'
            '${violations.join('\n')}',
      );
    });

    test('curveTimeInputs_areOnlyScrollOffsetOrWorldDistance', () {
      // Positive structural check: the public time-varying parameter names the
      // curve accepts are scrollOffset / worldDistance only (the SAME phase the
      // road body, dashes and pool consume). road_geometry takes worldDistance;
      // road_painter.centreLineOffset takes scrollOffset; side_object_pool's
      // advance takes scrollDelta (a delta of the SAME phase). There is no
      // second phase field/parameter.
      final geometry = code(_curveFiles[0]);
      final painter = code(_curveFiles[1]);
      final pool = code(_curveFiles[2]);

      // The geometry's pure entry points are keyed on worldDistance.
      expect(geometry.contains('lateralAt(double worldDistance)'), isTrue);
      expect(geometry.contains('lateralSlopeAt(double worldDistance)'), isTrue);
      // The painter's centre-line offset is keyed on scrollOffset.
      expect(painter.contains('centreLineOffset(Size size, double scrollOffset'),
          isTrue);
      // The pool advances on a delta of the SAME phase (scrollDelta), with the
      // curve amplitude as the only extra input — no second clock parameter.
      expect(pool.contains('void advance(double scrollDelta'), isTrue);
    });
  });
}
