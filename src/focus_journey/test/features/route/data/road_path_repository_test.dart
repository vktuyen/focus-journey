// Unit tests for the road-path DATA layer (route-real-road / AC-1).
//
// Two halves:
//   1. FAKE-bundle unit tests — deterministic, in-memory GeoJSON; verify the
//      parser stitches ordered LineString features into ONE path and caches
//      (parse-once — NFR-1), and reads via the bundled-asset seam only (no
//      network — AC-1 / NFR-2).
//   2. REAL-asset test — parses the shipped bundled GeoJSON from disk and asserts
//      it stitches into one ordered south→north path (QL1A + QL4A) of ~2566 km.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/data/road_path_repository.dart';
import 'package:focus_journey/features/route/domain/road_path.dart';

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

String _lineString(List<List<double>> coords) => jsonEncode(<String, dynamic>{
  'type': 'Feature',
  'properties': <String, dynamic>{'ref': 'QL'},
  'geometry': <String, dynamic>{
    'type': 'LineString',
    'coordinates': coords,
  },
});

String _featureCollection(List<String> features) =>
    '{"type":"FeatureCollection","features":[${features.join(',')}]}';

/// Reads the shipped GeoJSON from disk, walking up from the test cwd.
String _readAsset(String relativePath) {
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

void main() {
  group('AssetRoadPathRepository (fake bundle)', () {
    test('stitches ordered LineString features into ONE path', () async {
      final json = _featureCollection(<String>[
        _lineString(<List<double>>[
          [105.0, 9.0],
          [105.0, 10.0],
        ]),
        _lineString(<List<double>>[
          [105.0, 10.0], // shares the prior end → deduped at the seam.
          [105.0, 11.0],
        ]),
      ]);
      final bundle = _FakeAssetBundle(<String, String>{
        kRoadPathAssetPath: json,
      });
      final repo = AssetRoadPathRepository(bundle: bundle);
      final path = await repo.load();
      expect(path.points.length, 3);
      expect(path.points.first.latitude, 9.0);
      expect(path.points.last.latitude, 11.0);
    });

    test('parses the asset ONCE and caches (NFR-1)', () async {
      final bundle = _FakeAssetBundle(<String, String>{
        kRoadPathAssetPath: _featureCollection(<String>[
          _lineString(<List<double>>[
            [105.0, 9.0],
            [105.0, 10.0],
          ]),
        ]),
      });
      final repo = AssetRoadPathRepository(bundle: bundle);
      await repo.load();
      await repo.load();
      expect(bundle.loadStringCalls, 1);
    });

    test('throws on a FeatureCollection with no LineString', () {
      expect(
        () => AssetRoadPathRepository.parseGeoJson(
          '{"type":"FeatureCollection","features":[]}',
        ),
        throwsFormatException,
      );
    });
  });

  group('AssetRoadPathRepository (real bundled asset)', () {
    late RoadPath path;

    setUpAll(() {
      path = AssetRoadPathRepository.parseGeoJson(
        _readAsset(kRoadPathAssetPath),
      );
    });

    test('stitches QL1A + QL4A into one ordered south→north path', () {
      // ~346 (QL1A) + ~54 (QL4A) vertices, minus any deduped seam.
      expect(path.points.length, greaterThan(390));
      expect(path.points.length, lessThan(410));
      // South end near Cà Mau (~8.76 N); north end near Cao Bằng (~22.83 N).
      expect(path.points.first.latitude, lessThan(9.0));
      expect(path.points.last.latitude, greaterThan(22.0));
    });

    test('the full road length is ~2566 km', () {
      expect(path.lengthKm, greaterThan(2400));
      expect(path.lengthKm, lessThan(2700));
    });
  });
}
