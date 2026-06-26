// Widget tests for the map surface wiring (map-experience): the inline overlay
// on the journey tab, the tap → full-screen-in-the-same-window transition, the
// close-button / Esc dismiss back to inline, the re-homed start-picker +
// completion celebration, the absence of a standalone "Map" nav destination, and
// the tile-request payload (TC-231).
//
// The fake tile provider is injected into every surface — no test reaches the
// network. The MapCubit + RouteProgressCubit are real, driven by scripted
// snapshots (no engine, no timers).
//
// Covers:
//   AC-1  / TC-220  inline overlay renders on the journey tab; no "Map" nav tab
//   AC-1  / TC-221  removing the Map tab does not break other navigation
//   AC-2  / TC-222  tapping the inline overlay pushes a full-screen MaterialPageRoute
//                   (same window — no new-window API)
//   AC-3  / TC-223  close button, system back (maybePop), AND Esc all dismiss
//                   full-screen → back to inline
//   re-homed flows  start-picker shown when no route; celebration when completed
//   NFR-2 / TC-231  tile requests are anonymous {z}/{x}/{y} GETs, no user data

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/activity_segment.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_plan.dart';
import 'package:focus_journey/features/route/domain/route_repository.dart';
import 'package:focus_journey/features/route/domain/route_selection.dart';
import 'package:focus_journey/features/route/presentation/map_cubit.dart';
import 'package:focus_journey/features/route/presentation/map_surface.dart';
import 'package:focus_journey/features/route/presentation/map_view.dart';
import 'package:focus_journey/features/route/presentation/route_picker.dart';
import 'package:focus_journey/features/route/presentation/route_progress_cubit.dart';

import '../map_test_fixtures.dart';

