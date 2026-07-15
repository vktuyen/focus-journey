// Integration test for journey-reset Start over (AC-9/AC-10/AC-11/AC-12).
//
// Exercises the REAL RouteProgressCubit.abandonAndStartNew (the SHIPPED ADR-0005
// abandon path the launch-prompt Start over routes through) + the REAL
// shared_preferences stores + the REAL LocalDataResetService, over
// SharedPreferences.setMockInitialValues (no real disk / platform channel).
// Deterministic: distance is a scripted scalar; no engine, no timers, no clock.
//
// Traceability (one test group ↔ one case; TC + AC ids in each description):
//   TC-716 (AC-9)  Start over stamps a fresh offset == the never-reset
//                  cumulative D over the new route, and hands to authoring
//   TC-717 (AC-9)  Start over routes through the shipped abandon path — the
//                  engine cumulative (journey_progress_v1) is never reset
//   TC-718 (AC-10) completing Start over replaces ONLY the route keys; every
//                  lifetime/settings key is retained byte-for-byte
//   TC-719 (AC-10, AC-12) Start over clears NO lifetime key (not a wipe)
//   TC-720 (AC-11, AC-6) after Start over, relaunch offers Resume on the NEW route
//   TC-721 (AC-12) from an identical seed, Start over keeps cumulative while
//                  Factory reset clears it — the BR-8 carve-out asymmetry
//
// Run headless: fvm flutter test integration_test/journey_reset_start_over_test.dart
// On device:    fvm flutter test integration_test/journey_reset_start_over_test.dart -d macos

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/data/shared_preferences_journey_repository.dart';
import 'package:focus_journey/features/mini_window/data/shared_preferences_compact_window_position_repository.dart';
import 'package:focus_journey/features/mini_window/data/shared_preferences_hide_to_tray_hint_repository.dart';
import 'package:focus_journey/features/reset/domain/local_data_reset_service.dart';
import 'package:focus_journey/features/reset/domain/local_data_store.dart';
import 'package:focus_journey/features/reset/presentation/launch_gate_cubit.dart';
import 'package:focus_journey/features/route/data/shared_preferences_route_repository.dart';
import 'package:focus_journey/features/route/domain/province.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/domain/route_plan.dart';
import 'package:focus_journey/features/route/domain/route_planner.dart';
import 'package:focus_journey/features/route/presentation/route_progress_cubit.dart';
import 'package:focus_journey/features/stats/data/shared_preferences_earned_badges_repository.dart';
import 'package:focus_journey/features/stats/data/shared_preferences_history_repository.dart';
import 'package:focus_journey/features/stats/data/shared_preferences_settings_repository.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double _tol = 1e-6;

/// The lifetime/settings keys that MUST survive a Start over (AC-10/AC-12).
const Set<String> _lifetimeKeys = <String>{
  'app_settings_v1',
  'journey_progress_v1', // the never-reset cumulative distance lives here
  'stats_history_v1',
  'earned_badges_v1',
  'mini_window.compact_position.x',
  'mini_window.compact_position.y',
  'mini_window_hide_to_tray_hint_shown_v1',
};

/// A fully-populated store: an active route (v2 plan + a stale legacy blob) plus
/// a full set of lifetime data.
Map<String, Object> _seededPrefs() => <String, Object>{
  'route_plan_v1':
      '{"orderedNodeIds":["can_tho","ho_chi_minh"],"routeStartOffsetKm":50.0,"lifecycle":"active"}',
  'route_selection_v1': '{"startId":"can_tho","direction":"towardHaGiang"}',
  'app_settings_v1': '{"onboardingSeen":true}',
  'journey_progress_v1': '{"distanceKm":500.0}',
  'stats_history_v1': '[{"date":"2026-07-01"}]',
  'earned_badges_v1': '{"ids":["first_day"]}',
  'mini_window.compact_position.x': 42.0,
  'mini_window.compact_position.y': 84.0,
  'mini_window_hide_to_tray_hint_shown_v1': true,
};

