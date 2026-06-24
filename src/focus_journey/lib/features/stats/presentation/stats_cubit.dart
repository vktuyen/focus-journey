/// Presentation layer. The orchestrating Cubit for the stats / badges surface.
///
/// SEPARATION / PRIVACY INVARIANT (TC-026/TC-027): this Cubit holds **no**
/// `JourneyEngine` reference and reads **no** OS signal. It consumes a plain
/// [JourneyProgress] aggregate value object per tick (fed by the app-service
/// ticker's stats-sink, mirroring the route slice's `double` distance seam) plus
/// a [RouteProgressSnapshot] of route position. It therefore *cannot* read idle
/// seconds, touch a platform channel, accrue distance, or re-derive the streak
/// metric — it only projects, aggregates, evaluates badges, and gates local
/// toasts. All stat/weekly/streak/badge math lives in pure `domain/` functions;
/// day-boundary + week logic key off the injected [Clock].
///
/// A Cubit (not an event-Bloc) so tests drive deterministic snapshots directly.
library;

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../journey/domain/clock.dart';
import '../../journey/domain/journey_progress.dart';
import '../../journey/domain/journey_state.dart';
import '../../journey/domain/travel_mode.dart';
import '../domain/app_settings.dart';
import '../domain/badge.dart';
import '../domain/badge_catalogue.dart';
import '../domain/badge_evaluator.dart';
import '../domain/best_focus_tracker.dart';
import '../domain/daily_stats.dart';
import '../domain/day_stats.dart';
import '../domain/earned_badges.dart';
import '../domain/focus_streak.dart';
import '../domain/route_progress_snapshot.dart';
import '../domain/stats_repositories.dart';
import '../domain/streak_reminder_policy.dart';
import '../domain/weekly_stats.dart';
import 'stats_view_state.dart';

/// Drives the stats / badges view from per-tick engine aggregates + route
/// position, records each completed day to the bounded history before its
/// counters zero (AC-5/AC-19), evaluates the badge catalogue (AC-13/AC-18), and
/// fires gated local toasts (AC-11/AC-12).
class StatsCubit extends Cubit<StatsViewState> {
  /// Creates the cubit with injected dependencies (no `new`-ing inside).
  StatsCubit({
    required Clock clock,
    required HistoryRepository historyRepository,
    required EarnedBadgesRepository earnedBadgesRepository,
    required Notifier notifier,
    List<BadgeDefinition>? catalogue,
    int historyCap = defaultHistoryCap,
    TimeOfDayHm streakReminderTime = defaultStreakReminderTime,
  }) : _clock = clock,
       _historyRepository = historyRepository,
       _earnedBadgesRepository = earnedBadgesRepository,
       _notifier = notifier,
       _catalogue = catalogue ?? BadgeCatalogue.badges,
       _historyCap = historyCap,
       _streakReminderTime = streakReminderTime,
       super(StatsViewState.initial());

  /// The bounded per-day history retention cap — keep ~90 most-recent days
  /// (resolved OQ default; a single tunable constant, AC-6). Pruned beyond this.
  static const int defaultHistoryCap = 90;

  final Clock _clock;
  final HistoryRepository _historyRepository;
  final EarnedBadgesRepository _earnedBadgesRepository;
  final Notifier _notifier;
  final List<BadgeDefinition> _catalogue;
  final int _historyCap;
  final TimeOfDayHm _streakReminderTime;

  // --- Mutable in-memory state (restored from the stores at load). ---
  List<DayStats> _history = <DayStats>[];
  EarnedBadges _earned = EarnedBadges.empty();
  final BestFocusTracker _bestFocus = BestFocusTracker();

  /// The local day the live daily counters currently belong to (date-only),
  /// driving the record-before-zero rollover (AC-5/AC-19).
  DateTime? _currentDay;
  Duration _todayBestFocus = Duration.zero;
  double _cumulativeDistanceAtDayStart = 0;
  double _lastCumulativeDistance = 0;

