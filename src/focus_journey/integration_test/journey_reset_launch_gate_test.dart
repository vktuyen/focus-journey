// Integration test for the journey-reset launch gate (AC-6/AC-7/AC-8/AC-11).
//
// Exercises the REAL SharedPreferencesRouteRepository + the REAL LaunchGateCubit
// (seeded from the persisted lifecycle exactly as main.dart seeds it) + the REAL
// RouteProgressCubit restore path, over SharedPreferences.setMockInitialValues
// (no real disk / platform channel). A "relaunch" = fresh repos + a fresh gate
// constructed from the reloaded blob — the honest kill/reopen is the manual leg
// TC-M-BOOT. Deterministic: distance is a scripted scalar; no engine, no timers,
// no wall clock.
//
// Traceability (one test group ↔ one case; TC + AC ids in each description):
//   TC-710 (AC-6)  persisted `active` route → gate shows the prompt on relaunch
//   TC-711 (AC-7)  fresh install (no plan) → no prompt
//   TC-712 (AC-7)  persisted `completed` route → no prompt
//   TC-713 (AC-7)  persisted `abandoned` route → no prompt
//   TC-714 (AC-8)  Resume restores the IDENTICAL prior position (no drift)
//   TC-715 (AC-8)  Resume keys off persisted routeDistanceKm, not wall-clock —
//                  a simulated sleep/wake gap adds no phantom forward jump
//
// Run headless: fvm flutter test integration_test/journey_reset_launch_gate_test.dart
// On device:    fvm flutter test integration_test/journey_reset_launch_gate_test.dart -d macos

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/reset/presentation/launch_gate_cubit.dart';
import 'package:focus_journey/features/route/data/shared_preferences_route_repository.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_plan.dart';
import 'package:focus_journey/features/route/presentation/route_progress_cubit.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double _tol = 1e-6;

/// An in-progress active plan over the real spine, with a non-zero offset so
/// `routeDistanceKm = cumulative − offset` is meaningful.
RoutePlan _activePlan({double offsetKm = 100}) => RoutePlan(
  orderedNodeIds: const <String>['can_tho', 'ho_chi_minh', 'da_lat'],
  routeStartOffsetKm: offsetKm,
);

