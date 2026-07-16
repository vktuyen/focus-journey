// Widget tests for the shared map surface [MapView] (map-experience +
// vietnam-map-fidelity / ADR-0008).
//
// MapView is the rendered surface used inline + full-screen: a `flutter_map`
// [FlutterMap] whose BASE is the bundled, offline Vietnam 34-province
// [PolygonLayer] (single-tone land + thin borders — ADR-0008), with the shipped
// overlays drawn ON TOP: the projected base-road [PolylineLayer], the red
// idle-trace [PolylineLayer]s (solid=voluntary / dashed=lock-sleep), the
// checkpoint + current-position [MarkerLayer], and an in-app CC BY-SA 3.0
// attribution for the bundled base.
//
// ADR-0008(c) DROPPED the OSM `TileLayer` (network egress → zero). These tests
// therefore inject NO tile provider: the base is a bundled [BaseMapGeometry]
// (via [buildFixtureBaseMap]) so the surface renders fully offline and can never
// be a blank/grey canvas or an empty-tile placeholder. Assertions are on the
// RENDERED widget tree (polygons, polylines, markers, attribution, stroke
// patterns, semantics), never literal pixels (goldens are deferred project-wide
// — TC-806 relies on the manual recognisability leg TC-M-GEO).
//
// Covers (widget layer of):
//   AC-1  / TC-801, TC-802  offline full-map base renders BENEATH the overlays;
//                           NO TileLayer, no OSM URL (regression guard for the
//                           dropped tile base)
//   AC-2  / TC-803          the compact minimap renders the same base offline
//   AC-8  / TC-813, TC-814  overlays legible on the base on BOTH surfaces;
//                           idle-trace solid vs dashed by more than colour
//   AC-9  / TC-815          CC BY-SA 3.0 attribution shown full-screen; hidden on
//                           the compact minimap (shared via the full map)
//   AC-11 / TC-819          overlays render UNCHANGED with the base beneath
//   NFR-3 / TC-821          base + overlays exposed via Semantics
//   (retained map-experience red-trace coverage: TC-224 / TC-213 / TC-216 /
//    TC-225 / TC-217 — now drawn over the bundled base)

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/activity_segment.dart';
import 'package:focus_journey/features/route/domain/base_map_geometry.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/presentation/base_map_layer.dart';
import 'package:focus_journey/features/route/presentation/map_view.dart';
import 'package:focus_journey/features/route/presentation/map_view_state.dart';
import 'package:latlong2/latlong.dart';

import '../map_test_fixtures.dart';

