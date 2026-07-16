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
import 'vietnam_units_2026.dart';

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

/// The production geography for [vietnamProvinceChain] (province-chain-2026 /
/// candidate ADR-0009). The administrative-centre lat/long for all **34 current
/// units (2026)**, built from the single ordered source-of-record
/// [kVietnamUnits2026] so the chain and the geography can never disagree about
/// which units exist or where they sit (south tip Cà Mau ~9.18 N → north tip
/// Cao Bằng ~22.67 N). These are public place coordinates (static reference
/// data), NOT a device-location read (NFR-2). The old `mui_ca_mau` display-nudge
/// is retired: Cà Mau's authoritative centre now lands on the drawn landmass
/// directly. A handful of non-relocated coastal centres carry a small
/// coast-alignment offset (documented in [kVietnamUnits2026]); relocated centres
/// are exact. Validated against the chain at construction.
final ProvinceGeography vietnamProvinceGeography = ProvinceGeography(
  chain: vietnamProvinceChain,
  coordinates: <String, GeoCoordinate>{
    for (final unit in kVietnamUnits2026)
      unit.id: GeoCoordinate(latitude: unit.lat, longitude: unit.lon),
  },
);
