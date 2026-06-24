// Focused unit tests for the data-layer SharedPreferencesJourneyRepository.
//
// Scope: the JourneyRepository contract over the real shared_preferences impl,
// driven by SharedPreferences.setMockInitialValues({}) so there is no real disk
// I/O or platform channel (AC-11 / TC-018). The pure engine never sees this
// class; here we prove the persistence seam round-trips a JourneyProgress.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/data/shared_preferences_journey_repository.dart';
import 'package:focus_journey/features/journey/domain/journey_progress.dart';
import 'package:focus_journey/features/journey/domain/journey_state.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double kTol = 1e-6;

JourneyProgress _sample() => JourneyProgress(
  distanceKm: 42.25,
  activeTimeToday: const Duration(minutes: 25),
  rawActiveTime: const Duration(minutes: 20),
  idleTimeToday: const Duration(minutes: 10),
  state: JourneyState.active,
  mode: TravelMode.ship,
  storedDate: DateTime(2026, 6, 23),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesJourneyRepository (TC-018, AC-11)', () {
    test('load_whenNothingPersisted_returnsNull', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesJourneyRepository(prefs);

      expect(await repo.load(), isNull);
    });

    test('saveThenLoad_roundTripsTheSnapshot', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesJourneyRepository(prefs);
      final progress = _sample();

      await repo.save(progress);
      final loaded = await repo.load();

      expect(loaded, isNotNull);
      expect(loaded, progress); // Equatable equality.
      expect(loaded!.distanceKm, closeTo(42.25, kTol));
    });

    test('save_overwritesPreviousSnapshot', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPreferencesJourneyRepository(prefs);

      await repo.save(_sample());
      final second = JourneyProgress(
        distanceKm: 999.0,
        activeTimeToday: const Duration(hours: 1),
        rawActiveTime: const Duration(minutes: 50),
        idleTimeToday: Duration.zero,
        state: JourneyState.paused,
        mode: TravelMode.walk,
        storedDate: DateTime(2026, 6, 24),
      );
      await repo.save(second);

      expect(await repo.load(), second);
    });
  });

  group(
    'SharedPreferencesJourneyRepository — corrupt blob never crashes (B-4)',
    () {
      Future<SharedPreferencesJourneyRepository> repoWith(String stored) async {
        SharedPreferences.setMockInitialValues({
          SharedPreferencesJourneyRepository.storageKey: stored,
        });
        final prefs = await SharedPreferences.getInstance();
        return SharedPreferencesJourneyRepository(prefs);
      }

      test('corruptNonJsonString_returnsNull', () async {
        final repo = await repoWith('{not valid json at all');
        expect(await repo.load(), isNull);
      });

      test('nonObjectTopLevelJson_returnsNull', () async {
        final repo = await repoWith('[1, 2, 3]');
        expect(await repo.load(), isNull);
      });

      test('missingRequiredKey_returnsNull', () async {
        // Valid JSON object but the distanceKm field is absent.
        final repo = await repoWith(
          '{"activeTimeMs":1000,"rawActiveTimeMs":500,"idleTimeMs":0,'
          '"state":"active","mode":"ship","storedDate":"2026-06-23"}',
        );
        expect(await repo.load(), isNull);
      });

      test('wrongTypedNumericField_returnsNull', () async {
        // distanceKm is a string instead of a number.
        final repo = await repoWith(
          '{"distanceKm":"oops","activeTimeMs":1000,"rawActiveTimeMs":500,'
          '"idleTimeMs":0,"state":"active","mode":"ship","storedDate":"2026-06-23"}',
        );
        expect(await repo.load(), isNull);
      });

      test('malformedStoredDate_returnsNull', () async {
        final repo = await repoWith(
          '{"distanceKm":42.0,"activeTimeMs":1000,"rawActiveTimeMs":500,'
          '"idleTimeMs":0,"state":"active","mode":"ship","storedDate":"not-a-date"}',
        );
        expect(await repo.load(), isNull);
      });
    },
  );
}
