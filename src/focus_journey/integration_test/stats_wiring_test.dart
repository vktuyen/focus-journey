// Settings / notification / idle-threshold WIRING integration tests for
// local-stats, end to end across the injected fakes + (for TC-008) the REAL
// engine seam. No real OS, no real toast, no real timers, no DateTime.now().
//
// Covers:
//   TC-008   changing the idle threshold takes effect on the engine's NEXT tick:
//            a real JourneyEngine is rebuilt with the new threshold (the same
//            `applyIdleThreshold` seam main.dart wires) and a tick with an idle
//            reading BETWEEN the old and new boundary classifies per the NEW
//            threshold. Keyed off the threshold-crossing structure, not literals.
//   TC-010   launch-at-startup reads the OS state on open then writes it on flip
//            (against the injected StartupController fake).
//   TC-011   notifications are local toasts only and respect the master toggle:
//            toast requested IFF enabled (master + per-type); master off => no
//            toast for any type. Asserted against the injected Notifier fake.
//   TC-012   v1 fires badge-earned once + a gated streak reminder (no-nag,
//            not-while-active, only when today is unqualified).
//   TC-NF3   no network / offline: the slice's stores + notifier + settings all
//            function with no network dependency (a smoke that the wiring runs
//            entirely against in-memory/local fakes — see also the static
//            no-network import grep in stats_no_network_static_test.dart).
//
// Runs headless under `flutter test` and on a device:
//   fvm flutter test integration_test/stats_wiring_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/activity/data/mock_activity_source.dart';
import 'package:focus_journey/features/journey/domain/clock.dart';
import 'package:focus_journey/features/journey/domain/journey_engine.dart';
import 'package:focus_journey/features/journey/domain/journey_progress.dart';
import 'package:focus_journey/features/journey/domain/journey_state.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/stats/domain/app_settings.dart';
import 'package:focus_journey/features/stats/domain/badge.dart';
import 'package:focus_journey/features/stats/domain/badge_catalogue.dart';
import 'package:focus_journey/features/stats/domain/day_stats.dart';
import 'package:focus_journey/features/stats/domain/earned_badges.dart';
import 'package:focus_journey/features/stats/domain/stats_repositories.dart';
import 'package:focus_journey/features/stats/domain/streak_reminder_policy.dart';
import 'package:focus_journey/features/stats/presentation/settings_cubit.dart';
import 'package:focus_journey/features/stats/presentation/stats_cubit.dart';
import 'package:integration_test/integration_test.dart';

class _FixedClock implements Clock {
  _FixedClock(this._now);
  DateTime _now;
  void set(DateTime now) => _now = now;
  @override
  DateTime now() => _now;
}

class _FakeStartup implements StartupController {
  _FakeStartup({bool enabled = false}) : _enabled = enabled;
  bool _enabled;
  int readCount = 0;
  final List<bool> writes = <bool>[];
  bool get osState => _enabled;
  @override
  Future<bool> isEnabled() async {
    readCount++;
    return _enabled;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    writes.add(enabled);
    _enabled = enabled;
  }
}

class _FakeSettingsRepo implements SettingsRepository {
  AppSettings? stored;
  @override
  Future<AppSettings?> load() async => stored;
  @override
  Future<void> save(AppSettings settings) async => stored = settings;
}

class _FakeHistoryRepo implements HistoryRepository {
  List<DayStats> _stored = <DayStats>[];
  @override
  Future<List<DayStats>> load() async => _stored;
  @override
  Future<void> save(List<DayStats> history) async => _stored = history;
}

class _FakeBadgesRepo implements EarnedBadgesRepository {
  EarnedBadges? stored;
  @override
  Future<EarnedBadges?> load() async => stored;
  @override
  Future<void> save(EarnedBadges earned) async => stored = earned;
}

class _Toast {
  const _Toast(this.kind);
  final String kind;
}

class _FakeNotifier implements Notifier {
  final List<_Toast> toasts = <_Toast>[];
  List<_Toast> get badges => toasts.where((t) => t.kind == 'badge').toList();
  List<_Toast> get streaks => toasts.where((t) => t.kind == 'streak').toList();
  @override
  Future<void> showBadgeEarned({
    required String title,
    required String description,
  }) async => toasts.add(const _Toast('badge'));
  @override
  Future<void> showStreakReminder({
    required String title,
    required String body,
  }) async => toasts.add(const _Toast('streak'));
}

