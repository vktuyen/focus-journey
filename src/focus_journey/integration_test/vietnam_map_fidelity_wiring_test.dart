// Integration tests for vietnam-map-fidelity (ADR-0008): the bundled, OFFLINE
// Vietnam base map drawn UNDER the shipped overlays on both surfaces.
//
// ADR-0008(c) DROPPED the OSM `TileLayer` (network egress → zero). The base is a
// bundled [BaseMapGeometry] rendered as a PolygonLayer, so these legs are offline
// by construction: no tile provider, no asset load, no network — a real fetch is
// structurally impossible. The MapCubit/RouteProgressCubit project a real
// MapViewState (no engine, no timers) so the overlay geometry is production-true.
//
// Proves what the widget-only layer cannot at the full render pipeline:
//   - AC-1/AC-2 / TC-801, TC-803: the base renders on the FULL map AND the
//     ~150px minimap with no network — never blank, never a TileLayer.
//   - AC-11 / TC-819: the shipped route polyline, checkpoint markers, and the
//     current-position marker are STRUCTURALLY IDENTICAL with vs without the
//     base beneath — the base is purely additive.
//   - AC-7 / TC-812: the current-position marker advances along the route (its
//     projected point moves northward) as routeDistanceKm increases, with the
//     base beneath (the landmass point-in-polygon math is the domain suite's).
//   - AC-9 / TC-815: the CC BY-SA credit is present full-screen.
//   - AC-10 / TC-816: no OSM TileLayer / no OSM URL on either surface.
//
// Runs under `flutter test` (headless) and on a desktop device:
//   fvm flutter test integration_test/vietnam_map_fidelity_wiring_test.dart
//   fvm flutter test integration_test/vietnam_map_fidelity_wiring_test.dart -d macos

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/activity_segment.dart';
import 'package:focus_journey/features/journey/domain/journey_progress.dart';
import 'package:focus_journey/features/journey/domain/journey_state.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/route/domain/base_map_geometry.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_plan.dart';
import 'package:focus_journey/features/route/domain/route_repository.dart';
import 'package:focus_journey/features/route/domain/route_selection.dart';
import 'package:focus_journey/features/route/presentation/base_map_layer.dart';
import 'package:focus_journey/features/route/presentation/map_cubit.dart';
import 'package:focus_journey/features/route/presentation/map_view.dart';
import 'package:focus_journey/features/route/presentation/map_view_state.dart';
import 'package:focus_journey/features/route/presentation/route_progress_cubit.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';

ProvinceChain _fixtureChain() => ProvinceChain(
  nodes: const <Province>[
    Province(id: 'mui', name: 'Mũi Cà Mau'),
    Province(id: 'can_tho', name: 'Cần Thơ'),
    Province(id: 'da_lat', name: 'Đà Lạt'),
    Province(id: 'da_nang', name: 'Đà Nẵng'),
    Province(id: 'ha_noi', name: 'Hà Nội'),
    Province(id: 'ha_giang', name: 'Hà Giang'),
  ],
  segmentsKm: const <double>[60, 170, 300, 310, 600],
);

ProvinceGeography _fixtureGeography(ProvinceChain chain) => ProvinceGeography(
  chain: chain,
  coordinates: const <String, GeoCoordinate>{
    'mui': GeoCoordinate(latitude: 8.62, longitude: 104.72),
    'can_tho': GeoCoordinate(latitude: 10.04, longitude: 105.78),
    'da_lat': GeoCoordinate(latitude: 11.94, longitude: 108.44),
    'da_nang': GeoCoordinate(latitude: 16.05, longitude: 108.20),
    'ha_noi': GeoCoordinate(latitude: 21.03, longitude: 105.85),
    'ha_giang': GeoCoordinate(latitude: 22.82, longitude: 104.98),
  },
);

