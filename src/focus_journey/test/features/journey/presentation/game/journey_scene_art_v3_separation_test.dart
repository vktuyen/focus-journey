// journey-scene-art-v3 separation invariant + cosmetic-only engine guarantees.
//
// Covers:
//   TC-315 (AC-13) — the Flame scene + its siblings (incl. the re-source's
//                    manifest, sprites loader, side-object pool, road_painter
//                    band source) import ONLY dart:*, package:flame/*, and the
//                    pure-Dart domain TravelMode; no flutter_bloc / JourneyEngine
//                    / ActivityPlugin / MethodChannel / OS read; state still
//                    enters via applyState(...).
//   TC-312 (AC-12, AC-13 static half) — the engine/domain/ticker hold NO
//                    reference to any scene-render / art type (so the re-source
//                    can never perturb engine truth), AND the engine's counters
//                    are byte-for-byte deterministic for identical scripted input
//                    (exact equality, not ±epsilon) — the runtime AC-12 leg.
//
// Static halves read source from disk (doc comments stripped). The engine
// determinism leg drives a pure JourneyEngine with a scripted clock — no scene,
// no OS, no real timers.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/mock_activity_source.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/journey_engine.dart';

/// The Flame scene files the re-source touches — every one must obey the
/// separation invariant. Relative to the package root.
const List<String> _sceneFiles = <String>[
  'lib/features/journey/presentation/game/journey_game.dart',
  'lib/features/journey/presentation/game/journey_assets.dart',
  'lib/features/journey/presentation/game/journey_sprites.dart',
  'lib/features/journey/presentation/game/side_object_pool.dart',
  'lib/features/journey/presentation/game/road_painter.dart',
  'lib/features/journey/presentation/game/journey_skins.dart',
  'lib/features/journey/presentation/game/scene_motion.dart',
  'lib/features/journey/presentation/game/road_geometry.dart',
  'lib/features/journey/presentation/game/day_night_tint.dart',
  'lib/features/journey/presentation/game/cockpit_painter.dart',
];

/// The engine/domain/ticker files that must hold NO scene-render/art reference.
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