SharedPreferencesRouteRepository _routeRepo(SharedPreferences prefs) =>
    SharedPreferencesRouteRepository(
      prefs,
      vietnamProvinceChain,
      vietnamProvinceGeography,
    );

Province _node(String id) =>
    vietnamProvinceChain.nodes.firstWhere((p) => p.id == id);

/// A fresh authored route DIFFERENT from the seeded one (da_lat → ha_noi).
ResolvedRoute _newRoute() => RoutePlanner.resolve(
  fullChain: vietnamProvinceChain,
  fullGeography: vietnamProvinceGeography,
  start: _node('da_lat'),
  end: _node('ha_noi'),
);

LocalDataResetService _resetService(SharedPreferences prefs) =>
    LocalDataResetService(<LocalDataStore>[
      SharedPreferencesJourneyRepository(prefs),
      _routeRepo(prefs),
      SharedPreferencesSettingsRepository(prefs),
      SharedPreferencesHistoryRepository(prefs),
      SharedPreferencesEarnedBadgesRepository(prefs),
      SharedPreferencesCompactWindowPositionRepository(prefs),
      SharedPreferencesHideToTrayHintRepository(prefs),
    ]);

/// Drives a Start over over [prefs] at cumulative distance [cumulativeKm],
/// authoring [_newRoute]. Returns the cubit (already committed).
Future<RouteProgressCubit> _performStartOver(
  SharedPreferences prefs, {
  required double cumulativeKm,
}) async {
  final cubit = RouteProgressCubit(
    chain: vietnamProvinceChain,
    geography: vietnamProvinceGeography,
    repository: _routeRepo(prefs),
    initialPlan: await _routeRepo(prefs).loadPlan(),
  );
  cubit.updateFromDistance(cumulativeKm);
  // The launch prompt's Start over calls exactly this shipped abandon path.
  await cubit.abandonAndStartNew(_newRoute(), currentCumulativeKm: cumulativeKm);
  return cubit;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TC-716 / TC-717 (AC-9) Start over stamps a fresh offset, no engine reset', () {
    testWidgets(
      'the new route offset equals the never-reset cumulative D and '
      'journey_progress_v1 (the cumulative) is untouched',
      (tester) async {
        SharedPreferences.setMockInitialValues(_seededPrefs());
        final prefs = await SharedPreferences.getInstance();
        final journeyBefore = prefs.getString('journey_progress_v1');

        const cumulativeD = 500.0;
        final cubit = await _performStartOver(prefs, cumulativeKm: cumulativeD);
        addTearDown(cubit.close);

        // The persisted new plan carries a fresh offset == the cumulative D
        // (ADR-0005 abandon = new offset over the never-reset distance — AC-9).
        final newPlan = await _routeRepo(prefs).loadPlan();
        expect(newPlan, isNotNull);
        expect(newPlan!.routeStartOffsetKm, closeTo(cumulativeD, _tol));
        expect(newPlan.lifecycle, RouteLifecycle.active);
        // The new route restarts at routeDistanceKm == 0.
        expect(cubit.state.position!.routeDistanceKm, closeTo(0, _tol));

        // The engine's cumulative (journey_progress_v1) is NEVER reset by Start
        // over — no engine-reset call exists on this path (TC-717).
        expect(prefs.getString('journey_progress_v1'), journeyBefore);
      },
    );
  });

  group('TC-718 / TC-719 (AC-10, AC-12) Start over replaces ONLY the route keys', () {
    testWidgets(
      'route_plan_v1 changes, route_selection_v1 is cleared, every lifetime key '
      'is retained byte-for-byte — Start over is emphatically NOT a wipe',
      (tester) async {
        SharedPreferences.setMockInitialValues(_seededPrefs());
        final prefs = await SharedPreferences.getInstance();

        // Snapshot every lifetime key BEFORE.
        final before = <String, Object?>{
          for (final k in _lifetimeKeys) k: prefs.get(k),
        };
        final oldPlanBlob = prefs.getString('route_plan_v1');

        final cubit = await _performStartOver(prefs, cumulativeKm: 500);
        addTearDown(cubit.close);

        // Only the route plan changed; the stale legacy key was cleared by
        // savePlan (the v2 plan is authoritative).
        expect(prefs.getString('route_plan_v1'), isNot(oldPlanBlob));
        expect(prefs.getKeys().contains('route_selection_v1'), isFalse);

        // Every lifetime/settings key is retained byte-for-byte (AC-10).
        for (final k in _lifetimeKeys) {
          expect(prefs.get(k), before[k], reason: '$k must survive Start over');
        }
        // Negative guard (TC-719): no lifetime key was deleted.
        expect(prefs.getKeys(), containsAll(_lifetimeKeys));
      },
    );
  });

  group('TC-720 (AC-11, AC-6) relaunch after Start over offers Resume on NEW route', () {
    testWidgets(
      'the gate sees the new active route and Resume restores the NEW route, '
      'not the abandoned one',
      (tester) async {
        SharedPreferences.setMockInitialValues(_seededPrefs());
        final prefs = await SharedPreferences.getInstance();
        final soCubit = await _performStartOver(prefs, cumulativeKm: 500);
        addTearDown(soCubit.close);

        // --- Relaunch: fresh repo + gate + route cubit from the reloaded plan.
        final restored = await _routeRepo(prefs).loadPlan();
        expect(restored, isNotNull);
        expect(restored!.lifecycle, RouteLifecycle.active);
        // The reloaded plan is the NEW route (da_lat…ha_noi), not the abandoned one.
        expect(restored.orderedNodeIds.first, 'da_lat');
        expect(restored.orderedNodeIds.last, 'ha_noi');

        final gate = LaunchGateCubit(lifecycle: restored.lifecycle);
        addTearDown(gate.close);
        expect(gate.showPrompt, isTrue); // Resume vs Start over offered again

        final resumed = RouteProgressCubit(
          chain: vietnamProvinceChain,
          geography: vietnamProvinceGeography,
          repository: _routeRepo(prefs),
          initialPlan: restored,
        );
        addTearDown(resumed.close);
        // At the same cumulative the new route is at routeDistanceKm 0 (its own
        // position), not the abandoned route's progress.
        resumed.updateFromDistance(500);
        expect(resumed.state.position!.routeDistanceKm, closeTo(0, _tol));
        expect(resumed.state.selection!.start.id, 'da_lat');
      },
    );
  });

  group('TC-721 (AC-12) Start over vs Factory reset asymmetry (BR-8 carve-out)', () {
    testWidgets(
      'from an IDENTICAL seed, Start over keeps the cumulative + lifetime data '
      'while Factory reset clears them',
      (tester) async {
        // --- Run A: Start over.
        SharedPreferences.setMockInitialValues(_seededPrefs());
        final prefsA = await SharedPreferences.getInstance();
        final cubitA = await _performStartOver(prefsA, cumulativeKm: 500);
        addTearDown(cubitA.close);

        // Lifetime data survives Start over.
        expect(prefsA.getString('journey_progress_v1'), '{"distanceKm":500.0}');
        expect(prefsA.getKeys(), containsAll(_lifetimeKeys));

        // --- Run B: Factory reset over the SAME identical seed.
        SharedPreferences.setMockInitialValues(_seededPrefs());
        final prefsB = await SharedPreferences.getInstance();
        await _resetService(prefsB).clear();

        // Lifetime data is cleared by Factory reset (the deliberate exception).
        for (final k in _lifetimeKeys) {
          expect(prefsB.getKeys().contains(k), isFalse, reason: '$k should be wiped');
        }
        expect(prefsB.getKeys(), isEmpty);
      },
    );
  });
}
