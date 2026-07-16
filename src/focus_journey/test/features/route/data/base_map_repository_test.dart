// Unit tests for the base-map DATA layer (vietnam-map-fidelity / ADR-0008(a)):
// AssetBaseMapRepository loads + parses the bundled GeoJSON into the
// framework-free BaseMapGeometry, caches it, and asserts the declared bounds.
//
// Fully deterministic and offline: a FAKE AssetBundle serves small in-memory
// GeoJSON strings (no real asset IO, no network, no widget binding). The fake
// counts loadString calls so the parse-once caching contract is observable.
//
// Covers (see tests/cases/vietnam-map-fidelity.md):
//   - parse: land vs province rings split by properties.role; malformed skipped
//   - caching: JSON is parsed ONCE per repo (NFR-1 / TC-820 data half)
//   - declared-bounds guard: a mismatched bound fails loudly (ADR-0008 accuracy)
//   - degrades sensibly on malformed input (FormatException, not silent junk)

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/data/base_map_repository.dart';

/// A minimal in-memory [AssetBundle] that serves canned strings and counts how
/// many times each key is loaded — no real asset lookup, no platform channel.
class _FakeAssetBundle extends AssetBundle {
  _FakeAssetBundle(this._contents);

  final Map<String, String> _contents;
  int loadStringCalls = 0;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    loadStringCalls++;
    final value = _contents[key];
    if (value == null) {
      throw StateError('asset not found in fake bundle: $key');
    }
    return value;
  }

  @override
  Future<ByteData> load(String key) =>
      throw UnimplementedError('the repository only uses loadString');
}

/// Builds a GeoJSON FeatureCollection string with matching declared bounds and
/// the supplied features. Bounds match the shipped [EquirectangularBounds] so
/// the assert passes unless a test overrides them.
String _featureCollection(
  List<Map<String, dynamic>> features, {
  Map<String, dynamic>? bounds,
}) {
  return jsonEncode(<String, dynamic>{
    'type': 'FeatureCollection',
    'properties': <String, dynamic>{
      'bounds': bounds ??
          <String, dynamic>{
            'north': 24.0,
            'south': 8.0,
            'west': 101.8,
            'east': 110.3,
          },
    },
    'features': features,
  });
}

Map<String, dynamic> _polygon(String role, List<List<double>> ring) =>
    <String, dynamic>{
      'type': 'Feature',
      'properties': <String, dynamic>{'role': role},
      'geometry': <String, dynamic>{
        'type': 'Polygon',
        'coordinates': <dynamic>[ring],
      },
    };

// A closed 4-vertex ring (>= 4 points so it is not skipped) in [lon, lat].
const List<List<double>> _squareRing = <List<double>>[
  <double>[100.0, 10.0],
  <double>[102.0, 10.0],
  <double>[102.0, 12.0],
  <double>[100.0, 12.0],
];

