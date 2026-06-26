// Static-inspection separation / purity invariant for route-progress
// (TC-016 / TC-017 static half, and the source-inspection half of TC-NF3).
//
// Reads every route-feature source file from disk and asserts NONE of them
// contain — in CODE (doc comments stripped first) — any OS/activity surface, any
// platform channel, any JourneyEngine import/coupling, or any write to engine
// state. route-progress reads ONLY the cumulative `distanceKm` scalar (delivered
// as a plain double) plus its own persisted selection.
//
// The standalone custom-painted Map tab (`route_map_screen.dart`) was removed in
// the map-experience slice; the start-picker + completion-celebration were
// re-homed into `map_surface.dart` and the map is now drawn with `flutter_map`
// over OpenStreetMap tiles (ADR-0004). So the OS/activity/engine-coupling
// invariant below now also covers the map slice files (map_surface / map_view /
// map_cubit / map_view_state / lat_lng_mapper), while the no-network / no-tile
// (TC-NF3 source half) invariant applies ONLY to the non-map route files — the
// map slice is the one blessed exception that fetches anonymous OSM tiles.
//
// Mirrors test/features/journey/presentation/journey_separation_static_test.dart.
//
// The MANUAL ship-blocker /privacy-audit (TC-018) and the device frame-timing
// (TC-NF2) / network-disabled device run (TC-NF3 device half) are NOT automated
// here — see the test-plan; they are deferred-to-manual.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Non-map route-feature source files (domain + presentation + data) that must
/// stay FULLY OFFLINE — these never touch the network. Relative to the package
/// root. The deleted `route_map_screen.dart` is gone; the map slice files live
/// in [_mapSliceFiles] because they legitimately fetch OSM tiles.
const List<String> _routeFiles = <String>[
  'lib/features/route/domain/journey_direction.dart',
  'lib/features/route/domain/province.dart',
  'lib/features/route/domain/province_chain.dart',
  'lib/features/route/domain/route_position.dart',
  'lib/features/route/domain/route_repository.dart',
  'lib/features/route/domain/route_selection.dart',
  'lib/features/route/domain/route_progress_resolver.dart',
  'lib/features/route/presentation/route_progress_cubit.dart',
  'lib/features/route/presentation/route_view_state.dart',
  'lib/features/route/presentation/route_map_painter.dart',
  'lib/features/route/presentation/start_picker.dart',
  'lib/features/route/data/shared_preferences_route_repository.dart',
];

/// The map-experience slice files (re-homed picker/celebration + the
/// `flutter_map` surface). They MAY fetch anonymous OSM tiles (the one blessed
/// network exception, ADR-0004), so they are exempt from the no-network /
/// no-tile and no-flutter-services invariants — but they MUST still hold the
/// OS/activity-surface, platform-channel, and JourneyEngine-coupling invariant.
const List<String> _mapSliceFiles = <String>[
  'lib/features/route/presentation/map_surface.dart',
  'lib/features/route/presentation/map_view.dart',
  'lib/features/route/presentation/map_cubit.dart',
  'lib/features/route/presentation/map_view_state.dart',
  'lib/features/route/presentation/lat_lng_mapper.dart',
];

/// All route source files the OS/activity/engine-coupling invariant covers.
const List<String> _allRouteFiles = <String>[..._routeFiles, ..._mapSliceFiles];

