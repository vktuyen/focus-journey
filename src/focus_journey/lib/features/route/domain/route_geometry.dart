/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O, no
/// `latlong2`.
///
/// The framework-free CONTRACT the route drawing + idle-trace mapping depend on
/// (SOLID / DIP): a route's geometry keyed by arc-length km. Two implementations
/// satisfy it:
///   - [RoutePolylineProjector] — the CHAIN-centre polyline (province-chain-2026
///     legacy path, kept for back-compat + its shipped tests), and
///   - [RoadRoute] — the REAL-ROAD sub-path (route-real-road: the bundled national
///     highway between the snapped waypoints — the shipped model).
///
/// Depending on this abstraction (not the concrete projector) lets the map cubit +
/// [IdleTraceMapper] draw the SAME red/base geometry whether the route is projected
/// onto province centres (legacy) or onto the real road (shipped).
library;

import 'geo_polyline.dart';
import 'province_geography.dart';

/// A route's drawable geometry, addressed by arc-length km from the route origin.
abstract interface class RouteGeometry {
  /// The full route length in km (origin → destination).
  double get routeLengthKm;

  /// The ordered vertices the painter strokes as the base route line
  /// (origin → destination).
  List<GeoCoordinate> get baseRoutePolyline;

  /// The lat/long at [routeDistanceKm] along the route, clamped to
  /// `[0, routeLengthKm]` (origin at/below 0, destination at/above the length).
  GeoCoordinate coordinateAt(double routeDistanceKm);

  /// The contiguous polyline sub-path between arc-lengths [fromKm] and [toKm],
  /// following the geometry's own vertices across any interior vertex it crosses.
  /// A zero-length or out-of-route span yields an empty polyline.
  GeoPolyline stretchBetween(double fromKm, double toKm);
}
