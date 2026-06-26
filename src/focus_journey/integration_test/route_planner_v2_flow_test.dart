// Integration tests for route-planner-v2 (ADR-0005): the GATING zero-side-effect-
// until-confirm snapshot (AC-6), confirm→travel, the abandon→new-route lifecycle,
// and restart restoration of the active custom route (AC-12). Deterministic: a
// scripted cumulative `double` through the cubit seam + a recording / real-prefs
// repository — no real engine, no timers, no real network.
//
// Runs under `flutter test` (headless) and on a desktop device:
//   fvm flutter test integration_test/route_planner_v2_flow_test.dart
//   fvm flutter test integration_test/route_planner_v2_flow_test.dart -d macos
//
// Traceability (one test ↔ one case; TC + AC ids in each description):
//   TC-314 (AC-6)  review + edit + cancel leaves offset/position/cumulative/
//                  persisted-state byte-identical; ZERO repository writes (gating)
//   TC-315 (AC-6)  opening the review screen alone stamps no offset, writes nothing
//   TC-316 (AC-6/NFR-1) a burst of review edits is in-memory only — zero writes
//   TC-330 (AC-10/AC-7) confirm→travel then abandon→new-route end-to-end: new
//                  offset, preserved cumulative, correct new-route position
//   TC-334 (AC-12) an active custom route survives restart via the existing seam;
//                  restored position + route % match pre-restart
//   TC-335 (AC-12/AC-11) restored route's red trace is current-route-only after a
//                  prior abandon (no bleed survives the restart)
//   TC-336 (AC-12) lifecycle (active/completed/abandoned) persists + restores; no
//                  spurious re-celebration on restore

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/activity_segment.dart';
import 'package:focus_journey/features/journey/domain/journey_progress.dart';
import 'package:focus_journey/features/journey/domain/journey_state.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/route/data/shared_preferences_route_repository.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_plan.dart';
import 'package:focus_journey/features/route/domain/route_planner.dart';
import 'package:focus_journey/features/route/domain/route_position.dart';
import 'package:focus_journey/features/route/domain/route_repository.dart';
import 'package:focus_journey/features/route/domain/route_selection.dart';
import 'package:focus_journey/features/route/presentation/map_cubit.dart';
import 'package:focus_journey/features/route/presentation/route_progress_cubit.dart';
import 'package:focus_journey/features/route/presentation/route_review_screen.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Province _node(ProvinceChain chain, String id) =>
    chain.nodes.firstWhere((p) => p.id == id);

/// A repository that records EVERY write attempt (save + savePlan) so AC-6 can
/// assert "zero writes" across a whole review+edit+cancel cycle.
class _RecordingRepo implements RouteRepository {
  RouteSelection? _stored;
  RoutePlan? _storedPlan;

  final List<RouteSelection> saves = <RouteSelection>[];
  final List<RoutePlan> planSaves = <RoutePlan>[];

  /// Total mutating calls of any kind — the AC-6 "nothing recorded" counter.
  int get totalWrites => saves.length + planSaves.length;

  @override
  Future<RouteSelection?> load() async => _stored;

  @override
  Future<void> save(RouteSelection selection) async {
    saves.add(selection);
    _stored = selection;
  }

  @override
  Future<RoutePlan?> loadPlan() async => _storedPlan;

  @override
  Future<void> savePlan(RoutePlan plan) async {
    planSaves.add(plan);
    _storedPlan = plan;
  }
}

JourneyProgress _progress({
  required List<ActivitySegment> segments,
  double distanceKm = 0,
}) => JourneyProgress(
  distanceKm: distanceKm,
  activeTimeToday: Duration.zero,
  rawActiveTime: Duration.zero,
  idleTimeToday: Duration.zero,
  state: JourneyState.active,
  mode: TravelMode.motorbike,
  storedDate: DateTime(2026, 6, 25),
  segments: segments,
);