SharedPreferencesRouteRepository _repo(SharedPreferences prefs) =>
    SharedPreferencesRouteRepository(
      prefs,
      vietnamProvinceChain,
      vietnamProvinceGeography,
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('TC-710 (AC-6) relaunch with an active route shows the prompt', () {
    testWidgets('persisted `active` lifecycle seeds a shown prompt', (
      tester,
    ) async {
      // --- Session 1: persist an active plan.
      await _repo(await SharedPreferences.getInstance()).savePlan(_activePlan());

      // --- Relaunch: fresh repo + gate from the reloaded blob.
      final prefs2 = await SharedPreferences.getInstance();
      final restored = await _repo(prefs2).loadPlan();
      expect(restored, isNotNull);
      expect(restored!.lifecycle, RouteLifecycle.active);

      final gate = LaunchGateCubit(lifecycle: restored.lifecycle);
      addTearDown(gate.close);
      expect(gate.showPrompt, isTrue);
    });
  });

  group('TC-711 (AC-7) fresh install shows no prompt', () {
    testWidgets('no persisted plan → gate proceeds', (tester) async {
      final plan = await _repo(await SharedPreferences.getInstance()).loadPlan();
      expect(plan, isNull);
      final gate = LaunchGateCubit(lifecycle: plan?.lifecycle);
      addTearDown(gate.close);
      expect(gate.showPrompt, isFalse);
    });
  });

  group('TC-712 (AC-7) completed route shows no prompt', () {
    testWidgets('persisted `completed` lifecycle → gate proceeds', (
      tester,
    ) async {
      await _repo(await SharedPreferences.getInstance()).savePlan(
        _activePlan().copyWith(lifecycle: RouteLifecycle.completed),
      );
      final prefs2 = await SharedPreferences.getInstance();
      final restored = await _repo(prefs2).loadPlan();
      expect(restored!.lifecycle, RouteLifecycle.completed);
      final gate = LaunchGateCubit(lifecycle: restored.lifecycle);
      addTearDown(gate.close);
      expect(gate.showPrompt, isFalse);
    });
  });

  group('TC-713 (AC-7) abandoned route shows no prompt', () {
    testWidgets('persisted `abandoned` lifecycle → gate proceeds', (
      tester,
    ) async {
      await _repo(await SharedPreferences.getInstance()).savePlan(
        _activePlan().copyWith(lifecycle: RouteLifecycle.abandoned),
      );
      final prefs2 = await SharedPreferences.getInstance();
      final restored = await _repo(prefs2).loadPlan();
      expect(restored!.lifecycle, RouteLifecycle.abandoned);
      final gate = LaunchGateCubit(lifecycle: restored.lifecycle);
      addTearDown(gate.close);
      expect(gate.showPrompt, isFalse);
    });
  });

  group('TC-714 (AC-8) Resume restores the identical prior position', () {
    testWidgets(
      'resuming the persisted active route reaches the SAME position as before '
      'the reopen — no loss, no drift',
      (tester) async {
        const cumulativeKm = 250.0; // routeDistanceKm = 250 − 100 = 150
        // --- Session 1: an in-progress route at a known cumulative distance.
        final prefs1 = await SharedPreferences.getInstance();
        await _repo(prefs1).savePlan(_activePlan(offsetKm: 100));
        final session1 = RouteProgressCubit(
          chain: vietnamProvinceChain,
          geography: vietnamProvinceGeography,
          repository: _repo(prefs1),
          initialPlan: await _repo(prefs1).loadPlan(),
        );
        addTearDown(session1.close);
        session1.updateFromDistance(cumulativeKm);
        final before = session1.state.position!;

        // --- Relaunch + Resume: fresh cubit from the reloaded plan, same cumulative.
        final prefs2 = await SharedPreferences.getInstance();
        final restored = await _repo(prefs2).loadPlan();
        final gate = LaunchGateCubit(lifecycle: restored!.lifecycle);
        addTearDown(gate.close);
        expect(gate.showPrompt, isTrue);
        gate.resume(); // user chooses Resume — enters journey on restored state
        expect(gate.showPrompt, isFalse);

        final session2 = RouteProgressCubit(
          chain: vietnamProvinceChain,
          geography: vietnamProvinceGeography,
          repository: _repo(prefs2),
          initialPlan: restored,
        );
        addTearDown(session2.close);
        session2.updateFromDistance(cumulativeKm);
        final after = session2.state.position!;

        // Identical route, offset, distance and resolved position.
        expect(after.routeDistanceKm, closeTo(before.routeDistanceKm, _tol));
        expect(after.fractionAlongRoute, closeTo(before.fractionAlongRoute, _tol));
        expect(after.percentOfCountry, closeTo(before.percentOfCountry, _tol));
        expect(session2.state.selection!.start.id, session1.state.selection!.start.id);
        expect(after.routeDistanceKm, closeTo(150, _tol));
      },
    );
  });

  group('TC-715 (AC-8) Resume keys off persisted distance, not wall-clock', () {
    testWidgets(
      'a simulated sleep/wake gap adds NO forward jump — the resumed position is '
      'derived from the persisted routeDistanceKm/offset',
      (tester) async {
        const cumulativeAtClose = 300.0; // routeDistanceKm = 300 − 100 = 200
        final prefs1 = await SharedPreferences.getInstance();
        await _repo(prefs1).savePlan(_activePlan(offsetKm: 100));
        final atClose = RouteProgressCubit(
          chain: vietnamProvinceChain,
          geography: vietnamProvinceGeography,
          repository: _repo(prefs1),
          initialPlan: await _repo(prefs1).loadPlan(),
        );
        addTearDown(atClose.close);
        atClose.updateFromDistance(cumulativeAtClose);
        final closedRouteDistance = atClose.state.position!.routeDistanceKm;

        // --- Reopen after a (simulated) real-time gap. Because a closed app
        // accrues NO distance (BR-5, owned by journey-engine), the persisted
        // cumulative is unchanged across the gap — so we feed the SAME value.
        final prefs2 = await SharedPreferences.getInstance();
        final restored = await _repo(prefs2).loadPlan();
        final resumed = RouteProgressCubit(
          chain: vietnamProvinceChain,
          geography: vietnamProvinceGeography,
          repository: _repo(prefs2),
          initialPlan: restored,
        );
        addTearDown(resumed.close);
        resumed.updateFromDistance(cumulativeAtClose); // no phantom advance

        // No drift: exactly where the user left off (200 km along the route).
        expect(
          resumed.state.position!.routeDistanceKm,
          closeTo(closedRouteDistance, _tol),
        );
        expect(resumed.state.position!.routeDistanceKm, closeTo(200, _tol));
      },
    );
  });
}