  // Notification de-dup / gating state.
  AppSettings _settings = const AppSettings();
  RouteProgressSnapshot _route = const RouteProgressSnapshot.none();
  DateTime? _reminderFiredDate;

  /// Serial tick queue (M3). The ticker fires `onSnapshot` synchronously each
  /// tick, but `onTick`'s body has awaits (repo saves, notifier). To prevent a
  /// later tick interleaving with an in-flight one and racing `_history` /
  /// `_currentDay` / `_lastSnapshotForDay`, each `onTick` chains onto the
  /// previous so exactly one body runs at a time (no interleave, no drop).
  Future<void> _tickChain = Future<void>.value();

  /// Updates the settings used for notification gating + the daily goal (called
  /// by the settings Cubit when settings change; AC-11/AC-12).
  void updateSettings(AppSettings settings) {
    _settings = settings;
  }

  /// Updates the consumed route position (fed on the same cadence as distance;
  /// AC-15). Pure data crosses this seam — no cubit reference.
  void updateRoute(RouteProgressSnapshot route) {
    _route = route;
  }

  /// Restores persisted history + earned badges at startup and seeds the live
  /// daily state from [initialProgress] (the engine's restored snapshot), then
  /// emits the first view. Handles the app-closed-across-midnight case: if the
  /// restored progress's stored day is before today, the engine has already
  /// zeroed its daily counters (journey-engine AC-10) and the prior day is
  /// recorded to history here exactly once (AC-5/AC-19/TC-020).
  Future<void> load(JourneyProgress initialProgress) async {
    _history = await _historyRepository.load();
    _earned = (await _earnedBadgesRepository.load()) ?? EarnedBadges.empty();

    final today = _dateOf(_clock.now());

    // The snapshot whose daily counters we project on load. On the same-day
    // path it is the restored snapshot as-is; on the app-closed-across-midnight
    // path the restored daily counters belong to the PRIOR day, so we project a
    // zeroed-for-today view instead (AC-19) — consistent with the engine, which
    // has already zeroed its own daily counters for the new day (AC-10).
    var loadSnapshot = initialProgress;

    // App-closed-across-midnight: the restored progress is dated before today.
    // Its non-zero daily totals belong to that prior day — record them once
    // (if not already present) before treating today as zero.
    if (initialProgress.storedDate.isBefore(today)) {
      _recordDayIfAbsent(
        DayStats(
          date: initialProgress.storedDate,
          activeTime: initialProgress.activeTimeToday,
          rawActiveTime: initialProgress.rawActiveTime,
          // AC-5: on the closed-across-midnight path we record distance/best-
          // focus as 0 — the cold-restart JourneyProgress snapshot carries
          // neither a per-day distance delta nor a best-focus run (only the
          // three daily duration counters survive). Accepted v1 limitation: a
          // day the app was closed across loses its distance/best-focus detail,
          // but its active/raw/idle totals are preserved and never lost.
          distanceKmForDay: 0,
          idleTime: initialProgress.idleTimeToday,
          bestFocusPeriod: Duration.zero,
        ),
      );
      await _historyRepository.save(_history);
      if (isClosed) {
        return;
      }

      // The daily surfaces must read zero for the new day immediately on load
      // (AC-19): keep cumulative distance, zero the three daily counters, and
      // re-date to today. The prior day's totals now live only in history.
      loadSnapshot = JourneyProgress(
        distanceKm: initialProgress.distanceKm,
        activeTimeToday: Duration.zero,
        rawActiveTime: Duration.zero,
        idleTimeToday: Duration.zero,
        state: initialProgress.state,
        mode: initialProgress.mode,
        storedDate: today,
      );
    }

    _currentDay = today;
    _bestFocus.resetForNewDay(Duration.zero);
    _todayBestFocus = Duration.zero;
    _cumulativeDistanceAtDayStart = initialProgress.distanceKm;
    _lastCumulativeDistance = initialProgress.distanceKm;
    // Seed the per-day snapshot from the (possibly zeroed) load snapshot so
    // badge evaluation + a later rollover record use the new day's figures, not
    // the prior day's stale counters.
    _lastSnapshotForDay = loadSnapshot;

    // Reset windowed badges if we restored into a new week and daily badges if
    // we restored into a new day (AC-17/AC-18), so stale earned flags clear
    // immediately on launch rather than waiting for the first tick (M2). This
    // mirrors the same reset the evaluator runs on each tick.
    await _resetExpiredBadges(today);

    _emit(loadSnapshot);
  }

