// Full-wiring smoke for route-progress (the end-to-end consume path).
//
// Proves: ActivityTicker.tickOnce() — driven by a deterministic
// MockActivitySource + a scripted clock (NO real OS, NO real timers) — advances
// the engine's cumulative distanceKm and flows that single scalar through the
// ticker's onDistance sink into the RouteProgressCubit, which updates the route
// position; that route state then projects into the MapCubit (mirroring
// main.dart's `_routeCubit.stream.listen(_onRouteChanged)` →
// `_mapCubit.updateFromRoute`). The route cubit holds NO engine reference, so
// the engine is read, never mutated by route-progress (AC-16 / AC-17 reinforced
// at runtime).
//
// This is the integration counterpart to main.dart's wiring
// (`onDistance: routeCubit.updateFromDistance`). It does NOT re-test the engine's
// accrual (that is journey-engine's suite) — it asserts the seam delivers the
// scalar and the cubit consumes it. The standalone Map tab (RouteMapScreen) was
// removed in the map-experience slice; the surface under test is now the
// re-homed `InlineMapOverlay`. Per ADR-0008(c) the OSM `TileLayer` was DROPPED,
// so the surface is offline by construction (a bundled base [BaseMapGeometry]) —
// the smoke makes ZERO network requests with no tile provider to fake.
//
// Runs under `flutter test` (headless) and on a desktop device:
//   fvm flutter test integration_test/route_wiring_smoke_test.dart
//   fvm flutter test integration_test/route_wiring_smoke_test.dart -d macos

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/mock_activity_source.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/journey_engine.dart';
import 'package:focus_journey/features/journey/presentation/activity_ticker.dart';
import 'package:focus_journey/features/journey/presentation/journey_cubit.dart';
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
import 'package:focus_journey/features/route/presentation/map_surface.dart';
import 'package:focus_journey/features/route/presentation/route_progress_cubit.dart';
import 'package:integration_test/integration_test.dart';

const double _tol = 1e-6;

/// A scripted clock the test advances explicitly so each tick credits a real,
/// positive delta — no wall-clock waits.
class AdvanceableClock implements Clock {
  AdvanceableClock(this._now);
  DateTime _now;
  void advance(Duration d) => _now = _now.add(d);
  @override
  DateTime now() => _now;
}

/// The route-progress worked-example fixture chain (segments [60,170,300,310,600],
/// total 1440 km), used to wire the route + map cubits for the smoke.
ProvinceChain _fixture() => ProvinceChain(
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

/// Per-province lat/long so the MapCubit can project the polyline. Mirrors the
/// shared map fixtures — all inside the production bbox.
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

/// The bundled offline base geometry (ADR-0008): a land ring enclosing the
/// fixture chain. No asset, no network — the surface renders it directly.
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
  provinceRings: const <List<GeoCoordinate>>[],
);

/// An in-memory [RouteRepository] that records writes — proves route-progress
/// only ever persists its own selection, never resets engine state.
class InMemoryRouteRepo implements RouteRepository {
  RouteSelection? _stored;
  RoutePlan? _storedPlan;
  int saveCount = 0;

  @override
  Future<RouteSelection?> load() async => _stored;

  @override
  Future<void> save(RouteSelection selection) async {
    saveCount++;
    _stored = selection;
  }

  @override
  Future<RoutePlan?> loadPlan({double currentCumulativeKm = 0}) async => _storedPlan;