JourneyProgress _progress({
  required DateTime day,
  Duration? active,
  Duration raw = Duration.zero,
  Duration idle = Duration.zero,
  double cumulativeKm = 0,
  JourneyState state = JourneyState.active,
}) => JourneyProgress(
  distanceKm: cumulativeKm,
  // Honesty invariant: journey time is always >= raw active time. When a test
  // only cares about raw, default journey time to raw so the invariant holds.
  activeTimeToday: active ?? raw,
  rawActiveTime: raw,
  idleTimeToday: idle,
  state: state,
  mode: TravelMode.motorbike,
  storedDate: day,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('TC-008 idle threshold applied to the engine on the next tick', () {
    testWidgets(
      'a reading between old and new boundary classifies per the new threshold',
      (tester) async {
        final clock = _FixedClock(DateTime(2026, 6, 24, 12));
        final activity = MockActivitySource(
          idleSeconds: 0,
          screenLocked: false,
        );

        // The engine is rebuilt by the applyIdleThreshold seam (exactly how
        // main.dart wires settings -> engine), preserving progress via toProgress
        // / restore. We hold the live engine in a holder the closure updates.
        late JourneyEngine engine;
        JourneyEngine build(Duration threshold) => JourneyEngine(
          clock: clock,
          activityPlugin: activity,
          kmPerActiveHour: 250,
          threshold: threshold,
          grace: threshold, // G == T (epic default); the (G,T] band is empty
        );
        engine = build(const Duration(minutes: 3)); // start at 3 min

        final repo = _FakeSettingsRepo();
        final settings = SettingsCubit(
          repository: repo,
          startupController: _FakeStartup(),
          applyIdleThreshold: (threshold) {
            if (engine.threshold == threshold) {
              return;
            }
            final snap = engine.toProgress();
            engine = build(threshold);
            engine.restore(snap);
          },
          initialSettings: const AppSettings(
            idleThreshold: Duration(minutes: 3),
          ),
        );
        addTearDown(settings.close);

        // Idle reading of 4 minutes: ABOVE the old 3-min threshold (would pause),
        // we will raise the threshold to 10 min so the SAME reading now travels.
        const idleFourMin = 4 * 60;

        // Sanity: under the OLD 3-min threshold, a 4-min idle reading pauses.
        engine.tick(
          const Duration(seconds: 5),
          idleSeconds: idleFourMin,
          screenLocked: false,
        );
        expect(
          engine.state,
          JourneyState.paused,
          reason: 'old threshold (3 min) classifies a 4-min idle as paused',
        );

        // --- Change the threshold to 10 min via the settings Cubit. ---
        await settings.setIdleThreshold(const Duration(minutes: 10));
        expect(repo.stored!.idleThreshold, const Duration(minutes: 10));

        // NEXT tick with the SAME 4-min idle reading now classifies as travelling
        // (active), because the new 10-min threshold is applied to the engine.
        final beforeActive = engine.activeTimeToday;
        engine.tick(
          const Duration(seconds: 5),
          idleSeconds: idleFourMin,
          screenLocked: false,
        );
        expect(
          engine.state,
          JourneyState.active,
          reason: 'new threshold (10 min) reclassifies a 4-min idle as active',
        );
        expect(
          engine.activeTimeToday,
          greaterThan(beforeActive),
          reason: 'journey time accrues again under the new threshold',
        );
      },
    );
  });

  group('TC-010 launch-at-startup read-on-open then write-on-flip', () {
    testWidgets('reads the OS state then writes it through the controller', (
      tester,
    ) async {
      final startup = _FakeStartup(enabled: true);
      final repo = _FakeSettingsRepo();
      final cubit = SettingsCubit(
        repository: repo,
        startupController: startup,
        applyIdleThreshold: (_) {},
      );
      addTearDown(cubit.close);

      // On open: read the real OS state and reconcile the toggle.
      await cubit.syncLaunchAtStartupFromOs();
      expect(startup.readCount, greaterThanOrEqualTo(1));
      expect(cubit.state.launchAtStartup, isTrue);

      // On flip: write the real OS state.
      await cubit.setLaunchAtStartup(false);
      expect(startup.writes.last, isFalse);
      expect(startup.osState, isFalse);
      expect(cubit.state.launchAtStartup, isFalse);
    });
  });

  group('TC-011 notifications: local toasts only, gated by master toggle', () {
    Future<_FakeNotifier> driveBadgeEarn({
      required AppSettings settings,
    }) async {
      final clock = _FixedClock(DateTime(2026, 6, 24, 21));
      final notifier = _FakeNotifier();
      final cubit = StatsCubit(
        clock: clock,
        historyRepository: _FakeHistoryRepo(),
        earnedBadgesRepository: _FakeBadgesRepo(),
        notifier: notifier,
        // Single permanent badge that earns when cumulative distance >= 10.
        catalogue: <BadgeDefinition>[
          BadgeDefinition(
            id: 'd1',
            title: 'Test',
            description: 'd',
            family: BadgeFamily.distance,
            scope: BadgeScope.permanent,
            isEarned: (c) => c.cumulativeDistanceKm >= 10,
          ),
        ],
      );
      addTearDown(cubit.close);
      cubit.updateSettings(settings);
      await cubit.load(_progress(day: DateTime(2026, 6, 24)));
      // Cross the badge threshold (cumulative distance >= 10).
      await cubit.onTick(
        _progress(
          day: DateTime(2026, 6, 24),
          cumulativeKm: 12,
          raw: const Duration(minutes: 30),
        ),
      );
      return notifier;
    }

    testWidgets('master + per-type ON => exactly one badge toast', (
      tester,
    ) async {
      final notifier = await driveBadgeEarn(
        settings: const AppSettings(
          notificationsEnabled: true,
          badgeNotificationsEnabled: true,
        ),
      );
      expect(notifier.badges, hasLength(1));
    });

    testWidgets('master OFF => no toast for any type', (tester) async {
      final notifier = await driveBadgeEarn(
        settings: const AppSettings(notificationsEnabled: false),
      );
      expect(notifier.toasts, isEmpty);
    });

    testWidgets('per-type badge OFF (master on) => no badge toast', (
      tester,
    ) async {
      final notifier = await driveBadgeEarn(
        settings: const AppSettings(
          notificationsEnabled: true,
          badgeNotificationsEnabled: false,
        ),
      );
      expect(notifier.badges, isEmpty);
    });
  });

  group(
    'TC-012 streak reminder is gated (no-nag, not-while-active, unqualified)',
    () {
      Future<_FakeNotifier> driveReminder({
        required JourneyState state,
        required Duration rawToday,
        AppSettings settings = const AppSettings(),
        int reTriggers = 0,
      }) async {
        // Clock past the default reminder time (20:00).
        final clock = _FixedClock(DateTime(2026, 6, 24, 21));
        final notifier = _FakeNotifier();
        final cubit = StatsCubit(
          clock: clock,
          historyRepository: _FakeHistoryRepo(),
          earnedBadgesRepository: _FakeBadgesRepo(),
          notifier: notifier,
          // Empty catalogue so only the reminder path can fire.
          catalogue: const <BadgeDefinition>[],
          streakReminderTime: defaultStreakReminderTime,
        );
        addTearDown(cubit.close);
        cubit.updateSettings(settings);
        await cubit.load(_progress(day: DateTime(2026, 6, 24)));
        await cubit.onTick(
          _progress(day: DateTime(2026, 6, 24), raw: rawToday, state: state),
        );
        // Re-trigger the same day to prove the no-nag (at most once/day) rule.
        for (var i = 0; i < reTriggers; i++) {
          await cubit.onTick(
            _progress(day: DateTime(2026, 6, 24), raw: rawToday, state: state),
          );
        }
        return notifier;
      }

      testWidgets(
        'unqualified + idle + past reminder time => exactly one reminder',
        (tester) async {
          final notifier = await driveReminder(
            state: JourneyState.idle,
            rawToday: const Duration(minutes: 10), // < 25 min: unqualified
          );
          expect(notifier.streaks, hasLength(1));
        },
      );

      testWidgets('already qualified today => no reminder', (tester) async {
        final notifier = await driveReminder(
          state: JourneyState.idle,
          rawToday: const Duration(minutes: 30), // >= 25 min: qualified
        );
        expect(notifier.streaks, isEmpty);
      });

      testWidgets('actively progressing => no reminder', (tester) async {
        final notifier = await driveReminder(
          state: JourneyState.active,
          rawToday: const Duration(minutes: 10),
        );
        expect(notifier.streaks, isEmpty);
      });

      testWidgets(
        'no nag: re-triggering the same day still fires at most once',
        (tester) async {
          final notifier = await driveReminder(
            state: JourneyState.idle,
            rawToday: const Duration(minutes: 10),
            reTriggers: 3,
          );
          expect(notifier.streaks, hasLength(1));
        },
      );

      testWidgets('master off => no reminder even when unqualified + idle', (
        tester,
      ) async {
        final notifier = await driveReminder(
          state: JourneyState.idle,
          rawToday: const Duration(minutes: 10),
          settings: const AppSettings(notificationsEnabled: false),
        );
        expect(notifier.streaks, isEmpty);
      });
    },
  );

  group('TC-NF3 offline: the full wiring runs against local-only fakes', () {
    testWidgets('stats render, a badge earns + a toast fires with no network dep', (
      tester,
    ) async {
      // The entire flow below uses only in-memory fakes + a local notifier seam;
      // nothing performs I/O beyond shared_preferences. (The static import grep
      // in stats_no_network_static_test.dart proves no network package is used.)
      final notifier = _FakeNotifier();
      final cubit = StatsCubit(
        clock: _FixedClock(DateTime(2026, 6, 24, 21)),
        historyRepository: _FakeHistoryRepo(),
        earnedBadgesRepository: _FakeBadgesRepo(),
        notifier: notifier,
        catalogue: BadgeCatalogue.badges,
      );
      addTearDown(cubit.close);
      cubit.updateSettings(const AppSettings());
      await cubit.load(_progress(day: DateTime(2026, 6, 24)));
      await cubit.onTick(
        _progress(
          day: DateTime(2026, 6, 24),
          active: const Duration(minutes: 30),
          raw: const Duration(minutes: 30),
          cumulativeKm: 120, // crosses the first-100km badge
        ),
      );
      // Stats projected + a local toast requested — all without any network.
      expect(cubit.state.daily.rawActiveTime, const Duration(minutes: 30));
      expect(notifier.badges, isNotEmpty);
    });
  });
}
