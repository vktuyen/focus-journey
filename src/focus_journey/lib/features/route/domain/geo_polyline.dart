/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O, no
/// `latlong2`. A framework-free ordered list of [GeoCoordinate] vertices.
library;

import 'package:equatable/equatable.dart';

import 'province_geography.dart';

/// An ordered, immutable list of [GeoCoordinate] vertices — a road stretch or a
/// red idle stretch (map-experience). Pure value object (Equatable) so the
/// painter's `shouldRepaint` can cheaply compare projected geometry.
class GeoPolyline extends Equatable {
  /// Wraps [points] as an immutable polyline (the caller owns immutability of
  /// the list it passes; this stores the reference as-is for cheap construction).
  const GeoPolyline(this.points);

  /// The ordered vertices (lat/long), start → end. May be empty (no stretch).
  final List<GeoCoordinate> points;

  /// Whether this stretch has no drawable geometry (fewer than two vertices).
  bool get isEmpty => points.length < 2;

  @override
  List<Object?> get props => <Object?>[points];
}
