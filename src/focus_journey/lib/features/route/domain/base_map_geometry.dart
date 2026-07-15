/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O, no
/// `latlong2`.
///
/// The framework-free geometry of the bundled Vietnam base map (vietnam-map-
/// fidelity / ADR-0008(a)): the georeferenced (lat/long) polygons the map
/// surface draws UNDER the shipped overlays. Two roles:
///   - [landRings]: the single national landmass (one calm land fill + the
///     point-in-landmass reference). Multi-ring (mainland + islands).
///   - [provinceRings]: the 2025 provincial-unit outlines (thin borders —
///     AC-3's "34 merged units", no pre-2025 internal borders because the
///     source IS the 2025 34-unit map).
///
/// PRIVACY (NFR-2 — gating): every vertex here is STATIC app-shipped reference
/// data parsed from the bundled asset — never a device-location read. This file
/// imports no geolocation/GPS/platform API. Point-in-landmass is a pure
/// ray-cast over the loaded rings.
library;

import 'dart:math' as math;

import 'equirectangular_projection.dart';
import 'province_geography.dart';

/// The parsed base-map geometry (immutable). Built ONCE by the data layer and
/// cached — never re-parsed per frame (NFR-1 / TC-820).
class BaseMapGeometry {
  /// Creates the geometry from the [landRings] (fill + landmass test) and the
  /// [provinceRings] (unit-outline borders). Lists are stored as-is; the data
  /// layer owns their immutability.
  BaseMapGeometry({required this.landRings, required this.provinceRings});

  /// The empty base — draws nothing. Used as the back-compat default where no
  /// base geometry has been injected (e.g. legacy widget tests). Not `const`
  /// because the type memoizes its decimated [minimap] variant lazily.
  BaseMapGeometry.empty()
    : landRings = const <List<GeoCoordinate>>[],
      provinceRings = const <List<GeoCoordinate>>[];

  /// The national landmass rings (mainland + islands), single calm land tone.
  final List<List<GeoCoordinate>> landRings;

  /// The 2025 provincial-unit outline rings (thin borders — AC-3).
  final List<List<GeoCoordinate>> provinceRings;

  /// Whether there is anything to draw.
  bool get isEmpty => landRings.isEmpty && provinceRings.isEmpty;

  /// The count of drawn provincial units (border rings). Reported for the AC-3
  /// "≈34 merged units" check (TC-805); a few units are multipart (an island +
  /// mainland ring), so this reads slightly above 34.
  int get provinceUnitCount => provinceRings.length;

  /// Whether [p] falls on the drawn landmass (inside any [landRings] ring) — a
  /// pure even-odd ray-cast. Used to keep overlays honest (no pin/segment in
  /// the sea — AC-5/6/7 / TC-808/810/812).
  bool containsLandmass(GeoCoordinate p) {
    for (final ring in landRings) {
      if (_ringContains(ring, p.longitude, p.latitude)) {
        return true;
      }
    }
    return false;
  }

  static bool _ringContains(List<GeoCoordinate> ring, double lon, double lat) {
    var inside = false;
    final n = ring.length;
    var j = n - 1;
    for (var i = 0; i < n; i++) {
      final xi = ring[i].longitude;
      final yi = ring[i].latitude;
      final xj = ring[j].longitude;
      final yj = ring[j].latitude;
      final denom = (yj - yi);
      if (((yi > lat) != (yj > lat)) &&
          (lon < (xj - xi) * (lat - yi) / (denom == 0 ? 1e-15 : denom) + xi)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  /// A cheaper, decimated copy for the ~150px minimap (NFR-1 / TC-804): every
  /// ring is Douglas-Peucker–simplified at [toleranceDeg] degrees, trading
  /// vertex count for identity (the S-shape silhouette survives). Computed once
  /// and cached — see [minimap].
  BaseMapGeometry decimated(double toleranceDeg) {
    return BaseMapGeometry(
      landRings: <List<GeoCoordinate>>[
        for (final r in landRings) _simplify(r, toleranceDeg),
      ],
      provinceRings: <List<GeoCoordinate>>[
        for (final r in provinceRings) _simplify(r, toleranceDeg),
      ],
    );
  }

  BaseMapGeometry? _minimapCache;

  /// The decimated variant for the compact minimap, computed ONCE and cached so
  /// the cheap-geometry build never re-runs per frame (NFR-1 / TC-820).
  BaseMapGeometry get minimap =>
      _minimapCache ??= decimated(_kMinimapToleranceDeg);

  /// ~0.02° ≈ 2.2 km — coarse enough to lighten the minimap, fine enough that
  /// Vietnam stays recognisable (not a blob) at ~150px.
  static const double _kMinimapToleranceDeg = 0.02;

  static List<GeoCoordinate> _simplify(List<GeoCoordinate> ring, double eps) {
    if (ring.length < 4) {
      return ring;
    }
    final kept = _dp(ring, 0, ring.length - 1, eps);
    // _dp returns the retained indices (endpoints included), sorted.
    return <GeoCoordinate>[for (final i in kept) ring[i]];
  }

  static List<int> _dp(
    List<GeoCoordinate> pts,
    int first,
    int last,
    double eps,
  ) {
    var dmax = 0.0;
    var index = first;
    for (var i = first + 1; i < last; i++) {
      final d = _perpDist(pts[i], pts[first], pts[last]);
      if (d > dmax) {
        dmax = d;
        index = i;
      }
    }
    if (dmax > eps) {
      final left = _dp(pts, first, index, eps);
      final right = _dp(pts, index, last, eps);
      return <int>[...left.sublist(0, left.length - 1), ...right];
    }
    return <int>[first, last];
  }

  static double _perpDist(GeoCoordinate p, GeoCoordinate a, GeoCoordinate b) {
    final ax = a.longitude, ay = a.latitude;
    final bx = b.longitude, by = b.latitude;
    final px = p.longitude, py = p.latitude;
    final dx = bx - ax, dy = by - ay;
    if (dx == 0 && dy == 0) {
      return math.sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay));
    }
    final t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
    final cx = ax + t * dx, cy = ay + t * dy;
    return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
  }
}

/// The georeferencing bounds the base geometry was built under — re-exported so
/// callers importing the geometry get the matching frame contract.
typedef BaseMapBounds = EquirectangularBounds;