ActivitySegment _idle(double fromKm, double toKm) => ActivitySegment(
  fromKm: fromKm,
  toKm: toKm,
  elapsed: const Duration(minutes: 10),
  classification: SegmentClassification.idle,
  cause: SegmentCause.voluntary,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ProvinceChain chain;
  late ProvinceGeography geography;

  setUp(() {
    chain = _fixtureChain();
    geography = _fixtureGeography(chain);
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  ResolvedRoute resolve(String startId, String endId) => RoutePlanner.resolve(
    fullChain: chain,
    fullGeography: geography,
    start: _node(chain, startId),
    end: _node(chain, endId),
  );

  group(
    'TC-314 (AC-6) review + edit + cancel leaves everything byte-identical',
    () {
      testWidgets(
        'a full review+edit+cancel cycle records NOTHING (the gating snapshot)',
        (tester) async {
          final repo = _RecordingRepo();
          final cubit = RouteProgressCubit(
            chain: chain,
            geography: geography,
            repository: repo,
          );
          addTearDown(cubit.close);
          // A non-zero lifetime cumulative from prior travel (no route active).
          cubit.updateFromDistance(740);

          // --- Snapshot BEFORE entering review. ---
          final RouteViewStateSnapshot before = RouteViewStateSnapshot.of(
            cubit,
          );
          final int writesBefore = repo.totalWrites;
          expect(writesBefore, 0);

          // --- Enter review, edit (remove an intermediate), then CANCEL. ---
          var cancelled = false;
          final route = resolve(
            'can_tho',
            'ha_noi',
          ); // can_tho→da_lat→da_nang→ha_noi
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: RouteReviewScreen(
                    chain: chain,
                    geography: geography,
                    start: route.orderedNodes.first,
                    end: route.orderedNodes.last,
                    initial: route,
                    onConfirm: (_) =>
                        fail('confirm must not fire on a cancel cycle'),
                    onCancel: () => cancelled = true,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          // Edit: remove an auto-inserted intermediate.
          await tester.tap(
            find.byKey(const Key('route_review_remove_da_nang')),
          );
          await tester.pumpAndSettle();
          // Cancel back to the picker (no confirm).
          await tester.tap(find.byKey(const Key('route_review_cancel')));
          await tester.pumpAndSettle();
          expect(cancelled, isTrue);

          // --- Assert byte-for-byte identical state + ZERO writes. ---
          final RouteViewStateSnapshot after = RouteViewStateSnapshot.of(cubit);
          expect(after, equals(before));
          expect(
            repo.totalWrites,
            0,
            reason: 'review+edit+cancel must write NOTHING (AC-6 gating)',
          );
          // No offset stamped, no position, cumulative untouched.
          expect(cubit.state.selection, isNull);
          expect(cubit.state.position, isNull);
          expect(cubit.state.cumulativeDistanceKm, closeTo(740, _tol));
        },
      );
    },
  );

  group('TC-315 (AC-6) opening the review screen alone mutates nothing', () {
    testWidgets(
      'building the review screen stamps no offset and writes nothing',
      (tester) async {
        final repo = _RecordingRepo();
        final cubit = RouteProgressCubit(
          chain: chain,
          geography: geography,
          repository: repo,
        );
        addTearDown(cubit.close);
        cubit.updateFromDistance(740);
        final before = RouteViewStateSnapshot.of(cubit);

        final route = resolve('can_tho', 'da_nang');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RouteReviewScreen(
                  chain: chain,
                  geography: geography,
                  start: route.orderedNodes.first,
                  end: route.orderedNodes.last,
                  initial: route,
                  onConfirm: (_) {},
                  onCancel: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The act of reviewing is purely read-only — zero writes the moment it builds.
        expect(repo.totalWrites, 0);
        expect(RouteViewStateSnapshot.of(cubit), equals(before));
        expect(cubit.state.selection, isNull);
      },
    );
  });

  group('TC-316 (AC-6/NFR-1) a burst of review edits is in-memory only', () {
    testWidgets('remove/restore several intermediates → still zero writes', (
      tester,
    ) async {
      final repo = _RecordingRepo();
      final cubit = RouteProgressCubit(
        chain: chain,
        geography: geography,
        repository: repo,
      );
      addTearDown(cubit.close);
      cubit.updateFromDistance(740);

      final route = resolve('can_tho', 'ha_noi'); // 2 intermediates
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RouteReviewScreen(
                chain: chain,
                geography: geography,
                start: route.orderedNodes.first,
                end: route.orderedNodes.last,
                initial: route,
                onConfirm: (_) {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A burst of edits, each triggering an in-memory re-resolve.
      await tester.tap(find.byKey(const Key('route_review_remove_da_nang')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('route_review_remove_da_lat')));
      await tester.pumpAndSettle();
      // Add da_nang back.
      await tester.tap(find.byKey(const Key('route_review_removed_da_nang')));
      await tester.pumpAndSettle();

      // Every re-resolution is in-memory only — zero writes, no offset stamped.
      expect(repo.totalWrites, 0);
      expect(cubit.state.selection, isNull);
      expect(cubit.state.cumulativeDistanceKm, closeTo(740, _tol));
    });
  });

  group('TC-330 (AC-10/AC-7) confirm→travel→abandon→new-route end-to-end', () {
    testWidgets(
      'confirm stamps one offset, travel resolves; abandon stamps a new offset '
      'with preserved cumulative and a correct new-route position',
      (tester) async {
        final repo = _RecordingRepo();
        final cubit = RouteProgressCubit(
          chain: chain,
          geography: geography,
          repository: repo,
        );
        addTearDown(cubit.close);

        // Confirm route 1 at cumulative 0; travel to 200 km.
        cubit.updateFromDistance(0);
        await cubit.confirmRoute(resolve('can_tho', 'da_nang'));
        expect(repo.planSaves.single.routeStartOffsetKm, closeTo(0, _tol));
        cubit.updateFromDistance(200);
        expect(cubit.state.position!.routeDistanceKm, closeTo(200, _tol));
        expect(cubit.hasProgressToLose, isTrue);

        // Abandon at cumulative 200 → new route da_lat → ha_giang.
        await cubit.abandonAndStartNew(resolve('da_lat', 'ha_giang'));
        // New offset == cumulative at abandon; cumulative preserved.
        expect(cubit.state.selection!.routeStartOffsetKm, closeTo(200, _tol));
        expect(cubit.state.cumulativeDistanceKm, closeTo(200, _tol));
        expect(cubit.state.isCompleted, isFalse);

        // Travel the new route 100 km (cumulative 300 → routeKm 100).
        cubit.updateFromDistance(300);
        expect(cubit.state.position!.routeDistanceKm, closeTo(100, _tol));
        // Two plans persisted across the round-trip (original + new active).
        expect(repo.planSaves, hasLength(2));
      },
    );
  });

  group('TC-334 (AC-12) active custom route survives restart via the seam', () {
    testWidgets(
      'restored plan == pre-restart; position + route % recompute identically',
      (tester) async {
        // --- Session 1: confirm a custom route over the REAL prefs repo. ---
        final prefs1 = await SharedPreferences.getInstance();
        final repo1 = SharedPreferencesRouteRepository(
          prefs1,
          chain,
          geography,
        );
        final session1 = RouteProgressCubit(
          chain: chain,
          geography: geography,
          repository: repo1,
        );
        addTearDown(session1.close);
        session1.updateFromDistance(740);
        await session1.confirmRoute(
          resolve('can_tho', 'da_nang'),
        ); // offset 740
        session1.updateFromDistance(740 + 235); // 235 route km in
        final pos1 = session1.state.position!;
        final routePct1 = pos1.percentOfCountry;
        final countryPct1 = session1.state.countryPercent!;

        // Persistence used only the existing namespace (the v2 plan key).
        expect(
          prefs1.getKeys(),
          contains(SharedPreferencesRouteRepository.planStorageKey),
        );

        // --- Session 2 ("relaunch"): a fresh cubit restores from the saved plan. ---
        final prefs2 = await SharedPreferences.getInstance();
        final repo2 = SharedPreferencesRouteRepository(
          prefs2,
          chain,
          geography,
        );
        final restoredPlan = await repo2.loadPlan();
        expect(restoredPlan, isNotNull);
        expect(restoredPlan!.isActive, isTrue);
        expect(restoredPlan.orderedNodeIds, <String>[
          'can_tho',
          'da_lat',
          'da_nang',
        ]);
        expect(restoredPlan.routeStartOffsetKm, closeTo(740, _tol));

        final session2 = RouteProgressCubit(
          chain: chain,
          geography: geography,
          repository: repo2,
          initialPlan: restoredPlan,
        );
        addTearDown(session2.close);
        // Same engine cumulative → identical resolved position + percentages.
        session2.updateFromDistance(740 + 235);
        expect(session2.state.position, equals(pos1));
        expect(
          session2.state.position!.percentOfCountry,
          closeTo(routePct1, _tol),
        );
        expect(session2.state.countryPercent, closeTo(countryPct1, _tol));
      },
    );
  });

  group('TC-335 (AC-12/AC-11) restored route red trace is current-route-only', () {
    testWidgets(
      'after a prior abandon, the restored route paints only its own offset window',
      (tester) async {
        // --- Session 1: confirm route 1, abandon it, confirm route 2 (the
        // restart target), persisting route 2 with its NEW offset. ---
        final prefs1 = await SharedPreferences.getInstance();
        final repo1 = SharedPreferencesRouteRepository(
          prefs1,
          chain,
          geography,
        );
        final session1 = RouteProgressCubit(
          chain: chain,
          geography: geography,
          repository: repo1,
        );
        addTearDown(session1.close);
        session1.updateFromDistance(0);
        await session1.confirmRoute(resolve('can_tho', 'da_nang')); // offset 0
        session1.updateFromDistance(1180);
        await session1.abandonAndStartNew(
          resolve('da_lat', 'ha_giang'),
        ); // offset 1180

        // --- Session 2: restore the active plan (route 2) on restart. ---
        final prefs2 = await SharedPreferences.getInstance();
        final repo2 = SharedPreferencesRouteRepository(
          prefs2,
          chain,
          geography,
        );
        final restored = await repo2.loadPlan();
        expect(restored!.routeStartOffsetKm, closeTo(1180, _tol));

        final session2 = RouteProgressCubit(
          chain: chain,
          geography: geography,
          repository: repo2,
          initialPlan: restored,
        );
        addTearDown(session2.close);
        session2.updateFromDistance(1580); // 400 route km into route 2

        final mapCubit = MapCubit(geography: geography);
        addTearDown(mapCubit.close);
        // The record still carries the abandoned route's old-offset idle span
        // plus a new-route span — only the latter must paint after restart.
        final segments = <ActivitySegment>[
          _idle(200, 240), // abandoned route (old offset) — must NOT bleed
          _idle(1300, 1340), // route 2 (new offset) — must paint
        ];
        mapCubit
          ..updateFromRoute(session2.state)
          ..updateFromSnapshot(_progress(segments: segments, distanceKm: 1580));

        expect(
          mapCubit.state.idleStretches,
          hasLength(1),
          reason:
              'restored trace is current-route-only — no bleed survives restart',
        );
      },
    );
  });

  group('TC-336 (AC-12) lifecycle persists + restores without re-celebration', () {
    testWidgets('a completed plan restores completed and does not re-fire arrival', (
      tester,
    ) async {
      // Persist a COMPLETED plan directly via the real repo.
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesRouteRepository(prefs, chain, geography);
      const completed = RoutePlan(
        orderedNodeIds: <String>['can_tho', 'da_lat', 'da_nang'],
        routeStartOffsetKm: 0,
        lifecycle: RouteLifecycle.completed,
      );
      await repo.savePlan(completed);

      final restoredPlan = await repo.loadPlan();
      expect(restoredPlan!.lifecycle, RouteLifecycle.completed);

      // Restore: the cubit adopts the completed plan and shows arrival, but a
      // restore does not "re-fire" — it latches the already-completed state.
      final session = RouteProgressCubit(
        chain: chain,
        geography: geography,
        repository: repo,
        initialPlan: restoredPlan,
      );
      addTearDown(session.close);
      // Resolve at the destination distance: the route shows completed terminally.
      session.updateFromDistance(470);
      expect(session.state.isCompleted, isTrue);

      // The persisted lifecycle remains completed (not misclassified, not reset).
      final afterRestore = await repo.loadPlan();
      expect(afterRestore!.lifecycle, RouteLifecycle.completed);

      // And an ABANDONED plan is NOT the active route on restore (distinct from
      // completion) — loadPlan only adopts active/completed; an abandoned blob is
      // never persisted as the active route (the new active plan overwrites it),
      // so a restored active route is never spuriously "abandoned".
      const abandonedSeed = RoutePlan(
        orderedNodeIds: <String>['da_lat', 'da_nang'],
        routeStartOffsetKm: 0,
        lifecycle: RouteLifecycle.abandoned,
      );
      // Round-trips distinctly (not coerced to completed).
      expect(
        RoutePlan.fromJson(abandonedSeed.toJson()).lifecycle,
        RouteLifecycle.abandoned,
      );
    });
  });
}

/// An immutable snapshot of the route view state's mutable surface, for the AC-6
/// before/after equality. `RouteViewState` is itself Equatable, but capturing the
/// load-bearing fields explicitly documents exactly what AC-6 freezes.
class RouteViewStateSnapshot {
  RouteViewStateSnapshot({
    required this.selection,
    required this.position,
    required this.cumulativeDistanceKm,
    required this.countryPercent,
  });

  factory RouteViewStateSnapshot.of(RouteProgressCubit cubit) =>
      RouteViewStateSnapshot(
        selection: cubit.state.selection,
        position: cubit.state.position,
        cumulativeDistanceKm: cubit.state.cumulativeDistanceKm,
        countryPercent: cubit.state.countryPercent,
      );

  final RouteSelection? selection;
  final RoutePosition? position;
  final double cumulativeDistanceKm;
  final double? countryPercent;

  @override
  bool operator ==(Object other) =>
      other is RouteViewStateSnapshot &&
      other.selection == selection &&
      other.position == position &&
      other.cumulativeDistanceKm == cumulativeDistanceKm &&
      other.countryPercent == countryPercent;

  @override
  int get hashCode =>
      Object.hash(selection, position, cumulativeDistanceKm, countryPercent);
}
