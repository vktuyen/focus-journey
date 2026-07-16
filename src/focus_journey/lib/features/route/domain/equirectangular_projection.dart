/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O, no
/// `latlong2`.
///
/// The georeferencing CONTRACT for the bundled Vietnam base map (vietnam-map-
/// fidelity / ADR-0008). The bundled `vietnam_provinces_2025.geojson` was built
/// (offline, by `tool/svg_to_geojson.py`) from the sourced equirectangular SVG
/// under EXACTLY these bounds, so this file is the single home for the bounds
/// and the closed-form projection every overlay shares with the base.
///
/// PRIVACY (NFR-2 — gating): these bounds are STATIC app-shipped constants — the
/// same reference-data category as [ProvinceGeography]'s city coordinates. This
/// file imports no geolocation/GPS/platform API and reads nothing from the OS;
/// the projection is a pure function of its lat/long arguments. It is data about
/// *the map frame*, never about *the user*.
library;

import 'package:equatable/equatable.dart';

/// A point in the normalized (0..1) map frame: [x] runs west→east (0 at the
/// west bound, 1 at the east bound), [y] runs north→south (0 at the north
/// bound / top, 1 at the south bound / bottom).
class NormalizedPoint extends Equatable {
  /// Creates a normalized frame point.
  const NormalizedPoint(this.x, this.y);

  /// West→east fraction in [0, 1].
  final double x;

  /// North→south fraction in [0, 1] (0 = top / north).
  final double y;

  @override
  List<Object?> get props => <Object?>[x, y];

  @override
  String toString() => 'NormalizedPoint($x, $y)';
}

/// The equirectangular (plate-carrée) bounds the Vietnam base map is drawn
/// under (ADR-0008): North 24°, South 8° latitude · West 101.8°, East 110.3°
/// longitude. The bundled GeoJSON's declared bounds are asserted against these
/// at load (see `AssetBaseMapRepository`), so a future asset rebuilt under
/// different bounds fails loudly rather than silently misplacing overlays.
class EquirectangularBounds {
  const EquirectangularBounds._();

  /// North (top) latitude bound in degrees.
  static const double north = 24.0;

  /// South (bottom) latitude bound in degrees.
  static const double south = 8.0;

  /// West (left) longitude bound in degrees.
  static const double west = 101.8;

  /// East (right) longitude bound in degrees.
  static const double east = 110.3;

  /// Projects a geographic [lat]/[lon] (degrees) to the normalized (0..1) map
  /// frame:
  ///   x = (lon − west) / (east − west)
  ///   y = (north − lat) / (north − south)
  ///
  /// Out-of-bounds inputs are CLAMPED to [0, 1] (the defined contract — TC-811):
  /// no NaN, no negative overflow, no silent wrap. The shipped chain sits well
  /// inside the bounds, so clamping never fires for a real checkpoint; it only
  /// hardens the pure core against a stray input.
  static NormalizedPoint project(double lat, double lon) {
    final x = (lon - west) / (east - west);
    final y = (north - lat) / (north - south);
    return NormalizedPoint(_clamp01(x), _clamp01(y));
  }

  static double _clamp01(double v) => v < 0 ? 0.0 : (v > 1 ? 1.0 : v);
}
