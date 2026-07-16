// Widget tests for the bundled Vietnam base-map layer builder
// `buildBaseMapLayers` (vietnam-map-fidelity / ADR-0008).
//
// ADR-0008(c) DROPPED the OSM `TileLayer`: the base is now an offline, bundled
// [BaseMapGeometry] drawn as a single [PolygonLayer] (single-tone land fill +
// thin province borders) that sits UNDER the shipped overlays. These tests
// exercise the pure layer builder directly (it returns `List<Widget>`), so no
// network, no asset load, no timers — the base is deterministic geometry.
//
// Covers (base-layer half of):
//   AC-1 / TC-801, TC-802  offline full-map base renders the land polygons from
//                          the bundled geometry — never blank, never a TileLayer
//   AC-2 / TC-803, TC-804  the compact minimap uses the cached DECIMATED geometry
//                          and still renders a recognisable (non-blob) base
//   AC-3 / TC-805 (layer)  each province-outline ring contributes a thin border
//                          polygon (transparent fill — the land layer is the tone)
//   AC-10 / TC-816         the base is pure geometry — no TileLayer, no network
//   NFR-3 / TC-821         the base is exposed as ONE labelled Semantics region

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/route/domain/base_map_geometry.dart';
import 'package:focus_journey/features/route/domain/equirectangular_projection.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/presentation/base_map_layer.dart';

import '../map_test_fixtures.dart';

