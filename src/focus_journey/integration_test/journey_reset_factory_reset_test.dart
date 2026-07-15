// Integration test for journey-reset Factory reset (AC-3/AC-4/AC-5).
//
// Exercises the REAL shared_preferences-backed stores + the REAL aggregating
// LocalDataResetService + the REAL FactoryResetCubit re-init seam over
// SharedPreferences.setMockInitialValues (no real disk / platform channel).
// The store list mirrors main.dart's canonical reset registry EXACTLY, so a
// wipe here is the wipe the app performs. Deterministic: a fixed clock, a mock
// activity source, no real timers / DateTime.now() / network.
//
// Traceability (one test group ↔ one case; TC + AC ids in each description):
//   TC-704  (AC-3)  confirm clears EVERY persisted key incl. both mini_window
//                   keys + the legacy route_selection_v1 key
//   TC-706  (AC-4)  after the wipe + re-init, the NEXT autosave writes
//                   zero-state — no stale value / phantom journey re-persisted
//   TC-706b (AC-4)  the freshly reconstructed in-memory model reports zero, not
//                   the pre-reset values
//   AC-5            a simulated relaunch over the wiped store lands on first-run
//                   onboarding with the Resume/Start over prompt suppressed +
//                   both mini_window keys back at first-run defaults (TC-707/708/709)
//
// Run headless: fvm flutter test integration_test/journey_reset_factory_reset_test.dart
// On device:    fvm flutter test integration_test/journey_reset_factory_reset_test.dart -d macos

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/mock_activity_source.dart';
import 'package:focus_journey/features/journey/data/shared_preferences_journey_repository.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/journey_engine.dart';
import 'package:focus_journey/features/journey/domain/journey_progress.dart';
import 'package:focus_journey/features/journey/domain/journey_state.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/mini_window/data/shared_preferences_compact_window_position_repository.dart';
import 'package:focus_journey/features/mini_window/data/shared_preferences_hide_to_tray_hint_repository.dart';
import 'package:focus_journey/features/reset/domain/local_data_reset_service.dart';
import 'package:focus_journey/features/reset/domain/local_data_store.dart';
import 'package:focus_journey/features/reset/presentation/factory_reset_cubit.dart';
import 'package:focus_journey/features/reset/presentation/launch_gate_cubit.dart';
import 'package:focus_journey/features/route/data/shared_preferences_route_repository.dart';
import 'package:focus_journey/features/route/domain/province_chain.dart';
import 'package:focus_journey/features/route/domain/province_geography.dart';
import 'package:focus_journey/features/route/presentation/route_progress_cubit.dart';
import 'package:focus_journey/features/stats/data/shared_preferences_earned_badges_repository.dart';
import 'package:focus_journey/features/stats/data/shared_preferences_history_repository.dart';
import 'package:focus_journey/features/stats/data/shared_preferences_settings_repository.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fixed clock — the engine reads only the local date, never elapsed time.
class _FixedClock implements Clock {
  _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

/// The full in-scope key set (spec "Canonical persisted-key set"). Kept here for
/// the completeness assertion; the drift guard (TC-705) is the unit test coupled
/// to `LocalDataResetService.registeredKeys`.
const Set<String> _allInScopeKeys = <String>{
  'app_settings_v1',
  'journey_progress_v1',
  'route_plan_v1',
  'route_selection_v1', // legacy — most likely to be forgotten
  'stats_history_v1',
  'earned_badges_v1',
  'mini_window.compact_position.x', // mini_window key 1
  'mini_window.compact_position.y', // mini_window key 1
  'mini_window_hide_to_tray_hint_shown_v1', // mini_window key 2
};

/// A fully-populated store: every in-scope key present with a plausible value.
Map<String, Object> _seededPrefs() => <String, Object>{
  'app_settings_v1': '{"onboardingSeen":true}',
  'journey_progress_v1': '{"distanceKm":123.4}',
  'route_plan_v1':
      '{"orderedNodeIds":["can_tho","ho_chi_minh"],"routeStartOffsetKm":0.0,"lifecycle":"active"}',
  'route_selection_v1': '{"startId":"can_tho","direction":"towardHaGiang"}',
  'stats_history_v1': '[{"date":"2026-07-01"}]',
  'earned_badges_v1': '{"ids":["first_day"]}',
  'mini_window.compact_position.x': 42.0,
  'mini_window.compact_position.y': 84.0,
  'mini_window_hide_to_tray_hint_shown_v1': true,
};

/// Builds the aggregating reset seam over the SAME store list main.dart wires
/// (the canonical registry). Returns it plus the concrete repos we assert on.
LocalDataResetService _buildResetService(SharedPreferences prefs) {
  return LocalDataResetService(<LocalDataStore>[
    SharedPreferencesJourneyRepository(prefs),
    SharedPreferencesRouteRepository(
      prefs,
      vietnamProvinceChain,
      vietnamProvinceGeography,
    ),
    SharedPreferencesSettingsRepository(prefs),
    SharedPreferencesHistoryRepository(prefs),
    SharedPreferencesEarnedBadgesRepository(prefs),
    SharedPreferencesCompactWindowPositionRepository(prefs),
    SharedPreferencesHideToTrayHintRepository(prefs),
  ]);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TC-704 (AC-3) confirm clears EVERY persisted key', () {
    testWidgets(
      'a fully-populated store is left with NO in-scope key, explicitly '
      'including both mini_window keys and the legacy route_selection_v1',
      (tester) async {
        SharedPreferences.setMockInitialValues(_seededPrefs());
        final prefs = await SharedPreferences.getInstance();

        // Sanity: everything is present before the wipe.
        expect(prefs.getKeys(), containsAll(_allInScopeKeys));

        final service = _buildResetService(prefs);
        await service.clear();

        // Completeness: none of the in-scope keys survive.
        for (final key in _allInScopeKeys) {
          expect(prefs.getKeys().contains(key), isFalse, reason: '$key survived');
        }
        // Called out by name (the ones most likely to slip).
        expect(prefs.getKeys().contains('mini_window.compact_position.x'), isFalse);
        expect(prefs.getKeys().contains('mini_window.compact_position.y'), isFalse);
        expect(
          prefs.getKeys().contains('mini_window_hide_to_tray_hint_shown_v1'),
          isFalse,
        );
        expect(prefs.getKeys().contains('route_selection_v1'), isFalse);
        // Nothing at all remains.
        expect(prefs.getKeys(), isEmpty);
      },
    );
  });

  group('TC-706 (AC-4) no stale re-persist after the wipe + re-init', () {
    testWidgets(
      'the NEXT autosave after a Factory reset writes zero-state, not the '
      'pre-reset distance / journey',
      (tester) async {
        SharedPreferences.setMockInitialValues(_seededPrefs());
        final prefs = await SharedPreferences.getInstance();
        final clock = _FixedClock(DateTime(2026, 7, 15, 9));
        final journeyRepo = SharedPreferencesJourneyRepository(prefs);

        // A live engine at a non-zero cumulative distance (the pre-reset state).
        var engine = JourneyEngine(
          clock: clock,
          activityPlugin: MockActivitySource(),
          kmPerActiveHour: 250,
        );
        engine.restore(
          JourneyProgress(
            distanceKm: 123.4,
            activeTimeToday: const Duration(hours: 1),
            rawActiveTime: const Duration(hours: 1),
            idleTimeToday: Duration.zero,
            state: JourneyState.active,
            mode: TravelMode.motorbike,
            storedDate: clock.now(),
          ),
        );
        await engine.save(journeyRepo); // pre-reset persisted state
        expect((await journeyRepo.load())!.distanceKm, closeTo(123.4, 1e-6));

        final service = _buildResetService(prefs);
        var quiesced = false;
        final resetCubit = FactoryResetCubit(
          service: service,
          // Step 1: tear down the LIVE engine so it can never autosave again.
          onQuiesce: () async => quiesced = true,
          // Step 3: rebuild a ZERO engine from the now-empty persistence.
          onReinitialise: () async {
            engine = JourneyEngine(
              clock: clock,
              activityPlugin: MockActivitySource(),
              kmPerActiveHour: 250,
            );
            await engine.loadAndRestore(journeyRepo); // empty → stays zero
          },
        );
        addTearDown(resetCubit.close);

        await resetCubit.confirmReset();
        expect(quiesced, isTrue);

        // The honesty check: simulate the NEXT autosave tick from the rebuilt
        // engine. It must write zero-state — NOT re-persist the phantom 123.4.
        await engine.save(journeyRepo);

        final persisted = await journeyRepo.load();
        expect(persisted, isNotNull);
        expect(persisted!.distanceKm, closeTo(0, 1e-6));
        // And no other in-scope key was resurrected by the re-init/save.
        expect(prefs.getKeys().contains('route_plan_v1'), isFalse);
        expect(prefs.getKeys().contains('stats_history_v1'), isFalse);
        expect(prefs.getKeys().contains('earned_badges_v1'), isFalse);
      },
    );
  });

  group('TC-706b (AC-4) reconstructed in-memory model reports zero', () {
    testWidgets(
      'after the wipe the rebuilt engine + route cubit report zero distance and '
      'no active route (nothing rehydrates the pre-reset journey)',
      (tester) async {
        SharedPreferences.setMockInitialValues(_seededPrefs());
        final prefs = await SharedPreferences.getInstance();
        final clock = _FixedClock(DateTime(2026, 7, 15, 9));

        final service = _buildResetService(prefs);
        await service.clear();

        // Reconstruct the in-memory graph from the now-empty persistence
        // (the bootstrap path a Factory reset routes through).
        final journeyRepo = SharedPreferencesJourneyRepository(prefs);
        final engine = JourneyEngine(
          clock: clock,
          activityPlugin: MockActivitySource(),
          kmPerActiveHour: 250,
        );
        await engine.loadAndRestore(journeyRepo);

        final routeRepo = SharedPreferencesRouteRepository(
          prefs,
          vietnamProvinceChain,
          vietnamProvinceGeography,
        );
        final restoredPlan = await routeRepo.loadPlan();
        final routeCubit = RouteProgressCubit(
          chain: vietnamProvinceChain,
          geography: vietnamProvinceGeography,
          repository: routeRepo,
          initialPlan: restoredPlan,
        );
        addTearDown(routeCubit.close);

        // Zero cumulative, no active route.
        expect(engine.distanceKm, closeTo(0, 1e-6));
        expect(restoredPlan, isNull);
        expect(routeCubit.state.position, isNull);
        expect(routeCubit.state.selection, isNull);
      },
    );
  });

  group('AC-5 (TC-707/708/709) relaunch after reset = first-run onboarding', () {
    testWidgets(
      'a simulated relaunch over the wiped store shows onboarding, zero stats, '
      'default window/tray, and suppresses the launch prompt',
      (tester) async {
        SharedPreferences.setMockInitialValues(_seededPrefs());
        final prefs = await SharedPreferences.getInstance();

        await _buildResetService(prefs).clear();

        // --- "Relaunch": re-read persistence with fresh repos over the wiped store.
        final settingsRepo = SharedPreferencesSettingsRepository(prefs);
        final routeRepo = SharedPreferencesRouteRepository(
          prefs,
          vietnamProvinceChain,
          vietnamProvinceGeography,
        );
        final historyRepo = SharedPreferencesHistoryRepository(prefs);
        final badgesRepo = SharedPreferencesEarnedBadgesRepository(prefs);
        final hintRepo = SharedPreferencesHideToTrayHintRepository(prefs);
        final positionRepo = SharedPreferencesCompactWindowPositionRepository(
          prefs,
        );

        // True first-run onboarding: no persisted settings → onboarding not seen.
        final settings = await settingsRepo.load();
        expect(settings, isNull);

        // Launch prompt suppressed: no active route → gate proceeds (AC-5/AC-7/TC-709).
        final plan = await routeRepo.loadPlan();
        expect(plan, isNull);
        final gate = LaunchGateCubit(lifecycle: plan?.lifecycle);
        addTearDown(gate.close);
        expect(gate.showPrompt, isFalse);

        // Zero prior stats / badges (TC-708).
        expect(await historyRepo.load(), isEmpty);
        expect(await badgesRepo.load(), isNull);

        // Window/tray back at first-run defaults (TC-707): the two mini_window
        // keys are gone, so reads fall back to defaults.
        expect(await hintRepo.hasShownHint(), isFalse);
        expect(await positionRepo.load(), isNull);
      },
    );
  });
}