  /// Consumes the engine's latest aggregate snapshot once per tick (the
  /// stats-sink seam). Detects a local-day rollover and records the completed
  /// day to history **before** the new day's counters are treated as zero
  /// (AC-5/AC-19); updates the best-focus run; re-projects; evaluates badges +
  /// fires gated toasts.
  ///
  /// M3: serialised — each call chains onto the previous so a later tick never
  /// interleaves with an in-flight one mid-await. The returned future completes
  /// when **this** tick's body has run.
  Future<void> onTick(JourneyProgress snapshot) {
    final queued = _tickChain.then((_) => _onTickBody(snapshot));
    // Keep the chain alive even if a body throws, so one failure doesn't wedge
    // every later tick; swallow on the chain (the body itself never throws in
    // practice — repo/notifier fakes/impls handle their own errors).
    _tickChain = queued.catchError((_) {});
    return queued;
  }

  Future<void> _onTickBody(JourneyProgress snapshot) async {
    if (isClosed) {
      return;
    }
    final tickDay = _dateOf(_clock.now());
    final current = _currentDay;

    if (current != null && tickDay.isAfter(current)) {
      // --- Day rollover (FORWARD only). Record the day that just ended BEFORE
      // zeroing. The snapshot the engine produced for the *previous* day's
      // totals is the last one we saw; we capture from our tracked per-day
      // figures rather than `snapshot` (which may now read zero for the new
      // day). B1: a *backward* `tickDay` (DST fall-back / NTP step-back / TZ
      // change / sleep-wake skew) must NOT move `_currentDay` backward — we keep
      // the established current day, matching the engine which treats a future
      // stored date as "today, no reset" (journey_progress.dart). The dedup in
      // `_liveDay`/`_recordDayIfAbsent` guarantees a date already in history is
      // never double-counted even if the clock then walks back onto it.
      _recordDayIfAbsent(
        DayStats(
          date: current,
          activeTime: _lastSnapshotForDay.activeTimeToday,
          rawActiveTime: _lastSnapshotForDay.rawActiveTime,
          distanceKmForDay: _distanceForDay,
          idleTime: _lastSnapshotForDay.idleTimeToday,
          bestFocusPeriod: _todayBestFocus,
        ),
      );
      await _historyRepository.save(_history);
      if (isClosed) {
        return;
      }

      // Start the new day fresh.
      _currentDay = tickDay;
      _bestFocus.resetForNewDay(snapshot.rawActiveTime);
      _todayBestFocus = Duration.zero;
      _cumulativeDistanceAtDayStart = snapshot.distanceKm;
    }

    _currentDay ??= tickDay;
    _lastSnapshotForDay = snapshot;
    _lastCumulativeDistance = snapshot.distanceKm;

    // Update the best-focus run from the raw-active counter (AC-3).
    _bestFocus.observe(snapshot.rawActiveTime);
    if (_bestFocus.bestFocusPeriod > _todayBestFocus) {
      _todayBestFocus = _bestFocus.bestFocusPeriod;
    }

    _emit(snapshot);
    await _evaluateBadges();
    if (isClosed) {
      return;
    }
    await _maybeFireStreakReminder(snapshot.state);
  }

