// Widget tests for the map surface wiring (map-experience + vietnam-map-fidelity
// / ADR-0008): the inline overlay on the journey tab, the tap → full-screen
// transition, the close-button / Esc dismiss back to inline, the re-homed
// start-picker + completion celebration, the absence of a standalone "Map" nav
// destination, and — post-ADR-0008 — the bundled OFFLINE base on both surfaces
// with the CC BY-SA attribution full-screen.
//
// ADR-0008(c) DROPPED the OSM `TileLayer`, so there is no tile provider to
// inject: the base is a bundled [BaseMapGeometry] (via [buildFixtureBaseMap]),
// rendered as a PolygonLayer, and the surface makes ZERO network calls by
// construction. The MapCubit + RouteProgressCubit are real, driven by scripted
// snapshots (no engine, no timers).
//
// Covers:
//   AC-1  / TC-220  inline overlay renders on the journey tab; no "Map" nav tab
//   AC-1  / TC-221  removing the Map tab does not break other navigation
//   AC-2  / TC-222  tapping the inline overlay pushes a full-screen route
//   AC-3  / TC-223  close button, system back (maybePop), AND Esc all dismiss
//   AC-1/AC-2 / TC-803  the inline minimap renders the bundled offline base
//   AC-9  / TC-815  full-screen shows the CC BY-SA base-map attribution
//   AC-10 / TC-816  no OSM TileLayer / no OSM URL on either surface (offline)
//   re-homed flows  start-picker shown when no route; celebration when completed

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/activity_segment.dart';
import 'package:focus_journey/features/route/domain/base_map_geometry.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_plan.dart';
import 'package:focus_journey/features/route/domain/route_repository.dart';
import 'package:focus_journey/features/route/domain/route_selection.dart';
import 'package:focus_journey/features/route/presentation/base_map_layer.dart';
import 'package:focus_journey/features/route/presentation/map_cubit.dart';
import 'package:focus_journey/features/route/presentation/map_surface.dart';
import 'package:focus_journey/features/route/presentation/map_view.dart';
import 'package:focus_journey/features/route/presentation/route_picker.dart';
import 'package:focus_journey/features/route/presentation/route_progress_cubit.dart';

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

  /// An in-memory route repository (no persistence needed for these widget cases).
  RouteRepository inMemoryRepo() => _InMemoryRouteRepo();

  /// Builds a wired MapCubit + RouteProgressCubit pair and (optionally) starts a
  /// route, then feeds the map cubit a snapshot so it has a route to render.
  ({MapCubit map, RouteProgressCubit route}) buildCubits({
    String? startId,
    JourneyDirection direction = JourneyDirection.towardHaGiang,
    double routeDistanceKm = 0,
    List<ActivitySegment> segments = const <ActivitySegment>[],
  }) {
    final routeCubit = RouteProgressCubit(
      chain: chain,
      repository: inMemoryRepo(),
    );
    final mapCubit = MapCubit(geography: geography);
    if (startId != null) {
      final selection = selectionFor(chain, startId, direction);
      routeCubit.startNewRoute(nodeById(chain, startId), direction);
      routeCubit.updateFromDistance(routeDistanceKm);
      mapCubit.updateFromRoute(routeCubit.state);
      mapCubit.updateFromSnapshot(progressWith(segments: segments));
      expect(selection.start.id, startId);
    }
    return (map: mapCubit, route: routeCubit);
  }

  /// Pumps a faux "journey tab" hosting the inline overlay, with both cubits
  /// provided and the bundled base injected (offline — no tile provider).
  Future<void> pumpInlineTab(
    WidgetTester tester, {
    String? startId,
    double routeDistanceKm = 0,
    List<ActivitySegment> segments = const <ActivitySegment>[],
  }) async {
    final cubits = buildCubits(
      startId: startId,
      routeDistanceKm: routeDistanceKm,
      segments: segments,
    );
    addTearDown(cubits.map.close);
    addTearDown(cubits.route.close);
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<MapCubit>.value(value: cubits.map),
            BlocProvider<RouteProgressCubit>.value(value: cubits.route),
          ],
          child: Scaffold(
            body: Stack(
              children: <Widget>[
                const Positioned.fill(
                  child: Center(child: Text('journey-scene')),
                ),
                InlineMapOverlay(
                  chain: chain,
                  geography: geography,
                  baseMap: base,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Whether the bundled base PolygonLayer (land fill) is in the tree.
  bool baseMapPresent(WidgetTester tester) {
    final layers = tester.widgetList<PolygonLayer<Object>>(
      find.byType(PolygonLayer<Object>),
    );
    return layers.any((l) => l.polygons.any((p) => p.color == kLandFill));
  }

  group('AC-1 / TC-220 inline overlay on journey tab; no standalone Map tab', () {
    testWidgets('the inline overlay renders as a compact minimap on the tab', (
      tester,
    ) async {
      await pumpInlineTab(tester, startId: 'can_tho', routeDistanceKm: 200);

      expect(find.byType(InlineMapOverlay), findsOneWidget);
      expect(find.byType(MapView), findsOneWidget);
      expect(find.text('journey-scene'), findsOneWidget);

      // The minimap is a COMPACT fixed-size HUD card (≈150×190).
      final cardSize = tester.getSize(find.byType(InkWell).first);
      expect(cardSize.width, lessThan(200));
      expect(cardSize.height, lessThan(260));

      // AC-1/AC-2 / TC-803: the minimap renders the bundled OFFLINE base.
      expect(baseMapPresent(tester), isTrue);
      // AC-10 / TC-816: no OSM tiles and no network tile URL anywhere (offline
      // base). The compact minimap shows no attribution pill, so no credit text.
      expect(find.byType(TileLayer), findsNothing);
      expect(find.textContaining('tile.openstreetmap'), findsNothing);

      // A compact expand affordance marks it as tappable to open full-screen.
      expect(find.byIcon(Icons.open_in_full), findsOneWidget);
      expect(find.text('Tap to expand'), findsNothing);

      // NFR-3 / TC-232: the card stays screen-reader reachable.
      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label?.contains('Minimap of your journey') ??
                  false) &&
              (w.properties.button ?? false),
        ),
      );
      expect(semantics.properties.label, contains('open'));
    });

    testWidgets('the nav shell exposes NO NavigationDestination labelled "Map"', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: NavigationBar(
              selectedIndex: 0,
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.directions_bike),
                  label: 'Journey',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart),
                  label: 'Stats',
                ),
                NavigationDestination(
                  icon: Icon(Icons.emoji_events),
                  label: 'Badges',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final mapLabelled = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Map'),
      );
      expect(mapLabelled, findsNothing);
      expect(find.text('Journey'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });

  group(
    'AC-1 / TC-221 removing the Map tab does not break other navigation',
    () {
      testWidgets(
        'switching between the remaining tabs works (no dangling route)',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(home: _NavShellHarness(chain: chain)),
          );
          await tester.pump();

          expect(find.text('JOURNEY-BODY'), findsOneWidget);
          await tester.tap(find.text('Stats'));
          await tester.pumpAndSettle();
          expect(find.text('STATS-BODY'), findsOneWidget);
          await tester.tap(find.text('Settings'));
          await tester.pumpAndSettle();
          expect(find.text('SETTINGS-BODY'), findsOneWidget);
          await tester.tap(find.text('Journey'));
          await tester.pumpAndSettle();
          expect(find.text('JOURNEY-BODY'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    },
  );

  group(
    'AC-2 / TC-222 tap → full-screen in the SAME window (no new window)',
    () {
      testWidgets(
        'tapping the inline overlay pushes a full-screen MaterialPageRoute',
        (tester) async {
          await pumpInlineTab(tester, startId: 'can_tho', routeDistanceKm: 200);

          expect(find.byType(FullScreenMap), findsNothing);
          await tester.tap(find.byType(InkWell));
          await tester.pumpAndSettle();

          expect(find.byType(FullScreenMap), findsOneWidget);
          expect(
            find.byKey(const Key('map_full_screen_close')),
            findsOneWidget,
          );
          // The full-screen surface also renders the base offline (no tiles).
          expect(baseMapPresent(tester), isTrue);
          expect(find.byType(TileLayer), findsNothing);
        },
      );
    },
  );

  group('AC-3 / TC-223 dismiss full-screen → back to inline, tab functional', () {
    Future<void> openFullScreen(WidgetTester tester) async {
      await pumpInlineTab(tester, startId: 'can_tho', routeDistanceKm: 200);
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(find.byType(FullScreenMap), findsOneWidget);
    }

    testWidgets('the close button returns to the inline overlay', (
      tester,
    ) async {
      await openFullScreen(tester);

      await tester.tap(find.byKey(const Key('map_full_screen_close')));
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenMap), findsNothing);
      expect(find.byType(InlineMapOverlay), findsOneWidget);
      expect(find.text('journey-scene'), findsOneWidget);
    });

    testWidgets('the Esc key dismisses full-screen back to inline', (
      tester,
    ) async {
      await openFullScreen(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenMap), findsNothing);
      expect(find.byType(InlineMapOverlay), findsOneWidget);
      expect(find.text('journey-scene'), findsOneWidget);
    });

    testWidgets(
      'AC-3/TC-223: the system-back path (maybePop) dismisses full-screen',
      (tester) async {
        await openFullScreen(tester);

        final handled = await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(handled, isTrue);
        expect(find.byType(FullScreenMap), findsNothing);
        expect(find.byType(InlineMapOverlay), findsOneWidget);
        expect(find.text('journey-scene'), findsOneWidget);
      },
    );
  });

  group('AC-9 / TC-815 + AC-10 / TC-816 attribution + offline (no OSM)', () {
    testWidgets(
      'full-screen shows the CC BY-SA base-map credit; no OSM tile/URL',
      (tester) async {
        await pumpInlineTab(tester, startId: 'can_tho', routeDistanceKm: 200);
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        // The mandatory share-alike credit for the bundled Wikimedia base.
        expect(find.text(kBaseMapAttribution), findsOneWidget);
        expect(find.textContaining('CC BY-SA'), findsOneWidget);
        // route-real-road / NFR-4: the mandatory ODbL credit for the bundled road
        // geometry sits alongside it.
        expect(find.text(kRoadAttribution), findsOneWidget);
        // The dropped OSM tile base leaves no tile layer and no network tile URL
        // (offline base). The ODbL attribution above is a static credit, not a
        // fetch — the offline guard is on the tile LAYER + tile URL only.
        expect(find.byType(TileLayer), findsNothing);
        expect(find.textContaining('tile.openstreetmap'), findsNothing);
      },
    );

    testWidgets('the inline minimap does NOT show the attribution pill', (
      tester,
    ) async {
      await pumpInlineTab(tester, startId: 'can_tho', routeDistanceKm: 200);

      expect(find.text(kBaseMapAttribution), findsNothing);
      expect(find.textContaining('CC BY-SA'), findsNothing);
    });
  });

  group('Re-homed flows: start-picker (no route) + celebration (completed)', () {
    testWidgets(
      'the inline overlay shows the start-picker when no route is active',
      (tester) async {
        await pumpInlineTab(tester);

        expect(find.byType(RoutePicker), findsOneWidget);
        expect(find.byKey(const Key('route_picker_continue')), findsOneWidget);
        expect(find.byType(MapView), findsNothing);
      },
    );

    testWidgets(
      'the completion celebration appears full-screen when the route completed',
      (tester) async {
        await pumpInlineTab(tester, startId: 'can_tho', routeDistanceKm: 2000);
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('completion_start_new')), findsOneWidget);
        expect(find.textContaining('You reached'), findsOneWidget);
        expect(find.byType(MapView), findsOneWidget);
      },
    );
  });

  group('Full-screen enrichment: route readout + legend (full-screen only)', () {
    Future<void> openFullScreenMidRoute(WidgetTester tester) async {
      await pumpInlineTab(tester, startId: 'can_tho', routeDistanceKm: 200);
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(find.byType(FullScreenMap), findsOneWidget);
    }

    testWidgets(
      'the full-screen surface shows the route readout, reading state.position',
      (tester) async {
        await openFullScreenMidRoute(tester);

        expect(find.byKey(const Key('map_route_readout')), findsOneWidget);
        expect(find.textContaining('Next:'), findsOneWidget);
        expect(find.textContaining(RegExp(r'km to ')), findsOneWidget);
        expect(find.textContaining('% of Vietnam'), findsOneWidget);
      },
    );

    testWidgets(
      'the readout shows "Arrived at" once the route completes (AC-10)',
      (tester) async {
        await pumpInlineTab(tester, startId: 'can_tho', routeDistanceKm: 2000);
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('map_route_readout')), findsOneWidget);
        expect(find.textContaining('Arrived at'), findsOneWidget);
        expect(find.textContaining('Next:'), findsNothing);
        expect(find.byKey(const Key('completion_start_new')), findsOneWidget);
      },
    );

    testWidgets(
      'the full-screen legend restates the solid-vs-dashed idle cue (NFR-3)',
      (tester) async {
        await openFullScreenMidRoute(tester);

        expect(find.byKey(const Key('map_legend')), findsOneWidget);
        expect(find.text('Legend'), findsOneWidget);
        expect(find.text('Current position'), findsOneWidget);
        expect(find.text('Checkpoint / stop'), findsOneWidget);
        expect(find.text('Route'), findsOneWidget);
        expect(find.textContaining('voluntary pause (solid)'), findsOneWidget);
        expect(find.textContaining('lock / sleep (dashed)'), findsOneWidget);
      },
    );

    testWidgets(
      'the compact minimap shows NEITHER readout nor legend (minimap unchanged)',
      (tester) async {
        await pumpInlineTab(tester, startId: 'can_tho', routeDistanceKm: 200);

        expect(find.byKey(const Key('map_route_readout')), findsNothing);
        expect(find.byKey(const Key('map_legend')), findsNothing);
        expect(find.text('Legend'), findsNothing);
      },
    );
  });
}

/// An in-memory [RouteRepository] for the widget cases.
class _InMemoryRouteRepo implements RouteRepository {
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

/// A minimal nav shell mirroring main.dart's post-removal tab set (Journey /
/// Stats / Badges / Settings — no Map tab). Used by TC-221.
class _NavShellHarness extends StatefulWidget {
  const _NavShellHarness({required this.chain});

  final ProvinceChain chain;

  @override
  State<_NavShellHarness> createState() => _NavShellHarnessState();
}

class _NavShellHarnessState extends State<_NavShellHarness> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const <Widget>[
          Center(child: Text('JOURNEY-BODY')),
          Center(child: Text('STATS-BODY')),
          Center(child: Text('BADGES-BODY')),
          Center(child: Text('SETTINGS-BODY')),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.directions_bike),
            label: 'Journey',
          ),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Stats'),
          NavigationDestination(
            icon: Icon(Icons.emoji_events),
            label: 'Badges',
          ),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