/// The bundled offline base geometry (ADR-0008): a land ring generously
/// enclosing the fixture chain + a province-outline ring. No asset, no network.
BaseMapGeometry _baseMap() => BaseMapGeometry(
  landRings: const <List<GeoCoordinate>>[
    <GeoCoordinate>[
      GeoCoordinate(latitude: 8.0, longitude: 103.0),
      GeoCoordinate(latitude: 8.0, longitude: 109.8),
      GeoCoordinate(latitude: 23.5, longitude: 109.8),
      GeoCoordinate(latitude: 23.5, longitude: 103.0),
      GeoCoordinate(latitude: 8.0, longitude: 103.0),
    ],
  ],
  provinceRings: const <List<GeoCoordinate>>[
    <GeoCoordinate>[
      GeoCoordinate(latitude: 15.0, longitude: 107.0),
      GeoCoordinate(latitude: 15.0, longitude: 109.0),
      GeoCoordinate(latitude: 17.0, longitude: 109.0),
      GeoCoordinate(latitude: 17.0, longitude: 107.0),
      GeoCoordinate(latitude: 15.0, longitude: 107.0),
    ],
  ],
);

Province _node(ProvinceChain chain, String id) =>
    chain.nodes.firstWhere((p) => p.id == id);

ActivitySegment _idle(
  double fromKm,
  double toKm, {
  SegmentCause cause = SegmentCause.voluntary,
}) => ActivitySegment(
  fromKm: fromKm,
  toKm: toKm,
  elapsed: const Duration(minutes: 10),
  classification: SegmentClassification.idle,
  cause: cause,
);

