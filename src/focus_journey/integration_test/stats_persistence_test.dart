// Persistence + day-boundary integration tests for local-stats.
//
// Exercises the REAL shared_preferences-backed stores
// (SharedPreferencesHistoryRepository / ...SettingsRepository /
// ...EarnedBadgesRepository) over SharedPreferences.setMockInitialValues (no
// real disk / platform channel) plus a real StatsCubit driven by a MUTABLE
// CLOCK and scripted JourneyProgress snapshots. A "restart" = a fresh
// StatsCubit / SettingsCubit constructed from the reloaded blobs. No real
// timers, no DateTime.now(), no real OS waits.
//
// Covers:
//   TC-005  each completed day is recorded to history BEFORE its counters zero
//   TC-007  history + settings + earned-badges persist and reload identically
//           across a simulated restart (no new store type / key namespace)
//   TC-019  daily surfaces reset at local midnight while cumulative persists,
//           with the app RUNNING across midnight
//   TC-020  daily surfaces reset across midnight when the app was CLOSED across
//           midnight (restore on D+1 records D exactly once, no double-record)
//
// Runs headless under `flutter test` and on a desktop device:
//   fvm flutter test integration_test/stats_persistence_test.dart
//   fvm flutter test integration_test/stats_persistence_test.dart -d macos

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/journey_progress.dart';
import 'package:focus_journey/features/journey/domain/journey_state.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/stats/data/shared_preferences_earned_badges_repository.dart';
import 'package:focus_journey/features/stats/data/shared_preferences_history_repository.dart';
import 'package:focus_journey/features/stats/data/shared_preferences_settings_repository.dart';
import 'package:focus_journey/features/stats/domain/app_settings.dart';
import 'package:focus_journey/features/stats/domain/earned_badges.dart';
import 'package:focus_journey/features/stats/domain/stats_repositories.dart';
import 'package:focus_journey/features/stats/presentation/stats_cubit.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A clock whose value is re-pinned by the test to cross day boundaries.
class _MutableClock implements Clock {
  _MutableClock(this._now);
  DateTime _now;
  void set(DateTime now) => _now = now;
  @override
  DateTime now() => _now;
}

