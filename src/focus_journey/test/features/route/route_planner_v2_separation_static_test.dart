// Static-inspection privacy/separation invariant for the route-planner-v2 slice
// (ADR-0005). Reads every NEW route-planner-v2 source file from disk and asserts
// — in CODE (doc comments stripped first) — that selection/auto-insert/review/
// abandon read ONLY the static map-experience geography, use NO device-location /
// GPS / geolocation API, make NO network call, and that the auto-insert/route
// resolver is a pure, Flutter-free domain function.
//
// The automatable subset of the GATING NFR-2; mirrors route_separation_static_test
// + map_surface_test TC-230/TC-231 intent. The full /privacy-audit PASS + runtime
// egress legs are the manual gate TC-M-PRIV (see the companion checklist).
//
// Traceability (TC + AC/NFR ids per group):
//   TC-307 (AC-3/NFR-2) auto-insert resolver reads only static geography + is a
//                       pure, Flutter-free, timer-free domain function
//   TC-337 (NFR-2) no device-location / GPS API; descriptor carries no position
//   TC-338 (NFR-2/NFR-1) selection/auto-insert/review/abandon make NO network call

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The DOMAIN route-planner-v2 files — must be pure, Flutter-free, network-free,
/// location-free (the auto-insert resolver + the persisted descriptor).
const List<String> _domainFiles = <String>[
  'lib/features/route/domain/route_planner.dart',
  'lib/features/route/domain/route_plan.dart',
];

/// The PRESENTATION route-planner-v2 files — may import Flutter UI (material) but
/// must use NO device-location / GPS / network / platform channel.
const List<String> _presentationFiles = <String>[
  'lib/features/route/presentation/route_picker.dart',
  'lib/features/route/presentation/route_review_screen.dart',
  'lib/features/route/presentation/route_planner_flow.dart',
];

const List<String> _allFiles = <String>[..._domainFiles, ..._presentationFiles];

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
/// the files intentionally DOCUMENT the privacy invariant in their doc comments.
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

  group('TC-307 (AC-3/NFR-2) auto-insert resolver reads only static geography', () {
    test('the domain resolver/descriptor are Flutter-free + timer-free', () {
      final code = codeFor(_domainFiles);
      const forbidden = <String>[
        'package:flutter/',
        'package:flame',
        'package:latlong2',
        'dart:async',
        'Timer',
        'DateTime.now(',
      ];
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
        reason:
            'the auto-insert resolver must be a pure, Flutter-free, timer-free '
            'domain function (AC-3 / NFR-1):\n${violations.join('\n')}',
      );
    });

    test('the resolver imports the single map-experience geography model only', () {
      final code = codeFor(<String>[
        'lib/features/route/domain/route_planner.dart',
      ]);
      final src = code.values.single;
      // It consumes the shared static geography model (province_geography +
      // province_chain) — it does NOT define a rival geography/distance constant.
      expect(src.contains("import 'province_geography.dart'"), isTrue);
      expect(src.contains("import 'province_chain.dart'"), isTrue);
      // No rival hard-coded km/coordinate table re-derived inside the resolver.
      expect(
        RegExp(r'GeoCoordinate\(latitude:').hasMatch(src),
        isFalse,
        reason:
            'the resolver must not invent coordinates (build-once-consume-many)',
      );
    });
  });

  group('TC-337 (NFR-2) no device-location / GPS API in the slice', () {
    test('no geolocation / GPS / location-channel token in any slice file', () {
      final code = codeFor(_allFiles);
      const forbiddenLocation = <String>[
        'geolocator',
        'package:location',
        'CoreLocation',
        'geocoding',
        'CLLocation',
        'getCurrentPosition',
        'LocationPermission',
        'MethodChannel',
        'EventChannel',
        'package:flutter/services.dart',
      ];
      final violations = <String>[];
      code.forEach((rel, src) {
        for (final token in forbiddenLocation) {
          if (src.contains(token)) {
            violations.add('$rel contains location/channel token "$token"');
          }
        }
      });
      expect(
        violations,
        isEmpty,
        reason:
            'the slice must read NO device location / GPS (NFR-2 gating):\n'
            '${violations.join('\n')}',
      );
    });

    test('the persisted descriptor carries no device-position field', () {
      final code = codeFor(<String>[
        'lib/features/route/domain/route_plan.dart',
      ]);
      final src = code.values.single;
      // RoutePlan persists static reference ids + a distance offset + lifecycle —
      // never the user's position. No latitude/longitude/GPS field is serialised.
      for (final token in <String>[
        'latitude',
        'longitude',
        'gps',
        'coordinate',
      ]) {
        expect(
          src.toLowerCase().contains(token),
          isFalse,
          reason:
              'RoutePlan must not serialise a device-position field ($token)',
        );
      }
    });
  });

  group(
    'TC-338 (NFR-2/NFR-1) selection/auto-insert/review/abandon: no network',
    () {
      test('no network / tile / socket token in any slice file', () {
        final code = codeFor(_allFiles);
        const forbiddenNetwork = <String>[
          'dart:io',
          'package:http',
          'package:dio',
          'package:flutter_map',
          'TileProvider',
          'NetworkImage',
          'HttpClient',
          'Socket(',
          'WebSocket',
        ];
        final violations = <String>[];
        code.forEach((rel, src) {
          for (final token in forbiddenNetwork) {
            if (src.contains(token)) {
              violations.add('$rel contains network token "$token"');
            }
          }
        });
        expect(
          violations,
          isEmpty,
          reason:
              'selection/auto-insert/review/abandon must make NO network call '
              '(NFR-2 / NFR-1 — pure in-memory + local persistence):\n'
              '${violations.join('\n')}',
        );
      });
    },
  );
}
