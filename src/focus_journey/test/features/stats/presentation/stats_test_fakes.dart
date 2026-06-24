// Shared deterministic test doubles for the local-stats presentation suite.
//
// Per the test-case conventions (tests/cases/local-stats.md "Conventions"):
//   * NO real timers, NO real OS waits, NO `DateTime.now()` — a FixedClock is
//     injected and advanced by the test, never by the wall clock.
//   * The three stores (settings / per-day history / earned-badge) are faked
//     in-memory over the same JSON value objects the real `shared_preferences`
//     repos persist (a "restart" = construct a fresh Cubit from the same fake).
//   * The two OS interfaces (launch-at-startup, notifier) are faked, RECORDING
//     reads / writes / toast-requests — no real OS registration, no real toast.
//
// These doubles back the widget tests in this directory; the integration tests
// under `src/integration_test/` declare their own (binding-aware) copies so the
// two trees stay independently runnable.

import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/stats/domain/app_settings.dart';
import 'package:focus_journey/features/stats/domain/day_stats.dart';
import 'package:focus_journey/features/stats/domain/earned_badges.dart';
import 'package:focus_journey/features/stats/domain/stats_repositories.dart';

/// A clock whose `now()` is fixed (and re-assignable between ticks) so day- and
/// week-boundary logic is fully deterministic.
class MutableClock implements Clock {
  /// Creates a clock pinned at [_now].
  MutableClock(this._now);

  DateTime _now;

  /// Re-pins the clock (e.g. to cross a midnight or week boundary in a test).
  void set(DateTime now) => _now = now;

  @override
  DateTime now() => _now;
}

/// In-memory [SettingsRepository]. Holds the last-saved blob (round-trips via
/// the real JSON shape, so a "restart" restores exactly what was written).
class FakeSettingsRepository implements SettingsRepository {
  /// Optionally seed a pre-existing persisted value (a prior session).
  FakeSettingsRepository([AppSettings? seed]) : _stored = seed;

  AppSettings? _stored;

  /// The number of save() calls observed (write-count assertions).
  int saveCount = 0;

  @override
  Future<AppSettings?> load() async => _stored;

  @override
  Future<void> save(AppSettings settings) async {
    // Round-trip through JSON so the fake matches the real repo's fidelity.
    _stored = AppSettings.fromJson(settings.toJson());
    saveCount++;
  }
}

/// In-memory [HistoryRepository]. Round-trips through the real JSON shape.
class FakeHistoryRepository implements HistoryRepository {
  /// Optionally seed a pre-existing persisted history (a prior session).
  FakeHistoryRepository([List<DayStats>? seed])
    : _stored = seed == null
          ? <DayStats>[]
          : seed.map((d) => DayStats.fromJson(d.toJson())).toList();

  List<DayStats> _stored;

  /// Every saved snapshot, in call order (so ordering assertions are possible).
  final List<List<DayStats>> saves = <List<DayStats>>[];

  /// The most-recently persisted blob (what a restart would reload).
  List<DayStats> get current => _stored;

  @override
  Future<List<DayStats>> load() async =>
      _stored.map((d) => DayStats.fromJson(d.toJson())).toList();

  @override
  Future<void> save(List<DayStats> history) async {
    _stored = history.map((d) => DayStats.fromJson(d.toJson())).toList();
    saves.add(_stored);
  }
}

/// In-memory [EarnedBadgesRepository]. Round-trips through the real JSON shape.
class FakeEarnedBadgesRepository implements EarnedBadgesRepository {
  /// Optionally seed a pre-existing earned-badge state (a prior session).
  FakeEarnedBadgesRepository([EarnedBadges? seed])
    : _stored = seed == null ? null : EarnedBadges.fromJson(seed.toJson());

  EarnedBadges? _stored;

  /// The number of save() calls observed.
  int saveCount = 0;

  /// The most-recently persisted state (what a restart would reload).
  EarnedBadges? get current => _stored;

  @override
  Future<EarnedBadges?> load() async => _stored;

  @override
  Future<void> save(EarnedBadges earned) async {
    _stored = EarnedBadges.fromJson(earned.toJson());
    saveCount++;
  }
}

/// In-memory [StartupController] fake: records every read + write of the OS
/// "open at login" flag. No real OS registration (TC-010).
class FakeStartupController implements StartupController {
  /// Creates the fake, seeding the simulated OS state with [_enabled].
  FakeStartupController({bool enabled = false}) : _enabled = enabled;

  bool _enabled;

  /// Number of times the OS state was READ on open (AC-10 read-on-open).
  int readCount = 0;

  /// Every value WRITTEN to the OS, in order (AC-10 write-on-flip).
  final List<bool> writes = <bool>[];

  /// The simulated current OS open-at-login state.
  bool get osState => _enabled;

  /// If set, [isEnabled] throws to simulate an unsupported platform.
  bool throwOnRead = false;

  @override
  Future<bool> isEnabled() async {
    readCount++;
    if (throwOnRead) {
      throw UnsupportedError('open-at-login unsupported on this platform');
    }
    return _enabled;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    writes.add(enabled);
    _enabled = enabled;
  }
}

/// A single recorded toast request (kind + title + body), for assertions.
class ToastRequest {
  /// Creates a recorded toast.
  const ToastRequest(this.kind, this.title, this.body);

  /// `'badge'` or `'streak'`.
  final String kind;

  /// The toast title.
  final String title;

  /// The toast body / description.
  final String body;
}

/// In-memory [Notifier] fake: records every toast request. No real OS toast,
/// no network — proves "toast requested ⇔ enabled" (TC-011/TC-012).
class FakeNotifier implements Notifier {
  /// Every toast requested, in order.
  final List<ToastRequest> toasts = <ToastRequest>[];

  /// Convenience: badge-earned toasts only.
  List<ToastRequest> get badgeToasts =>
      toasts.where((t) => t.kind == 'badge').toList();

  /// Convenience: streak-reminder toasts only.
  List<ToastRequest> get streakToasts =>
      toasts.where((t) => t.kind == 'streak').toList();

  @override
  Future<void> showBadgeEarned({
    required String title,
    required String description,
  }) async {
    toasts.add(ToastRequest('badge', title, description));
  }

  @override
  Future<void> showStreakReminder({
    required String title,
    required String body,
  }) async {
    toasts.add(ToastRequest('streak', title, body));
  }
}
