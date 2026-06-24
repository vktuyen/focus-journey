// Deterministic unit tests for StatsCubit's orchestration logic (AC-1/AC-5/
// AC-6/AC-12/AC-13/AC-19, TC-001/005/006/012/013/019/020). The cubit holds no
// engine reference and reads no OS signal — it consumes plain JourneyProgress
// aggregates + a RouteProgressSnapshot, projects/aggregates/evaluates badges,
// and fires gated local toasts. All deps are in-memory fakes + an injected
// FakeClock; no real timers, no DateTime.now(). No widget pumping here.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/journey_state.dart';
import 'package:focus_journey/features/stats/domain/app_settings.dart';
import 'package:focus_journey/features/stats/domain/badge.dart';
import 'package:focus_journey/features/stats/domain/day_stats.dart';
import 'package:focus_journey/features/stats/domain/route_progress_snapshot.dart';
import 'package:focus_journey/features/stats/domain/stats_repositories.dart';
import 'package:focus_journey/features/stats/domain/streak_reminder_policy.dart';
import 'package:focus_journey/features/stats/presentation/stats_cubit.dart';

import '../stats_test_fixtures.dart';

void main() {
  late FakeClock clock;
  late InMemoryHistoryRepository history;
  late InMemoryEarnedBadgesRepository badges;
  late RecordingNotifier notifier;

  final dayD = DateTime(2026, 6, 24, 12); // a Wednesday, noon
  final dayDPlus1 = DateTime(2026, 6, 25, 9); // next day, morning

  setUp(() {
    clock = FakeClock(dayD);
    history = InMemoryHistoryRepository();
    badges = InMemoryEarnedBadgesRepository();
    notifier = RecordingNotifier();
  });

  StatsCubit build({
    List<BadgeDefinition>? catalogue,
    int historyCap = StatsCubit.defaultHistoryCap,
    TimeOfDayHm reminderTime = defaultStreakReminderTime,
  }) {
    final cubit = StatsCubit(
      clock: clock,
      historyRepository: history,
      earnedBadgesRepository: badges,
      notifier: notifier,
      catalogue: catalogue,
      historyCap: historyCap,
      streakReminderTime: reminderTime,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  group('StatsCubit.load + onTick — daily projection (AC-1 / TC-001)', () {
    test('projectsTheFourHeadlineNumbersFromTheSnapshot', () async {
      final cubit = build();
      await cubit.load(progress(storedDate: DateTime(2026, 6, 24)));

      await cubit.onTick(
        progress(
          storedDate: DateTime(2026, 6, 24),
          distanceKm: 8,
          activeTimeToday: const Duration(minutes: 30),
          rawActiveTime: const Duration(minutes: 26),
          idleTimeToday: const Duration(minutes: 4),
        ),
      );

      final daily = cubit.state.daily;
      expect(daily.activeTime, const Duration(minutes: 30));
      expect(daily.rawActiveTime, const Duration(minutes: 26));
      expect(daily.distanceKm, 8); // delta from day-start cumulative (0).
      expect(daily.idleTime, const Duration(minutes: 4));
    });

    test('distanceForDay_isTheDeltaFromDayStartCumulative', () async {
      final cubit = build();
      // Start the day already at 100 km cumulative.
      await cubit.load(
        progress(storedDate: DateTime(2026, 6, 24), distanceKm: 100),
      );
      await cubit.onTick(
        progress(
          storedDate: DateTime(2026, 6, 24),
          distanceKm: 105,
          rawActiveTime: const Duration(minutes: 10),
        ),
      );
      expect(cubit.state.daily.distanceKm, 5);
    });
  });

  group('StatsCubit — record-before-zero on running rollover (AC-5/AC-19)', () {
    test('recordsDayDToHistory_beforeTreatingDPlus1AsZero (TC-019)', () async {
      final cubit = build();
      await cubit.load(progress(storedDate: DateTime(2026, 6, 24)));

      // Day D accrues.
      await cubit.onTick(
        progress(
          storedDate: DateTime(2026, 6, 24),
          distanceKm: 12,
          activeTimeToday: const Duration(minutes: 40),
          rawActiveTime: const Duration(minutes: 35),
          idleTimeToday: const Duration(minutes: 6),
        ),
      );

      // Clock crosses midnight; the engine has zeroed its daily counters for D+1.
      clock.setNow(dayDPlus1);
      await cubit.onTick(
        progress(
          storedDate: DateTime(2026, 6, 25),
          distanceKm: 12, // cumulative carries over; today's delta is 0
          rawActiveTime: Duration.zero,
        ),
      );

      // Day D landed in history with its non-zero totals.
      final recorded = history.saves
          .expand((s) => s)
          .where((d) => d.date == DateTime(2026, 6, 24));
      expect(recorded, isNotEmpty);
      final dEntry = recorded.first;
      expect(dEntry.activeTime, const Duration(minutes: 40));
      expect(dEntry.rawActiveTime, const Duration(minutes: 35));

      // The daily surface now reads zero for D+1.
      expect(cubit.state.daily.rawActiveTime, Duration.zero);
      expect(cubit.state.daily.distanceKm, 0);
    });

    test(
      'dayDRecordedExactlyOnce_acrossSeveralDPlus1Ticks (no double-record)',
      () async {
        final cubit = build();
        await cubit.load(progress(storedDate: DateTime(2026, 6, 24)));
        await cubit.onTick(
          progress(
            storedDate: DateTime(2026, 6, 24),
            rawActiveTime: const Duration(minutes: 30),
          ),
        );

        clock.setNow(dayDPlus1);
        await cubit.onTick(progress(storedDate: DateTime(2026, 6, 25)));
        await cubit.onTick(progress(storedDate: DateTime(2026, 6, 25)));
        await cubit.onTick(progress(storedDate: DateTime(2026, 6, 25)));

        final dCount = history.stored
            .where((d) => d.date == DateTime(2026, 6, 24))
            .length;
        expect(dCount, 1);
      },
    );
  });

  group('StatsCubit.load — app-closed-across-midnight (AC-5/AC-19 / TC-020)', () {
    test('restoredDDatedProgress_onDPlus1_recordsDOnceAndZeroesDaily', () async {
      clock.setNow(dayDPlus1); // launched on D+1
      final cubit = build();

      // The restored snapshot is dated D with non-zero daily totals (the engine
      // has not yet zeroed because the app was closed across midnight).
      await cubit.load(
        progress(
          storedDate: DateTime(2026, 6, 24),
          distanceKm: 50,
          activeTimeToday: const Duration(minutes: 50),
          rawActiveTime: const Duration(minutes: 45),
          idleTimeToday: const Duration(minutes: 5),
        ),
      );

      // D was recorded to history exactly once.
      final dEntries = history.stored.where(
        (d) => d.date == DateTime(2026, 6, 24),
      );
      expect(dEntries.length, 1);
      expect(dEntries.first.rawActiveTime, const Duration(minutes: 45));

      // AC-19: the daily surface reads zero for D+1 IMMEDIATELY ON LOAD — the
      // prior day's totals live only in history now, not on today's card. The
      // day-start cumulative is anchored at the restored distance, so D+1's
      // distance delta also starts at zero (the missed day is not reconstructed).
      expect(cubit.state.daily.activeTime, Duration.zero);
      expect(cubit.state.daily.rawActiveTime, Duration.zero);
      expect(cubit.state.daily.idleTime, Duration.zero);
      expect(cubit.state.daily.distanceKm, 0);

      // The first zeroed D+1 tick keeps the daily surface at zero — and D is NOT
      // re-recorded (no double-record).
      await cubit.onTick(
        progress(
          storedDate: DateTime(2026, 6, 25),
          distanceKm: 50, // cumulative carries over; today's delta is 0
          rawActiveTime: Duration.zero,
        ),
      );
      expect(cubit.state.daily.rawActiveTime, Duration.zero);
      expect(cubit.state.daily.distanceKm, 0);
      expect(
        history.stored.where((d) => d.date == DateTime(2026, 6, 24)).length,
        1,
      );
    });

    test('restoredSameDayProgress_doesNotRecordToHistory', () async {
      clock.setNow(dayD); // same local day as the stored date
      final cubit = build();
      await cubit.load(
        progress(
          storedDate: DateTime(2026, 6, 24),
          rawActiveTime: const Duration(minutes: 30),
        ),
      );
      expect(
        history.stored.where((d) => d.date == DateTime(2026, 6, 24)),
        isEmpty,
      );
    });
  });

  group('StatsCubit — bounded history pruning (AC-6 / TC-006)', () {
    test('countNeverExceedsCap_andOldestIsDropped', () async {
      // Small cap so the test does not depend on the literal 90.
      const cap = 3;
      // Seed cap days already present (oldest first).
      final base = DateTime(2026, 6, 1);
      history.seed(<DayStats>[
        for (var i = 0; i < cap; i++)
          dayStats(
            base.add(Duration(days: i)),
            rawActiveTime: const Duration(minutes: 30),
          ),
      ]);

      // Start a run on a day after the seeded window, then roll to the next day
      // so the just-finished day is recorded — overflowing the cap.
      final startDay = base.add(const Duration(days: 10));
      clock.setNow(DateTime(startDay.year, startDay.month, startDay.day, 12));
      final cubit = build(historyCap: cap);
      await cubit.load(progress(storedDate: startDay));
      await cubit.onTick(
        progress(
          storedDate: startDay,
          rawActiveTime: const Duration(minutes: 30),
        ),
      );

      final next = startDay.add(const Duration(days: 1));
      clock.setNow(DateTime(next.year, next.month, next.day, 9));
      await cubit.onTick(progress(storedDate: next));

      // Never exceeds the cap, and the oldest seeded day was pruned.
      expect(history.stored.length, lessThanOrEqualTo(cap));
      expect(history.stored.any((d) => d.date == base), isFalse);
      // The most-recent in-window day (the just-finished run day) is retained.
      expect(history.stored.any((d) => d.date == startDay), isTrue);
    });
  });

  group('StatsCubit — badge earn + gated toast (AC-13/AC-12 / TC-013)', () {
    BadgeDefinition distanceBadge() => BadgeDefinition(
      id: 'test_distance',
      title: 'Test distance',
      description: 'cross 1 km',
      family: BadgeFamily.distance,
      scope: BadgeScope.permanent,
      isEarned: (c) => c.cumulativeDistanceKm >= 1,
    );

    test('crossingAThreshold_earnsPersistsAndFiresOneBadgeToast', () async {
      final cubit = build(catalogue: <BadgeDefinition>[distanceBadge()]);
      cubit.updateSettings(const AppSettings()); // notifications on by default
      await cubit.load(progress(storedDate: DateTime(2026, 6, 24)));

      await cubit.onTick(
        progress(
          storedDate: DateTime(2026, 6, 24),
          distanceKm: 5,
          rawActiveTime: const Duration(minutes: 10),
        ),
      );

      expect(cubit.state.earnedBadgeIds, contains('test_distance'));
      expect(badges.saves.last.contains('test_distance'), isTrue);
      expect(notifier.badgeToasts.length, 1);
    });

    test('masterNotificationsOff_earnsBadgeButFiresNoToast (AC-11)', () async {
      final cubit = build(catalogue: <BadgeDefinition>[distanceBadge()]);
      cubit.updateSettings(const AppSettings(notificationsEnabled: false));
      await cubit.load(progress(storedDate: DateTime(2026, 6, 24)));

      await cubit.onTick(
        progress(
          storedDate: DateTime(2026, 6, 24),
          distanceKm: 5,
          rawActiveTime: const Duration(minutes: 10),
        ),
      );
      expect(cubit.state.earnedBadgeIds, contains('test_distance'));
      expect(notifier.badgeToasts, isEmpty);
    });

    test('alreadyEarnedBadge_doesNotReFireOnSubsequentTicks', () async {
      final cubit = build(catalogue: <BadgeDefinition>[distanceBadge()]);
      cubit.updateSettings(const AppSettings());
      await cubit.load(progress(storedDate: DateTime(2026, 6, 24)));
      await cubit.onTick(
        progress(storedDate: DateTime(2026, 6, 24), distanceKm: 5),
      );
      await cubit.onTick(
        progress(storedDate: DateTime(2026, 6, 24), distanceKm: 6),
      );
      expect(notifier.badgeToasts.length, 1);
    });

    test('routeBadge_consumesInjectedRoutePosition (AC-15)', () async {
      final routeBadge = BadgeDefinition(
        id: 'test_route',
        title: 'Halfway',
        description: '50%',
        family: BadgeFamily.journeyProgress,
        scope: BadgeScope.permanent,
        isEarned: (c) => c.percentOfCountry >= 50,
      );
      final cubit = build(catalogue: <BadgeDefinition>[routeBadge]);
      cubit.updateSettings(const AppSettings());
      cubit.updateRoute(
        const RouteProgressSnapshot(
          percentOfCountry: 60,
          provincesPassed: 3,
          completed: false,
        ),
      );
      await cubit.load(progress(storedDate: DateTime(2026, 6, 24)));
      await cubit.onTick(progress(storedDate: DateTime(2026, 6, 24)));
      expect(cubit.state.earnedBadgeIds, contains('test_route'));
    });
  });

  group('StatsCubit — gated streak reminder (AC-12 / TC-012)', () {
    test('unqualifiedIdlePastReminderTime_firesOnceThenNoNag', () async {
      // Clock at 21:00 (past the default 20:00 reminder).
      clock.setNow(DateTime(2026, 6, 24, 21));
      final cubit = build();
      cubit.updateSettings(const AppSettings());
      await cubit.load(progress(storedDate: DateTime(2026, 6, 24)));

      // Below the 25-min bar and idle: should fire once.
      await cubit.onTick(
        progress(
          storedDate: DateTime(2026, 6, 24),
          rawActiveTime: const Duration(minutes: 5),
          state: JourneyState.idle,
        ),
      );
      expect(notifier.streakToasts.length, 1);

      // Same day, re-trigger: no nag.
      await cubit.onTick(
        progress(
          storedDate: DateTime(2026, 6, 24),
          rawActiveTime: const Duration(minutes: 6),
          state: JourneyState.idle,
        ),
      );
      expect(notifier.streakToasts.length, 1);
    });

    test('todayAlreadyQualified_firesNoReminder', () async {
      clock.setNow(DateTime(2026, 6, 24, 21));
      final cubit = build();
      cubit.updateSettings(const AppSettings());
      await cubit.load(progress(storedDate: DateTime(2026, 6, 24)));
      await cubit.onTick(
        progress(
          storedDate: DateTime(2026, 6, 24),
          rawActiveTime: const Duration(minutes: 30), // already qualified
          state: JourneyState.idle,
        ),
      );
      expect(notifier.streakToasts, isEmpty);
    });

    test('whileActivelyProgressing_firesNoReminder', () async {
      clock.setNow(DateTime(2026, 6, 24, 21));
      final cubit = build();
      cubit.updateSettings(const AppSettings());
      await cubit.load(progress(storedDate: DateTime(2026, 6, 24)));
      await cubit.onTick(
        progress(
          storedDate: DateTime(2026, 6, 24),
          rawActiveTime: const Duration(minutes: 5),
          state: JourneyState.active,
        ),
      );
      expect(notifier.streakToasts, isEmpty);
    });

    test('beforeReminderTime_firesNoReminder', () async {
      clock.setNow(DateTime(2026, 6, 24, 9)); // morning, before 20:00
      final cubit = build();
      cubit.updateSettings(const AppSettings());
      await cubit.load(progress(storedDate: DateTime(2026, 6, 24)));
      await cubit.onTick(
        progress(
          storedDate: DateTime(2026, 6, 24),
          rawActiveTime: const Duration(minutes: 5),
          state: JourneyState.idle,
        ),
      );
      expect(notifier.streakToasts, isEmpty);
    });
  });

  // B1 regression: a backwards clock move after a forward rollover must not
  // move _currentDay backward nor double-count "today" in the weekly / streak /
  // badge inputs. Reproduces the DST fall-back / NTP step-back / TZ-change /
  // sleep-wake skew hazard.
  group('StatsCubit — backwards clock after rollover (B1 / AC-4/16/17)', () {
    test('backwardsClockAfterRollover_doesNotDoubleCountTodayInWeekly', () async {
      // Start on day D with real raw-active work.
      clock.setNow(dayD);
      final cubit = build();
      await cubit.load(progress(storedDate: DateTime(2026, 6, 24)));
      await cubit.onTick(
        progress(
          storedDate: DateTime(2026, 6, 24),
          distanceKm: 10,
          rawActiveTime: const Duration(minutes: 40),
        ),
      );

      // Forward roll to D+1: D is recorded to history, the new day starts fresh.
      clock.setNow(dayDPlus1);
      await cubit.onTick(
        progress(
          storedDate: DateTime(2026, 6, 25),
          distanceKm: 10, // cumulative carries; today's delta is 0
          rawActiveTime: Duration.zero,
        ),
      );
      expect(
        history.stored.where((d) => d.date == DateTime(2026, 6, 24)).length,
        1,
        reason: 'D recorded exactly once on the forward roll',
      );

      final weeklyAfterRoll = cubit.state.weekly;

      // Now the clock walks BACKWARD onto D (e.g. NTP correction / DST fall-back
      // / sleep-wake skew). _currentDay must NOT move back; D (already in
      // history) must NOT be double-counted by the live-day append.
      clock.setNow(dayD); // back onto 2026-06-24
      await cubit.onTick(
        progress(
          storedDate: DateTime(2026, 6, 24),
          distanceKm: 10,
          rawActiveTime: const Duration(minutes: 40),
        ),
      );

      // D still appears exactly once in stored history (no spurious re-record).
      expect(
        history.stored.where((d) => d.date == DateTime(2026, 6, 24)).length,
        1,
        reason: 'backwards clock must not re-record an already-stored day',
      );

      // The weekly raw-active total must not have inflated beyond the single
      // real D contribution (40m) — i.e. D is counted once, not twice.
      expect(
        cubit.state.weekly.rawActiveTime,
        const Duration(minutes: 40),
        reason:
            'today (D) is deduped against the history entry, not summed twice',
      );
      // And the streak counts D once (a single qualifying day), not two.
      expect(cubit.state.weekly.daysActive, weeklyAfterRoll.daysActive);
    });
  });

  // B2 regression: an already-scheduled tick whose awaited futures resolve AFTER
  // the cubit is closed must not throw a Bloc emit-after-close StateError.
  group('StatsCubit — emit-after-close safety (B2)', () {
    test('tickResolvingAfterClose_doesNotThrow', () async {
      clock.setNow(dayD);
      final slowNotifier = _CompleterNotifier();
      final cubit = StatsCubit(
        clock: clock,
        historyRepository: history,
        earnedBadgesRepository: badges,
        notifier: slowNotifier,
        // A tiny catalogue with an always-earnable badge so the badge path
        // (which awaits the notifier) is exercised on this tick.
        catalogue: <BadgeDefinition>[
          BadgeDefinition(
            id: 'always',
            title: 'Always',
            description: 'always earned',
            family: BadgeFamily.focusTime,
            scope: BadgeScope.permanent,
            isEarned: (_) => true,
          ),
        ],
      );
      cubit.updateSettings(const AppSettings());
      await cubit.load(progress(storedDate: DateTime(2026, 6, 24)));

      // Fire a tick but DO NOT await it — it parks on the notifier's future.
      final tickFuture = cubit.onTick(
        progress(
          storedDate: DateTime(2026, 6, 24),
          rawActiveTime: const Duration(minutes: 30),
        ),
      );

      // Close the cubit while the tick is mid-await (mirrors main.dart disposing
      // the ticker then close()-ing the cubit while a tick is in flight).
      await cubit.close();

      // Resolve the parked notifier future, letting the tick resume after close.
      slowNotifier.completeAll();

      // The tick must complete without throwing an emit-after-close StateError.
      await expectLater(tickFuture, completes);
    });
  });

  // M3 regression: ticks are serialised. The ticker fires onSnapshot
  // synchronously; a slow-disk tick N+1 must NOT interleave with tick N
  // mid-await and race _history / _currentDay / _lastSnapshotForDay.
  group('StatsCubit — serialised ticks, no interleave (M3)', () {
    test('overlappingTicks_doNotInterleaveOrDoubleRecord', () async {
      clock.setNow(dayD);
      final gated = _GatedHistoryRepository();
      final cubit = StatsCubit(
        clock: clock,
        historyRepository: gated,
        earnedBadgesRepository: badges,
        notifier: notifier,
      );
      cubit.updateSettings(const AppSettings());
      addTearDown(cubit.close);

      // Establish day D with some work (no save yet — no rollover).
      await cubit.onTick(
        progress(
          storedDate: DateTime(2026, 6, 24),
          distanceKm: 10,
          rawActiveTime: const Duration(minutes: 40),
        ),
      );

      // Fire tick A that rolls D -> D+1: its body records D and parks on the
      // gated history save. DO NOT await it.
      clock.setNow(dayDPlus1);
      final tickA = cubit.onTick(
        progress(
          storedDate: DateTime(2026, 6, 25),
          distanceKm: 10,
          rawActiveTime: Duration.zero,
        ),
      );

      // Let tick A reach its parked save.
      await Future<void>.delayed(Duration.zero);
      expect(
        gated.saveCallsStarted,
        1,
        reason: 'tick A is parked on its first history save',
      );

      // Fire tick B WHILE tick A is parked. With serialisation, B must not start
      // its body (no second save begins) until A completes.
      final tickB = cubit.onTick(
        progress(
          storedDate: DateTime(2026, 6, 25),
          distanceKm: 10,
          rawActiveTime: const Duration(minutes: 5),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        gated.saveCallsStarted,
        1,
        reason: 'tick B must wait — its body has not run while A is parked',
      );

      // Release A's save; both ticks now drain in order.
      gated.releaseNext();
      await tickA;
      await tickB;

      // D recorded exactly once across both ticks (no double-record from a race).
      expect(
        gated.stored.where((d) => d.date == DateTime(2026, 6, 24)).length,
        1,
      );
      // Final daily reflects D+1's last snapshot (5 min raw), not an interleaved
      // mix — _lastSnapshotForDay was not clobbered mid-await.
      expect(cubit.state.daily.rawActiveTime, const Duration(minutes: 5));
    });
  });
}

/// A [Notifier] whose toast futures park until [completeAll] is called, so a
/// test can resolve them AFTER closing the cubit (B2 emit-after-close).
class _CompleterNotifier implements Notifier {
  final List<Completer<void>> _pending = <Completer<void>>[];

  void completeAll() {
    for (final c in _pending) {
      if (!c.isCompleted) {
        c.complete();
      }
    }
  }

  Future<void> _park() {
    final c = Completer<void>();
    _pending.add(c);
    return c.future;
  }

  @override
  Future<void> showBadgeEarned({
    required String title,
    required String description,
  }) => _park();

  @override
  Future<void> showStreakReminder({
    required String title,
    required String body,
  }) => _park();
}

/// A [HistoryRepository] whose `save` parks on a completer the test releases one
/// at a time, so a tick can be held mid-await to exercise tick serialisation
/// (M3). Records how many saves have *started* so the test can assert that a
/// later tick's body has not begun while an earlier one is parked.
class _GatedHistoryRepository implements HistoryRepository {
  List<DayStats> _stored = <DayStats>[];
  final List<Completer<void>> _gates = <Completer<void>>[];

  /// Count of `save` calls that have begun (parked or completed).
  int saveCallsStarted = 0;

  List<DayStats> get stored => List<DayStats>.unmodifiable(_stored);

  /// Releases the oldest parked save so it can complete.
  void releaseNext() {
    if (_gates.isNotEmpty) {
      _gates.removeAt(0).complete();
    }
  }

  @override
  Future<List<DayStats>> load() async => List<DayStats>.of(_stored);

  @override
  Future<void> save(List<DayStats> history) async {
    saveCallsStarted++;
    final gate = Completer<void>();
    _gates.add(gate);
    await gate.future;
    _stored = List<DayStats>.of(history);
  }
}