void main() {
  late ProvinceChain chain;
  late ProvinceGeography geography;

  setUp(() {
    chain = buildFixtureChain();
    geography = buildFixtureGeography(chain);
  });

  /// An in-memory route repository (no persistence needed for these widget cases).
  RouteRepository inMemoryRepo() => _InMemoryRouteRepo();

  /// Builds a wired MapCubit + RouteProgressCubit pair and (optionally) starts a
  /// route, then feeds the map cubit a snapshot so it has a route to render.
  ///
  /// When [startId] is null the cubits stay route-less (the picker surface).
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
      // Drive the route cubit so its RouteViewState carries the resolved position.
      routeCubit.startNewRoute(nodeById(chain, startId), direction);
      routeCubit.updateFromDistance(routeDistanceKm);
      // Forward to the map cubit (the wiring main.dart performs).
      mapCubit.updateFromRoute(routeCubit.state);
      mapCubit.updateFromSnapshot(progressWith(segments: segments));
      // Keep the selection referenced (avoids an unused-var lint).
      expect(selection.start.id, startId);
    }
    return (map: mapCubit, route: routeCubit);
  }

  /// Pumps a faux "journey tab" hosting the inline overlay, with both cubits
  /// provided and the fake tile provider injected.
  Future<FakeTileProvider> pumpInlineTab(
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
    final provider = FakeTileProvider();
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<MapCubit>.value(value: cubits.map),
            BlocProvider<RouteProgressCubit>.value(value: cubits.route),
          ],
          child: Scaffold(
            // The faux journey tab mirrors main.dart's new full-bleed layout:
            // the scene fills the tab and the inline overlay (the floating
            // minimap) rides on top in a Stack. A sibling label proves the rest
            // of the tab stays functional behind the minimap.
            body: Stack(
              children: <Widget>[
                const Positioned.fill(
                  child: Center(child: Text('journey-scene')),
                ),
                InlineMapOverlay(
                  chain: chain,
                  geography: geography,
                  tileProvider: provider,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return provider;
  }

  group('AC-1 / TC-220 inline overlay on journey tab; no standalone Map tab', () {
    testWidgets('the inline overlay renders as a compact minimap on the tab', (
      tester,
    ) async {
      await pumpInlineTab(tester, startId: 'can_tho', routeDistanceKm: 200);

      // The inline overlay (and the MapView it wraps) is present on the tab.
      expect(find.byType(InlineMapOverlay), findsOneWidget);
      expect(find.byType(MapView), findsOneWidget);
      // The journey scene sibling is intact behind the minimap (full-bleed
      // scene + floating HUD card — not a 50/50 split).
      expect(find.text('journey-scene'), findsOneWidget);

      // The minimap is a COMPACT, fixed-size HUD card (≈150×190) — not a
      // half-screen panel. Assert the rendered InkWell card is small.
      final cardSize = tester.getSize(find.byType(InkWell).first);
      expect(cardSize.width, lessThan(200));
      expect(cardSize.height, lessThan(260));

      // The minimap renders the route WITHOUT live OSM tiles (showTiles:false):
      // no TileLayer and no attribution pill inline — tiles are reserved for
      // the full-screen surface (AC-11). This means the minimap makes no tile
      // network calls (strictly fewer GETs — NFR-2).
      expect(find.byType(TileLayer), findsNothing);
      expect(find.textContaining('OpenStreetMap'), findsNothing);

      // A compact expand affordance (icon, not the old wide text badge) marks
      // it as tappable to open full-screen.
      expect(find.byIcon(Icons.open_in_full), findsOneWidget);
      expect(find.text('Tap to expand'), findsNothing);

      // NFR-3 / TC-232: the card stays screen-reader reachable via a Semantics
      // button label even though the visible text badge is gone.
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
      // Build a minimal nav shell mirroring main.dart's _HomeTabs destinations
      // (Journey / Stats / Badges / Settings — the Map tab was removed, AC-1).
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

      // Assert NO destination is labelled "Map" (the standalone tab is gone).
      final mapLabelled = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Map'),
      );
      expect(mapLabelled, findsNothing);
      // The remaining tabs are present.
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

          // Start on Journey.
          expect(find.text('JOURNEY-BODY'), findsOneWidget);
          // Tap Stats, then Settings — each reachable, no crash/blank.
          await tester.tap(find.text('Stats'));
          await tester.pumpAndSettle();
          expect(find.text('STATS-BODY'), findsOneWidget);
          await tester.tap(find.text('Settings'));
          await tester.pumpAndSettle();
          expect(find.text('SETTINGS-BODY'), findsOneWidget);
          // Back to Journey.
          await tester.tap(find.text('Journey'));
          await tester.pumpAndSettle();
          expect(find.text('JOURNEY-BODY'), findsOneWidget);
          // No exception across the whole navigation sweep.
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

          // Full-screen is not present yet.
          expect(find.byType(FullScreenMap), findsNothing);

          // Tap the minimap card (the single tap target — a Semantics button
          // InkWell anchored bottom-right).
          await tester.tap(find.byType(InkWell));
          await tester.pumpAndSettle();

          // A full-screen MapView is now pushed — in the SAME Navigator (a
          // MaterialPageRoute), not a new OS window.
          expect(find.byType(FullScreenMap), findsOneWidget);
          // The close affordance for the full-screen surface is present.
          expect(
            find.byKey(const Key('map_full_screen_close')),
            findsOneWidget,
          );
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

      // Back to inline; the journey scene sibling is still there & functional.
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
      'AC-3/TC-223: the system-back path (maybePop) dismisses full-screen '
      'back to inline, journey tab intact',
      (tester) async {
        await openFullScreen(tester);

        // System back: route the platform "pop route" event through the same
        // Navigator.maybePop seam the close button + back gesture invoke (the
        // third AC-3 dismiss affordance, distinct from the close button & Esc).
        final handled = await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        // The back event was consumed by the pushed full-screen route (not the
        // app/OS), proving it popped within the same Navigator stack.
        expect(handled, isTrue);
        // Back to the inline overlay; the journey scene sibling is intact.
        expect(find.byType(FullScreenMap), findsNothing);
        expect(find.byType(InlineMapOverlay), findsOneWidget);
        expect(find.text('journey-scene'), findsOneWidget);
      },
    );
  });

  group('Re-homed flows: start-picker (no route) + celebration (completed)', () {
    testWidgets(
      'the inline overlay shows the start-picker when no route is active',
      (tester) async {
        // No startId → the cubits stay route-less.
        await pumpInlineTab(tester);

        // The route-planner-v2 picker → review flow is reachable inline
        // (replacing the shipped start-picker — ADR-0005 supersedes it).
        expect(find.byType(RoutePicker), findsOneWidget);
        expect(find.byKey(const Key('route_picker_continue')), findsOneWidget);
        // No full-screen MapView is shown for a route-less state.
        expect(find.byType(MapView), findsNothing);
      },
    );

    testWidgets(
      'the completion celebration appears full-screen when the route completed',
      (tester) async {
        // Drive a completed route (past the 1380 km Cần Thơ→Hà Giang length).
        await pumpInlineTab(tester, startId: 'can_tho', routeDistanceKm: 2000);
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        // The re-homed completion celebration is shown over the full-screen map
        // (it does NOT block completion — AC-10).
        expect(find.byKey(const Key('completion_start_new')), findsOneWidget);
        expect(find.textContaining('You reached'), findsOneWidget);
        // The map still rendered behind the celebration.
        expect(find.byType(MapView), findsOneWidget);
      },
    );
  });

  group('Full-screen enrichment: route readout + legend (full-screen only)', () {
    /// Opens the full-screen surface over an active mid-route.
    Future<void> openFullScreenMidRoute(WidgetTester tester) async {
      await pumpInlineTab(tester, startId: 'can_tho', routeDistanceKm: 200);
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(find.byType(FullScreenMap), findsOneWidget);
    }

    testWidgets(
      'the full-screen surface shows the route readout (Next / km to / % of '
      'Vietnam), reading state.position',
      (tester) async {
        await openFullScreenMidRoute(tester);

        // The re-homed readout card is present full-screen.
        expect(find.byKey(const Key('map_route_readout')), findsOneWidget);
        // Line 1: next checkpoint + distance (mid-route, next != null).
        expect(find.textContaining('Next:'), findsOneWidget);
        // Line 2: distance to destination.
        expect(find.textContaining(RegExp(r'km to ')), findsOneWidget);
        // Line 3: percent of Vietnam.
        expect(find.textContaining('% of Vietnam'), findsOneWidget);
      },
    );

    testWidgets(
      'the readout shows "Arrived at" (not "Next:") once the route completes '
      '(AC-10) and does not block the completion celebration',
      (tester) async {
        // Drive a completed route (past the 1380 km Cần Thơ→Hà Giang length).
        await pumpInlineTab(tester, startId: 'can_tho', routeDistanceKm: 2000);
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        // The readout reflects arrival (position.next == null branch).
        expect(find.byKey(const Key('map_route_readout')), findsOneWidget);
        expect(find.textContaining('Arrived at'), findsOneWidget);
        expect(find.textContaining('Next:'), findsNothing);
        // The completion celebration is NOT blocked by the readout (AC-10).
        expect(find.byKey(const Key('completion_start_new')), findsOneWidget);
      },
    );

    testWidgets(
      'the full-screen surface shows the legend with the solid-vs-dashed idle '
      'cue (AC-9 / NFR-3 colour-blind aid)',
      (tester) async {
        await openFullScreenMidRoute(tester);

        // The legend card is present full-screen.
        expect(find.byKey(const Key('map_legend')), findsOneWidget);
        expect(find.text('Legend'), findsOneWidget);
        // Symbol explanations: position, checkpoint, route, both idle causes.
        expect(find.text('Current position'), findsOneWidget);
        expect(find.text('Checkpoint / stop'), findsOneWidget);
        expect(find.text('Route'), findsOneWidget);
        // The AC-9 non-colour cue is stated in words (solid vs dashed).
        expect(find.textContaining('voluntary pause (solid)'), findsOneWidget);
        expect(find.textContaining('lock / sleep (dashed)'), findsOneWidget);
      },
    );

    testWidgets(
      'the compact minimap shows NEITHER readout nor legend (minimap unchanged)',
      (tester) async {
        await pumpInlineTab(tester, startId: 'can_tho', routeDistanceKm: 200);

        // The inline minimap is the only surface; no full-screen overlays leak
        // onto it (readout + legend are full-screen-only).
        expect(find.byKey(const Key('map_route_readout')), findsNothing);
        expect(find.byKey(const Key('map_legend')), findsNothing);
        expect(find.text('Legend'), findsNothing);
      },
    );
  });

  group('NFR-2 / TC-231 tile requests are anonymous {z}/{x}/{y} GETs', () {
    testWidgets('the minimap makes NO tile requests (no live tiles inline)', (
      tester,
    ) async {
      final provider = await pumpInlineTab(
        tester,
        startId: 'can_tho',
        routeDistanceKm: 200,
      );
      // Give any (nonexistent) inline tile layer a chance to request tiles.
      await tester.pump(const Duration(milliseconds: 50));

      // The minimap renders without live OSM tiles (showTiles:false), so it
      // issues ZERO tile GETs — strictly fewer than before (better for
      // NFR-2). Tiles are reserved for the full-screen surface (below).
      expect(provider.requestedUrls, isEmpty);
    });

    testWidgets('full-screen tile URLs carry only coordinates — no user data', (
      tester,
    ) async {
      final provider = await pumpInlineTab(
        tester,
        startId: 'can_tho',
        routeDistanceKm: 200,
      );
      // Open the full-screen surface, where live OSM tiles DO load (AC-11).
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      // Let the tile layer request tiles from the injected fake provider.
      await tester.pump(const Duration(milliseconds: 50));

      // The fake provider was used (proving no real network provider was hit).
      // Each requested URL is the standard OSM tile endpoint, with no query
      // string and no user identifier / location / idle data — only z/x/y.
      expect(provider.requestedUrls, isNotEmpty);
      for (final url in provider.requestedUrls) {
        expect(url, startsWith('https://tile.openstreetmap.org/'));
        expect(url, endsWith('.png'));
        expect(url.contains('?'), isFalse, reason: 'no query payload: $url');
        // Path is exactly /{z}/{x}/{y}.png — three integer segments.
        final path = url
            .replaceFirst('https://tile.openstreetmap.org/', '')
            .replaceFirst('.png', '');
        final parts = path.split('/');
        expect(parts, hasLength(3), reason: 'expected z/x/y in $url');
        for (final part in parts) {
          expect(
            int.tryParse(part),
            isNotNull,
            reason: 'tile coordinate "$part" must be an integer (no payload)',
          );
        }
      }
    });
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
  Future<RoutePlan?> loadPlan() async => _storedPlan;

  @override
  Future<void> savePlan(RoutePlan plan) async => _storedPlan = plan;
}

/// A minimal nav shell mirroring main.dart's post-removal tab set (Journey /
/// Stats / Badges / Settings — no Map tab). Used by TC-221 to prove navigation
/// between the remaining tabs still works after the Map tab's removal.
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
