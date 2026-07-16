/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O, no
/// `latlong2`, no network. Deterministic and fully unit-testable.
///
/// THE DRAWN ROUTE THAT TOUCHES EVERY REAL WAYPOINT (route-real-road / AC-2).
/// Given the bundled [RoadPath] and the route's ordered waypoint coordinates
/// (start, any user stops, end — from `province_geography`), a [RoadRoute] draws
/// a black line that genuinely passes through EACH real waypoint by DETOURING off
/// the highway out to the stop and back (a visible spur). It:
///   1. snaps each waypoint to its nearest road vertex
///      ([RoadPath.nearestVertexIndex]) to find where its highway spur joins the
///      road,
///   2. builds ONE ordered polyline that starts at the real start `w_0`, and for
///      each leg `k → k+1` travels the contiguous road slice from `s_k` to
///      `s_{k+1}` (reversing a slice only if a later waypoint snaps to a lower
///      index, so the drawn line never backtracks against travel order at a
///      seam), then spurs out to the real `w_{k+1}`; for an INTERMEDIATE stop it
///      then returns to `road[s_{k+1}]` before the next slice. Net effect: a
///      short connector at the start, the highway in between, a spur out-and-back
///      to each intermediate stop, and a final connector out to the real end, and
///   3. precomputes cumulative km along that FULL polyline (including the detour
///      connectors, so the route length legitimately grows by the round-trip
///      detour distance) so the marker + red idle trace can be addressed by km
///      (NFR-1 — computed once per route).
///
/// The result IS the geometry the map strokes — it already curves along the real
/// road and reaches every real stop, so NO extra smoothing/spline is applied
/// (route-real-road drops the `route_curve` spline for this path; the road is the
/// geometry). Implements the [RouteGeometry] contract so the map cubit +
/// [IdleTraceMapper] consume it exactly as they consumed the chain projector.
library;

import 'package:equatable/equatable.dart';

import 'geo_polyline.dart';
import 'haversine.dart';
import 'province_geography.dart';
import 'road_path.dart';
import 'route_geometry.dart';

/// The drawn path for one route (start → stops → end): the bundled highway with
/// a spur out to every real waypoint. Immutable [Equatable] value object so
/// [MapViewState]/[RouteViewState] equality lets the painter skip redundant
/// redraws.
class RoadRoute extends Equatable implements RouteGeometry {
  const RoadRoute._({
    required this.points,
    required List<double> cumulativeKm,
    required this.waypointCoordinates,
  }) : _cumulativeKm = cumulativeKm;

  /// Builds the drawn path for [waypoints] (ordered: start, stops…, end) over the
  /// bundled [road]. Each waypoint is snapped to its nearest road vertex to find
  /// where its spur joins the highway; the drawn line then TOUCHES every real
  /// waypoint by detouring off the road out to it and back (see the library doc).
  /// [waypoints] with fewer than two entries yields an empty route (nothing
  /// drawn).
  factory RoadRoute.build({
    required RoadPath road,
    required List<GeoCoordinate> waypoints,
  }) {
    if (waypoints.length < 2) {
      return const RoadRoute._(
        points: <GeoCoordinate>[],
        cumulativeKm: <double>[],
        waypointCoordinates: <GeoCoordinate>[],
      );
    }
    final snappedIndices = <int>[
      for (final w in waypoints) road.nearestVertexIndex(w),
    ];
    final lastLeg = snappedIndices.length - 1;
    final path = <GeoCoordinate>[];
    // De-dup consecutive identical vertices at the seams (a near-on-road waypoint
    // then adds no zero-length step).
    void addPoint(GeoCoordinate point) {
      if (path.isNotEmpty && path.last == point) {
        return;
      }
      path.add(point);
    }

    // Start at the REAL start waypoint — the line must touch it exactly.
    addPoint(waypoints.first);
    for (var w = 0; w < lastLeg; w++) {
      final from = snappedIndices[w];
      final to = snappedIndices[w + 1];
      // Travel the contiguous road slice from this waypoint's snapped vertex to
      // the next waypoint's snapped vertex, in travel order.
      if (to >= from) {
        for (var i = from; i <= to; i++) {
          addPoint(road.points[i]);
        }
      } else {
        // A later waypoint snapped to a lower index — walk the slice backwards so
        // the drawn line still runs from this waypoint toward the next in travel
        // order (never a forward-then-backward zigzag at the seam).
        for (var i = from; i >= to; i--) {
          addPoint(road.points[i]);
        }
      }
      // Spur out to the REAL next waypoint so the line genuinely reaches it.
      addPoint(waypoints[w + 1]);
      // For an INTERMEDIATE stop, return to the highway (its snapped vertex)
      // before continuing the next slice — completing the out-and-back detour.
      if (w + 1 < lastLeg) {
        addPoint(road.points[to]);
      }
    }
    final cumulative = List<double>.filled(path.length, 0);
    for (var i = 1; i < path.length; i++) {
      final a = path[i - 1];
      final b = path[i];
      cumulative[i] =
          cumulative[i - 1] +
          greatCircleKm(a.latitude, a.longitude, b.latitude, b.longitude);
    }
    return RoadRoute._(
      points: List<GeoCoordinate>.unmodifiable(path),
      cumulativeKm: List<double>.unmodifiable(cumulative),
      // The markers sit at the TRUE province locations (the real input
      // waypoints), and the drawn line's spur reaches each of them.
      waypointCoordinates: List<GeoCoordinate>.unmodifiable(waypoints),
    );
  }

