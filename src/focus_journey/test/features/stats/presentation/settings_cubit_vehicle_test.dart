// Deterministic unit tests for SettingsCubit.setVehicle (vehicle-picker AC-5,
// TC-605). Mirrors settings_cubit_test.dart's harness: an in-memory
// SettingsRepository fake + a FakeStartupController + an ApplyIdleThreshold
// recorder, all from stats_test_fixtures.dart — no real OS, no real timers, no
// real shared_preferences.
//
// COSMETIC-ONLY firewall (ADR-0007): setVehicle must emit + persist the
// preference WITHOUT touching the engine-affecting idle-threshold seam — these
// tests assert no ApplyIdleThreshold call fires on a vehicle pick, the runtime
// half of the AC-9 separation at the Cubit level.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/stats/domain/app_settings.dart';
import 'package:focus_journey/features/stats/presentation/settings_cubit.dart';

import '../stats_test_fixtures.dart';

void main() {
  late InMemorySettingsRepository repository;
  late FakeStartupController startup;
  late List<Duration> appliedThresholds;

  setUp(() {
    repository = InMemorySettingsRepository();
    startup = FakeStartupController();
    appliedThresholds = <Duration>[];
  });

  SettingsCubit build({AppSettings? initialSettings}) {
    final cubit = SettingsCubit(
      repository: repository,
      startupController: startup,
      applyIdleThreshold: appliedThresholds.add,
      initialSettings: initialSettings,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  group('SettingsCubit.setVehicle — emit + persist (AC-5)', () {
    test('emitsTheNewPreference_andSavesItViaTheRepository', () async {
      final cubit = build();
      await cubit.setVehicle(TravelMode.car);

      expect(cubit.state.vehiclePreference, TravelMode.car);
      expect(repository.saves.last.vehiclePreference, TravelMode.car);
    });

    test('eachOfTheSixModes_emitsAndPersists', () async {
      final cubit = build();
      for (final TravelMode mode in TravelMode.values) {
        await cubit.setVehicle(mode);
        expect(cubit.state.vehiclePreference, mode);
        expect(repository.saves.last.vehiclePreference, mode);
      }
    });

    blocTest<SettingsCubit, AppSettings>(
      'emitsAnAppSettingsCarryingTheChosenPreference',
      build: () => build(),
      act: (cubit) => cubit.setVehicle(TravelMode.ship),
      expect: () => <AppSettings>[
        const AppSettings(vehiclePreference: TravelMode.ship),
      ],
    );
  });

  group('SettingsCubit.setVehicle(null) — clears the preference (AC-5)', () {
    test('clearsAPreviouslySetPreference_andPersistsTheCleared', () async {
      final cubit = build(
        initialSettings: const AppSettings(vehiclePreference: TravelMode.car),
      );
      await cubit.setVehicle(null);

      expect(cubit.state.vehiclePreference, isNull);
      expect(repository.saves.last.vehiclePreference, isNull);
    });
  });

  group('SettingsCubit.setVehicle — does NOT alter other settings (AC-5)', () {
    test('leavesEveryOtherSettingsFieldUnchanged', () async {
      const seed = AppSettings(
        idleThreshold: Duration(minutes: 10),
        launchAtStartup: true,
        notificationsEnabled: false,
        badgeNotificationsEnabled: false,
        streakReminderEnabled: false,
        onboardingSeen: true,
      );
      final cubit = build(initialSettings: seed);

      await cubit.setVehicle(TravelMode.bicycle);

      final s = cubit.state;
      expect(s.vehiclePreference, TravelMode.bicycle);
      expect(s.idleThreshold, const Duration(minutes: 10));
      expect(s.launchAtStartup, isTrue);
      expect(s.notificationsEnabled, isFalse);
      expect(s.badgeNotificationsEnabled, isFalse);
      expect(s.streakReminderEnabled, isFalse);
      expect(s.onboardingSeen, isTrue);
    });
  });

  group('SettingsCubit.setVehicle — never touches the engine seam (AC-9)', () {
    test('aVehiclePick_doesNotApplyAnIdleThreshold', () async {
      final cubit = build();
      appliedThresholds.clear(); // ignore the construction-time apply.

      await cubit.setVehicle(TravelMode.car);
      await cubit.setVehicle(TravelMode.ship);
      await cubit.setVehicle(null);

      // The cosmetic pick is firewalled from the only engine-affecting seam.
      expect(appliedThresholds, isEmpty);
    });
  });
}
