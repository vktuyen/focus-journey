// Static-inspection guards for journey-cockpit-lean.
//
// Authored by test-script-author from tests/cases/journey-cockpit-lean.md. One
// group per case; each carries its TC-ID + AC-ID for traceability. Mirrors
// cockpit_separation_static_test.dart / journey_dynamic_curve_separation_static_test.dart
// (comment-stripped CODE-only matching; positive import allowlist + negative
// forbidden-token scan).
//
//   TC-511 (AC-10) — signal-source: the lean-angle source in journey_game.dart /
//                    cockpit_painter.dart derives the angle SOLELY from the
//                    in-scene curve sample (lateralSlopeAt / centreLineOffsetAt /
//                    worldAtCamera) + the reduceMotion / mode gates — NO Bloc,
//                    JourneyEngine, ActivityPlugin, OS read, DateTime/Random/
//                    second clock, or second phase.
//   TC-512 (AC-11) — separation invariant: cockpit_painter.dart + journey_game.dart
//                    (the lean sources) import ONLY dart:*, package:flame/*, and
//                    pure-Dart siblings (TravelMode + the pure scene siblings) —
//                    no flutter_bloc / engine / ActivityPlugin / MethodChannel /
//                    OS read / package:flutter / package:meta.
//   TC-517 (NFR-1 static leg) — no-per-frame-allocation / constant-cost angle
//                    update: the lean's update path (_advanceLean) and the
//                    cockpit's transform path allocate NOTHING per frame (no `new`
//                    Paint/Path/Offset/Matrix/List on the hot path) and contain NO
//                    accumulating loop keyed on scroll length — the angle update is
//                    O(1) regardless of how long the session has scrolled. (The
//                    runtime constant-cost / no-growth proxy is in the behaviour +
//                    perf tests; this is the source-inspection half.)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _cockpitPainter =
    'lib/features/journey/presentation/game/cockpit_painter.dart';
const String _journeyGame =
    'lib/features/journey/presentation/game/journey_game.dart';

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

/// Strips `//`, `///`, and `/* */` comments so matches are against CODE only —
/// the files DELIBERATELY name the forbidden APIs in doc comments to document
/// that they do NOT use them.
String _stripComments(String source) {
  final noBlock = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  final buffer = StringBuffer();
  for (final line in noBlock.split('\n')) {
    final idx = line.indexOf('//');
    buffer.writeln(idx >= 0 ? line.substring(0, idx) : line);
  }
  return buffer.toString();
}

