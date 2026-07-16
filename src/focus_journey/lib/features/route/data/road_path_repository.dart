/// Data layer. Loads + parses the bundled Vietnam national-road GeoJSON into the
/// framework-free [RoadPath] domain type (route-real-road / AC-1).
///
/// PRIVACY (NFR-2 / NFR-4 — gating): the ONLY input is a BUNDLED STATIC ASSET read
/// through the app [AssetBundle] (`rootBundle` by default). It performs NO network
/// request and reads NO location/GPS/platform channel — the same offline seam the
/// base map + CC0 art already use. The road geometry is license-clean (OpenStreetMap,
/// ODbL) sourced at dev/build time; the app makes zero runtime egress (ADR-0008
/// posture preserved).
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../domain/province_geography.dart';
import '../domain/road_path.dart';

/// The path of the bundled national-road GeoJSON (declared under `assets/map/` in
/// pubspec). Sourced from OpenStreetMap (route relations QL1 + QL4A) at dev time —
/// see `assets/CREDITS.md`. Attribution: "Road data © OpenStreetMap contributors,
/// ODbL".
const String kRoadPathAssetPath = 'assets/map/vietnam_national_route.geojson';

/// The required in-app attribution for the bundled road geometry (NFR-4). ODbL
/// share-alike → mandatory. Surfaced on the map attribution pill alongside the
/// base-map CC BY-SA credit.
const String kRoadPathAttribution =
    'Road data © OpenStreetMap contributors, ODbL';

/// Loads the bundled national road as a [RoadPath]. An interface so the map
/// pipeline depends on the abstraction (SOLID / DI) and tests can inject a fake.
abstract class RoadPathRepository {
  /// Loads (and caches) the parsed, stitched road path.
  Future<RoadPath> load();
}

/// Reads [kRoadPathAssetPath] from the injected [AssetBundle] (default:
/// `rootBundle`), parses the GeoJSON FeatureCollection's `LineString` features in
/// file order (QL1A south→north, then the QL4A connector), and stitches them into
/// one ordered [RoadPath]. Cached so the JSON is parsed ONCE per app run, never
/// per frame (NFR-1).
class AssetRoadPathRepository implements RoadPathRepository {
  /// Creates the repository over an optional [bundle] seam (tests inject a fake
  /// bundle; production uses `rootBundle`) and an optional [assetPath] override.
  AssetRoadPathRepository({AssetBundle? bundle, String? assetPath})
    : _bundle = bundle ?? rootBundle,
      _assetPath = assetPath ?? kRoadPathAssetPath;

  final AssetBundle _bundle;
  final String _assetPath;

  RoadPath? _cache;

  @override
  Future<RoadPath> load() async {
    final cached = _cache;
    if (cached != null) {
      return cached;
    }
    final raw = await _bundle.loadString(_assetPath);
    final path = parseGeoJson(raw);
    _cache = path;
    return path;
  }

  /// Parses a GeoJSON FeatureCollection string into a stitched [RoadPath]. Every
  /// `LineString` feature contributes its ordered `[lon, lat]` vertices (same
  /// WGS84 convention as the base-map asset); features are stitched in the order
  /// they appear (the asset is authored south→north: QL1A then the QL4A connector).
  static RoadPath parseGeoJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('road path: root is not a JSON object');
    }
    final features = decoded['features'];
    if (features is! List) {
      throw const FormatException('road path: "features" is not a list');
    }
    final segments = <List<GeoCoordinate>>[];
    for (final feature in features) {
      if (feature is! Map<String, dynamic>) {
        continue;
      }
      final geometry = feature['geometry'] as Map<String, dynamic>?;
      if (geometry == null || geometry['type'] != 'LineString') {
        continue;
      }
      final coords = geometry['coordinates'] as List?;
      if (coords == null || coords.length < 2) {
        continue;
      }
      segments.add(_line(coords));
    }
    if (segments.isEmpty) {
      throw const FormatException('road path: no LineString features found');
    }
    return RoadPath.stitch(segments);
  }

  static List<GeoCoordinate> _line(List raw) {
    return <GeoCoordinate>[
      for (final pt in raw)
        if (pt is List && pt.length >= 2)
          GeoCoordinate(
            longitude: (pt[0] as num).toDouble(),
            latitude: (pt[1] as num).toDouble(),
          ),
    ];
  }
}
