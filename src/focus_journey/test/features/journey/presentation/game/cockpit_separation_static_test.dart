// Static-inspection separation invariant for journey-pov (TC-214 / AC-9) and
// the cosmetic-only dependency direction static half (TC-215 / AC-10 static).
//
// AC-9: the Flame scene + its siblings — INCLUDING the new cockpit source
// (cockpit_painter.dart) — import ONLY `dart:*`, `package:flame/*`, and the
// pure-Dart domain `TravelMode` (plus the sibling presentation/game files,
// which are themselves under the same invariant, and the asset-bundle surface
// allowed for the sprite store only). NO flutter_bloc, JourneyEngine,
// ActivityPlugin, MethodChannel/platform channel, or OS idle/lock/screen/
// location read.
//
// This MIRRORS journey_separation_static_test.dart's approach but is scoped to
// the journey-pov cockpit additions so the new file is explicitly guarded
// (re-run on any new cockpit source). It is positive (allowlist of imports) AND
// negative (forbidden tokens) for cockpit_painter.dart specifically.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The journey-pov cockpit source + the scene file that composites it. Relative
/// to the package root.
const String _cockpitPainter =
    'lib/features/journey/presentation/game/cockpit_painter.dart';
const String _journeyGame =
    'lib/features/journey/presentation/game/journey_game.dart';
const String _journeyAssets =
    'lib/features/journey/presentation/game/journey_assets.dart';

/// The engine/domain files that must hold NO cockpit / scene-render reference
/// (cosmetic-only dependency direction — AC-10 static half).
const List<String> _engineFiles = <String>[
  'lib/features/journey/domain/journey_engine.dart',
  'lib/features/journey/domain/journey_progress.dart',
  'lib/features/journey/domain/journey_state.dart',
  'lib/features/journey/domain/travel_mode.dart',
  'lib/features/journey/presentation/activity_ticker.dart',
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
/// against CODE only (doc comments intentionally NAME the invariant).
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

  group('TC-214 cockpit_painter separation invariant (AC-9)', () {
    test('cockpitPainter_importsOnly_dart_flame_orPureSiblings', () {
      final imports = _importTargets(code(_cockpitPainter));
      expect(imports, isNotEmpty);
      for (final imp in imports) {
        final bool allowed =
            imp.startsWith('dart:') ||
            imp.startsWith('package:flame/') ||
            // The pure-Dart domain TravelMode + the pure asset manifest are the
            // ONLY in-repo imports allowed (both are themselves separation-clean).
            imp.endsWith('domain/travel_mode.dart') ||
            imp.endsWith('journey_assets.dart');
        expect(
          allowed,
          isTrue,
          reason:
              'cockpit_painter.dart imports a disallowed target "$imp" — '
              'AC-9 permits only dart:*, package:flame/*, TravelMode, and the '
              'pure asset manifest',
        );
      }
    });

    test('cockpitPainter_hasNoForbiddenOsBlocOrEngineToken', () {
      const forbidden = <String>[
        'flutter_bloc',
        'Bloc',
        'Cubit',
        'JourneyEngine',
        'journey_engine',
        'ActivityPlugin',
        'getSystemIdleSeconds',
        'isScreenLocked',
        'MethodChannel',
        'EventChannel',
        'BasicMessageChannel',
        'package:flutter/services',
        'DateTime.now(',
        'distanceKm',
      ];
      final src = code(_cockpitPainter);
      final violations = <String>[
        for (final t in forbidden)
          if (src.contains(t)) t,
      ];
      expect(
        violations,
        isEmpty,
        reason:
            'cockpit_painter.dart breaches the separation invariant with: '
            '$violations',
      );
    });

    test('cockpitPainter_importsNo_flutter_widgets_or_material', () {
      final imports = _importTargets(code(_cockpitPainter));
      for (final imp in imports) {
        expect(
          imp.startsWith('package:flutter/'),
          isFalse,
          reason: 'cockpit_painter.dart must not import any Flutter surface',
        );
      }
    });
  });

  group('TC-214 the scene composites the cockpit but stays clean (AC-9)', () {
    test('journeyGame_referencesCockpitPainter_butNoEngineOrBloc', () {
      final src = code(_journeyGame);
      // It DOES wire the cockpit (composites it).
      expect(src.contains('CockpitPainter'), isTrue);
      // ...but still imports no engine/bloc.
      expect(src.contains('journey_engine'), isFalse);
      expect(src.contains('flutter_bloc'), isFalse);
    });

    test('journeyAssets_cockpitManifest_isPureDart_noOsSurface', () {
      final imports = _importTargets(code(_journeyAssets));
      // The manifest is pure constants — it should import nothing OS/Flutter.
      for (final imp in imports) {
        expect(
          imp.startsWith('package:flutter/') ||
              imp.contains('journey_engine') ||
              imp.contains('flutter_bloc'),
          isFalse,
          reason: 'journey_assets.dart must stay a pure manifest ($imp)',
        );
      }
    });
  });

  group('TC-215 cosmetic-only dependency direction (AC-10 static half)', () {
    // The engine / domain / ticker must hold NO reference to the cockpit or any
    // scene-render type — so a cockpit can never perturb engine numbers.
    const cockpitRenderTokens = <String>[
      'CockpitPainter',
      'cockpit_painter',
      'isCockpitActive',
      'cockpitAssetPaths',
      'cockpitViewportFraction',
      'JourneyGame',
      'cockpitCar',
      'cockpitMotorbike',
    ];

    test('engineAndDomain_holdNoCockpitOrSceneRenderReference', () {
      final violations = <String>[];
      for (final rel in _engineFiles) {
        final src = code(rel);
        for (final token in cockpitRenderTokens) {
          if (src.contains(token)) {
            violations.add('$rel references cockpit/render token "$token"');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason:
            'the engine/domain/ticker must not reference the cockpit or any '
            'scene-render type (cosmetic-only, AC-10):\n'
            '${violations.join('\n')}',
      );
    });
  });
}
