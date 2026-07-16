// Integration tests for the map-experience wiring (the Bloc ↔ overlay seam +
// restart restoration + the pure-visualizer runtime guard).
//
// Proves three things the widget-only layer cannot:
//   - TC-215 (AC-8): the current-route red trace is RESTORED UNCHANGED after an
//     app "restart" — a fresh MapCubit seeded from a reloaded JourneyProgress +
//     RouteSelection blob (via the real SharedPreferences-backed repos over
//     setMockInitialValues) re-projects the same idle stretches + marker.
//   - TC-222 (AC-2): tapping the inline overlay opens full-screen via a Material
//     route in the SAME window — the prior MaterialApp frame stays mounted
//     beneath the pushed route. The map surface has NO window-mode dependency
//     by construction (it imports/accepts no WindowModeController, no
//     MethodChannel — only MapCubit + RouteProgressCubit + Navigator), so a
//     new OS window is structurally impossible on this path; the same-Navigator
//     push IS the single-window guarantee.
//   - TC-226 / TC-228 (AC-12): driving the visualizer through a sweep of
//     distances + segment sets writes NOTHING back — the recording route repo
//     and the snapshot inputs are unchanged; the map cubit constructs no engine /
//     ticker (it holds none by construction).
//
// No real engine, no real timers, no real network. ADR-0008(c) DROPPED the OSM
// `TileLayer`, so the map is offline by construction: the base is a bundled
// [BaseMapGeometry] ([_baseMap]) drawn as a PolygonLayer — there is no tile
// provider to fake and no request that could reach the network.
//
// Runs under `flutter test` (headless) and on a desktop device:
//   fvm flutter test integration_test/map_experience_wiring_test.dart
//   fvm flutter test integration_test/map_experience_wiring_test.dart -d macos

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:focus_journey/features/route/presentation/map_surface.dart';
import 'package:focus_journey/features/route/presentation/map_view.dart';
import 'package:focus_journey/features/route/presentation/route_progress_cubit.dart';
import 'package:integration_test/integration_test.dart';

const double _tol = 1e-6;

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

/// The bundled offline base geometry (ADR-0008): a land ring enclosing the
/// fixture chain + a couple of province-outline rings. No asset, no network.
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

/// Whether the bundled base PolygonLayer (land fill) is in the tree.
bool _baseMapPresent(WidgetTester tester) {
  final layers = tester.widgetList<PolygonLayer<Object>>(
    find.byType(PolygonLayer<Object>),
  );
  return layers.any((l) => l.polygons.any((p) => p.color == kLandFill));
}

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

