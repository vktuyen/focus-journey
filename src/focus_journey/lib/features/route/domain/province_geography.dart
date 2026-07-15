/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O, NO
/// `latlong2` (latlong2 is converted to ONLY at the presentation boundary).
///
/// The SINGLE real-geography model for the Vietnam province chain (map-experience
/// Decision B). [Province] deliberately carries no position; this file maps each
/// province `id` → a static [GeoCoordinate] (real, approximately-correct Vietnam
/// lat/long) so the map road can trace the actual country outline (AC-4).
///
/// PRIVACY (NFR-2 — CRITICAL/gating): every coordinate here is **static
/// app-supplied reference data**, hand-authored from public city locations. It is
/// NEVER a device-location read — this file imports no geolocation/GPS API and
/// reads nothing from the OS. It is reference data about *places*, never about
/// *the user*.
///
/// SINGLE SOURCE (AC-5): this is the one geography model the overlay consumes and
/// the one `route-planner-v2` (#9 waypoint auto-insert) will later consume — the
/// feature introduces no second geography definition.
library;

import 'package:equatable/equatable.dart';

import 'province.dart';
import 'province_chain.dart';

/// A static geographic point (WGS-84 degrees). Pure value object — Equatable, no
/// Flutter, no `latlong2`. Converted to a `latlong2.LatLng` only at the
/// presentation boundary so the domain stays framework-free.
class GeoCoordinate extends Equatable {
  /// Creates a coordinate from [latitude] (degrees, south-negative) and
  /// [longitude] (degrees, west-negative).
  const GeoCoordinate({required this.latitude, required this.longitude});

  /// Degrees latitude (Vietnam spans roughly 8.5 .. 23.5 N).
  final double latitude;

  /// Degrees longitude (Vietnam spans roughly 102 .. 110 E).
  final double longitude;

  /// Linearly interpolates between this coordinate and [other] by [t] in [0, 1]
  /// (0 → this, 1 → [other]). Used by the polyline projector to place a point a
  /// fraction of the way along a chain leg (map-experience Decision A). Linear in
  /// lat/long space — adequate at the chain's leg scale and deterministic.
  GeoCoordinate lerpTo(GeoCoordinate other, double t) {
    final clamped = t < 0 ? 0.0 : (t > 1 ? 1.0 : t);
    return GeoCoordinate(
      latitude: latitude + (other.latitude - latitude) * clamped,
      longitude: longitude + (other.longitude - longitude) * clamped,
    );
  }

  @override
  List<Object?> get props => <Object?>[latitude, longitude];

  @override
  String toString() =>
      'GeoCoordinate(${latitude.toStringAsFixed(4)}, '
      '${longitude.toStringAsFixed(4)})';
}

/// The static geography for a [ProvinceChain]: a province `id` → [GeoCoordinate]
/// lookup, validated against the chain at construction so a missing coordinate
/// fails LOUDLY (mirrors [ProvinceChain]'s constructor-time guards) rather than
/// silently dropping a checkpoint at paint time.
///
/// Invariant (enforced by the constructor — chain-data integrity, TC-209):
/// every province `id` in [chain].nodes has a coordinate in [coordinates], and
/// each coordinate sits within Vietnam's bounding box.
class ProvinceGeography {
  /// Builds and validates the geography over [chain]. Throws [ArgumentError] if
  /// any chain province lacks a coordinate or sits outside the Vietnam bbox.
  ProvinceGeography({
    required this.chain,
    required Map<String, GeoCoordinate> coordinates,
  }) : _coordinates = Map<String, GeoCoordinate>.unmodifiable(coordinates) {
    for (final node in chain.nodes) {
      final coordinate = _coordinates[node.id];
      if (coordinate == null) {
        throw ArgumentError.value(
          node.id,
          'coordinates',
          'every chain province must have a coordinate; "${node.id}" is missing',
        );
      }
      if (coordinate.latitude < _minLat ||
          coordinate.latitude > _maxLat ||
          coordinate.longitude < _minLong ||
          coordinate.longitude > _maxLong) {
        throw ArgumentError.value(
          coordinate,
          'coordinates',
          'coordinate for "${node.id}" is outside Vietnam\'s bounding box',
        );
      }
    }
  }

  /// Vietnam bounding box (degrees) — a loose guard so a typo (e.g. a swapped
  /// lat/long) fails at construction. Not a precise border.
  static const double _minLat = 8.0;
  static const double _maxLat = 24.0;
  static const double _minLong = 101.0;
  static const double _maxLong = 110.5;

  /// The chain whose checkpoints this geography positions.
  final ProvinceChain chain;

  final Map<String, GeoCoordinate> _coordinates;

  /// The coordinate for [province]. Throws [ArgumentError] if it is not part of
  /// the validated chain (it cannot be, given the constructor guard — this is a
  /// defensive backstop for a province from a different chain).
  GeoCoordinate coordinateOf(Province province) {
    final coordinate = _coordinates[province.id];
    if (coordinate == null) {
      throw ArgumentError.value(
        province.id,
        'province',
        'no coordinate for this province',
      );
    }
    return coordinate;
  }

  /// The chain's checkpoints in canonical south→north order, each paired with
  /// its coordinate. Convenience for building the base polyline.
  List<GeoCoordinate> get canonicalCoordinates =>
      List<GeoCoordinate>.unmodifiable(<GeoCoordinate>[
        for (final node in chain.nodes) coordinateOf(node),
      ]);
}

/// The production geography for [vietnamProvinceChain] (map-experience Decision
/// B). Real, approximately-correct city lat/long for all 13 checkpoints — enough
/// to trace Vietnam's S-shape (south tip Mũi Cà Mau ~8.6 N → north tip Hà Giang
/// ~22.8 N). These are public place coordinates (static reference data), NOT a
/// device-location read (NFR-2). Validated against the chain at construction.
final ProvinceGeography vietnamProvinceGeography = ProvinceGeography(
  chain: vietnamProvinceChain,
  coordinates: const <String, GeoCoordinate>{
    // Display alignment to the generalized bundled coastline: the true cape
    // (~8.62, 104.72) sits ~800 m OFFSHORE of the simplified bundled outline, so
    // the start pin / first segment / km=0 marker would render in the Gulf. This
    // is a sub-1-km nudge (~0.95 km SSE) onto the drawn landmass so
    // containsLandmass is true (AC-5/6/7); it is NOT a re-survey. The
    // authoritative province-centre coordinate is re-derived in province-chain-2026.
    'mui_ca_mau': GeoCoordinate(latitude: 8.613, longitude: 104.725),
    'can_tho': GeoCoordinate(latitude: 10.04, longitude: 105.78),
    'ho_chi_minh': GeoCoordinate(latitude: 10.82, longitude: 106.63),
    'da_lat': GeoCoordinate(latitude: 11.94, longitude: 108.44),
    'nha_trang': GeoCoordinate(latitude: 12.24, longitude: 109.19),
    'quy_nhon': GeoCoordinate(latitude: 13.78, longitude: 109.22),
    'da_nang': GeoCoordinate(latitude: 16.05, longitude: 108.20),
    'hue': GeoCoordinate(latitude: 16.46, longitude: 107.59),
    'vinh': GeoCoordinate(latitude: 18.68, longitude: 105.69),
    'ninh_binh': GeoCoordinate(latitude: 20.25, longitude: 105.97),
    'ha_noi': GeoCoordinate(latitude: 21.03, longitude: 105.85),
    'sa_pa': GeoCoordinate(latitude: 22.34, longitude: 103.84),
    'ha_giang': GeoCoordinate(latitude: 22.82, longitude: 104.98),
  },
);
