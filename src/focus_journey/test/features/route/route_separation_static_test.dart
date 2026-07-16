// Static-inspection separation / purity invariant for the route feature
// (TC-016 / TC-017 static half, and the source-inspection privacy half —
// TC-816 / TC-817 for the vietnam-map-fidelity base map).
//
// Reads every route-feature source file from disk and asserts NONE of them
// contain — in CODE (doc comments stripped first) — any OS/activity surface, any
// platform channel, any JourneyEngine import/coupling, any write to engine
// state, or (the privacy half) any network / map-tile-fetch API.
//
// ADR-0008 UPDATE (why this test changed): the map slice USED to fetch anonymous
// OSM tiles via `flutter_map`'s `TileLayer` (ADR-0004) — that was the one blessed
// network exception. ADR-0008(c) DROPPED the OSM `TileLayer`: the base map is now
// a BUNDLED, OFFLINE GeoJSON asset (`assets/map/vietnam_provinces_2025.geojson`)
// rendered as a static `flutter_map` `PolygonLayer`, so the WHOLE route feature —
// map slice included — now issues ZERO network egress. The no-network invariant
// below therefore covers EVERY route file, with no exceptions. `flutter_map`
// itself is allowed (it renders static polygons, not tiles) and
// `flutter/services` is allowed (the `BaseMapRepository` reads the bundled asset
// through `rootBundle`/`AssetBundle` — the same seam the app uses for its CC0
// art) — what stays banned is any real network/tile-fetch client.
//
// Mirrors test/features/journey/presentation/journey_separation_static_test.dart.
//
// The MANUAL ship-blocker /privacy-audit (TC-M-PRIV) and the network-disabled
// device run are NOT automated here — see the test-plan; they are
// deferred-to-manual.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The base-map data repository — called out explicitly because it is the one
/// route file that legitimately imports `flutter/services` (for `rootBundle`).
/// The privacy guard proves that import is asset loading, never a network client.
const String _baseMapRepository = 'lib/features/route/data/base_map_repository.dart';

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

/// Every `.dart` source file under `lib/features/route`, relative to the package
/// root. Globbed (not hand-listed) so a file added by a sibling slice is covered
/// automatically — the separation/offline invariant must hold for the whole
/// feature, not just the files that existed when this test was written.
List<String> _allRouteFiles(Directory root) {
  final dir = Directory('${root.path}/lib/features/route');
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .map((f) => f.path.substring(root.path.length + 1))
      .toList()
    ..sort();
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

  final routeFiles = _allRouteFiles(root);

  test('routeFileScanIsNonEmpty_soTheGuardIsMeaningful', () {
    expect(routeFiles, isNotEmpty);
    expect(routeFiles, contains(_baseMapRepository));
  });

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
      // Covers the map slice too: the picker/celebration, the flutter_map surface
      // and the bundled-base repository read NO OS/activity surface (separation).
      final code = codeFor(routeFiles);
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

    test('noJourneyEngineCouplingAnywhereInRoute', () {
      // route consumes a plain `double` distance scalar / derived value types —
      // it imports neither the engine nor the activity feature.
      final code = codeFor(routeFiles);
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
    const engineStateFields = <String>[
      'activeTimeToday',
      'rawActiveTime',
      'idleTimeToday',
    ];

    test('noAssignmentToEngineStateFieldsInRouteFiles', () {
      final code = codeFor(routeFiles);
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
      final code = codeFor(routeFiles);
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

  group('TC-816/TC-817 route renders fully offline — no network/tile fetch', () {
    // ADR-0008: the base map is a BUNDLED asset (no OSM tiles anymore), so the
    // whole route feature must be network-free. `package:flutter_map` is NOT
    // banned (it renders static polygons, not tiles) and `flutter/services` is
    // NOT banned (asset loading via rootBundle). What is banned is any genuine
    // network / tile-fetch client.
    const forbiddenNetwork = <String>[
      'dart:io', // sockets / HttpClient
      'package:http',
      'package:dio',
      'TileLayer', // OSM tile fetch — dropped by ADR-0008(c)
      'TileProvider',
      'urlTemplate', // OSM tile URL template
      'openstreetmap',
      'NetworkImage',
      'HttpClient',
      'Socket(',
      'WebSocket',
    ];

    test('noNetworkOrTileTokenInAnyRouteCodeLine', () {
      final code = codeFor(routeFiles);
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
            'route must render fully offline (ADR-0008 — no network/tiles):\n'
            '${violations.join('\n')}',
      );
    });

    test('noLocationOrGpsApiAnywhereInRoute', () {
      // NFR-2 / TC-817: the georeferencing bounds + coordinates are static
      // app-shipped constants — never a device-location read.
      const locationTokens = <String>[
        'geolocator',
        'package:location',
        'CoreLocation',
        'getCurrentPosition',
        'LocationPermission',
      ];
      final code = codeFor(routeFiles);
      final violations = <String>[];
      code.forEach((rel, src) {
        for (final token in locationTokens) {
          if (src.contains(token)) {
            violations.add('$rel contains location token "$token"');
          }
        }
      });
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('baseMapRepositoryUsesFlutterServicesForAssetsOnly_notNetwork', () {
      // The base map's ONLY input is the bundled asset read through
      // rootBundle/AssetBundle. `flutter/services` is present (allowed), but the
      // file must add NO network client — proving the "no new egress" promise
      // (TC-816) at the source that replaced the OSM tile fetch.
      final src = codeFor(<String>[_baseMapRepository])[_baseMapRepository]!;
      expect(
        src.contains('package:flutter/services.dart'),
        isTrue,
        reason: 'base map repo is expected to read the bundled asset',
      );
      for (final token in forbiddenNetwork) {
        expect(
          src.contains(token),
          isFalse,
          reason: '$_baseMapRepository must not add a network client ("$token")',
        );
      }
    });
  });
}