  /// The ordered drawn vertices (start → end) — the route line, which spurs off
  /// the highway to touch every real waypoint.
  final List<GeoCoordinate> points;

  /// The REAL waypoint coordinates (start, stops…, end) at their true province
  /// locations — the big markers sit here, and the drawn line's spur reaches each
  /// of them (Google-style, but honouring the true stop position rather than
  /// snapping the marker onto the highway).
  final List<GeoCoordinate> waypointCoordinates;

  final List<double> _cumulativeKm;

  /// Whether there is nothing drawable.
  bool get isEmpty => points.length < 2;

  @override
  double get routeLengthKm => _cumulativeKm.isEmpty ? 0 : _cumulativeKm.last;

  @override
  List<GeoCoordinate> get baseRoutePolyline => points;

  /// The drawn sub-path as a [GeoPolyline] (what the map strokes).
  GeoPolyline get polyline => GeoPolyline(points);

  @override
  GeoCoordinate coordinateAt(double routeDistanceKm) {
    final clamped = _clamp(routeDistanceKm);
    if (points.isEmpty) {
      throw StateError('coordinateAt on an empty road route');
    }
    if (clamped <= 0 || points.length == 1) {
      return points.first;
    }
    if (clamped >= routeLengthKm) {
      return points.last;
    }
    final i = _segmentIndexFor(clamped);
    final segStart = _cumulativeKm[i];
    final segEnd = _cumulativeKm[i + 1];
    final segKm = segEnd - segStart;
    final t = segKm <= 0 ? 0.0 : (clamped - segStart) / segKm;
    return points[i].lerpTo(points[i + 1], t);
  }

  /// The lat/long at [fraction] (0..1) of the way along the road sub-path.
  GeoCoordinate coordinateAtFraction(double fraction) =>
      coordinateAt(fraction * routeLengthKm);

  @override
  GeoPolyline stretchBetween(double fromKm, double toKm) {
    if (points.length < 2) {
      return const GeoPolyline(<GeoCoordinate>[]);
    }
    final lo = _clamp(fromKm < toKm ? fromKm : toKm);
    final hi = _clamp(fromKm < toKm ? toKm : fromKm);
    if (hi - lo <= _epsilon) {
      return const GeoPolyline(<GeoCoordinate>[]);
    }
    final out = <GeoCoordinate>[coordinateAt(lo)];
    for (var i = 0; i < _cumulativeKm.length; i++) {
      final km = _cumulativeKm[i];
      if (km > lo + _epsilon && km < hi - _epsilon) {
        out.add(points[i]);
      }
    }
    out.add(coordinateAt(hi));
    return GeoPolyline(List<GeoCoordinate>.unmodifiable(out));
  }

  double _clamp(double km) {
    if (!km.isFinite || km < 0) {
      return 0;
    }
    if (km > routeLengthKm) {
      return routeLengthKm;
    }
    return km;
  }

  int _segmentIndexFor(double km) {
    for (var i = _cumulativeKm.length - 1; i >= 1; i--) {
      if (km >= _cumulativeKm[i]) {
        return i;
      }
    }
    return 0;
  }

  static const double _epsilon = 1e-6;

  @override
  List<Object?> get props => <Object?>[points, waypointCoordinates];
}