void main() {
  late ProvinceChain chain;
  late ProvinceGeography geography;
  late BaseMapGeometry base;

  setUp(() {
    chain = buildFixtureChain();
    geography = buildFixtureGeography(chain);
    base = buildFixtureBaseMap();
  });

  /// Pumps [MapView] inside a sized [MaterialApp]. [withBase] injects the fixture
  /// base geometry (default) or, when `false`, models the legacy no-base host.
  /// [compact] selects the ~150px minimap surface.
  Future<void> pumpMapView(
    WidgetTester tester,
    MapViewState state, {
    bool withBase = true,
    bool compact = false,
    double width = 400,
    double height = 400,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: MapView(
              state: state,
              baseMap: withBase ? base : null,
              compact: compact,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The base-map [PolygonLayer] (land fill + province borders), or `null`.
  PolygonLayer<Object>? baseMapLayer(WidgetTester tester) {
    final layers = tester.widgetList<PolygonLayer<Object>>(
      find.byType(PolygonLayer<Object>),
    );
    for (final layer in layers) {
      if (layer.polygons.any((p) => p.color == kLandFill)) {
        return layer;
      }
    }
    return null;
  }

  /// All red idle-trace polylines currently in the tree.
  List<Polyline<Object>> redPolylines(WidgetTester tester) {
    final layers = tester.widgetList<PolylineLayer<Object>>(
      find.byType(PolylineLayer<Object>),
    );
    return <Polyline<Object>>[
      for (final layer in layers)
        for (final line in layer.polylines)
          if (line.color == kIdleRed) line,
    ];
  }

  /// The base-road polylines (slate colour) in the tree.
  List<Polyline<Object>> baseRoadPolylines(WidgetTester tester) {
    final layers = tester.widgetList<PolylineLayer<Object>>(
      find.byType(PolylineLayer<Object>),
    );
    return <Polyline<Object>>[
      for (final layer in layers)
        for (final line in layer.polylines)
          if (line.color == kBaseRoadColor) line,
    ];
  }

  /// The current-position marker point, or `null`.
  LatLng? currentMarker(WidgetTester tester) {
    final layer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    for (final m in layer.markers) {
      final child = m.child;
      if (child is Semantics &&
          child.properties.label == 'Your current position on the route') {
        return m.point;
      }
    }
    return null;
  }

  MapViewState midRouteState() {
    final selection = selectionFor(
      chain,
      'can_tho',
      JourneyDirection.towardHaGiang,
    );
    return resolveMapState(
      chain: chain,
      geography: geography,
      selection: selection,
      routeDistanceKm: 500,
      segments: <ActivitySegment>[
        idleSegment(100, 200, cause: SegmentCause.voluntary),
        idleSegment(400, 500, cause: SegmentCause.lockSleep),
      ],
    );
  }

  group('AC-1 / TC-801 offline full-map base renders beneath the overlays', () {
    testWidgets(
      'the bundled base PolygonLayer is present and drawn UNDER the overlays',
      (tester) async {
        await pumpMapView(tester, midRouteState());

        // The base is present (land fill from the bundled geometry) — the
        // surface is never a blank canvas with no network / no tiles.
        final layer = baseMapLayer(tester);
        expect(layer, isNotNull);
        expect(
          layer!.polygons.where((p) => p.color == kLandFill),
          isNotEmpty,
          reason: 'the land polygons render (never blank)',
        );

        // Z-ORDER (AC-11): the base is the FIRST child of the FlutterMap, so it
        // paints BENEATH the road / idle-trace / markers stacked above it.
        final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
        final first = map.children.first;
        expect(first, isA<Semantics>());
        expect((first as Semantics).child, isA<PolygonLayer<Object>>());
        expect(
          (first.child! as PolygonLayer<Object>).polygons.any(
            (p) => p.color == kLandFill,
          ),
          isTrue,
        );
        // The overlays are all present above the base.
        expect(baseRoadPolylines(tester), hasLength(1));
        expect(find.byType(MarkerLayer), findsOneWidget);
      },
    );

    testWidgets(
      'AC-10 / TC-802: no OSM TileLayer and no OSM URL exist — base is offline',
      (tester) async {
        await pumpMapView(tester, midRouteState());

        // The optional OSM tile base was DROPPED (ADR-0008(c)); the base is a
        // bundled asset that never depends on a tile fetch. Regression guard for
        // the drop: no tile LAYER and no network tile URL appears. (The
        // "© OpenStreetMap contributors, ODbL" ATTRIBUTION for the bundled road
        // geometry is expected — route-real-road / NFR-4 — and is verified in the
        // attribution tests; it is a static credit string, not a network fetch.)
        expect(find.byType(TileLayer), findsNothing);
        expect(find.textContaining('tile.openstreetmap'), findsNothing);
        expect(find.textContaining('http'), findsNothing);
        // The base still drew regardless (independent of any tile state).
        expect(baseMapLayer(tester), isNotNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a legacy host that injects NO base renders the overlays without a base',
      (tester) async {
        // Back-compat: no base injected → no base layer, overlays still render.
        await pumpMapView(tester, midRouteState(), withBase: false);

        expect(baseMapLayer(tester), isNull);
        expect(baseRoadPolylines(tester), hasLength(1));
        expect(find.byType(TileLayer), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('AC-2 / TC-803 offline compact minimap renders the same base', () {
    testWidgets('the compact surface draws the bundled base (no tiles)', (
      tester,
    ) async {
      await pumpMapView(
        tester,
        midRouteState(),
        compact: true,
        width: 150,
        height: 190,
      );

      // The minimap shares the base — its land polygons render at compact size.
      expect(baseMapLayer(tester), isNotNull);
      expect(find.byType(TileLayer), findsNothing);
      // The route is still glanceable over the base (road + markers).
      expect(baseRoadPolylines(tester), hasLength(1));
      expect(find.byType(MarkerLayer), findsOneWidget);
    });
  });

  group('AC-8 / TC-813 / TC-814 idle-trace solid vs dashed by more than colour', () {
    testWidgets(
      'TC-813 full map: two causes → same red, distinct StrokePattern over base',
      (tester) async {
        await pumpMapView(tester, midRouteState());

        // The base is beneath (legibility is against the bundled fill).
        expect(baseMapLayer(tester), isNotNull);

        final reds = redPolylines(tester);
        expect(reds, hasLength(2));
        // AC-8: both stretches share the ONE "drifted off" red …
        expect(reds.every((p) => p.color == kIdleRed), isTrue);
        // … but the cause is conveyed by the STROKE PATTERN, not a second hue.
        const solid = StrokePattern.solid();
        expect(
          reds.where((p) => p.pattern == solid),
          hasLength(1),
          reason: 'exactly one stretch (voluntary) is solid',
        );
        final dashed = reds.where((p) => p.pattern != solid).toList();
        expect(dashed, hasLength(1), reason: 'one stretch (lock/sleep) is dashed');
        expect(dashed.single.pattern.segments, isNotEmpty);
      },
    );

    testWidgets(
      'TC-814 compact minimap: solid vs dashed NOT collapsed by decimation',
      (tester) async {
        await pumpMapView(
          tester,
          midRouteState(),
          compact: true,
          width: 150,
          height: 190,
        );

        final reds = redPolylines(tester);
        expect(reds, hasLength(2));
        expect(reds.every((p) => p.color == kIdleRed), isTrue);
        const solid = StrokePattern.solid();
        // The dash cue survives at ~150px (not flattened to solid).
        expect(reds.where((p) => p.pattern == solid), hasLength(1));
        expect(reds.where((p) => p.pattern != solid), hasLength(1));
      },
    );

    testWidgets(
      'NFR-3 the idle-trace Semantics names the solid-vs-dashed distinction',
      (tester) async {
        await pumpMapView(tester, midRouteState());

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                (w.properties.label?.contains('Solid') ?? false) &&
                (w.properties.label?.contains('dashed') ?? false),
          ),
        );
        expect(semantics.properties.label, contains('voluntary'));
      },
    );

    testWidgets('active-only stretches contribute no red polyline', (
      tester,
    ) async {
      final selection = selectionFor(
        chain,
        'can_tho',
        JourneyDirection.towardHaGiang,
      );
      final state = resolveMapState(
        chain: chain,
        geography: geography,
        selection: selection,
        routeDistanceKm: 500,
        segments: <ActivitySegment>[activeSegment(0, 500)],
      );
      await pumpMapView(tester, state);

      expect(redPolylines(tester), isEmpty);
      expect(baseRoadPolylines(tester), hasLength(1));
      expect(baseMapLayer(tester), isNotNull);
    });

    testWidgets('TC-213 zero-idle route draws no red anywhere', (tester) async {
      final selection = selectionFor(
        chain,
        'can_tho',
        JourneyDirection.towardHaGiang,
      );
      final state = resolveMapState(
        chain: chain,
        geography: geography,
        selection: selection,
        routeDistanceKm: 300,
      );
      await pumpMapView(tester, state);

      expect(state.idleStretches, isEmpty);
      expect(redPolylines(tester), isEmpty);
      expect(baseRoadPolylines(tester), hasLength(1));
      expect(find.byType(MarkerLayer), findsOneWidget);
    });
  });

  group('AC-9 / TC-815 CC BY-SA 3.0 attribution for the bundled base', () {
    testWidgets('full-screen shows the CC BY-SA credit line', (tester) async {
      await pumpMapView(tester, midRouteState());

      // The share-alike base makes the credit MANDATORY — it must be visibly
      // rendered (not collapsed / off-screen).
      expect(find.text(kBaseMapAttribution), findsOneWidget);
      expect(find.textContaining('CC BY-SA 3.0'), findsOneWidget);
      // And it credits Wikimedia, distinct from any (now-removed) tile credit.
      expect(find.textContaining('Wikimedia'), findsOneWidget);
    });

    testWidgets('the compact minimap does NOT show the attribution pill', (
      tester,
    ) async {
      await pumpMapView(
        tester,
        midRouteState(),
        compact: true,
        width: 150,
        height: 190,
      );

      // The minimap stays uncluttered; the credit rides on the full-map surface.
      expect(find.text(kBaseMapAttribution), findsNothing);
      expect(find.textContaining('CC BY-SA'), findsNothing);
    });
  });

  group('AC-11 / TC-819 overlays render UNCHANGED with the base beneath', () {
    testWidgets(
      'route polyline, checkpoint markers, and current marker are identical '
      'with vs without the base layer',
      (tester) async {
        final state = midRouteState();

        // --- WITHOUT the base. ---
        await pumpMapView(tester, state, withBase: false);
        expect(baseMapLayer(tester), isNull);
        final roadNoBase = baseRoadPolylines(tester).single.points;
        final markerNoBase = currentMarker(tester);
        final markerCountNoBase = tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .length;
        final redsNoBase = redPolylines(tester)
            .map((p) => p.pattern)
            .toList();

        // --- WITH the base beneath. ---
        await pumpMapView(tester, state);
        expect(baseMapLayer(tester), isNotNull);
        final roadWithBase = baseRoadPolylines(tester).single.points;
        final markerWithBase = currentMarker(tester);
        final markerCountWithBase = tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .length;
        final redsWithBase = redPolylines(tester)
            .map((p) => p.pattern)
            .toList();

        // The base is PURELY additive: every overlay is structurally identical.
        expect(roadWithBase, roadNoBase);
        expect(markerWithBase, markerNoBase);
        expect(markerCountWithBase, markerCountNoBase);
        expect(redsWithBase, redsNoBase);
      },
    );
  });

  group('AC-10 / TC-217 overlay states over the base: start / mid / completed', () {
    testWidgets('start (km=0): current-position marker present, no red trace', (
      tester,
    ) async {
      final selection = selectionFor(
        chain,
        'can_tho',
        JourneyDirection.towardHaGiang,
      );
      final state = resolveMapState(
        chain: chain,
        geography: geography,
        selection: selection,
        routeDistanceKm: 0,
      );
      await pumpMapView(tester, state);

      expect(redPolylines(tester), isEmpty);
      expect(state.markerPosition, geography.coordinateOf(selection.start));
      expect(currentMarker(tester), isNotNull);
      expect(baseMapLayer(tester), isNotNull);
    });

    testWidgets(
      'completed: full road + marker + base still render (not blocked)',
      (tester) async {
        final selection = selectionFor(
          chain,
          'can_tho',
          JourneyDirection.towardHaGiang,
        );
        final state = resolveMapState(
          chain: chain,
          geography: geography,
          selection: selection,
          routeDistanceKm: 2000,
          segments: <ActivitySegment>[idleSegment(100, 200)],
        );
        await pumpMapView(tester, state);

        expect(state.isCompleted, isTrue);
        expect(baseRoadPolylines(tester), hasLength(1));
        expect(redPolylines(tester), hasLength(1));
        expect(baseMapLayer(tester), isNotNull);
        expect(
          state.markerPosition,
          geography.coordinateOf(
            chain.destinationOf(selection.start, selection.direction),
          ),
        );
      },
    );
  });

  group('Full-screen province labels + hover tooltips (minimap stays bare)', () {
    testWidgets(
      'full-screen checkpoint markers carry a province-name label + a tooltip',
      (tester) async {
        final selection = selectionFor(
          chain,
          'can_tho',
          JourneyDirection.towardHaGiang,
        );
        final state = resolveMapState(
          chain: chain,
          geography: geography,
          selection: selection,
          routeDistanceKm: 300,
        );
        await pumpMapView(tester, state, width: 800, height: 800);

        final firstStop = state.orderedNodes.first.name;
        final lastStop = state.orderedNodes.last.name;
        expect(find.text(firstStop), findsWidgets);
        expect(find.text(lastStop), findsWidgets);

        final tooltips = tester.widgetList<Tooltip>(find.byType(Tooltip));
        expect(tooltips.length, state.orderedNodes.length);
        final messages = tooltips.map((t) => t.message).toSet();
        expect(messages, contains(firstStop));
        expect(messages, contains(lastStop));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'the compact minimap shows NO province labels and NO tooltips',
      (tester) async {
        final selection = selectionFor(
          chain,
          'can_tho',
          JourneyDirection.towardHaGiang,
        );
        final state = resolveMapState(
          chain: chain,
          geography: geography,
          selection: selection,
          routeDistanceKm: 300,
        );
        await pumpMapView(
          tester,
          state,
          compact: true,
          width: 150,
          height: 190,
        );

        expect(find.byType(Tooltip), findsNothing);
        expect(find.text(state.orderedNodes.first.name), findsNothing);
      },
    );
  });

  group('route-real-road — curved road (AC-1)', () {
    testWidgets('the drawn road has more vertices than the checkpoint count', (
      tester,
    ) async {
      final state = resolveMapState(
        chain: chain,
        geography: geography,
        selection: selectionFor(
          chain,
          'can_tho',
          JourneyDirection.towardHaGiang,
        ),
        routeDistanceKm: 300,
      );
      await pumpMapView(tester, state, width: 800, height: 800);

      final road = baseRoadPolylines(tester).single;
      // A smooth curve is densified far beyond the raw checkpoint chords (AC-1).
      expect(road.points.length, greaterThan(state.orderedNodes.length * 5));
    });
  });

  group('route-real-road — marker hierarchy (AC-2/AC-3/AC-4/NFR-3)', () {
    /// Counts the marker dots painted with [color] (emphasized teal vs pass-
    /// through grey). Both are the only [DecoratedBox]es carrying these colours.
    int dotsOfColour(WidgetTester tester, Color color) {
      return tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where((d) {
            final dec = d.decoration;
            return dec is BoxDecoration && dec.color == color;
          })
          .length;
    }

    /// All marker Semantics labels (NFR-3 — the role is recoverable non-visually).
    List<String> markerLabels(WidgetTester tester) {
      return <String>[
        for (final s in tester.widgetList<Semantics>(find.byType(Semantics)))
          if (s.properties.label != null) s.properties.label!,
      ];
    }

    int labelsMatching(WidgetTester tester, Pattern p) =>
        markerLabels(tester).where((l) => l.startsWith(p as String)).length;

    MapViewState fullSpineState({List<String> markedStopIds = const []}) {
      return resolveMapState(
        chain: chain,
        geography: geography,
        selection: selectionFor(
          chain,
          'can_tho',
          JourneyDirection.towardHaGiang,
        ),
        routeDistanceKm: 300,
        markedStopIds: markedStopIds,
      );
    }

    testWidgets(
      'only start + end are big; every pass-through is small grey (AC-2/AC-3)',
      (tester) async {
        final state = fullSpineState();
        // can_tho → da_lat → da_nang → ha_noi → ha_giang (N = 5).
        expect(state.orderedNodes, hasLength(5));
        await pumpMapView(tester, state, width: 800, height: 800);

        final labels = markerLabels(tester);
        expect(labels, contains('Start: ${state.orderedNodes.first.name}'));
        expect(
          labels,
          contains('Destination: ${state.orderedNodes.last.name}'),
        );
        // The three interior provinces are pass-through (never a Stop here).
        expect(labelsMatching(tester, 'Passing through '), 3);
        expect(labelsMatching(tester, 'Stop: '), 0);

        // Exactly two big (teal) dots; three small grey dots.
        expect(dotsOfColour(tester, kEmphasizedMarkerColor), 2);
        expect(dotsOfColour(tester, kPassThroughGrey), 3);
      },
    );

    testWidgets(
      'a user-marked stop renders as a THIRD big marker (AC-4)',
      (tester) async {
        final state = fullSpineState(markedStopIds: <String>['da_lat']);
        await pumpMapView(tester, state, width: 800, height: 800);

        expect(markerLabels(tester), contains('Stop: Đà Lạt'));
        // Start + end + the one stop = three big; the remaining two are grey.
        expect(dotsOfColour(tester, kEmphasizedMarkerColor), 3);
        expect(dotsOfColour(tester, kPassThroughGrey), 2);
        // The pass-through provinces are still reachable/labelled (NFR-3).
        expect(labelsMatching(tester, 'Passing through '), 2);
      },
    );

    testWidgets('the compact minimap keeps the tier (small dots, no tooltips)', (
      tester,
    ) async {
      final state = fullSpineState();
      await pumpMapView(
        tester,
        state,
        compact: true,
        width: 150,
        height: 190,
      );
      // Endpoints emphasized (teal), pass-through grey — but no tooltips/labels.
      expect(dotsOfColour(tester, kEmphasizedMarkerColor), 2);
      expect(dotsOfColour(tester, kPassThroughGrey), 3);
      expect(find.byType(Tooltip), findsNothing);
    });
  });
}
