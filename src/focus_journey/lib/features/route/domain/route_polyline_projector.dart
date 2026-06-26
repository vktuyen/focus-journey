/// Domain layer — the PURE projection heart of map-experience. Framework-free
/// Dart: no Flutter, no flame, no `latlong2`, no `Timer`, no `DateTime.now()`, no
/// I/O, no network. Deterministic and fully unit-testable (TC-201..TC-210).
///
/// ## CANONICAL-KM-AXIS DECISION (map-experience Decision A — resolves the spec's
/// open question / TC-210)
/// The curated [ProvinceChain.segmentsKm] (the engine's locked 2000 km total)
/// REMAINS the canonical distance axis. This projector does NOT re-derive
/// distances from geodesic lat/long lengths — that would break AC-5 and the
/// engine's `totalChainKm`. Instead, to project a `routeDistanceKm` (or a
/// segment's from/to km) onto map geometry it:
///   1. locates which chain leg the cumulative-from-origin distance falls in,
///   2. computes `fraction = kmIntoLeg / legKm`,
///   3. **linearly interpolates the lat/long between that leg's two checkpoint
///      coordinates** by that fraction.
///
/// So km-fraction maps LINEARLY to position along each leg's straight line
/// between the two real cities. This satisfies AC-4 (the polyline traces the real
/// country, because each checkpoint is at its real lat/long) AND AC-5 (the marker
/// + red trace reuse the exact `routeDistanceKm` math) simultaneously. A
/// consequence by design: the on-map visual length of a leg (the geodesic gap
/// between its cities) intentionally DIFFERS from that leg's km proportion — a leg
/// that is short in km but far apart on the map still consumes only its km share
/// of the distance axis. This is deliberate (the chain km are stylised flavour
/// distances, not GIS survey lengths) and is the contract the red-trace and the
/// marker both key off, so they stay mutually consistent.
///
/// SEPARATION / PRIVACY INVARIANT (AC-12 / NFR-2 / TC-227/TC-230): this projector
/// reads ONLY a given distance + the static [ProvinceGeography]/[ProvinceChain]
/// reference data. It imports no `ActivityPlugin`, no platform channel, no
/// OS/idle/lock/sleep API, no geolocation/GPS; it makes NO active-vs-idle decision
/// and accrues NO distance — it only *maps* a given distance onto geometry.
library;

import 'geo_polyline.dart';
import 'journey_direction.dart';
import 'province.dart';
import 'province_chain.dart';
import 'province_geography.dart';
import 'route_selection.dart';

/// Projects route distances onto the real-geography polyline for a single route
/// (a [start] + [direction] over a [ProvinceChain] with a [ProvinceGeography]).
///
/// All arc-length is measured in CHAIN KM (the canonical axis — see the library
/// doc), re-based to the route origin so `routeDistanceKm = 0` is the [start]
/// pin. The projector exposes:
/// - [baseRoutePolyline] — the ordered checkpoint coordinates for the current
///   route (origin → destination), the base road the painter draws (AC-4/AC-10);
/// - [coordinateAt] — the lat/long at a given `routeDistanceKm` (the marker, via
///   the SAME km math `route-progress` uses — AC-5/TC-211);
/// - [stretchBetween] — the contiguous polyline sub-path between two
///   route-distance-km arc-lengths, following the road's vertices across any
///   checkpoint boundary it crosses (the red-trace stretch — AC-6/TC-201..208).
class RoutePolylineProjector {
  /// Builds a projector for [selection] over [geography]. Precomputes the
  /// route's ordered checkpoint coordinates + their cumulative-from-origin km
  /// (the canonical axis) once, so projection is allocation-light per call.
  RoutePolylineProjector({
    required RouteSelection selection,
    required ProvinceGeography geography,
  }) : _geography = geography,
       _chain = geography.chain {
    final start = selection.start;
    final direction = selection.direction;
    // Ordered route nodes: origin first, then each checkpoint ahead in travel
    // order (the destination tip last). Matches the resolver's `passed`/`ahead`
    // ordering, so the polyline and the position math agree (AC-5).
    _orderedNodes = <Province>[
      start,
      ..._chain.checkpointsAhead(start, direction),
    ];
    // Each node's cumulative km from the origin along the route (the canonical
    // distance axis, re-based to the route start). Strictly increasing.
    _cumulativeKm = <double>[
      for (final node in _orderedNodes)
        _chain.distanceFromStartTo(start, node, direction),
    ];
    _coordinates = <GeoCoordinate>[
      for (final node in _orderedNodes) _geography.coordinateOf(node),
    ];
  }

  final ProvinceGeography _geography;
  final ProvinceChain _chain;

  late final List<Province> _orderedNodes;

  /// `_cumulativeKm[i]` = canonical km from the route origin to `_orderedNodes[i]`
  /// (index 0 == 0.0). Strictly increasing (chain segments are strictly positive).
  late final List<double> _cumulativeKm;

  /// `_coordinates[i]` = the real lat/long of `_orderedNodes[i]`.
  late final List<GeoCoordinate> _coordinates;

  /// The full route distance (km) — origin to destination tip.
  double get routeLengthKm => _cumulativeKm.last;