void main() {
  group('AssetBaseMapRepository.load — parsing (via fake bundle)', () {
    test('splitsFeaturesIntoLandAndProvinceRingsByRole', () async {
      final source = _featureCollection(<Map<String, dynamic>>[
        _polygon('land', _squareRing),
        _polygon('province', _squareRing),
        _polygon('province', _squareRing),
      ]);
      final repo = AssetBaseMapRepository(
        bundle: _FakeAssetBundle(<String, String>{kBaseMapAssetPath: source}),
      );

      final geometry = await repo.load();

      expect(geometry.landRings, hasLength(1));
      expect(geometry.provinceUnitCount, 2);
    });

    test('readsCoordinatesAsLonLatPerGeoJsonConvention', () async {
      final source = _featureCollection(<Map<String, dynamic>>[
        _polygon('land', _squareRing),
      ]);
      final repo = AssetBaseMapRepository(
        bundle: _FakeAssetBundle(<String, String>{kBaseMapAssetPath: source}),
      );

      final ring = (await repo.load()).landRings.single;

      // First vertex [100.0, 10.0] -> longitude 100, latitude 10.
      expect(ring.first.longitude, 100.0);
      expect(ring.first.latitude, 10.0);
    });

    test('featureWithoutRole_defaultsToLand', () async {
      final source = _featureCollection(<Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'Feature',
          'properties': <String, dynamic>{}, // no role
          'geometry': <String, dynamic>{
            'type': 'Polygon',
            'coordinates': <dynamic>[_squareRing],
          },
        },
      ]);
      final repo = AssetBaseMapRepository(
        bundle: _FakeAssetBundle(<String, String>{kBaseMapAssetPath: source}),
      );

      final geometry = await repo.load();
      expect(geometry.landRings, hasLength(1));
      expect(geometry.provinceUnitCount, 0);
    });

    test('skipsNonPolygonAndDegenerateRings', () async {
      final source = _featureCollection(<Map<String, dynamic>>[
        _polygon('land', _squareRing), // valid
        <String, dynamic>{
          'type': 'Feature',
          'properties': <String, dynamic>{'role': 'land'},
          'geometry': <String, dynamic>{
            'type': 'LineString', // not a Polygon -> skipped
            'coordinates': <dynamic>[_squareRing],
          },
        },
        _polygon('land', const <List<double>>[
          <double>[100.0, 10.0],
          <double>[101.0, 10.0], // only 2 points (< 4) -> skipped
        ]),
      ]);
      final repo = AssetBaseMapRepository(
        bundle: _FakeAssetBundle(<String, String>{kBaseMapAssetPath: source}),
      );

      final geometry = await repo.load();
      expect(geometry.landRings, hasLength(1));
    });

    test('honoursAnAssetPathOverride', () async {
      const customPath = 'assets/map/custom.geojson';
      final source = _featureCollection(<Map<String, dynamic>>[
        _polygon('province', _squareRing),
      ]);
      final repo = AssetBaseMapRepository(
        bundle: _FakeAssetBundle(<String, String>{customPath: source}),
        assetPath: customPath,
      );

      final geometry = await repo.load();
      expect(geometry.provinceUnitCount, 1);
    });
  });

  group('AssetBaseMapRepository.load — caching (NFR-1 / TC-820 data half)', () {
    test('parsesTheAssetOnce_secondLoadReturnsTheCachedInstance', () async {
      final source = _featureCollection(<Map<String, dynamic>>[
        _polygon('land', _squareRing),
      ]);
      final bundle = _FakeAssetBundle(<String, String>{
        kBaseMapAssetPath: source,
      });
      final repo = AssetBaseMapRepository(bundle: bundle);

      final first = await repo.load();
      final second = await repo.load();

      expect(identical(first, second), isTrue);
      expect(bundle.loadStringCalls, 1);
    });
  });

  group('AssetBaseMapRepository — declared-bounds guard (ADR-0008 accuracy)', () {
    test('parsesNormally_whenDeclaredBoundsMatchTheShippedFrame', () {
      final source = _featureCollection(<Map<String, dynamic>>[
        _polygon('land', _squareRing),
      ]);
      expect(
        () => AssetBaseMapRepository.parseGeoJson(source),
        returnsNormally,
      );
    });

    test('throwsFormatException_whenADeclaredBoundDiffers', () {
      final source = _featureCollection(
        <Map<String, dynamic>>[_polygon('land', _squareRing)],
        bounds: <String, dynamic>{
          'north': 25.0, // != 24.0 shipped -> overlays would be misplaced
          'south': 8.0,
          'west': 101.8,
          'east': 110.3,
        },
      );
      expect(
        () => AssetBaseMapRepository.parseGeoJson(source),
        throwsFormatException,
      );
    });

    test('trustsTheAsset_whenNoBoundsAreDeclared', () {
      // Missing bounds block -> no assertion, parse proceeds (documented fallback).
      final source = jsonEncode(<String, dynamic>{
        'type': 'FeatureCollection',
        'features': <dynamic>[_polygon('land', _squareRing)],
      });
      expect(
        () => AssetBaseMapRepository.parseGeoJson(source),
        returnsNormally,
      );
    });
  });

  group('AssetBaseMapRepository.parseGeoJson — malformed input degrades', () {
    test('throwsFormatException_onInvalidJson', () {
      expect(
        () => AssetBaseMapRepository.parseGeoJson('{ this is not json'),
        throwsFormatException,
      );
    });

    test('throwsFormatException_whenRootIsNotAnObject', () {
      expect(
        () => AssetBaseMapRepository.parseGeoJson('[1, 2, 3]'),
        throwsFormatException,
      );
    });

    test('throwsFormatException_whenFeaturesIsNotAList', () {
      final source = jsonEncode(<String, dynamic>{
        'type': 'FeatureCollection',
        'features': <String, dynamic>{'not': 'a list'},
      });
      expect(
        () => AssetBaseMapRepository.parseGeoJson(source),
        throwsFormatException,
      );
    });

    test('yieldsEmptyGeometry_whenFeaturesListIsEmpty', () {
      final source = _featureCollection(<Map<String, dynamic>>[]);
      final geometry = AssetBaseMapRepository.parseGeoJson(source);
      expect(geometry.isEmpty, isTrue);
    });
  });

  group('AssetBaseMapRepository — real bundled asset (pubspec/manifest guard)', () {
    // Uses the REAL `rootBundle` (the flutter_test asset bundle over the actually
    // bundled assets), NOT a fake — so this fails if the GeoJSON is renamed,
    // dropped from pubspec, or malformed. Without it, such a regression would
    // silently reproduce the blank-sea map (`main._loadBaseMap` degrades to the
    // empty base), which AC-1/AC-2 forbid. Complements S1's error logging.
    TestWidgetsFlutterBinding.ensureInitialized();

    test('loadsTheActuallyBundledGeoJson_geometryIsNonEmpty', () async {
      final geometry = await AssetBaseMapRepository().load();

      expect(
        geometry.isEmpty,
        isFalse,
        reason: 'the bundled base map must load a non-empty geometry — an empty '
            'result means a pubspec/manifest regression (blank-sea map)',
      );
      expect(geometry.landRings, isNotEmpty);
      expect(geometry.provinceUnitCount, greaterThan(0));
    });
  });
}
