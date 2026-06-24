// Static-inspection separation / purity invariant for route-progress
// (TC-016 / TC-017 static half, and the source-inspection half of TC-NF3).
//
// Reads every route-feature source file from disk and asserts NONE of them
// contain — in CODE (doc comments stripped first) — any OS/activity surface, any
// platform channel, any JourneyEngine import/coupling, any write to engine
// state, or any network / map-tile package. route-progress reads ONLY the
// cumulative `distanceKm` scalar (delivered as a plain double) plus its own
// persisted selection.
//
// Mirrors test/features/journey/presentation/journey_separation_static_test.dart.
//
// The MANUAL ship-blocker /privacy-audit (TC-018) and the device frame-timing
// (TC-NF2) / network-disabled device run (TC-NF3 device half) are NOT automated
// here — see the test-plan; they are deferred-to-manual.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every route-feature source file under inspection (domain + presentation +
/// data). Relative to the package root.
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
  'lib/features/route/presentation/route_map_screen.dart',
  'lib/features/route/presentation/route_map_painter.dart',
  'lib/features/route/presentation/start_picker.dart',
  'lib/features/route/data/shared_preferences_route_repository.dart',
];

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

  Map<String, String> codeByFile() {
    final map = <String, String>{};
    for (final rel in _routeFiles) {
      final file = File('${root.path}/$rel');
      expect(file.existsSync(), isTrue, reason: 'missing source: $rel');
      map[rel] = _stripComments(file.readAsStringSync());
    }
    return map;
  }

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

    test('noPlatformServicesImportAnywhereInRoute', () {
      // Unlike journey-view's sprite store, NO route file legitimately needs
      // flutter services (no asset bundle, no platform channel). Ban it outright.
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
      // holds no JourneyEngine reference.)
      final code = codeByFile();
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
      final code = codeByFile();
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
      final code = codeByFile();
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

  group('TC-NF3 (source half) route uses no network / tile provider', () {
    // Any network or map-tile dependency would break the offline promise.
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