JourneyProgress _progress({
  required DateTime day,
  Duration active = Duration.zero,
  Duration raw = Duration.zero,
  Duration idle = Duration.zero,
  double cumulativeKm = 0,
  JourneyState state = JourneyState.active,
}) {
  // Honesty invariant: journey time is always >= raw active time.
  final journey = active >= raw ? active : raw;
  return JourneyProgress(
    distanceKm: cumulativeKm,
    activeTimeToday: journey,
    rawActiveTime: raw,
    idleTimeToday: idle,
    state: state,
    mode: TravelMode.motorbike,
    storedDate: day,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('TC-005 / TC-019 record-day-before-zero, running across midnight', () {
    testWidgets(
      'a completed day is persisted with its non-zero totals before D+1 zeroes',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final history = SharedPreferencesHistoryRepository(prefs);
        final badges = SharedPreferencesEarnedBadgesRepository(prefs);
        final clock = _MutableClock(DateTime(2026, 6, 24, 9)); // day D, morning

        final cubit = StatsCubit(
          clock: clock,
          historyRepository: history,
          earnedBadgesRepository: badges,
          notifier: _Notifier(),
        );
        addTearDown(cubit.close);

        // Start the day at zero cumulative so today's delta is the cumulative.
        await cubit.load(
          _progress(
            day: DateTime(2026, 6, 24),
            active: Duration.zero,
            raw: Duration.zero,
            idle: Duration.zero,
            cumulativeKm: 0,
          ),
        );
        // Accrue real activity for day D.
        await cubit.onTick(
          _progress(
            day: DateTime(2026, 6, 24),
            active: const Duration(minutes: 90),
            raw: const Duration(minutes: 80),
            idle: const Duration(minutes: 10),
            cumulativeKm: 15,
          ),
        );
        // Daily surface for D is non-zero.
        expect(cubit.state.daily.rawActiveTime, const Duration(minutes: 80));
        expect(cubit.state.daily.distanceKm, closeTo(15, 1e-6));

        // --- Cross midnight (clock to D+1) and tick: engine has zeroed daily. ---
        clock.set(DateTime(2026, 6, 25, 0, 1));
        await cubit.onTick(
          _progress(
            day: DateTime(2026, 6, 25),
            active: Duration.zero,
            raw: Duration.zero,
            idle: Duration.zero,
            cumulativeKm: 15, // cumulative persists across the boundary
          ),
        );

        // Daily surfaces zero for D+1.
        expect(cubit.state.daily.rawActiveTime, Duration.zero);
        expect(cubit.state.daily.distanceKm, closeTo(0, 1e-6));

        // Day D was recorded to the persisted history with its NON-ZERO totals
        // (recorded before zeroing — no day's totals lost across the boundary).
        final saved = await history.load();
        final dayD = saved.where((d) => d.dateIso == '2026-06-24').toList();
        expect(dayD, hasLength(1), reason: 'D recorded exactly once');
        expect(dayD.single.rawActiveTime, const Duration(minutes: 80));
        expect(dayD.single.activeTime, const Duration(minutes: 90));
        expect(dayD.single.distanceKmForDay, closeTo(15, 1e-6));
      },
    );
  });

  group('TC-020 closed-across-midnight: restore on D+1 records D once', () {
    // StatsCubit.load documents that when the restored snapshot's stored day is
    // before today, it records the prior day to history (AC-5) before treating
    // today as zero (AC-19). We feed exactly that documented input.
    JourneyProgress priorDay() => _progress(
      day: DateTime(2026, 6, 24), // stored date is the PRIOR day
      active: const Duration(minutes: 120),
      raw: const Duration(minutes: 100),
      idle: const Duration(minutes: 30),
      cumulativeKm: 40,
    );

    testWidgets('the prior day D is recorded to history exactly once (AC-5)', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final history = SharedPreferencesHistoryRepository(prefs);
      final badges = SharedPreferencesEarnedBadgesRepository(prefs);
      final clock = _MutableClock(DateTime(2026, 6, 25, 8)); // D+1

      final cubit = StatsCubit(
        clock: clock,
        historyRepository: history,
        earnedBadgesRepository: badges,
        notifier: _Notifier(),
      );
      addTearDown(cubit.close);
      await cubit.load(priorDay());

      // D's totals landed in history exactly once with its non-zero totals.
      final saved = await history.load();
      final dayD = saved.where((d) => d.dateIso == '2026-06-24').toList();
      expect(dayD, hasLength(1), reason: 'D recorded exactly once');
      expect(dayD.single.rawActiveTime, const Duration(minutes: 100));

      // Re-loading again (idempotent restore) must NOT double-record D.
      final cubit2 = StatsCubit(
        clock: clock,
        historyRepository: history,
        earnedBadgesRepository: badges,
        notifier: _Notifier(),
      );
      addTearDown(cubit2.close);
      await cubit2.load(priorDay());
      final saved2 = await history.load();
      expect(
        saved2.where((d) => d.dateIso == '2026-06-24').length,
        1,
        reason: 'absent-guard prevents a duplicate D entry',
      );
    });

    testWidgets('daily surface zeroes for D+1 after recording D (AC-19)', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final history = SharedPreferencesHistoryRepository(prefs);
      final badges = SharedPreferencesEarnedBadgesRepository(prefs);
      final clock = _MutableClock(DateTime(2026, 6, 25, 8)); // D+1

      final cubit = StatsCubit(
        clock: clock,
        historyRepository: history,
        earnedBadgesRepository: badges,
        notifier: _Notifier(),
      );
      addTearDown(cubit.close);
      await cubit.load(priorDay());

      // AC-19: the DAILY surface must read zero for D+1 once D is recorded —
      // the prior day's totals must not appear as today's.
      expect(cubit.state.daily.rawActiveTime, Duration.zero);
      expect(cubit.state.daily.activeTime, Duration.zero);
      expect(cubit.state.daily.distanceKm, closeTo(0, 1e-6));
    });
  });

  group('TC-007 history + settings + earned badges reload identically', () {
    testWidgets(
      'a simulated restart restores every store with no new key namespace',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final history = SharedPreferencesHistoryRepository(prefs);
        final settings = SharedPreferencesSettingsRepository(prefs);
        final badges = SharedPreferencesEarnedBadgesRepository(prefs);

        // --- Session 1: persist a day + settings + an earned badge. ---
        final clock = _MutableClock(DateTime(2026, 6, 24, 9));
        final cubit = StatsCubit(
          clock: clock,
          historyRepository: history,
          earnedBadgesRepository: badges,
          notifier: _Notifier(),
        );
        addTearDown(cubit.close);
        await cubit.load(
          _progress(
            day: DateTime(2026, 6, 24),
            active: Duration.zero,
            raw: Duration.zero,
            idle: Duration.zero,
            cumulativeKm: 0,
          ),
        );
        await cubit.onTick(
          _progress(
            day: DateTime(2026, 6, 24),
            active: const Duration(minutes: 40),
            raw: const Duration(minutes: 30),
            idle: const Duration(minutes: 5),
            cumulativeKm: 8,
          ),
        );
        // Roll over so the day is persisted.
        clock.set(DateTime(2026, 6, 25, 0, 1));
        await cubit.onTick(
          _progress(
            day: DateTime(2026, 6, 25),
            active: Duration.zero,
            raw: Duration.zero,
            idle: Duration.zero,
            cumulativeKm: 8,
          ),
        );

        // Persist settings + an earned badge through the real stores.
        await settings.save(
          const AppSettings(idleThreshold: Duration(minutes: 10)),
        );
        await badges.save(
          EarnedBadges(earnedIds: <String>{'distance_first_100km'}),
        );

        final historyBefore = await history.load();
        expect(
          historyBefore.where((d) => d.dateIso == '2026-06-24'),
          hasLength(1),
        );

        // The slice persisted only its three keys — no new store type / namespace.
        expect(prefs.getKeys(), <String>{
          SharedPreferencesHistoryRepository.storageKey,
          SharedPreferencesSettingsRepository.storageKey,
          SharedPreferencesEarnedBadgesRepository.storageKey,
        });

        // --- Session 2 ("relaunch"): fresh repos over the same prefs. ---
        final prefs2 = await SharedPreferences.getInstance();
        final history2 = SharedPreferencesHistoryRepository(prefs2);
        final settings2 = SharedPreferencesSettingsRepository(prefs2);
        final badges2 = SharedPreferencesEarnedBadgesRepository(prefs2);

        final restoredHistory = await history2.load();
        final restoredSettings = await settings2.load();
        final restoredBadges = await badges2.load();

        // History reloads identically (recompute would be identical from it).
        expect(
          restoredHistory.map((d) => d.toJson()),
          historyBefore.map((d) => d.toJson()),
        );
        // Settings round-trip (the engine-affecting threshold restored).
        expect(restoredSettings!.idleThreshold, const Duration(minutes: 10));
        // Earned badges round-trip.
        expect(restoredBadges!.contains('distance_first_100km'), isTrue);
      },
    );
  });
}

/// A no-op notifier (no real OS toast) for the persistence tests.
class _Notifier implements Notifier {
  @override
  Future<void> showBadgeEarned({
    required String title,
    required String description,
  }) async {}

  @override
  Future<void> showStreakReminder({
    required String title,
    required String body,
  }) async {}
}
