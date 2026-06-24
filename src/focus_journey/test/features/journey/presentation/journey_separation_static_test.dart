// Static-inspection separation invariant (TC-009 / TC-010 static half).
//
// Reads the journey-view source files from disk and asserts NONE of them
// contain — in CODE (doc comments stripped first) — any OS/activity surface or
// any write to journey state. This is the separation invariant (AC-9/AC-10):
// the scene is a pure VIEW of state/mode/distanceKm and reads no OS signal.
//
// The runtime half of TC-010 (a fake cubit recording write attempts) lives in
// the screen widget test.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The journey-view source files under inspection (the scene + its wrapper +
/// the cubit + view-state). Relative to the package root.
const List<String> _journeyViewFiles = <String>[
  'lib/features/journey/presentation/journey_screen.dart',
  'lib/features/journey/presentation/journey_cubit.dart',
  'lib/features/journey/presentation/journey_view_state.dart',
  'lib/features/journey/presentation/game/journey_game.dart',
  'lib/features/journey/presentation/game/journey_assets.dart',
  'lib/features/journey/presentation/game/journey_skins.dart',
  'lib/features/journey/presentation/game/journey_sprites.dart',
  'lib/features/journey/presentation/game/scene_motion.dart',
  'lib/features/journey/presentation/game/side_object_pool.dart',
  'lib/features/journey/presentation/game/road_painter.dart',
  'lib/features/journey/presentation/game/day_night_tint.dart',
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

/// Strips `//`-line comments, `///` doc comments, and `/* */` block comments so
/// matches are against CODE only (doc-comment mentions of these terms — which
/// the files intentionally use to DOCUMENT the invariant — are allowed).
String _stripComments(String source) {
  // Remove block comments first.
  final noBlock = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  final buffer = StringBuffer();
  for (final line in noBlock.split('\n')) {
    final idx = line.indexOf('//');
    if (idx >= 0) {
      buffer.writeln(line.substring(0, idx));
    } else {
      buffer.writeln(line);
    }
  }
  return buffer.toString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final root = _packageRoot();

  Map<String, String> codeByFile() {
    final map = <String, String>{};
    for (final rel in _journeyViewFiles) {
      final file = File('${root.path}/$rel');
      expect(file.existsSync(), isTrue, reason: 'missing source: $rel');
      map[rel] = _stripComments(file.readAsStringSync());
    }
    return map;
  }

  group('TC-009 scene source reads no OS/activity surface (code only)', () {
    // Forbidden tokens that would indicate the scene reaching for an OS/activity
    // signal or making its own activity decision. Applies to ALL journey-view
    // files. (The cubit's documented exception — it READS a JourneyEngine's
    // getters — is checked separately below; that read is a pure mapping, not an
    // OS/activity surface, so JourneyEngine is intentionally NOT in this list.)
    const forbidden = <String>[
      'ActivityPlugin',
      'getSystemIdleSeconds',
      'isScreenLocked',
      'MethodChannel',
      'EventChannel',
      'BasicMessageChannel',
      'DateTime.now(',
    ];

    test('noForbiddenOsActivityTokenInAnyJourneyViewCodeLine', () {
      final code = codeByFile();
      final violations = <String>[];
      code.forEach((rel, src) {
        for (final token in forbidden) {
          if (src.contains(token)) {
            violations.add('$rel contains forbidden token "$token"');
          }
        }
      });
      expect(
        violations,
        isEmpty,
        reason: 'separation invariant breached:\n${violations.join('\n')}',
      );
    });

    test('noPlatformChannelImport', () {
      // The separation invariant bans the OS/platform-channel SURFACE, not the
      // asset surface. `package:flutter/services.dart` is the only public home
      // of both `AssetBundle`/`AssetManifest`/`rootBundle` (asset loading — used
      // by the sprite store to pre-check which curated files actually shipped,
      // the B-1 fix) AND `MethodChannel`/`EventChannel` (platform channels). So
      // we allow that import ONLY when restricted to asset-bundle symbols, and
      // we still forbid every platform-channel token everywhere (enforced by
      // `noForbiddenOsActivityTokenInAnyJourneyViewCodeLine` above). Any OTHER
      // file importing services at all is still a violation.
      const assetBundleAllowed = <String>{
        'lib/features/journey/presentation/game/journey_sprites.dart',
      };
      // The only services symbols the sprite store may use. (Channel tokens are
      // independently banned for ALL files in the forbidden-token test.)
      const allowedServicesSymbols = <String>[
        'AssetBundle',
        'AssetManifest',
        'rootBundle',
      ];

      final code = codeByFile();
      code.forEach((rel, src) {
        final importsServices = src.contains('package:flutter/services.dart');
        if (!importsServices) {
          return;
        }
        expect(
          assetBundleAllowed.contains(rel),
          isTrue,
          reason: '$rel imports flutter services (platform channels)',
        );
        // The allowed file must show its `show` clause restricting the import
        // to asset-bundle symbols only — so it can never reach a channel.
        final showClause = RegExp(
          r"import\s+'package:flutter/services\.dart'\s+show\s+([^;]+);",
        ).firstMatch(src);
        expect(
          showClause,
          isNotNull,
          reason: '$rel must import services with an explicit `show` clause',
        );
        final shown = showClause!
            .group(1)!
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        for (final symbol in shown) {
          expect(
            allowedServicesSymbols.contains(symbol),
            isTrue,
            reason: '$rel imports a disallowed services symbol: "$symbol"',
          );
        }
      });
    });

    test('cubit_isTheOnlyFileAllowedToImportTheEngine_andSceneFilesDoNot', () {
      // The Flame scene files (game/**) must not import the engine at all; they
      // take plain values via applyState.
      final code = codeByFile();
      code.forEach((rel, src) {
        if (rel.contains('/game/')) {
          expect(
            src.contains('journey_engine'),
            isFalse,
            reason: '$rel (scene) must not import the engine',
          );
          expect(
            src.contains('flutter_bloc'),
            isFalse,
            reason: '$rel (scene) must not import flutter_bloc',
          );
        }
      });
    });
  });

  group('TC-010 scene mutates no journey state (static half)', () {
    // Journey-state field names that the scene must only READ, never WRITE.
    const journeyStateFields = <String>[
      'distanceKm',
      'activeTimeToday',
      'rawActiveTime',
      'idleTimeToday',
    ];

    test('noAssignmentToJourneyStateFieldsInSceneFiles', () {
      final code = codeByFile();
      final violations = <String>[];
      code.forEach((rel, src) {
        // The Flame scene (game/**) is what must accrue NO distance. The
        // view-state value object legitimately holds an immutable `distanceKm`
        // FIELD initialised in its constructor (it carries the read value to the
        // counter widget); that is a constructor initialiser, not a runtime
        // mutation of engine state, so it is excluded from this scene check.
        if (!rel.contains('/game/')) return;
        for (final field in journeyStateFields) {
          // Look for an assignment "<field> =" or "<field> +=" / "<field>++".
          final assign = RegExp(
            r'(?<![A-Za-z0-9_.])' + field + r'\s*(=[^=]|\+=|-=|\+\+|--)',
          );
          for (final m in assign.allMatches(src)) {
            final snippet = src
                .substring(m.start, (m.end + 10).clamp(0, src.length))
                .trim();
            // Allow named-parameter passing like `distanceKm: x` (colon, not =).
            if (snippet.startsWith('$field:')) continue;
            violations.add('$rel writes journey state field: $snippet');
          }
        }
      });
      expect(
        violations,
        isEmpty,
        reason:
            'scene must not mutate journey state:\n${violations.join('\n')}',
      );
    });
  });
}