Directory _packageRoot() {
  Directory dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        Directory('${dir.path}/lib/features/route').existsSync()) {
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
/// the files intentionally DOCUMENT the invariant in their doc comments.
String _stripComments(String source) {
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

  Map<String, String> codeFor(List<String> files) {
    final map = <String, String>{};
    for (final rel in files) {
      final file = File('${root.path}/$rel');
      expect(file.existsSync(), isTrue, reason: 'missing source: $rel');
      map[rel] = _stripComments(file.readAsStringSync());
    }
    return map;
  }

  // The non-map files that must stay fully offline (no network / tiles).
  Map<String, String> codeByFile() => codeFor(_routeFiles);

  group('TC-016 route source reads no OS/activity surface (code only)', () {
    const forbidden = <String>[
      'ActivityPlugin',
      'getSystemIdleSeconds',
      'isScreenLocked',
      'MethodChannel',
      'EventChannel',
      'BasicMessageChannel',
      'DateTime.now(',
    ];

    test('noForbiddenOsActivityTokenInAnyRouteCodeLine', () {
      // Covers the map slice too: the re-homed picker/celebration + the
      // flutter_map surface read NO OS/activity surface (AC-12 / separation).
      final code = codeFor(_allRouteFiles);
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

    test('noPlatformServicesImportAnywhereInRoute', () {
      // The non-map route files need no flutter services (no asset bundle, no
      // platform channel). Ban it outright. (The map slice legitimately imports
      // flutter/services for the injectable TileProvider seam — see map_surface.)
      final code = codeByFile();
      code.forEach((rel, src) {
        expect(
          src.contains('package:flutter/services.dart'),
          isFalse,
          reason: '$rel must not import flutter services',
        );
      });
    });

    test('noJourneyEngineCouplingAnywhereInRoute', () {
      // route-progress consumes a plain `double` scalar — it imports neither the
      // engine nor the activity feature. (AC-16 true-by-construction: the cubit
      // holds no JourneyEngine reference.) Covers the map slice too: it consumes
      // only derived journey value types (segment/progress snapshots), never the
      // engine itself nor the activity feature.
      final code = codeFor(_allRouteFiles);
      code.forEach((rel, src) {
        expect(
          src.contains('journey_engine'),
          isFalse,
          reason: '$rel must not import/couple the JourneyEngine',
        );
        expect(
          src.contains('features/activity'),
          isFalse,
          reason: '$rel must not import the activity feature',
        );
      });
    });
  });

  group('TC-017 route mutates no engine state (static half)', () {
    // Engine/journey-state field names route-progress must never WRITE.
    const engineStateFields = <String>[
      'activeTimeToday',
      'rawActiveTime',
      'idleTimeToday',
    ];

    test('noAssignmentToEngineStateFieldsInRouteFiles', () {
      final code = codeFor(_allRouteFiles);
      final violations = <String>[];
      code.forEach((rel, src) {
        for (final field in engineStateFields) {
          final assign = RegExp(
            r'(?<![A-Za-z0-9_.])' + field + r'\s*(=[^=]|\+=|-=|\+\+|--)',
          );
          for (final m in assign.allMatches(src)) {
            final snippet = src
                .substring(m.start, (m.end + 10).clamp(0, src.length))
                .trim();
            if (snippet.startsWith('$field:')) continue;
            violations.add('$rel writes engine state field: $snippet');
          }
        }
      });
      expect(
        violations,
        isEmpty,
        reason: 'route must not mutate engine state:\n${violations.join('\n')}',
      );
    });

    test('routeOwnedDistanceKmIsNeverAccrued', () {
      // The slice may READ a `distanceKm` scalar and STORE it in immutable view
      // fields (constructor initialisers / named params), but must never accrue
      // it (`distanceKm += ...`, `distanceKm++`). Catch only mutating forms.
      final code = codeFor(_allRouteFiles);
      final violations = <String>[];
      code.forEach((rel, src) {
        final accrue = RegExp(
          r'(?<![A-Za-z0-9_.])distanceKm\s*(\+=|-=|\+\+|--)',
        );
        for (final m in accrue.allMatches(src)) {
          violations.add(
            '$rel accrues distanceKm: ${src.substring(m.start, m.end)}',
          );
        }
      });
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });

  group('TC-NF3 (source half) non-map route uses no network / tile provider', () {
    // Any network or map-tile dependency would break the offline promise for the
    // non-map route files. (The map slice is the one blessed exception — it
    // fetches anonymous OSM tiles, ADR-0004 — so it is deliberately excluded
    // here; its tile-request payload is audited in map_surface_test TC-231.)
    const forbiddenNetwork = <String>[
      'dart:io', // sockets / HttpClient
      'package:http',
      'package:dio',
      'package:flutter_map',
      'TileProvider',
      'NetworkImage',
      'HttpClient',
      'Socket(',
      'WebSocket',
    ];

    test('noNetworkOrTileTokenInAnyRouteCodeLine', () {
      final code = codeByFile();
      final violations = <String>[];
      code.forEach((rel, src) {
        for (final token in forbiddenNetwork) {
          if (src.contains(token)) {
            violations.add('$rel contains network/tile token "$token"');
          }
        }
      });
      expect(
        violations,
        isEmpty,
        reason:
            'route must render fully offline (no network/tiles):\n'
            '${violations.join('\n')}',
      );
    });
  });
}
