// Widget tests for the shared map surface [MapView] (map-experience).
//
// MapView is the rendered surface used inline + full-screen: a flutter_map
// [FlutterMap] with an OSM [TileLayer], the projected base-road [PolylineLayer]
// (real geography), the red idle-trace [PolylineLayer]s (solid=voluntary /
// dashed=lock-sleep), the checkpoint + current-position [MarkerLayer], and the
// always-visible '© OpenStreetMap contributors' attribution text. These tests drive a resolved [MapViewState]
// (built via the REAL resolver/projector/idle-mapper in map_test_fixtures.dart)
// and assert the RENDERED widget tree — the polylines, markers, attribution,
// stroke patterns, and semantics — never literal pixels (no goldens; the
// project's golden approach is deferred, so TC-224/TC-225 assert behaviourally).
//
// THE FAKE TILE PROVIDER IS INJECTED EVERYWHERE — no test reaches the network.
//
// Covers (widget layer of):
//   AC-6  / TC-224  idle span renders a red Polyline on the matching stretch;
//                   active spans are not red
//   AC-7  / TC-213  zero-idle route draws no red Polyline
//   AC-9  / TC-216, TC-225  voluntary=solid vs lockSleep=dashed StrokePattern;
//                   same red colour; legend/semantics conveys the distinction
//   AC-10 / TC-217  start (no red, start marker) / mid-route (red behind marker)
//                   / completed (renders, not blocked) overlay states
//   AC-11 / TC-218  OSM attribution shown when tiles configured
//   AC-11 / TC-219  fake provider failing (offline) → road+markers+red still
//                   render, no exception, attribution still present
//
// Conventions mirror route_map_screen_test.dart (finders/structure, not pixels).

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/activity_segment.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/presentation/map_view.dart';
import 'package:focus_journey/features/route/presentation/map_view_state.dart';

import '../map_test_fixtures.dart';