void main() {
  /// The single [PolygonLayer] the builder emits (wrapped in the labelled
  /// Semantics region). Fails the test if the builder returned no base.
  PolygonLayer<Object> baseLayerOf(List<Widget> layers) {
    expect(layers, isNotEmpty, reason: 'the base builder emitted no layer');
    final first = layers.first;
    expect(
      first,
      isA<Semantics>(),
      reason: 'the base layer is wrapped in a Semantics region (NFR-3)',
    );
    final child = (first as Semantics).child;
    expect(child, isA<PolygonLayer<Object>>());
    return child! as PolygonLayer<Object>;
  }

  /// The land-fill polygons in [layer] (the single calm land tone).
  List<Polygon<Object>> landPolygons(PolygonLayer<Object> layer) =>
      layer.polygons.where((p) => p.color == kLandFill).toList();

  /// The province-outline polygons (transparent fill, drawn only for the border).
  List<Polygon<Object>> provincePolygons(PolygonLayer<Object> layer) =>
      layer.polygons.where((p) => p.borderColor == kProvinceBorder).toList();

  group('AC-1 / TC-801 offline full-map base renders the land polygons', () {
    test('the builder emits a PolygonLayer with land fill + province borders', () {
      final geometry = buildFixtureBaseMap();

      final layers = buildBaseMapLayers(geometry);
      final layer = baseLayerOf(layers);

      // The landmass draws as a single calm tone (never blank / never a tile).
      final land = landPolygons(layer);
      expect(land, hasLength(geometry.landRings.length));
      expect(
        land.every((p) => p.points.length >= 4),
        isTrue,
        reason: 'each land ring is a drawable polygon (>= 4 vertices)',
      );
      // Every 2025 provincial unit contributes a thin border (AC-3).
      expect(provincePolygons(layer), hasLength(geometry.provinceRings.length));
    });

    testWidgets(
      'AC-10 / TC-802: the base is pure geometry — NO TileLayer, no network',
      (tester) async {
        final geometry = buildFixtureBaseMap();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: FlutterMap(
                  options: const MapOptions(),
                  children: buildBaseMapLayers(geometry),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // The base draws with zero tile dependency — the OSM TileLayer is gone
        // (ADR-0008(c)); the country reads from the bundled polygons alone.
        expect(find.byType(TileLayer), findsNothing);
        expect(find.byType(PolygonLayer<Object>), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    test('province-outline polygons are transparent-filled (land supplies tone)', () {
      final geometry = buildFixtureBaseMap();
      final layer = baseLayerOf(buildBaseMapLayers(geometry));

      for (final poly in provincePolygons(layer)) {
        // The unit polygon contributes ONLY its border; the land layer beneath
        // supplies the single land tone (AC-3 / ADR-0008(b)).
        expect(poly.color, const Color(0x00000000));
        expect(poly.borderColor, kProvinceBorder);
      }
    });
  });

  group('AC-2 / TC-803 / TC-804 the compact minimap uses the decimated base', () {
    test('compact:true draws from the cached decimated geometry, still non-blob', () {
      // A dense ring (a rectangle sampled at 0.1° along its edges) so the
      // Douglas-Peucker decimation for the minimap measurably reduces the
      // vertex count while preserving the silhouette (identity, not a blob).
      final dense = _denseRectGeometry();
      final fullLen = dense.landRings.first.length;
      final minimapLen = dense.minimap.landRings.first.length;
      expect(
        minimapLen,
        lessThan(fullLen),
        reason: 'the minimap geometry is decimated (fewer vertices)',
      );

      final fullLayer = baseLayerOf(buildBaseMapLayers(dense));
      final compactLayer = baseLayerOf(
        buildBaseMapLayers(dense, compact: true),
      );

      // The compact layer draws the DECIMATED ring, not the full-resolution one.
      expect(landPolygons(compactLayer).first.points, hasLength(minimapLen));
      expect(landPolygons(fullLayer).first.points, hasLength(fullLen));

      // Decimation trades vertex count, not identity: the minimap ring is still
      // a real polygon whose bbox stays within the Vietnam frame (not collapsed).
      final pts = landPolygons(compactLayer).first.points;
      expect(pts.length, greaterThanOrEqualTo(4));
      for (final p in pts) {
        expect(p.latitude, inInclusiveRange(
          EquirectangularBounds.south,
          EquirectangularBounds.north,
        ));
        expect(p.longitude, inInclusiveRange(
          EquirectangularBounds.west,
          EquirectangularBounds.east,
        ));
      }
    });

    test('compact borders are thinner than full-screen borders', () {
      final geometry = buildFixtureBaseMap();
      final full = baseLayerOf(buildBaseMapLayers(geometry));
      final compact = baseLayerOf(buildBaseMapLayers(geometry, compact: true));

      expect(
        provincePolygons(compact).first.borderStrokeWidth,
        lessThan(provincePolygons(full).first.borderStrokeWidth),
      );
    });
  });

  group('back-compat + semantics', () {
    test('empty geometry emits no layer (legacy hosts render as before)', () {
      expect(buildBaseMapLayers(BaseMapGeometry.empty()), isEmpty);
      expect(
        buildBaseMapLayers(BaseMapGeometry.empty(), compact: true),
        isEmpty,
      );
    });

    test('NFR-3 / TC-821: the base is one labelled Semantics region', () {
      final layers = buildBaseMapLayers(buildFixtureBaseMap());
      final semantics = layers.first as Semantics;
      expect(semantics.properties.label, contains('Vietnam'));
      expect(semantics.properties.label, contains('provinces'));
    });
  });
}

/// A geometry whose land ring is a rectangle densely sampled (0.1° steps) along
/// each edge, so its many near-collinear points are collapsed by the minimap
/// decimation — letting TC-804 assert the vertex count genuinely drops while the
/// silhouette (bbox) survives.
BaseMapGeometry _denseRectGeometry() {
  const south = 9.0, north = 22.0, west = 104.0, east = 109.0;
  final ring = <GeoCoordinate>[];
  for (var lon = west; lon < east; lon += 0.1) {
    ring.add(GeoCoordinate(latitude: south, longitude: lon));
  }
  for (var lat = south; lat < north; lat += 0.1) {
    ring.add(GeoCoordinate(latitude: lat, longitude: east));
  }
  for (var lon = east; lon > west; lon -= 0.1) {
    ring.add(GeoCoordinate(latitude: north, longitude: lon));
  }
  for (var lat = north; lat > south; lat -= 0.1) {
    ring.add(GeoCoordinate(latitude: lat, longitude: west));
  }
  ring.add(const GeoCoordinate(latitude: south, longitude: west));
  return BaseMapGeometry(
    landRings: <List<GeoCoordinate>>[ring],
    provinceRings: const <List<GeoCoordinate>>[],
  );
}