  // The last snapshot observed for the current day, used to record the day's
  // totals at rollover before the engine zeroes them.
  JourneyProgress _lastSnapshotForDay = JourneyProgress(
    distanceKm: 0,
    activeTimeToday: Duration.zero,
    rawActiveTime: Duration.zero,
    idleTimeToday: Duration.zero,
    state: JourneyState.paused,
    mode: TravelMode.motorbike,
    storedDate: DateTime(2000),
  );

  double get _distanceForDay =>
      _lastCumulativeDistance - _cumulativeDistanceAtDayStart;

  void _recordDayIfAbsent(DayStats day) {
    final exists = _history.any((d) => d.date == day.date);
    if (exists) {
      return;
    }
    _history = <DayStats>[..._history, day];
    _pruneHistory();
  }

  /// Bounds the history to the most-recent [_historyCap] days, pruning oldest
  /// (AC-6). Sorts by date so "oldest" is well-defined regardless of insert
  /// order.
  void _pruneHistory() {
    if (_history.length <= _historyCap) {
      return;
    }
    final sorted = <DayStats>[..._history]
      ..sort((a, b) => a.date.compareTo(b.date));
    _history = sorted.sublist(sorted.length - _historyCap);
  }

  /// Projects + emits the current view from [snapshot] + history (AC-1/AC-4).
  void _emit(JourneyProgress snapshot) {
    if (isClosed) {
      return;
    }
    final today = _dateOf(_clock.now());
    final daily = DailyStatsProjection.project(
      activeTime: snapshot.activeTimeToday,
      rawActiveTime: snapshot.rawActiveTime,
      // Low #5: clamp to >= 0 so a transient backward-clock tick (where today's
      // start cumulative briefly exceeds the snapshot) never renders a negative
      // "distance today".
      distanceKm: _distanceForDayFrom(snapshot).clamp(0, double.infinity),
      idleTime: snapshot.idleTimeToday,
      bestFocusPeriod: _todayBestFocus,
    );
    // Include today's live figures in the weekly aggregate (the history holds
    // only completed days), so the week reflects in-progress work too. The
    // helper dedups by date so today's live figures can NEVER be double-counted
    // alongside an already-recorded same-date history entry (B1).
    final liveHistory = _historyWithLiveDay(snapshot, today);
    final weekly = WeeklyStatsAggregator.aggregate(liveHistory, today);
    final streak = FocusStreak.currentLength(liveHistory, today);
    emit(
      StatsViewState(
        daily: daily,
        weekly: weekly,
        currentStreakDays: streak,
        earnedBadgeIds: _earned.earnedIds,
        catalogue: _catalogue,
      ),
    );
  }

  double _distanceForDayFrom(JourneyProgress snapshot) =>
      snapshot.distanceKm - _cumulativeDistanceAtDayStart;

  DayStats _liveDay(JourneyProgress snapshot, DateTime today) => DayStats(
    date: today,
    activeTime: snapshot.activeTimeToday,
    rawActiveTime: snapshot.rawActiveTime,
    distanceKmForDay: _distanceForDayFrom(snapshot),
    idleTime: snapshot.idleTimeToday,
    bestFocusPeriod: _todayBestFocus,
  );

  /// History with today's live figures folded in for aggregation — the single
  /// source of the (history + live day) list used by weekly stats, the streak,
  /// and badge inputs. B1: if [today] already has a recorded entry in
  /// `_history` (e.g. the clock walked backward onto an already-rolled-over
  /// day), the live day **replaces** that entry rather than being appended, so
  /// a date is never present twice — preventing inflated weekly stats /
  /// totalRawActiveHours / streak inputs and over-easy badge earns.
  List<DayStats> _historyWithLiveDay(JourneyProgress snapshot, DateTime today) {
    final live = _liveDay(snapshot, today);
    final out = <DayStats>[
      for (final d in _history)
        if (d.date != today) d,
    ];
    out.add(live);
    return out;
  }