  @override
  Future<void> savePlan(RoutePlan plan) async {
    saveCount++;
    _storedPlan = plan;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TC-wiring: ticker.tickOnce flows distanceKm → route cubit → map state',
    (tester) async {
      final chain = _fixture();
      final geography = _fixtureGeography(chain);
      final clock = AdvanceableClock(DateTime(2026, 6, 23, 12));
      final mock = MockActivitySource(idleSeconds: 0, screenLocked: false);
      // 60 km/active-hour so 1 active hour ⇒ exactly 60 km (a clean position).
      final engine = JourneyEngine(
        clock: clock,
        activityPlugin: mock,
        kmPerActiveHour: 60,
        maxTickDelta: const Duration(hours: 6),
      );
      final journeyCubit = JourneyCubit();
      addTearDown(journeyCubit.close);

      final repo = InMemoryRouteRepo();
      final routeCubit = RouteProgressCubit(chain: chain, repository: repo);
      addTearDown(routeCubit.close);

      // The map cubit projects the route state, exactly as main.dart wires it
      // (`_routeCubit.stream.listen(_onRouteChanged)` → `updateFromRoute`).
      final mapCubit = MapCubit(geography: geography);
      addTearDown(mapCubit.close);
      final sub = routeCubit.stream.listen(mapCubit.updateFromRoute);
      addTearDown(sub.cancel);

      // The seam under test: ticker forwards only a double to the route cubit.
      final ticker = ActivityTicker(
        engine: engine,
        clock: clock,
        cubit: journeyCubit,
        onDistance: routeCubit.updateFromDistance,
      );

      // The surface under test is now the re-homed inline overlay (the standalone
      // RouteMapScreen was removed); a fake tile provider keeps it offline.
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<RouteProgressCubit>.value(value: routeCubit),
              BlocProvider<MapCubit>.value(value: mapCubit),
            ],
            child: Scaffold(
              body: InlineMapOverlay(
                chain: chain,
                geography: geography,
                baseMap: _baseMap(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Pick a route up front (Cần Thơ north) so the map renders the position.
      await routeCubit.startNewRoute(
        chain.nodes.firstWhere((p) => p.id == 'can_tho'),
        JourneyDirection.towardHaGiang,
      );
      await tester.pump();
      await tester.pump();

      // Prime lastTick (delta 0 — no accrual), then advance + tick.
      await tester.runAsync(ticker.tickOnce);
      final cumulativeBefore = engine.distanceKm;

      // Advance 1 active hour ⇒ engine accrues 60 km; the scalar flows through.
      clock.advance(const Duration(hours: 1));
      await tester.runAsync(ticker.tickOnce);
      await tester.pump();
      await tester.pump();

      // The engine advanced (journey-engine's job) ...
      expect(engine.distanceKm, greaterThan(cumulativeBefore));
      expect(engine.distanceKm, closeTo(60, _tol));
      // ... and the route cubit consumed exactly that scalar via onDistance.
      expect(routeCubit.state.cumulativeDistanceKm, closeTo(60, _tol));
      // routeDistanceKm == cumulative − offset (offset captured at startNewRoute,
      // which was 0 since no distance was seen before it) ⇒ 60 along the route.
      final position = routeCubit.state.position!;
      expect(position.routeDistanceKm, closeTo(60, _tol));

      // The consumed distance resolves the position: 60 km past Cần Thơ lands
      // before Đà Lạt (170 km away) ⇒ next is Đà Lạt, 110 km out. (This is the
      // same fact the deleted screen's "Next: Đà Lạt in 110 km" readout showed —
      // now asserted on the projected route position the surface renders.)
      expect(position.next!.name, 'Đà Lạt');
      expect(position.distanceToNextKm, closeTo(110, _tol));

      // ... and that scalar projected into the MAP cubit (the wiring seam under
      // test): the map state carries the same resolved position + a marker.
      expect(mapCubit.state.hasRoute, isTrue);
      expect(mapCubit.state.position!.routeDistanceKm, closeTo(60, _tol));
      expect(mapCubit.state.position!.next!.name, 'Đà Lạt');
      expect(mapCubit.state.markerPosition, isNotNull);

      // The re-homed map surface rendered (proving the consume path reaches UI)
      // over the bundled OFFLINE base (a PolygonLayer with the land fill) and
      // with NO OSM tile layer (ADR-0008(c) drop — offline by construction).
      expect(find.byType(InlineMapOverlay), findsOneWidget);
      final baseLayers = tester.widgetList<PolygonLayer<Object>>(
        find.byType(PolygonLayer<Object>),
      );
      expect(
        baseLayers.any((l) => l.polygons.any((p) => p.color == kLandFill)),
        isTrue,
      );
      expect(find.byType(TileLayer), findsNothing);

      // Route-progress never mutated the engine: feeding more distance does not
      // change engine.activeTimeToday and the repo saw only the start write.
      expect(engine.activeTimeToday, const Duration(hours: 1));
      expect(repo.saveCount, 1); // only the startNewRoute selection write.
    },
  );
}