  /// The base road for the current route: every checkpoint coordinate in travel
  /// order (origin → destination). The polyline the painter strokes (AC-4).
  /// Index 0 is the start pin; the last is the destination pin.
  List<GeoCoordinate> get baseRoutePolyline =>
      List<GeoCoordinate>.unmodifiable(_coordinates);

  /// The ordered route checkpoints (origin → destination) — pin markers (AC-10).
  List<Province> get orderedNodes => List<Province>.unmodifiable(_orderedNodes);

  /// The lat/long at [routeDistanceKm] along the route (the marker position,
  /// AC-5/TC-211). Uses the canonical km axis: locate the leg, interpolate the
  /// leg's two checkpoint coordinates by the km-fraction (Decision A).
  ///
  /// Clamps to `[0, routeLengthKm]` so `routeDistanceKm <= 0` resolves to the
  /// start pin (TC-205) and `routeDistanceKm >= routeLengthKm` resolves to the
  /// destination pin (TC-206) — no overshoot, no underflow.
  GeoCoordinate coordinateAt(double routeDistanceKm) {
    final clamped = _clampToRoute(routeDistanceKm);
    if (clamped <= 0 || _coordinates.length == 1) {
      return _coordinates.first;
    }
    if (clamped >= routeLengthKm) {
      return _coordinates.last;
    }
    final legIndex = _legIndexFor(clamped);
    final legStartKm = _cumulativeKm[legIndex];
    final legEndKm = _cumulativeKm[legIndex + 1];
    final legKm = legEndKm - legStartKm;
    final fraction = legKm <= 0 ? 0.0 : (clamped - legStartKm) / legKm;
    return _coordinates[legIndex].lerpTo(_coordinates[legIndex + 1], fraction);
  }

  /// The contiguous polyline stretch between arc-lengths [fromKm] and [toKm]
  /// (route distance km), following the road across any checkpoint boundary it
  /// crosses (AC-6 / TC-201..TC-208).
  ///
  /// Half-open `[fromKm, toKm)` ownership is the caller's concern (the segment
  /// record is already contiguous); this method renders the geometry for the
  /// given span. The returned [GeoPolyline] vertices are:
  ///   start point at [fromKm] · every interior checkpoint coordinate strictly
  ///   between [fromKm] and [toKm] (so the stretch follows the road, not a chord
  ///   — TC-202/TC-203) · end point at [toKm].
  ///
  /// Both ends are clamped to `[0, routeLengthKm]` (TC-205/TC-206). A zero-length
  /// or out-of-route span yields an empty polyline (no red drawn).
  GeoPolyline stretchBetween(double fromKm, double toKm) {
    final lo = _clampToRoute(fromKm < toKm ? fromKm : toKm);
    final hi = _clampToRoute(fromKm < toKm ? toKm : fromKm);
    if (hi - lo <= _epsilon) {
      return const GeoPolyline(<GeoCoordinate>[]);
    }
    final points = <GeoCoordinate>[coordinateAt(lo)];
    // Append every interior checkpoint strictly inside (lo, hi) so the stretch
    // traces the road's real vertices across boundaries (TC-202/TC-203). The
    // half-open boundary rule lives upstream; here a checkpoint sitting exactly
    // on `lo` or `hi` is already represented by the clamped endpoint, so we add
    // only strictly-interior nodes to avoid duplicating the boundary point
    // (TC-202 "no duplication of the boundary point").
    for (var i = 0; i < _cumulativeKm.length; i++) {
      final nodeKm = _cumulativeKm[i];
      if (nodeKm > lo + _epsilon && nodeKm < hi - _epsilon) {
        points.add(_coordinates[i]);
      }
    }
    points.add(coordinateAt(hi));
    return GeoPolyline(List<GeoCoordinate>.unmodifiable(points));
  }

  /// Clamps a route distance into `[0, routeLengthKm]`, treating a non-finite
  /// value as 0 (the resolver applies the same defensive sanitisation).
  double _clampToRoute(double routeDistanceKm) {
    if (!routeDistanceKm.isFinite) {
      return 0;
    }
    if (routeDistanceKm < 0) {
      return 0;
    }
    if (routeDistanceKm > routeLengthKm) {
      return routeLengthKm;
    }
    return routeDistanceKm;
  }

  /// The index `i` of the leg `[_cumulativeKm[i], _cumulativeKm[i+1])` that
  /// contains [routeDistanceKm] (assumed already in `(0, routeLengthKm)`). A
  /// distance landing exactly on an interior node belongs to the leg STARTING at
  /// that node (deterministic ownership — TC-207).
  int _legIndexFor(double routeDistanceKm) {
    for (var i = _cumulativeKm.length - 1; i >= 1; i--) {
      if (routeDistanceKm >= _cumulativeKm[i]) {
        return i;
      }
    }
    return 0;
  }

  /// Float tolerance for arc-length comparisons (km) — matches the test-case
  /// tolerance (±1e-6 km).
  static const double _epsilon = 1e-6;

  /// Convenience factory from a [start] + [direction] pair (for callers that do
  /// not already hold a [RouteSelection]).
  factory RoutePolylineProjector.fromRoute({
    required Province start,
    required JourneyDirection direction,
    required ProvinceGeography geography,
  }) {
    return RoutePolylineProjector(
      selection: RouteSelection(
        start: start,
        direction: direction,
        routeStartOffsetKm: 0,
      ),
      geography: geography,
    );
  }
}
