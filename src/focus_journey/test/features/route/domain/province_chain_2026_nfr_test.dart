// province-chain-2026 — non-functional guards (NFR-1 build-once, NFR-2 privacy).
//
// Traceability (one test <-> one case; PC + NFR ids in each description):
//   PC-928 (NFR-1) the chain + geography are top-level constants built ONCE and
//                  the projector precomputes its cumulative-km + coordinate arrays
//                  once in its constructor — nothing is re-parsed/re-allocated per
//                  access (static / hot-path guard; mirrors the sibling TC-820).
//   PC-929 (NFR-2) the slice's new chain/geography/haversine source imports no
//                  geolocation/GPS/location API and adds no new network/file read,
//                  and no GPS package was added to pubspec — every coordinate is
//                  static reference data (local-only, BR-1). Gating audit is
//                  TC-M-PRIV; this is its static reinforcement.
//
// Deterministic, offline: pure-data assertions + source-level static inspection
// (reads shipped .dart / pubspec from disk, walking up from the test cwd).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_polyline_projector.dart';

String _readSource(String relativePath) {
  Directory dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    final candidate = File('${dir.path}/$relativePath');
    if (candidate.existsSync()) {
      return candidate.readAsStringSync();
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('could not locate $relativePath from cwd ${Directory.current.path}');
}

/// Strips `//`/`///` line + doc comments so import/lexical checks see code only.
String _codeOnly(String source) => source
    .split('\n')
    .map((line) {
      final idx = line.indexOf('//');
      return idx < 0 ? line : line.substring(0, idx);
    })
    .join('\n');

void main() {
  group('build-once / memoized (NFR-1 / PC-928)', () {
    test('PC-928 chainAndGeographyAreSingleTopLevelConstants', () {
      // Repeated access returns the SAME instances (top-level `final` constants,
      // built once) — no per-access rebuild.
      expect(identical(vietnamProvinceChain, vietnamProvinceChain), isTrue);
      expect(identical(vietnamProvinceChain.nodes, vietnamProvinceChain.nodes), isTrue);
      expect(
        identical(vietnamProvinceChain.segmentsKm, vietnamProvinceChain.segmentsKm),
        isTrue,
      );
      // Single source: the geography positions the SAME chain instance.
      expect(identical(vietnamProvinceGeography.chain, vietnamProvinceChain), isTrue);
      // The node/segment lists are unmodifiable (built once, never mutated).
      expect(
        () => vietnamProvinceChain.segmentsKm.add(1),
        throwsUnsupportedError,
      );
    });

    test('PC-928 projectorPrecomputesArraysOnce_repeatQueriesAreDeterministic', () {
      final projector = RoutePolylineProjector.fromRoute(
        start: vietnamProvinceChain.southTip,
        direction: JourneyDirection.towardHaGiang,
        geography: vietnamProvinceGeography,
      );
      // Precomputed length is stable; repeated projections are identical (no
      // re-parse / re-derive per call).
      final len1 = projector.routeLengthKm;
      final len2 = projector.routeLengthKm;
      expect(len1, len2);
      const d = 1234.5;
      expect(projector.coordinateAt(d), projector.coordinateAt(d));
      // Source-level: the projector's arrays are `late final` (assigned once in
      // the constructor), not recomputed per query.
      final src = _readSource(
        'lib/features/route/domain/route_polyline_projector.dart',
      );
      expect(src.contains('late final List<double> _cumulativeKm'), isTrue);
      expect(src.contains('late final List<GeoCoordinate> _coordinates'), isTrue);
    });

    test('PC-928 chainConstantIsDeclaredTopLevelFinal_builtOnce', () {
      final chainSrc = _codeOnly(
        _readSource('lib/features/route/domain/province_chain.dart'),
      );
      expect(
        chainSrc.contains('final ProvinceChain vietnamProvinceChain'),
        isTrue,
      );
      final geoSrc = _codeOnly(
        _readSource('lib/features/route/domain/province_geography.dart'),
      );
      expect(
        geoSrc.contains('final ProvinceGeography vietnamProvinceGeography'),
        isTrue,
      );
    });
  });

  group('no new location / network / file read (NFR-2 / PC-929)', () {
    // The slice's NEW / rebuilt pure-data source. None of it may reach for a
    // device signal, a network socket, or the filesystem.
    const sliceSources = <String>[
      'lib/features/route/domain/vietnam_units_2026.dart',
      'lib/features/route/domain/province_chain.dart',
      'lib/features/route/domain/province_geography.dart',
      'lib/features/route/domain/haversine.dart',
      'lib/features/route/domain/route_polyline_projector.dart',
      'lib/features/route/domain/route_planner.dart',
    ];

    // Forbidden import / API tokens (case-insensitive).
    const forbidden = <String>[
      'geolocator',
      'geolocation',
      'geocoding',
      'package:location',
      'gps',
      'dart:io',
      'dart:ffi',
      'package:http',
      'httpclient',
      'methodchannel',
      'platformchannel',
      'shared_preferences',
    ];

    test('PC-929 sliceSourceImportsNoLocationNetworkOrFileApi', () {
      for (final path in sliceSources) {
        final code = _codeOnly(_readSource(path)).toLowerCase();
        for (final token in forbidden) {
          expect(
            code.contains(token),
            isFalse,
            reason: '$path must not reference "$token" (NFR-2 local-only)',
          );
        }
      }
    });

    test('PC-929 pubspecAddsNoGeolocationOrGpsDependency', () {
      final pubspec = _readSource('pubspec.yaml').toLowerCase();
      for (final token in const <String>[
        'geolocator',
        'geolocation',
        'geocoding',
        'gps',
      ]) {
        expect(
          pubspec.contains(token),
          isFalse,
          reason: 'pubspec must not declare a "$token" dependency (NFR-2)',
        );
      }
    });
  });
}
