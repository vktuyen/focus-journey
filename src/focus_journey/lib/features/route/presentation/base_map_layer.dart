/// Presentation layer. The bundled Vietnam base map rendered as a `flutter_map`
/// [PolygonLayer] that sits UNDER the shipped overlays (vietnam-map-fidelity /
/// ADR-0008): one calm single-tone land fill + thin province borders, drawn
/// over the themed sea background. No live tiles, no network (AC-1/2/10).
///
/// The GeoCoordinate→LatLng conversion happens here at the presentation
/// boundary (via `lat_lng_mapper`), keeping the [BaseMapGeometry] domain type
/// framework-free. The static geometry is parsed ONCE by the repository and
/// cached; the compact minimap uses the geometry's cached decimated variant
/// (NFR-1 / TC-804/TC-820).
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../domain/base_map_geometry.dart';
import 'lat_lng_mapper.dart';

/// The themed sea background painted behind the land polygons (the app's own
/// background — the sea is NOT a per-province asset colour, ADR-0008(b)).
const Color kSeaBackground = Color(0xFFAECBD6);

/// The single calm land tone (one fill for the whole landmass — ADR-0008(b)).
const Color kLandFill = Color(0xFFEDE6D3);

/// The thin province-border stroke (a muted tone that reads against the land
/// fill without competing with the red idle trace / teal pins / orange marker).
const Color kProvinceBorder = Color(0xFF9E9A8C);

/// The land outline (coastline) stroke — a touch darker than the province
/// borders so the country edge reads crisply against the sea.
const Color kCoastline = Color(0xFF7D8A93);

/// Memoizes the converted base-map [PolygonLayer]s per [BaseMapGeometry] instance
/// (NFR-1 / TC-820). The GeoCoordinate→LatLng conversion over the ~73 rings is
/// independent of [MapViewState], but `buildBaseMapLayers` runs inside a
/// state-driven `BlocBuilder` that rebuilds on every marker/distance tick. The
/// geometry is loaded ONCE and stable, so we cache the built layers against the
/// instance (an `Expando`, so it never leaks the geometry — kept OUT of the
/// framework-free domain type) and reuse the immutable layer widgets. Index 0 =
/// full, index 1 = compact.
final Expando<List<List<Widget>?>> _baseLayerCache =
    Expando<List<List<Widget>?>>('baseMapLayers');

/// Builds the base-map [PolygonLayer]s for a [FlutterMap]. Returns the land
/// fill layer first, then the province-border layer on top, so the caller can
/// splice them beneath the route/pins/marker/idle-trace overlays.
///
/// [compact] selects the geometry's cached decimated variant for the ~150px
/// minimap (NFR-1). Returns an empty list for empty geometry, so a host that
/// injects no base (legacy tests) renders exactly as before. The converted
/// layers are memoized per `(geometry, compact)` so the ~73-ring conversion runs
/// once per app run, not per state tick (NFR-1 / TC-820).
List<Widget> buildBaseMapLayers(
  BaseMapGeometry geometry, {
  bool compact = false,
}) {
  final slot = compact ? 1 : 0;
  final cache = _baseLayerCache[geometry] ??= <List<Widget>?>[null, null];
  final cached = cache[slot];
  if (cached != null) {
    return cached;
  }
  return cache[slot] = _buildBaseMapLayers(geometry, compact: compact);
}

List<Widget> _buildBaseMapLayers(
  BaseMapGeometry geometry, {
  required bool compact,
}) {
  final source = compact ? geometry.minimap : geometry;
  if (source.isEmpty) {
    return const <Widget>[];
  }
  final landPolys = <Polygon<Object>>[
    for (final ring in source.landRings)
      Polygon<Object>(
        points: toLatLngs(ring),
        color: kLandFill,
        borderColor: kCoastline,
        borderStrokeWidth: 0.8,
      ),
  ];
  final provincePolys = <Polygon<Object>>[
    for (final ring in source.provinceRings)
      Polygon<Object>(
        points: toLatLngs(ring),
        // Transparent fill: the land layer beneath supplies the single tone; a
        // province polygon contributes only its thin border (AC-3 unit lines).
        color: const Color(0x00000000),
        borderColor: kProvinceBorder,
        borderStrokeWidth: compact ? 0.4 : 0.7,
      ),
  ];
  return <Widget>[
    // The whole surface is decorative context for the overlays; expose it to
    // assistive tech as a single labelled region rather than 70+ polygons.
    Semantics(
      label: 'Map of Vietnam and its provinces',
      child: PolygonLayer<Object>(
        polygonCulling: true,
        polygons: <Polygon<Object>>[...landPolys, ...provincePolys],
      ),
    ),
  ];
}
