/// Data layer. Loads + parses the bundled Vietnam base-map GeoJSON into the
/// framework-free [BaseMapGeometry] domain type (vietnam-map-fidelity /
/// ADR-0008(a)).
///
/// PRIVACY (NFR-2 — gating / AC-10): the ONLY input is a BUNDLED STATIC ASSET
/// read through the app [AssetBundle] (`rootBundle` by default). This performs
/// NO network request (the base is offline by construction — the app's tile
/// egress was removed by ADR-0008(c)) and reads NO location/GPS/platform
/// channel. `flutter/services` is used solely for `rootBundle`/`AssetBundle`
/// asset loading — the same seam the app already uses for its CC0 art.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../domain/base_map_geometry.dart';
import '../domain/equirectangular_projection.dart';
import '../domain/province_geography.dart';

/// The path of the bundled base-map GeoJSON (declared under `assets/map/` in
/// pubspec). Built offline from `vietnam_provinces_2025_base.svg` by
/// `tool/svg_to_geojson.py` (see `assets/CREDITS.md`).
const String kBaseMapAssetPath = 'assets/map/vietnam_provinces_2025.geojson';

/// Loads the bundled base-map geometry. An interface so the map surface depends
/// on the abstraction (SOLID / DI), and tests can inject a fake.
abstract class BaseMapRepository {
  /// Loads (and caches) the parsed base-map geometry.
  Future<BaseMapGeometry> load();
}

/// Reads [kBaseMapAssetPath] from the injected [AssetBundle] (default:
/// `rootBundle`), parses the GeoJSON FeatureCollection, and builds the
/// [BaseMapGeometry]. The result is cached so the JSON is parsed ONCE per app
/// run, never per frame (NFR-1 / TC-820).
class AssetBaseMapRepository implements BaseMapRepository {
  /// Creates the repository over an optional [bundle] seam (tests inject a fake
  /// bundle; production uses `rootBundle`) and an optional [assetPath] override.
  AssetBaseMapRepository({AssetBundle? bundle, String? assetPath})
    : _bundle = bundle ?? rootBundle,
      _assetPath = assetPath ?? kBaseMapAssetPath;

  final AssetBundle _bundle;
  final String _assetPath;

  BaseMapGeometry? _cache;

  @override
  Future<BaseMapGeometry> load() async {
    final cached = _cache;
    if (cached != null) {
      return cached;
    }
    final raw = await _bundle.loadString(_assetPath);
    final geometry = parseGeoJson(raw);
    _cache = geometry;
    return geometry;
  }

  /// Parses a GeoJSON FeatureCollection string into a [BaseMapGeometry]. Each
  /// `Feature`'s `properties.role` selects the ring list (`land` → fill /
  /// landmass test; `province` → unit-outline border). Rings are read as
  /// [GeoCoordinate] lists ([lon, lat] per the GeoJSON convention).
  ///
  /// Asserts the FeatureCollection's declared `bounds` match the shipped
  /// [EquirectangularBounds] so an asset rebuilt under different bounds fails
  /// loudly rather than silently misplacing every overlay (ADR-0008 accuracy
  /// risk).
  static BaseMapGeometry parseGeoJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('base map: root is not a JSON object');
    }
    _assertBounds(decoded['properties']);
    final features = decoded['features'];
    if (features is! List) {
      throw const FormatException('base map: "features" is not a list');
    }
    final land = <List<GeoCoordinate>>[];
    final province = <List<GeoCoordinate>>[];
    for (final feature in features) {
      if (feature is! Map<String, dynamic>) {
        continue;
      }
      final role =
          (feature['properties'] as Map<String, dynamic>?)?['role'] as String?;
      final geometry = feature['geometry'] as Map<String, dynamic>?;
      if (geometry == null || geometry['type'] != 'Polygon') {
        continue;
      }
      final coords = geometry['coordinates'] as List?;
      if (coords == null || coords.isEmpty) {
        continue;
      }
      final ring = _ring(coords.first as List);
      if (ring.length < 4) {
        continue;
      }
      if (role == 'province') {
        province.add(ring);
      } else {
        land.add(ring);
      }
    }
    return BaseMapGeometry(
      landRings: List<List<GeoCoordinate>>.unmodifiable(land),
      provinceRings: List<List<GeoCoordinate>>.unmodifiable(province),
    );
  }

  static List<GeoCoordinate> _ring(List raw) {
    return List<GeoCoordinate>.unmodifiable(<GeoCoordinate>[
      for (final pt in raw)
        if (pt is List && pt.length >= 2)
          GeoCoordinate(
            longitude: (pt[0] as num).toDouble(),
            latitude: (pt[1] as num).toDouble(),
          ),
    ]);
  }

  static void _assertBounds(Object? properties) {
    if (properties is! Map<String, dynamic>) {
      return; // no declared bounds → trust the shipped asset.
    }
    final bounds = properties['bounds'];
    if (bounds is! Map<String, dynamic>) {
      return;
    }
    void check(String key, double expected) {
      final v = (bounds[key] as num?)?.toDouble();
      if (v != null && (v - expected).abs() > 1e-6) {
        throw FormatException(
          'base map: declared bound "$key"=$v does not match the shipped '
          'EquirectangularBounds ($expected) — overlays would be misplaced',
        );
      }
    }

    check('north', EquirectangularBounds.north);
    check('south', EquirectangularBounds.south);
    check('west', EquirectangularBounds.west);
    check('east', EquirectangularBounds.east);
  }
}
