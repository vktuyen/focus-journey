// Shared deterministic test doubles for the local-stats slice (unit layer).
//
// Everything here is in-memory and clock-injected — no real timers, no real OS,
// no DateTime.now(). These mirror the journey/route fakes (FakeClock from the
// journey cubit test; the in-memory recording repositories from the route
// fixtures) so the stats unit suite stays equally deterministic.
//
//  - FakeClock                       scriptable Clock (settable now)
//  - InMemoryHistoryRepository       HistoryRepository over an in-memory blob
//  - InMemoryEarnedBadgesRepository  EarnedBadgesRepository over an in-memory blob
//  - InMemorySettingsRepository      SettingsRepository over an in-memory blob
//  - FakeStartupController           StartupController (records get/set)
//  - RecordingNotifier               Notifier (records toast requests)
//  - dayStats / progress helpers     terse builders for seeding history/snapshots

import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/journey_progress.dart';
import 'package:focus_journey/features/journey/domain/journey_state.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/stats/domain/app_settings.dart';
import 'package:focus_journey/features/stats/domain/day_stats.dart';
import 'package:focus_journey/features/stats/domain/earned_badges.dart';
import 'package:focus_journey/features/stats/domain/stats_repositories.dart';

/// A fully scriptable [Clock]: tests set [now] explicitly (mirrors the journey
/// cubit test's FakeClock so the stats tests stay equally deterministic).
class FakeClock implements Clock {
  FakeClock(this._now);

  DateTime _now;

  void setNow(DateTime value) => _now = value;

  @override
  DateTime now() => _now;
}

/// In-memory [HistoryRepository]. Persists the list across "restart" — a fresh
/// cubit constructed with the same instance restores the saved list. Records
/// save calls so ordering assertions (record-before-zero, AC-5) are possible.
class InMemoryHistoryRepository implements HistoryRepository {
  List<DayStats> _stored = <DayStats>[];

  /// All persisted blobs, in order — index 0 is the first save (AC-5 ordering).
  final List<List<DayStats>> saves = <List<DayStats>>[];

  /// Seeds the store as if a prior run had persisted [history] (a "saved blob").
  void seed(List<DayStats> history) => _stored = List<DayStats>.of(history);

  /// The currently-persisted blob (for assertions on the saved state).
  List<DayStats> get stored => List<DayStats>.unmodifiable(_stored);

  @override
  Future<List<DayStats>> load() async => List<DayStats>.of(_stored);

  @override
  Future<void> save(List<DayStats> history) async {
    _stored = List<DayStats>.of(history);
    saves.add(List<DayStats>.of(history));
  }
}

/// In-memory [EarnedBadgesRepository] with restart-style persistence + save log.
class InMemoryEarnedBadgesRepository implements EarnedBadgesRepository {
  EarnedBadges? _stored;

  /// All persisted earned-badge states, in order.
  final List<EarnedBadges> saves = <EarnedBadges>[];

  /// Seeds the store as if a prior run had persisted [earned].
  void seed(EarnedBadges earned) => _stored = earned;

  @override
  Future<EarnedBadges?> load() async => _stored;

  @override
  Future<void> save(EarnedBadges earned) async {
    _stored = earned;
    saves.add(earned);
  }
}

/// In-memory [SettingsRepository] with restart-style persistence + save log.
class InMemorySettingsRepository implements SettingsRepository {
  AppSettings? _stored;

  /// All persisted settings, in order.
  final List<AppSettings> saves = <AppSettings>[];

  /// Seeds the store as if a prior run had persisted [settings].
  void seed(AppSettings settings) => _stored = settings;

  @override
  Future<AppSettings?> load() async => _stored;

  @override
  Future<void> save(AppSettings settings) async {
    _stored = settings;
    saves.add(settings);
  }
}

/// In-memory [StartupController] fake: holds the "OS" open-at-login flag and
/// records every read and write so the cubit's read-then-write wiring (AC-10)
/// is observable — no real OS registration.
class FakeStartupController implements StartupController {
  FakeStartupController({bool enabled = false, this.throwOnRead = false})
    : _enabled = enabled;

  bool _enabled;

  /// When true, [isEnabled] throws to simulate an unsupported platform (AC-10).
  bool throwOnRead;

  /// Count of [isEnabled] reads.
  int reads = 0;

  /// The values passed to [setEnabled], in order.
  final List<bool> writes = <bool>[];

  /// The current fake OS state (for assertions).
  bool get current => _enabled;

  @override
  Future<bool> isEnabled() async {
    reads++;
    if (throwOnRead) {
      throw StateError('unsupported platform');
    }
    return _enabled;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    writes.add(enabled);
    _enabled = enabled;
  }
}

/// A recorded toast request (which type + its text), so tests assert "toast
/// requested ⇔ enabled" and the exact gated counts (AC-11/AC-12).
class ToastRequest {
  ToastRequest.badge(this.title, this.body) : type = 'badge';
  ToastRequest.streak(this.title, this.body) : type = 'streak';

  final String type;
  final String title;
  final String body;
}

/// [Notifier] fake recording every toast request — no real OS toast, no network.
class RecordingNotifier implements Notifier {
  final List<ToastRequest> requests = <ToastRequest>[];

  List<ToastRequest> get badgeToasts =>
      requests.where((r) => r.type == 'badge').toList();
  List<ToastRequest> get streakToasts =>
      requests.where((r) => r.type == 'streak').toList();

  @override
  Future<void> showBadgeEarned({
    required String title,
    required String description,
  }) async {
    requests.add(ToastRequest.badge(title, description));
  }

  @override
  Future<void> showStreakReminder({
    required String title,
    required String body,
  }) async {
    requests.add(ToastRequest.streak(title, body));
  }
}

/// Terse [DayStats] builder for seeding history. Active defaults to raw so the
/// honesty invariant (raw <= active) always holds unless overridden.
DayStats dayStats(
  DateTime date, {
  Duration? activeTime,
  Duration rawActiveTime = Duration.zero,
  double distanceKmForDay = 0,
  Duration idleTime = Duration.zero,
  Duration bestFocusPeriod = Duration.zero,
}) => DayStats(
  date: date,
  activeTime: activeTime ?? rawActiveTime,
  rawActiveTime: rawActiveTime,
  distanceKmForDay: distanceKmForDay,
  idleTime: idleTime,
  bestFocusPeriod: bestFocusPeriod,
);

/// Terse [JourneyProgress] builder for cubit ticks. [activeTimeToday] defaults
/// to [rawActiveTime] so the honesty invariant holds unless overridden.
JourneyProgress progress({
  required DateTime storedDate,
  double distanceKm = 0,
  Duration? activeTimeToday,
  Duration rawActiveTime = Duration.zero,
  Duration idleTimeToday = Duration.zero,
  JourneyState state = JourneyState.active,
  TravelMode mode = TravelMode.motorbike,
}) => JourneyProgress(
  distanceKm: distanceKm,
  activeTimeToday: activeTimeToday ?? rawActiveTime,
  rawActiveTime: rawActiveTime,
  idleTimeToday: idleTimeToday,
  state: state,
  mode: mode,
  storedDate: storedDate,
);