void main() {
  late ProvinceChain chain;
  late ProvinceGeography geography;

  setUp(() {
    chain = buildFixtureChain();
    geography = buildFixtureGeography(chain);
  });

  /// Pumps [MapView] inside a sized [MaterialApp] with the fake tile provider.
  /// [showTiles] toggles the live OSM tile base + attribution (default true =
  /// full-screen surface; false = the compact minimap).
  Future<FakeTileProvider> pumpMapView(
    WidgetTester tester,
    MapViewState state, {
    bool failing = false,
    bool showTiles = true,
    double width = 400,
    double height = 400,
  }) async {
    final provider = FakeTileProvider(failing: failing);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // FlutterMap needs a bounded size to lay out / request tiles.
          body: SizedBox(
            width: width,
            height: height,
            child: MapView(
              state: state,
              tileProvider: provider,
              showTiles: showTiles,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return provider;
  }

  /// All red idle-trace polylines currently in the tree (excludes the base road,
  /// which is the calm slate [kBaseRoadColor]).
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

  group('AC-6 / TC-224 idle span renders a red Polyline; active is not red', () {
    testWidgets('a single idle segment produces one red polyline over the road', (
      tester,
    ) async {
      // Cần Thơ north: route legs 170/300/310/600. Idle [240,320) sits inside the
      // Đà Lạt→Đà Nẵng leg (rebased: Cần Thơ start). Active spans elsewhere.
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
        segments: <ActivitySegment>[
          activeSegment(0, 240),
          idleSegment(240, 320),
          activeSegment(320, 500),
        ],
      );
      await pumpMapView(tester, state);

      final reds = redPolylines(tester);
      expect(reds, hasLength(1));
      // The red is drawn OVER the base road (same z-stack); the base road exists.
      expect(baseRoadPolylines(tester), hasLength(1));
      // The red stretch has drawable geometry (>= 2 vertices).
      expect(reds.single.points.length, greaterThanOrEqualTo(2));
    });

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
      // The base road is still drawn (the surface is not blank).
      expect(baseRoadPolylines(tester), hasLength(1));
    });
  });

  group('AC-7 / TC-213 zero-idle route draws no red anywhere', () {
    testWidgets('no idle segments → empty idle-trace layer, no red polyline', (
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
        routeDistanceKm: 300,
        // no segments at all.
      );
      await pumpMapView(tester, state);

      expect(state.idleStretches, isEmpty);
      expect(redPolylines(tester), isEmpty);
      // Road + at least the checkpoint markers still render.
      expect(baseRoadPolylines(tester), hasLength(1));
      expect(find.byType(MarkerLayer), findsOneWidget);
    });
  });

  group('AC-9 / TC-216 / TC-225 voluntary=solid vs lockSleep=dashed, same red', () {
    testWidgets(
      'two causes → same red colour, distinct StrokePattern (solid vs dashed)',
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
          routeDistanceKm: 700,
          segments: <ActivitySegment>[
            idleSegment(100, 200, cause: SegmentCause.voluntary),
            idleSegment(400, 500, cause: SegmentCause.lockSleep),
          ],
        );
        await pumpMapView(tester, state);

        final reds = redPolylines(tester);
        expect(reds, hasLength(2));
        // Both are the SAME single "drifted off" red (AC-9: one colour).
        expect(reds.every((p) => p.color == kIdleRed), isTrue);
        // ... but the stroke PATTERNS differ (the non-colour cue / NFR-3): a
        // solid pattern has `segments == null`; a dashed pattern has a segment
        // list. The two stretches must not share the same pattern.
        const solid = StrokePattern.solid();
        final solidReds = reds.where((p) => p.pattern == solid).toList();
        final dashedReds = reds.where((p) => p.pattern != solid).toList();
        expect(
          solidReds,
          hasLength(1),
          reason: 'exactly one stretch (voluntary) is solid',
        );
        expect(
          dashedReds,
          hasLength(1),
          reason: 'exactly one stretch (lock/sleep) is non-solid (dashed)',
        );
        // The dashed stretch carries an actual dash segment list (the cue).
        expect(dashedReds.single.pattern.segments, isNotEmpty);
      },
    );

    testWidgets(
      'NFR-3 a Semantics legend conveys the solid-vs-dashed distinction',
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
          routeDistanceKm: 700,
          segments: <ActivitySegment>[
            idleSegment(100, 200, cause: SegmentCause.voluntary),
            idleSegment(400, 500, cause: SegmentCause.lockSleep),
          ],
        );
        await pumpMapView(tester, state);

        // The idle-trace layer carries a semantic label that names BOTH the red
        // meaning and the solid/dashed cue (screen-reader recoverable — NFR-3).
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
  });

  group('AC-10 / TC-217 overlay states: start / mid-route / completed', () {
    testWidgets('start (km=0): start marker present, no red trace', (
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
      // The marker sits on the start pin (km=0 resolves to origin coordinate).
      expect(state.markerPosition, geography.coordinateOf(selection.start));
      final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      // The current-position marker is present (checkpoints + 1 position pin)
      // and carries its screen-reader label (NFR-3 — semantics, not visual-only).
      final positionMarkers = markerLayer.markers.where(
        (m) =>
            m.child is Semantics &&
            (m.child as Semantics).properties.label ==
                'Your current position on the route',
      );
      expect(positionMarkers, hasLength(1));
    });

    testWidgets(
      'mid-route: red covers only idle BEHIND the marker, road still drawn',
      (tester) async {
        final selection = selectionFor(
          chain,
          'can_tho',
          JourneyDirection.towardHaGiang,
        );
        // routeDistanceKm = 400; an idle span behind the marker [100,200).
        final state = resolveMapState(
          chain: chain,
          geography: geography,
          selection: selection,
          routeDistanceKm: 400,
          segments: <ActivitySegment>[idleSegment(100, 200)],
        );
        await pumpMapView(tester, state);

        expect(redPolylines(tester), hasLength(1));
        expect(baseRoadPolylines(tester), hasLength(1));
        expect(state.isCompleted, isFalse);
      },
    );

    testWidgets(
      'completed: surface renders the full road + marker, not blocked',
      (tester) async {
        final selection = selectionFor(
          chain,
          'can_tho',
          JourneyDirection.towardHaGiang,
        );
        // Cần Thơ → Hà Giang full route length is 1380 km; drive past it.
        final state = resolveMapState(
          chain: chain,
          geography: geography,
          selection: selection,
          routeDistanceKm: 2000,
          segments: <ActivitySegment>[idleSegment(100, 200)],
        );
        await pumpMapView(tester, state);

        // Completion does not suppress the map: road, marker, and red still draw.
        expect(state.isCompleted, isTrue);
        expect(baseRoadPolylines(tester), hasLength(1));
        expect(redPolylines(tester), hasLength(1));
        // The marker is clamped to the destination pin (no overshoot).
        expect(
          state.markerPosition,
          geography.coordinateOf(
            chain.destinationOf(selection.start, selection.direction),
          ),
        );
      },
    );
  });

  group('AC-11 OSM attribution + offline fallback', () {
    testWidgets('TC-218 OSM attribution widget is shown when tiles configured', (
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
        routeDistanceKm: 300,
      );
      final provider = await pumpMapView(tester, state);

      // OSM attribution is VISIBLY shown (required by OSM tile-usage policy and
      // AC-11/TC-218). The attribution text is rendered inline (no expand
      // button), so the 'OpenStreetMap' text is on-screen — assert the visible
      // text, not merely a widget type that could be collapsed.
      expect(
        find.textContaining('OpenStreetMap'),
        findsOneWidget,
        reason: 'attribution text must be visibly rendered, not collapsed',
      );
      // The OSM tile layer is configured with the anonymous template + UA.
      final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(tileLayer.urlTemplate, kOsmTileUrlTemplate);
      // The map used the INJECTED fake provider — never a real network provider.
      expect(tileLayer.tileProvider, same(provider));
    });

    testWidgets(
      'TC-219 failing provider (offline): road+markers+red still render, no throw',
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
          routeDistanceKm: 500,
          segments: <ActivitySegment>[idleSegment(100, 200)],
        );
        // failing: every tile load errors (simulated no-network).
        await pumpMapView(tester, state, failing: true);
        await tester.pump(const Duration(milliseconds: 100));

        // No exception bubbled to the journey tab.
        expect(tester.takeException(), isNull);
        // The province road, markers, and the red idle trace STILL render on the
        // map's base, independent of tile success (the defined fallback).
        expect(baseRoadPolylines(tester), hasLength(1));
        expect(redPolylines(tester), hasLength(1));
        expect(find.byType(MarkerLayer), findsOneWidget);
        // Attribution is still visibly shown even when tiles fail.
        expect(find.textContaining('OpenStreetMap'), findsOneWidget);
      },
    );
  });

  group('Full-screen province labels + hover tooltips on checkpoint stops', () {
    testWidgets(
      'full-screen checkpoint markers carry a province-name label + a '
      'hover Tooltip; the camera still fits the full route extent',
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
        // Full-screen surface (showTiles default true) at a large size so the
        // route's extent fits and labels lay out.
        await pumpMapView(tester, state, width: 800, height: 800);

        // Each ordered checkpoint name is rendered as a visible label on the map
        // (province labels — requirement #3). Assert the first/last stop names.
        final firstStop = state.orderedNodes.first.name;
        final lastStop = state.orderedNodes.last.name;
        // The name appears at least once (label text); may also appear in the
        // Tooltip message, so use findsWidgets.
        expect(find.text(firstStop), findsWidgets);
        expect(find.text(lastStop), findsWidgets);

        // A desktop hover Tooltip wraps each checkpoint — one Tooltip per stop.
        final tooltips = tester.widgetList<Tooltip>(find.byType(Tooltip));
        expect(
          tooltips.length,
          state.orderedNodes.length,
          reason: 'one hover tooltip per checkpoint stop',
        );
        // Tooltip messages name the provinces (hover identifies the stop).
        final messages = tooltips.map((t) => t.message).toSet();
        expect(messages, contains(firstStop));
        expect(messages, contains(lastStop));

        // The camera-fit still uses the full route extent (no thrown layout).
        expect(tester.takeException(), isNull);
        // Tiles + attribution remain on the full-screen surface (AC-11).
        expect(find.byType(TileLayer), findsOneWidget);
        expect(find.textContaining('OpenStreetMap'), findsOneWidget);
      },
    );

    testWidgets(
      'the compact minimap shows NO province labels and NO tooltips (unchanged)',
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
          showTiles: false,
          width: 150,
          height: 190,
        );

        // Minimap stays uncluttered: bare dots, no name labels, no tooltips.
        expect(find.byType(Tooltip), findsNothing);
        expect(find.text(state.orderedNodes.first.name), findsNothing);
      },
    );
  });

  group('compact minimap (showTiles:false) — route glanceable, no tiles', () {
    testWidgets(
      'default (full-screen) shows the OSM tile layer + attribution',
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
        // Default showTiles:true → full-screen surface.
        await pumpMapView(tester, state);

        expect(find.byType(TileLayer), findsOneWidget);
        expect(find.textContaining('OpenStreetMap'), findsOneWidget);
      },
    );

    testWidgets(
      'compact shows polyline + markers + red trace but NO tiles/attribution',
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
          routeDistanceKm: 500,
          segments: <ActivitySegment>[
            idleSegment(100, 200, cause: SegmentCause.voluntary),
            idleSegment(300, 400, cause: SegmentCause.lockSleep),
          ],
        );
        // showTiles:false at minimap size → no live tiles, no attribution pill.
        final provider = await pumpMapView(
          tester,
          state,
          showTiles: false,
          // The compact minimap dimensions (≈150×190 — see map_surface.dart).
          width: 150,
          height: 190,
        );
        await tester.pump(const Duration(milliseconds: 50));

        // No live OSM tile base inline, and no attribution pill (it would be
        // illegible at ~150px; reserved for the full-screen surface — AC-11).
        expect(find.byType(TileLayer), findsNothing);
        expect(find.textContaining('OpenStreetMap'), findsNothing);
        // …and therefore ZERO tile network calls from the minimap (NFR-2).
        expect(provider.requestedUrls, isEmpty);

        // The route is STILL glanceable: base road, checkpoint + position
        // markers, AND the red idle trace (solid + dashed) render (AC-6/AC-9).
        expect(baseRoadPolylines(tester), hasLength(1));
        expect(find.byType(MarkerLayer), findsOneWidget);
        final reds = redPolylines(tester);
        expect(reds, hasLength(2));
        expect(reds.every((p) => p.color == kIdleRed), isTrue);
        const solid = StrokePattern.solid();
        expect(reds.where((p) => p.pattern == solid), hasLength(1));
        expect(reds.where((p) => p.pattern != solid), hasLength(1));
      },
    );
  });
}