  /// Clears windowed/daily earned badges whose window/day has expired relative
  /// to [today] and persists the change (M2 / AC-17/AC-18). Used on load so a
  /// stale earned flag does not linger past its reset boundary before the first
  /// tick. The badge evaluator runs the same reset on every tick.
  Future<void> _resetExpiredBadges(DateTime today) async {
    final windowedIds = _catalogue
        .where((b) => b.scope == BadgeScope.weekly)
        .map((b) => b.id)
        .toSet();
    final dailyIds = _catalogue
        .where((b) => b.scope == BadgeScope.daily)
        .map((b) => b.id)
        .toSet();
    final reset = _earned
        .resetWindowedIfNewWeek(today, windowedIds)
        .resetDailyIfNewDay(today, dailyIds);
    if (reset != _earned) {
      _earned = reset;
      await _earnedBadgesRepository.save(_earned);
    }
  }

  Future<void> _evaluateBadges() async {
    if (isClosed) {
      return;
    }
    final today = _dateOf(_clock.now());
    // Dedup-by-date so a clock walk-back can't double-count today (B1).
    final liveHistory = _historyWithLiveDay(_lastSnapshotForDay, today);
    final totalRawMicros = liveHistory.fold<int>(
      0,
      (sum, d) => sum + d.rawActiveTime.inMicroseconds,
    );
    final context = BadgeContext(
      cumulativeDistanceKm: _lastCumulativeDistance,
      weekDistanceKm: WeeklyStatsAggregator.aggregate(
        liveHistory,
        today,
      ).distanceKm,
      percentOfCountry: _route.percentOfCountry,
      provincesPassed: _route.provincesPassed,
      routeCompleted: _route.completed,
      currentStreakDays: FocusStreak.currentLength(liveHistory, today),
      todayRawActive: _lastSnapshotForDay.rawActiveTime,
      todayBestFocusPeriod: _todayBestFocus,
      totalRawActiveHours: totalRawMicros / Duration.microsecondsPerHour,
    );

    final result = BadgeEvaluator.evaluate(
      catalogue: _catalogue,
      context: context,
      current: _earned,
      today: today,
    );

    if (result.earned != _earned) {
      _earned = result.earned;
      await _earnedBadgesRepository.save(_earned);
      if (isClosed) {
        return;
      }
      // Re-emit so the badges view reflects the new earned set + any window
      // reset (AC-18). (`_emit` self-guards on `isClosed`.)
      _emit(_lastSnapshotForDay);
    }

    // Fire one local toast per newly-earned badge (AC-12), gated by settings.
    if (_settings.canNotifyBadge) {
      for (final id in result.newlyEarned) {
        if (isClosed) {
          return;
        }
        final badge = _catalogue.firstWhere((b) => b.id == id);
        await _notifier.showBadgeEarned(
          title: badge.title,
          description: badge.description,
        );
      }
    }
  }

  Future<void> _maybeFireStreakReminder(JourneyState journeyState) async {
    if (isClosed) {
      return;
    }
    final now = _clock.now();
    final today = _dateOf(now);
    final alreadyFired = _reminderFiredDate == today;
    final todayEntry = _liveDay(_lastSnapshotForDay, today);
    final todayQualified = FocusStreak.qualifies(todayEntry);

    final fire = StreakReminderPolicy.shouldFire(
      settings: _settings,
      now: now,
      reminderTime: _streakReminderTime,
      todayQualified: todayQualified,
      alreadyFiredToday: alreadyFired,
      journeyState: journeyState,
    );
    if (!fire) {
      return;
    }
    _reminderFiredDate = today;
    // S4: derive the minutes from the locked qualifying constant so retuning it
    // can never drift the copy out of sync.
    final minutes = FocusStreak.qualifyingRawActive.inMinutes;
    await _notifier.showStreakReminder(
      title: 'Keep your focus streak alive',
      body: 'You have not reached $minutes minutes of focus today yet.',
    );
  }

  static DateTime _dateOf(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