List<String> _importTargets(String source) {
  final re = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''');
  return re.allMatches(source).map((m) => m.group(1)!).toList();
}

/// Extracts the body of the named method (brace-matched) from [source], or null.
/// The method's opening `{` is the one that begins the body — i.e. the `{` that
/// follows the closing `)` of the (possibly multi-line, named-param) parameter
/// list, NOT the `{` that opens an optional/named parameter block `{ ... }`. We
/// therefore find the parameter list's matching `)` first, then the next `{`.
String? _methodBody(String source, String signaturePrefix) {
  final int sigIdx = source.indexOf(signaturePrefix);
  if (sigIdx < 0) return null;
  // A getter (no `(`) opens its body at the first `{` after the signature; a
  // method opens it at the first `{` after the parameter list's closing `)`.
  final int parenOpen = source.indexOf('(', sigIdx);
  final int firstBrace = source.indexOf('{', sigIdx);
  int searchFrom = sigIdx;
  if (parenOpen >= 0 && (firstBrace < 0 || parenOpen < firstBrace)) {
    // Method: match the parameter list's closing `)` (paren-depth aware so the
    // named-param `{ }` block + `<...>` generics inside do not confuse it).
    int pdepth = 0;
    int parenClose = -1;
    for (int i = parenOpen; i < source.length; i++) {
      final ch = source[i];
      if (ch == '(') pdepth++;
      if (ch == ')') {
        pdepth--;
        if (pdepth == 0) {
          parenClose = i;
          break;
        }
      }
    }
    if (parenClose < 0) return null;
    searchFrom = parenClose;
  }
  final int braceStart = source.indexOf('{', searchFrom);
  if (braceStart < 0) return null;
  int depth = 0;
  for (int i = braceStart; i < source.length; i++) {
    final ch = source[i];
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) return source.substring(braceStart, i + 1);
    }
  }
  return null;
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
  // TC-512 (AC-11) — separation invariant for the lean sources.
  // ===========================================================================
  group('TC-512 lean sources import only dart:*, flame, pure siblings (AC-11)', () {
    const leanSources = <String>[_cockpitPainter, _journeyGame];

    test('eachLeanSource_importsOnly_dart_flame_orPureSiblings', () {
      for (final rel in leanSources) {
        final imports = _importTargets(code(rel));
        expect(imports, isNotEmpty, reason: '$rel must declare imports');
        for (final imp in imports) {
          final bool allowed =
              imp.startsWith('dart:') ||
              imp.startsWith('package:flame/') ||
              imp.endsWith('domain/travel_mode.dart') ||
              // Pure scene siblings (each itself under the same invariant): the
              // game wires the painters/geometry/pool/skins/sprites/tint/motion.
              imp.endsWith('.dart') &&
                  !imp.startsWith('package:') &&
                  !imp.contains('engine') &&
                  !imp.contains('bloc') &&
                  !imp.contains('activity');
          expect(
            allowed,
            isTrue,
            reason:
                '$rel imports a disallowed target "$imp" — AC-11 permits only '
                'dart:*, package:flame/*, TravelMode, and pure scene siblings',
          );
        }
      }
    });

    test('noLeanSource_importsAnyFlutterOrMetaSurface', () {
      for (final rel in leanSources) {
        for (final imp in _importTargets(code(rel))) {
          expect(
            imp.startsWith('package:flutter/'),
            isFalse,
            reason: '$rel must not import any Flutter surface ("$imp")',
          );
          expect(
            imp.startsWith('package:meta/'),
            isFalse,
            reason: '$rel must not import package:meta ("$imp")',
          );
        }
      }
    });

    test('noLeanSource_hasForbiddenOsBlocEngineOrChannelToken', () {
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
      for (final rel in leanSources) {
        final src = code(rel);
        for (final t in forbidden) {
          if (src.contains(t)) violations.add('$rel contains "$t"');
        }
      }
      expect(
        violations,
        isEmpty,
        reason:
            'the lean sources breach the separation invariant (AC-11):\n'
            '${violations.join('\n')}',
      );
    });
  });

  // ===========================================================================
  // TC-511 (AC-10) — the lean angle is sourced SOLELY from the in-scene curve.
  // ===========================================================================
  group('TC-511 lean signal sourced solely from the in-scene curve (AC-10)', () {
    test('advanceLeanBody_readsOnlyCurveSeam_reduceMotion_andMode', () {
      final game = code(_journeyGame);
      final body = _methodBody(game, 'void _advanceLean(');
      expect(body, isNotNull, reason: 'the lean update path must exist');
      final b = body!;

      // POSITIVE: its time-varying input is the in-scene curve sample only —
      // worldAtCamera(scroll) -> lateralSlopeAt(...). (centreLineOffsetAt is the
      // alternative permitted signal; the build chose the slope.)
      expect(
        b.contains('worldAtCamera') && b.contains('lateralSlopeAt'),
        isTrue,
        reason:
            'AC-10: the lean must derive its target from the in-scene curve '
            'sample (worldAtCamera -> lateralSlopeAt)',
      );
      // The only gates besides the signal are reduceMotion + the cockpit mode.
      expect(b.contains('_reduceMotion'), isTrue);
      expect(b.contains('TravelMode.car') || b.contains('TravelMode.motorbike'),
          isTrue);

      // NEGATIVE: NO engine / Bloc / OS / second-clock / second-phase input.
      const forbiddenInLeanPath = <String>[
        'JourneyEngine',
        'Bloc',
        'Cubit',
        'ActivityPlugin',
        'getSystemIdleSeconds',
        'isScreenLocked',
        'MethodChannel',
        'DateTime',
        'Stopwatch',
        'Random',
        'Timer',
        'distanceKm',
      ];
      for (final t in forbiddenInLeanPath) {
        expect(
          b.contains(t),
          isFalse,
          reason: 'AC-10: the lean update path must not read "$t"',
        );
      }
    });

    test('rawLeanTargetBody_readsOnlyCurveSeam', () {
      final game = code(_journeyGame);
      final body = _methodBody(game, 'double get rawLeanTargetAngle');
      expect(body, isNotNull);
      final b = body!;
      expect(b.contains('worldAtCamera') && b.contains('lateralSlopeAt'), isTrue);
      for (final t in <String>['DateTime', 'Random', 'Stopwatch', 'Timer',
        'JourneyEngine', 'ActivityPlugin', 'MethodChannel']) {
        expect(b.contains(t), isFalse, reason: 'rawLeanTarget must not read "$t"');
      }
    });

    test('cockpitPainter_leanPath_appliesOnlyACanvasTransform_noSignalSource', () {
      // The painter must only APPLY the angle the game passes (a canvas
      // rotate/translate); it must not COMPUTE the signal itself nor read any OS
      // / engine / clock. It takes `leanRadians` as a parameter.
      final src = code(_cockpitPainter);
      expect(
        src.contains('double leanRadians'),
        isTrue,
        reason: 'AC-10: the painter receives the angle as a passed-in value',
      );
      expect(src.contains('canvas.rotate(leanRadians)'), isTrue,
          reason: 'AC-9: the painter applies the rotation transform');
      for (final t in <String>['lateralSlopeAt', 'DateTime', 'Random',
        'Stopwatch', 'Timer', 'JourneyEngine', 'ActivityPlugin']) {
        expect(
          src.contains(t),
          isFalse,
          reason: 'AC-10: the painter must not compute/read "$t" (angle is given)',
        );
      }
    });
  });

  // ===========================================================================
  // TC-517 (NFR-1 static leg) — no per-frame allocation / constant-cost update.
  // ===========================================================================
  group('TC-517 lean update is alloc-free / O(1) per frame (NFR-1 static)', () {
    test('advanceLeanBody_hasNoPerFrameAllocation_norAccumulatingLoop', () {
      final game = code(_journeyGame);
      final body = _methodBody(game, 'void _advanceLean(')!;

      // No per-frame heap allocation in the angle update: no `new`, no `[...]` /
      // `<...>[` list literals, no Paint/Path/Offset/Matrix4/Vector2/Size/Rect
      // construction on the hot path.
      const allocTokens = <String>[
        ' new ',
        'Paint(',
        'Path(',
        'Offset(',
        'Matrix4',
        'Vector2(',
        'Size(',
        'Rect.',
        '<double>[',
        '<int>[',
        'List<',
      ];
      for (final t in allocTokens) {
        expect(
          body.contains(t),
          isFalse,
          reason:
              'NFR-1: the lean angle update must allocate nothing per frame '
              '(found "$t" in _advanceLean)',
        );
      }

      // Constant-cost: NO loop in the angle update (no for/while) — it is a fixed
      // set of arithmetic ops + one clamp + one lerp, independent of how far the
      // session has scrolled. (The geometry slope it calls is itself a documented
      // O(1) closed form — guarded by journey_dynamic_curve_test.dart NFR-1.)
      expect(body.contains('for ('), isFalse,
          reason: 'NFR-1: no accumulating loop in the angle update');
      expect(body.contains('for('), isFalse);
      expect(body.contains('while ('), isFalse);
      expect(body.contains('while('), isFalse);
    });

    test('cockpitPainter_leanTransform_isAllocFree_translateRotateTranslate', () {
      // The lean transform in the painter is a single save/translate/rotate/
      // translate/restore (no Matrix4 / Offset allocation on the hot path).
      final src = code(_cockpitPainter);
      // Find the paint() method body and check the transform block has no
      // per-frame allocation (Matrix4 / new Offset).
      final paintBody = _methodBody(src, 'void paint(');
      expect(paintBody, isNotNull);
      final pb = paintBody!;
      expect(pb.contains('canvas.save()'), isTrue);
      expect(pb.contains('canvas.rotate('), isTrue);
      expect(pb.contains('canvas.translate('), isTrue);
      expect(pb.contains('canvas.restore()'), isTrue);
      // No Matrix4 allocation for the rotation (it uses canvas primitives).
      expect(pb.contains('Matrix4'), isFalse,
          reason: 'NFR-1: the lean transform must use canvas primitives, no Matrix4');
    });
  });
}
