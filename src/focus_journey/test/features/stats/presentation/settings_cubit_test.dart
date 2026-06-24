// Deterministic unit tests for SettingsCubit (AC-8/AC-9/AC-10/AC-11/AC-12/
// AC-20, TC-008/009/010). The cubit's only engine-affecting output is the idle
// threshold, applied via the injected ApplyIdleThreshold seam (no engine
// reference); launch-at-startup goes through an injected StartupController fake
// (read-then-write); notification + onboarding toggles only persist. All deps
// are in-memory fakes — no real OS registration, no real timers.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/stats/domain/app_settings.dart';
import 'package:focus_journey/features/stats/presentation/settings_cubit.dart';

import '../stats_test_fixtures.dart';

void main() {
  late InMemorySettingsRepository repository;
  late FakeStartupController startup;
  late List<Duration> appliedThresholds;
  late List<AppSettings> changeNotifications;

  setUp(() {
    repository = InMemorySettingsRepository();
    startup = FakeStartupController();
    appliedThresholds = <Duration>[];
    changeNotifications = <AppSettings>[];
  });

  SettingsCubit build({AppSettings? initialSettings}) {
    final cubit = SettingsCubit(
      repository: repository,
      startupController: startup,
      applyIdleThreshold: appliedThresholds.add,
      onSettingsChanged: changeNotifications.add,
      initialSettings: initialSettings,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  group(
    'SettingsCubit — construction applies the restored threshold (AC-9)',
    () {
      test('appliesInitialThresholdToTheEngineSeamOnConstruction', () {
        build(
          initialSettings: const AppSettings(
            idleThreshold: Duration(minutes: 10),
          ),
        );
        // The restored value is re-applied to the engine immediately on restart.
        expect(appliedThresholds, <Duration>[const Duration(minutes: 10)]);
      });

      test('defaultsToFiveMinutesWhenNoInitialSettings', () {
        build();
        expect(appliedThresholds, <Duration>[AppSettings.defaultIdleThreshold]);
      });
    },
  );

  group('SettingsCubit.setIdleThreshold (AC-8 / TC-008)', () {
    test('appliesNewThresholdToTheEngineSeam_andPersistsIt', () async {
      final cubit = build();
      appliedThresholds.clear(); // ignore the construction-time apply

      await cubit.setIdleThreshold(const Duration(minutes: 3));

      expect(appliedThresholds, <Duration>[const Duration(minutes: 3)]);
      expect(cubit.state.idleThreshold, const Duration(minutes: 3));
      expect(repository.saves.last.idleThreshold, const Duration(minutes: 3));
    });

    test('supportsACustomThresholdOutsideThePresets', () async {
      final cubit = build();
      appliedThresholds.clear();
      await cubit.setIdleThreshold(const Duration(minutes: 7));
      expect(cubit.state.idleThreshold, const Duration(minutes: 7));
      expect(appliedThresholds.last, const Duration(minutes: 7));
    });

    blocTest<SettingsCubit, AppSettings>(
      'emitsTheNewSettingsWithTheChangedThreshold',
      build: () => build(),
      act: (cubit) => cubit.setIdleThreshold(const Duration(minutes: 10)),
      expect: () => <AppSettings>[
        const AppSettings(idleThreshold: Duration(minutes: 10)),
      ],
    );
  });

  group(
    'SettingsCubit — launch-at-startup read-then-write (AC-10 / TC-010)',
    () {
      test('syncFromOs_readsTheRealOsStateAndReconcilesTheToggle', () async {
        startup = FakeStartupController(enabled: true);
        final cubit = build(); // persisted launchAtStartup defaults to false
        await cubit.syncLaunchAtStartupFromOs();

        expect(startup.reads, 1);
        expect(
          cubit.state.launchAtStartup,
          isTrue,
        ); // reconciled to the OS state
        expect(repository.saves.last.launchAtStartup, isTrue);
      });

      test('syncFromOs_whenOsMatchesPersisted_doesNotRewrite', () async {
        startup = FakeStartupController(enabled: false);
        final cubit = build(
          initialSettings: const AppSettings(launchAtStartup: false),
        );
        await cubit.syncLaunchAtStartupFromOs();
        expect(startup.reads, 1);
        expect(repository.saves, isEmpty); // no change → no persist
      });

      test('syncFromOs_onReadFailure_keepsThePersistedValue', () async {
        startup = FakeStartupController(enabled: true, throwOnRead: true);
        final cubit = build(
          initialSettings: const AppSettings(launchAtStartup: false),
        );
        await cubit.syncLaunchAtStartupFromOs();
        // Unsupported platform: the toggle is left unchanged, no crash.
        expect(cubit.state.launchAtStartup, isFalse);
        expect(repository.saves, isEmpty);
      });

      test('setLaunchAtStartup_writesTheRealOsStateThenPersists', () async {
        final cubit = build();
        await cubit.setLaunchAtStartup(true);

        expect(startup.writes, <bool>[true]);
        expect(startup.current, isTrue);
        expect(cubit.state.launchAtStartup, isTrue);
        expect(repository.saves.last.launchAtStartup, isTrue);
      });

      test('setLaunchAtStartup_disabling_writesFalseToTheOs', () async {
        startup = FakeStartupController(enabled: true);
        final cubit = build(
          initialSettings: const AppSettings(launchAtStartup: true),
        );
        await cubit.setLaunchAtStartup(false);
        expect(startup.writes, <bool>[false]);
        expect(startup.current, isFalse);
      });
    },
  );

  group('SettingsCubit — notification toggles persist (AC-11/AC-12)', () {
    test('masterToggle_persists', () async {
      final cubit = build();
      await cubit.setNotificationsEnabled(false);
      expect(cubit.state.notificationsEnabled, isFalse);
      expect(repository.saves.last.notificationsEnabled, isFalse);
    });

    test('perTypeBadgeToggle_persists', () async {
      final cubit = build();
      await cubit.setBadgeNotificationsEnabled(false);
      expect(cubit.state.badgeNotificationsEnabled, isFalse);
      expect(repository.saves.last.badgeNotificationsEnabled, isFalse);
    });

    test('perTypeStreakToggle_persists', () async {
      final cubit = build();
      await cubit.setStreakReminderEnabled(false);
      expect(cubit.state.streakReminderEnabled, isFalse);
      expect(repository.saves.last.streakReminderEnabled, isFalse);
    });

    test(
      'notificationToggles_doNotTouchTheEngineThresholdSeam (AC-9)',
      () async {
        final cubit = build();
        appliedThresholds.clear();
        await cubit.setNotificationsEnabled(false);
        await cubit.setBadgeNotificationsEnabled(false);
        await cubit.setStreakReminderEnabled(false);
        await cubit.setLaunchAtStartup(true);
        // OS-only settings never feed the engine threshold.
        expect(appliedThresholds, isEmpty);
      },
    );
  });

  group('SettingsCubit — onboarding flag (AC-20)', () {
    test('markOnboardingSeen_persistsTheFlag', () async {
      final cubit = build();
      expect(cubit.state.onboardingSeen, isFalse);
      await cubit.markOnboardingSeen();
      expect(cubit.state.onboardingSeen, isTrue);
      expect(repository.saves.last.onboardingSeen, isTrue);
    });
  });

  group('SettingsCubit — settings-changed notification fan-out (AC-11)', () {
    test('everyPersist_notifiesTheOnSettingsChangedListener', () async {
      final cubit = build();
      await cubit.setIdleThreshold(const Duration(minutes: 3));
      await cubit.setNotificationsEnabled(false);
      expect(changeNotifications.length, 2);
      expect(changeNotifications.last.notificationsEnabled, isFalse);
    });
  });
}
