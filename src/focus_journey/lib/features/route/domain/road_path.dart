/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O, no
/// `latlong2`, no network. Deterministic and fully unit-testable.
///
/// THE REAL BUNDLED NATIONAL ROAD (route-real-road / AC-1). A [RoadPath] is the
/// framework-free model of Vietnam's national highway: one ordered south→north
/// list of [GeoCoordinate] vertices (QL1A stitched with the QL4A connector toward
/// the northern terminus), with the cumulative great-circle km along the path
/// precomputed ONCE (reusing [greatCircleKm]) so the drawn route can be measured
/// and segmented by km without re-walking the vertices per frame (NFR-1).
///
/// The data layer ([AssetRoadPathRepository]) parses the bundled GeoJSON and
/// stitches the ordered `LineString` features into one path via [RoadPath.stitch].
/// This type performs NO I/O and NO network — it is pure reference geometry about
/// *the road*, never a device-location read (NFR-2 / NFR-4).
library;

import 'haversine.dart';
import 'province_geography.dart';

/// The bundled national road as one ordered, immutable polyline with precomputed
/// cumulative great-circle distance.
class RoadPath {
  /// Wraps an already-ordered [points] list (south→north) and precomputes the
  /// cumulative great-circle km at each vertex. Requires at least two vertices.
  RoadPath(List<GeoCoordinate> points)
    : points = List<GeoCoordinate>.unmodifiable(points) {
    if (this.points.length < 2) {
      throw ArgumentError.value(
        this.points.length,
        'points',
        'a road path needs at least two vertices',
      );
    }
    final cumulative = List<double>.filled(this.points.length, 0);
    for (var i = 1; i < this.points.length; i++) {
      final a = this.points[i - 1];
      final b = this.points[i];
      cumulative[i] =
          cumulative[i - 1] +
          greatCircleKm(a.latitude, a.longitude, b.latitude, b.longitude);
    }
    _cumulativeKm = List<double>.unmodifiable(cumulative);
  }

  /// Stitches the [segments] (each an ordered vertex list, given in travel order
  /// south→north) into ONE ordered [RoadPath]. Consecutive segments are appended
  /// end-to-start; a duplicate join vertex (the next segment's first point equal
  /// to the running last point) is dropped so the seam adds no zero-length step.
  /// A small real gap between segments (the highways connect ~a few km apart) is
  /// kept as a normal edge — it is on the real road network.
  factory RoadPath.stitch(List<List<GeoCoordinate>> segments) {
    final merged = <GeoCoordinate>[];
    for (final segment in segments) {
      for (final point in segment) {
        if (merged.isNotEmpty && merged.last == point) {
          continue; // drop an exact duplicate join vertex.
        }
        merged.add(point);
      }
    }
    return RoadPath(merged);
  }

  /// The ordered road vertices (south→north), immutable.
  final List<GeoCoordinate> points;

  late final List<double> _cumulativeKm;

  /// The cumulative great-circle km from the south end to vertex [index].
  double cumulativeKmAt(int index) => _cumulativeKm[index];

  /// The total road length (km) — the cumulative distance at the last vertex.
  double get lengthKm => _cumulativeKm.last;

  /// The index of the road vertex nearest to [target] by great-circle distance.
  /// A nearest-VERTEX snap is exact enough given the road's ~0.6 km vertex spacing
  /// (route-real-road: "nearest vertex is fine"). Ties resolve to the lower index.
  int nearestVertexIndex(GeoCoordinate target) {
    var bestIndex = 0;
    var bestKm = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final km = greatCircleKm(
        target.latitude,
        target.longitude,
        p.latitude,
        p.longitude,
      );
      if (km < bestKm) {
        bestKm = km;
        bestIndex = i;
      }
    }
    return bestIndex;
  }
}
