// Full-wiring smoke for route-progress (the end-to-end consume path).
//
// Proves: ActivityTicker.tickOnce() — driven by a deterministic
// MockActivitySource + a scripted clock (NO real OS, NO real timers) — advances
// the engine's cumulative distanceKm and flows that single scalar through the
// ticker's onDistance sink into the RouteProgressCubit, which updates the map
// readout. The route cubit holds NO engine reference, so the engine is read,
// never mutated by route-progress (AC-16 / AC-17 reinforced at runtime).
//
// This is the integration counterpart to main.dart's wiring
// (`onDistance: routeCubit.updateFromDistance`). It does NOT re-test the engine's
// accrual (that is journey-engine's suite) — it asserts the seam delivers the
// scalar and the cubit consumes it.
//
// Runs under `flutter test` (headless) and on a desktop device:
//   fvm flutter test integration_test/route_wiring_smoke_test.dart
//   fvm flutter test integration_test/route_wiring_smoke_test.dart -d macos

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/mock_activity_source.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/journey_engine.dart';
import 'package:focus_journey/features/journey/presentation/activity_ticker.dart';
import 'package:focus_journey/features/journey/presentation/journey_cubit.dart';
import 'package:focus_journey/features/route/domain/journey_direction.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/route_repository.dart';
import 'package:focus_journey/features/route/domain/route_selection.dart';
import 'package:focus_journey/features/route/presentation/route_map_screen.dart';
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

/// An in-memory repo (no shared_preferences needed for the wiring smoke).
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

/// An in-memory [RouteRepository] that records writes — proves route-progress
/// only ever persists its own selection, never resets engine state.
class InMemoryRouteRepo implements RouteRepository {
  RouteSelection? _stored;
  int saveCount = 0;

  @override
  Future<RouteSelection?> load() async => _stored;

  @override
  Future<void> save(RouteSelection selection) async {
    saveCount++;
    _stored = selection;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TC-wiring: ticker.tickOnce flows distanceKm → route cubit → map readout',
    (tester) async {
      final chain = _fixture();
      final clock = AdvanceableClock(DateTime(2026, 6, 23, 12));
      final mock = MockActivitySource(idleSeconds: 0, screenLocked: false);
      // 60 km/active-hour so 1 active hour ⇒ exactly 60 km (a clean readout).
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

      // The seam under test: ticker forwards only a double to the route cubit.
      final ticker = ActivityTicker(
        engine: engine,
        clock: clock,
        cubit: journeyCubit,
        onDistance: routeCubit.updateFromDistance,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<RouteProgressCubit>.value(
            value: routeCubit,
            child: RouteMapScreen(chain: chain),
          ),
        ),
      );
      await tester.pump();

      // Pick a route up front (Cần Thơ north) so the map renders the readout.
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
      expect(routeCubit.state.position!.routeDistanceKm, closeTo(60, _tol));

      // The map readout reflects the consumed distance: 60 km past Cần Thơ lands
      // before Đà Lạt (170 km away) ⇒ "Next: Đà Lạt in 110 km".
      expect(find.textContaining('Next: Đà Lạt'), findsOneWidget);
      expect(find.textContaining('110 km'), findsOneWidget);

      // Route-progress never mutated the engine: feeding more distance does not
      // change engine.activeTimeToday and the repo saw only the start write.
      expect(engine.activeTimeToday, const Duration(hours: 1));
      expect(repo.saveCount, 1); // only the startNewRoute selection write.
    },
  );
}