/// A scripted clock advanced by hand — no wall-clock waits.
class _ScriptClock implements Clock {
  _ScriptClock(this._now);
  DateTime _now;
  void advance(Duration d) => _now = _now.add(d);
  @override
  DateTime now() => _now;
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
  // TC-315 (AC-13) — scene + siblings import only dart:*, flame/*, TravelMode.
  // ===========================================================================
  group('TC-315 scene separation invariant after the re-source (AC-13)', () {
    test('everySceneFile_importsOnly_dart_flame_TravelMode_orPureSiblings', () {
      final violations = <String>[];
      for (final rel in _sceneFiles) {
        final imports = _importTargets(code(rel));
        for (final imp in imports) {
          final bool allowed =
              imp.startsWith('dart:') ||
              imp.startsWith('package:flame/') ||
              // pure-Dart domain TravelMode
              imp.endsWith('domain/travel_mode.dart') ||
              // sibling presentation/game files (themselves under this invariant)
              (!imp.startsWith('package:') &&
                  !imp.startsWith('dart:') &&
                  imp.endsWith('.dart')) ||
              // the ONLY allowed Flutter surface: asset bundle/manifest, and only
              // for the sprite store (restricted further by its `show` clause and
              // the channel-token ban below).
              (imp == 'package:flutter/services.dart' &&
                  rel.endsWith('journey_sprites.dart'));
          if (!allowed) {
            violations.add('$rel imports disallowed target "$imp"');
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('noSceneFile_containsAForbiddenOsBlocOrEngineToken', () {
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
        'DateTime.now(',
      ];
      final violations = <String>[];
      for (final rel in _sceneFiles) {
        final src = code(rel);
        for (final t in forbidden) {
          if (src.contains(t)) violations.add('$rel contains "$t"');
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('stateStillEntersViaApplyState_singleSeam', () {
      // The scene's only state-entry seam is applyState(...) with the documented
      // signature — re-affirm it survived the re-source unchanged.
      final src = code(
        'lib/features/journey/presentation/game/journey_game.dart',
      );
      expect(src.contains('void applyState('), isTrue);
      for (final param in const <String>[
        'required bool moving',
        'required TravelMode mode',
        'required bool reduceMotion',
        'required double timeOfDayHours',
      ]) {
        expect(
          src.contains(param),
          isTrue,
          reason: 'applyState must keep its plain-value param "$param"',
        );
      }
    });

    test('roadPainter_bandSource_holdsNoGeographicOrClockInput', () {
      // AC-5 structural: the beach band cycles by scroll phase only — the band
      // source reads no clock/geography/coordinate input.
      final src = code(
        'lib/features/journey/presentation/game/road_painter.dart',
      );
      const forbidden = <String>[
        'DateTime.now(',
        'latitude',
        'longitude',
        'LatLng',
        'province',
        'geograph',
        'coordinate',
      ];
      final hits = <String>[
        for (final t in forbidden)
          if (src.contains(t)) t,
      ];
      expect(
        hits,
        isEmpty,
        reason:
            'road_painter band source must take no geographic/clock input: $hits',
      );
      // The theme seam is a pure function of the scroll offset.
      expect(
        src.contains('backdropThemeIndexFor(double scrollOffset)'),
        isTrue,
      );
    });
  });

  // ===========================================================================
  // TC-312 (AC-12 + AC-13 static half) — engine holds no art reference; counters
  // byte-for-byte deterministic.
  // ===========================================================================
  group('TC-312 engine is cosmetic-only + byte-for-byte deterministic (AC-12)', () {
    test('engineAndDomain_holdNoSceneRenderOrArtReference', () {
      // The engine/domain/ticker reference no scene/art type, so the wholesale
      // re-source (which touches ONLY the scene's image files) cannot perturb
      // engine truth. This is the AC-13 dependency-direction half folded into
      // AC-12 (the runtime equality leg below relies on this isolation).
      const renderArtTokens = <String>[
        'JourneyGame',
        'road_painter',
        'RoadPainter',
        'JourneyAssets',
        'JourneySprites',
        'SideObjectPool',
        'SideObjectKind',
        'coastBand',
        'backdropThemeIndex',
        'scrollOffset',
        'cruiseSpeed',
        'SceneMotion',
      ];
      final violations = <String>[];
      for (final rel in _engineFiles) {
        final src = code(rel);
        for (final t in renderArtTokens) {
          if (src.contains(t)) {
            violations.add('$rel references art/render "$t"');
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('counters_areByteForByteIdentical_forIdenticalScriptedInput', () {
      // AC-12 runtime leg: build TWO independent engines and feed them an
      // IDENTICAL scripted tick sequence with identical injected elapsed. Because
      // the engine is isolated from the art (proven above), the re-source cannot
      // change these numbers — so two runs of the same input must be EXACTLY
      // equal (the byte-for-byte contract, asserted with == not ±epsilon).
      JourneyEngine mkEngine(_ScriptClock clock) => JourneyEngine(
        clock: clock,
        activityPlugin: MockActivitySource(idleSeconds: 0, screenLocked: false),
      );

      // A scripted sequence: active, brief idle within grace, paused-idle, active.
      const seq = <({Duration delta, int idle})>[
        (delta: Duration(seconds: 5), idle: 0),
        (delta: Duration(seconds: 5), idle: 2),
        (delta: Duration(seconds: 30), idle: 120),
        (delta: Duration(seconds: 600), idle: 600),
        (delta: Duration(seconds: 5), idle: 0),
        (delta: Duration(seconds: 5), idle: 0),
      ];

      ({double km, Duration active, Duration raw, Duration idle}) run() {
        final clock = _ScriptClock(DateTime(2026, 6, 25, 9));
        final engine = mkEngine(clock);
        for (final step in seq) {
          clock.advance(step.delta);
          engine.tick(step.delta, idleSeconds: step.idle, screenLocked: false);
        }
        return (
          km: engine.distanceKm,
          active: engine.activeTimeToday,
          raw: engine.rawActiveTime,
          idle: engine.idleTimeToday,
        );
      }

      final a = run();
      final b = run();
      // EXACT equality (byte-for-byte), not closeTo — engine truth, not floats.
      expect(a.km, b.km);
      expect(a.active, b.active);
      expect(a.raw, b.raw);
      expect(a.idle, b.idle);
      // Sanity: the sequence actually accrued distance (the run is non-trivial).
      expect(a.km, greaterThan(0));
    });
  });
}