JourneyProgress _progress(List<ActivitySegment> segments, double distanceKm) =>
    JourneyProgress(
      distanceKm: distanceKm,
      activeTimeToday: Duration.zero,
      rawActiveTime: Duration.zero,
      idleTimeToday: Duration.zero,
      state: JourneyState.active,
      mode: TravelMode.motorbike,
      storedDate: DateTime(2026, 6, 24),
      segments: segments,
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ProvinceChain chain;
  late ProvinceGeography geography;

  setUp(() {
    chain = _fixtureChain();
    geography = _fixtureGeography(chain);
  });

  /// Builds a production MapViewState for `Cần Thơ → Hà Giang` at [distanceKm]
  /// with [segments], via the real MapCubit projection path.
  MapViewState stateFor(
    double distanceKm, {
    List<ActivitySegment> segments = const <ActivitySegment>[],
  }) {
    final route = RouteProgressCubit(chain: chain, repository: _NullRepo());
    addTearDown(route.close);
    route.startNewRoute(_node(chain, 'can_tho'), JourneyDirection.towardHaGiang);
    route.updateFromDistance(distanceKm);
    final map = MapCubit(geography: geography);
    addTearDown(map.close);
    map.updateFromRoute(route.state);
    map.updateFromSnapshot(_progress(segments, distanceKm));
    return map.state;
  }

  Future<void> pump(
    WidgetTester tester,
    MapViewState state, {
    BaseMapGeometry? baseMap,
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
            child: MapView(state: state, baseMap: baseMap, compact: compact),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  bool baseMapPresent(WidgetTester tester) {
    final layers = tester.widgetList<PolygonLayer<Object>>(
      find.byType(PolygonLayer<Object>),
    );
    return layers.any((l) => l.polygons.any((p) => p.color == kLandFill));
  }

  List<LatLng> baseRoadPoints(WidgetTester tester) {
    final layers = tester.widgetList<PolylineLayer<Object>>(
      find.byType(PolylineLayer<Object>),
    );
    for (final layer in layers) {
      for (final line in layer.polylines) {
        if (line.color == kBaseRoadColor) {
          return line.points;
        }
      }
    }
    return const <LatLng>[];
  }

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

  int markerCount(WidgetTester tester) =>
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length;

  group('AC-1/AC-2 / TC-801, TC-803 offline base on both surfaces', () {
    testWidgets('full map renders the bundled base — no network, no TileLayer', (
      tester,
    ) async {
      await pump(tester, stateFor(500), baseMap: _baseMap());

      expect(baseMapPresent(tester), isTrue);
      expect(find.byType(TileLayer), findsNothing);
      // Assertion updated for route-real-road: the bundled QL1A national road is
      // OSM data under ODbL, so NFR-4 now MANDATES the ODbL road attribution be
      // shown on the full map (the kRoadAttribution line of the _BaseMapAttribution
      // pill). This supersedes vietnam-map-fidelity's original "no OSM credit"
      // expectation. This is a static text credit, not a tile fetch — the
      // no-TileLayer / no-network privacy invariant above still holds.
      expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('~150px minimap renders the same base offline', (tester) async {
      await pump(
        tester,
        stateFor(500),
        baseMap: _baseMap(),
        compact: true,
        width: 150,
        height: 190,
      );

      expect(baseMapPresent(tester), isTrue);
      expect(find.byType(TileLayer), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('AC-11 / TC-819 base is purely additive under the overlays', () {
    testWidgets(
      'route polyline + markers are structurally identical with vs without base',
      (tester) async {
        final segments = <ActivitySegment>[
          _idle(100, 200, cause: SegmentCause.voluntary),
          _idle(400, 500, cause: SegmentCause.lockSleep),
        ];
        final state = stateFor(500, segments: segments);

        // Without the base.
        await pump(tester, state);
        expect(baseMapPresent(tester), isFalse);
        final roadNoBase = baseRoadPoints(tester);
        final markerNoBase = currentMarker(tester);
        final countNoBase = markerCount(tester);

        // With the base beneath.
        await pump(tester, state, baseMap: _baseMap());
        expect(baseMapPresent(tester), isTrue);
        final roadWithBase = baseRoadPoints(tester);
        final markerWithBase = currentMarker(tester);
        final countWithBase = markerCount(tester);

        // The base adds only what is BELOW the overlays — they are unchanged.
        expect(roadWithBase, roadNoBase);
        expect(markerWithBase, markerNoBase);
        expect(countWithBase, countNoBase);
      },
    );

    testWidgets(
      'the base is the FIRST FlutterMap child (z-order: beneath the overlays)',
      (tester) async {
        await pump(tester, stateFor(500), baseMap: _baseMap());

        final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
        final first = map.children.first;
        expect(first, isA<Semantics>());
        expect((first as Semantics).child, isA<PolygonLayer<Object>>());
      },
    );
  });

  group('AC-7 / TC-812 current-position marker advances along the route', () {
    testWidgets(
      'the projected marker moves northward (lower latitude → higher) as '
      'distance increases, with the base beneath',
      (tester) async {
        // start → mid → near-completion (Cần Thơ→Hà Giang route length 1380 km).
        await pump(tester, stateFor(0), baseMap: _baseMap());
        final atStart = currentMarker(tester);

        await pump(tester, stateFor(600), baseMap: _baseMap());
        final atMid = currentMarker(tester);

        await pump(tester, stateFor(1300), baseMap: _baseMap());
        final atNear = currentMarker(tester);

        expect(atStart, isNotNull);
        expect(atMid, isNotNull);
        expect(atNear, isNotNull);
        // The route runs south→north, so latitude increases as distance grows.
        expect(atMid!.latitude, greaterThan(atStart!.latitude));
        expect(atNear!.latitude, greaterThan(atMid.latitude));
      },
    );
  });

  group('AC-9 / TC-815 + AC-10 / TC-816 attribution + no OSM', () {
    testWidgets('full-screen shows the CC BY-SA credit; no OSM tile/URL', (
      tester,
    ) async {
      await pump(tester, stateFor(500), baseMap: _baseMap());

      expect(find.text(kBaseMapAttribution), findsOneWidget);
      expect(find.textContaining('CC BY-SA'), findsOneWidget);
      expect(find.byType(TileLayer), findsNothing);
      // Assertion updated for route-real-road: the bundled QL1A national road is
      // OSM data under ODbL, so NFR-4 now MANDATES the ODbL road attribution be
      // shown on the full map (the kRoadAttribution line of the _BaseMapAttribution
      // pill). This supersedes vietnam-map-fidelity's original "no OSM credit"
      // expectation. This is a static text credit, not a tile fetch — the
      // no-TileLayer / no-network privacy invariant above still holds.
      expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);
    });
  });
}

/// An in-memory route repository (the projection path needs a repo but these
/// legs never exercise persistence).
class _NullRepo implements RouteRepository {
  RouteSelection? _stored;
  RoutePlan? _storedPlan;

  @override
  Future<RouteSelection?> load() async => _stored;

  @override
  Future<void> save(RouteSelection selection) async => _stored = selection;

  @override
  Future<RoutePlan?> loadPlan({double currentCumulativeKm = 0}) async => _storedPlan;

  @override
  Future<void> savePlan(RoutePlan plan) async => _storedPlan = plan;
}