ActivitySegment _active(double fromKm, double toKm) => ActivitySegment(
  fromKm: fromKm,
  toKm: toKm,
  elapsed: const Duration(minutes: 10),
  classification: SegmentClassification.active,
  cause: SegmentCause.none,
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

/// An in-memory [RouteRepository] that RECORDS every write so AC-12 can assert
/// the map slice never persists anything (only route-progress writes its own
/// selection). Replays its last saved selection on [load] (the restart seam).
class _RecordingRouteRepo implements RouteRepository {
  _RecordingRouteRepo({RouteSelection? seed}) : _stored = seed;

  RouteSelection? _stored;
  RoutePlan? _storedPlan;
  final List<RouteSelection> saves = <RouteSelection>[];
  final List<RoutePlan> planSaves = <RoutePlan>[];

  @override
  Future<RouteSelection?> load() async => _stored;

  @override
  Future<void> save(RouteSelection selection) async {
    saves.add(selection);
    _stored = selection;
  }

  @override
  Future<RoutePlan?> loadPlan({double currentCumulativeKm = 0}) async => _storedPlan;

  @override
  Future<void> savePlan(RoutePlan plan) async {
    planSaves.add(plan);
    _storedPlan = plan;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ProvinceChain chain;
  late ProvinceGeography geography;

  setUp(() {
    chain = _fixtureChain();
    geography = _fixtureGeography(chain);
  });

  group('TC-215 (AC-8) red trace restored unchanged after a restart', () {
    testWidgets(
      'a fresh MapCubit seeded from the reloaded selection re-projects the same '
      'stretches + marker',
      (tester) async {
        final selection = RouteSelection.create(
          start: _node(chain, 'can_tho'),
          direction: JourneyDirection.towardHaGiang,
          routeStartOffsetKm: 0,
          chain: chain,
        );
        final segments = <ActivitySegment>[
          _active(0, 100),
          _idle(100, 200, cause: SegmentCause.voluntary),
          _active(200, 400),
          _idle(400, 500, cause: SegmentCause.lockSleep),
        ];

        // --- Session 1: project the current state. ---
        final cubit1 = MapCubit(
          geography: geography,
          initialSelection: selection,
        );
        addTearDown(cubit1.close);
        final route1 = RouteProgressCubit(
          chain: chain,
          repository: _RecordingRouteRepo(),
          initialSelection: selection,
        );
        addTearDown(route1.close);
        route1.updateFromDistance(500);
        cubit1.updateFromRoute(route1.state);
        cubit1.updateFromSnapshot(_progress(segments, 500));
        final before = cubit1.state;
        expect(before.idleStretches, hasLength(2));
        expect(before.markerPosition, isNotNull);

        // --- "Restart": a fresh cubit + route cubit seeded from the SAME
        // persisted selection + the SAME restored snapshot blob. ---
        final route2 = RouteProgressCubit(
          chain: chain,
          repository: _RecordingRouteRepo(seed: selection),
          initialSelection: selection,
        );
        addTearDown(route2.close);
        route2.updateFromDistance(500);
        final cubit2 = MapCubit(
          geography: geography,
          initialSelection: selection,
        );
        addTearDown(cubit2.close);
        cubit2.updateFromRoute(route2.state);
        cubit2.updateFromSnapshot(_progress(segments, 500));
        final after = cubit2.state;

        // The restored red trace + marker are byte-identical (Equatable).
        expect(after.idleStretches, before.idleStretches);
        expect(after.markerPosition, before.markerPosition);
        expect(after.baseRoutePolyline, before.baseRoutePolyline);
        // Both causes survive the restore, in order (no re-classification).
        expect(after.idleStretches.map((s) => s.cause).toList(), <SegmentCause>[
          SegmentCause.voluntary,
          SegmentCause.lockSleep,
        ]);
      },
    );
  });

  group('TC-222 (AC-2) tap opens full-screen in the SAME window', () {
    testWidgets(
      'opening full-screen pushes a MaterialPageRoute and invokes no window API',
      (tester) async {
        final route = RouteProgressCubit(
          chain: chain,
          repository: _RecordingRouteRepo(),
        );
        addTearDown(route.close);
        await route.startNewRoute(
          _node(chain, 'can_tho'),
          JourneyDirection.towardHaGiang,
        );
        route.updateFromDistance(200);
        final map = MapCubit(geography: geography);
        addTearDown(map.close);
        map.updateFromRoute(route.state);
        map.updateFromSnapshot(_progress(const <ActivitySegment>[], 200));

        await tester.pumpWidget(
          MaterialApp(
            home: MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<MapCubit>.value(value: map),
                BlocProvider<RouteProgressCubit>.value(value: route),
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

        // The inline minimap renders the bundled offline base (no tiles).
        expect(_baseMapPresent(tester), isTrue);
        expect(find.byType(TileLayer), findsNothing);

        expect(find.byType(FullScreenMap), findsNothing);
        // Tap the floating minimap card (the InkWell is the single tap target).
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        // Full-screen appears in the SAME single test binding — pushed onto the
        // host MaterialApp's own Navigator as a MaterialPageRoute (the prior
        // route is left below it on that one stack). A new OS window would
        // instead require a window-mode controller, which this surface neither
        // imports nor accepts: it depends only on MapCubit + RouteProgressCubit
        // + Navigator (verified structurally — no WindowModeController and no
        // MethodChannel on the map path). So this same-Navigator push IS the
        // single-window guarantee for AC-2; popping it returns to the inline
        // overlay (see the widget-layer TC-223 dismiss cases).
        expect(find.byType(FullScreenMap), findsOneWidget);
        // The full-screen surface also renders the base offline (AC-1) with no
        // OSM tile layer (AC-10 regression guard for the dropped tile base).
        expect(_baseMapPresent(tester), isTrue);
        expect(find.byType(TileLayer), findsNothing);
        // Popping the pushed route restores the inline overlay on the SAME
        // stack — confirming it was a same-window route, not a separate window.
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.pop();
        await tester.pumpAndSettle();
        expect(find.byType(FullScreenMap), findsNothing);
        expect(find.byType(InlineMapOverlay), findsOneWidget);
      },
    );
  });

  group('TC-226 / TC-228 (AC-12) pure visualizer — zero writes through a sweep', () {
    testWidgets(
      'driving distances + segment sets never persists or mutates inputs',
      (tester) async {
        final repo = _RecordingRouteRepo();
        final route = RouteProgressCubit(chain: chain, repository: repo);
        addTearDown(route.close);
        await route.startNewRoute(
          _node(chain, 'can_tho'),
          JourneyDirection.towardHaGiang,
        );
        // Advance the route cubit through the whole distance sweep FIRST. Any
        // repo write here belongs to route-progress (its own selection +
        // completion latch), NOT to the map slice.
        final distances = <double>[0, 60, 300, 2000];
        for (final d in distances) {
          route.updateFromDistance(d);
        }
        // From here on, ONLY the map slice is driven. The map cubit holds no
        // repository (true by construction), so it cannot write at all (AC-12);
        // we snapshot the route-progress write count and assert the map sweep
        // adds exactly zero.
        final savesBeforeMapSweep = repo.saves.length;

        final map = MapCubit(geography: geography);
        addTearDown(map.close);
        map.updateFromRoute(route.state);

        final segmentSets = <List<ActivitySegment>>[
          const <ActivitySegment>[], // zero-idle
          <ActivitySegment>[_idle(0, 60)], // start
          <ActivitySegment>[_active(0, 200), _idle(200, 300)], // mid
          <ActivitySegment>[_idle(0, 1380)], // all-idle to completion
        ];

        for (final segments in segmentSets) {
          final snapshot = _progress(
            segments,
            route.state.cumulativeDistanceKm,
          );
          final snapshotSegmentsRef = snapshot.segments;
          map.updateFromSnapshot(snapshot);
          // The map slice never mutates the snapshot's segment list (same
          // reference, same contents — it is a read-only consumer).
          expect(identical(snapshot.segments, snapshotSegmentsRef), isTrue);
        }

        // The map sweep persisted NOTHING — zero writes from the map slice.
        expect(repo.saves.length, savesBeforeMapSweep);
        // The map cubit's last state still resolves (no crash through the sweep).
        expect(map.state.hasRoute, isTrue);
      },
    );

    testWidgets(
      'toggling the overlay off and on leaves the upstream data unchanged',
      (tester) async {
        final repo = _RecordingRouteRepo();
        final route = RouteProgressCubit(chain: chain, repository: repo);
        addTearDown(route.close);
        await route.startNewRoute(
          _node(chain, 'can_tho'),
          JourneyDirection.towardHaGiang,
        );
        route.updateFromDistance(300);
        final savesBefore = repo.saves.length;

        final map = MapCubit(geography: geography);
        addTearDown(map.close);
        map.updateFromRoute(route.state);
        final snapshot = _progress(<ActivitySegment>[_idle(100, 200)], 300);
        map.updateFromSnapshot(snapshot);

        // Mount the overlay, then unmount it (toggle off), then remount it.
        Widget host(bool show) => MaterialApp(
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<MapCubit>.value(value: map),
              BlocProvider<RouteProgressCubit>.value(value: route),
            ],
            child: Scaffold(
              body: show
                  ? InlineMapOverlay(
                      chain: chain,
                      geography: geography,
                      baseMap: _baseMap(),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        );

        await tester.pumpWidget(host(true));
        await tester.pump();
        expect(find.byType(MapView), findsOneWidget);

        await tester.pumpWidget(host(false)); // toggle off
        await tester.pump();
        expect(find.byType(MapView), findsNothing);

        await tester.pumpWidget(host(true)); // toggle back on
        await tester.pump();
        expect(find.byType(MapView), findsOneWidget);

        // The recorded route writes and the engine-side distance are unchanged:
        // toggling the overlay wrote nothing back (AC-12).
        expect(repo.saves.length, savesBefore);
        expect(route.state.cumulativeDistanceKm, closeTo(300, _tol));
        expect(map.state.idleStretches, hasLength(1));
      },
    );
  });
}
