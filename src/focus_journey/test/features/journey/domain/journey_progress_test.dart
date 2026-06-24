// Deterministic unit tests for JourneyProgress — the persistable snapshot
// serialised by the data layer (supports AC-9/AC-10/AC-11, used by TC-017/018/020).
//
// Scope: JSON round-trip fidelity, date-only normalisation, ISO date format,
// and the forward-incompatible enum fallbacks. No I/O, no real preferences.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/journey_progress.dart';
import 'package:focus_journey/features/journey/domain/journey_state.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';

const double kTol = 1e-6;

JourneyProgress _sample({DateTime? storedDate}) => JourneyProgress(
  distanceKm: 1234.5,
  activeTimeToday: const Duration(minutes: 40, seconds: 30),
  rawActiveTime: const Duration(minutes: 30),
  idleTimeToday: const Duration(minutes: 20),
  state: JourneyState.idle,
  mode: TravelMode.car,
  storedDate: storedDate ?? DateTime(2026, 6, 23),
);

void main() {
  group('JourneyProgress — JSON round-trip (AC-11)', () {
    test('toJsonThenFromJson_preservesAllFields', () {
      final original = _sample();

      final restored = JourneyProgress.fromJson(original.toJson());

      expect(restored.distanceKm, closeTo(original.distanceKm, kTol));
      expect(restored.activeTimeToday, original.activeTimeToday);
      expect(restored.rawActiveTime, original.rawActiveTime);
      expect(restored.idleTimeToday, original.idleTimeToday);
      expect(restored.state, original.state);
      expect(restored.mode, original.mode);
      expect(restored.storedDate, original.storedDate);
      // Equatable equality across the round trip.
      expect(restored, original);
    });
  });

  group('JourneyProgress — date normalisation (AC-9/AC-10)', () {
    test('storedDateWithClockTime_isNormalisedToDateOnly', () {
      final progress = _sample(storedDate: DateTime(2026, 6, 23, 17, 45, 12));

      expect(progress.storedDate, DateTime(2026, 6, 23));
    });

    test('storedDateIso_isZeroPaddedYyyyMmDd', () {
      final progress = _sample(storedDate: DateTime(2026, 1, 5));

      expect(progress.storedDateIso, '2026-01-05');
    });
  });

  group('JourneyProgress — forward-incompatible fallbacks', () {
    test('unknownStateName_fallsBackToPaused_noThrow', () {
      final json = _sample().toJson()..['state'] = 'warp-speed';

      final restored = JourneyProgress.fromJson(json);

      expect(restored.state, JourneyState.paused);
    });

    test('unknownModeName_fallsBackToMotorbike_noThrow', () {
      final json = _sample().toJson()..['mode'] = 'rocket';

      final restored = JourneyProgress.fromJson(json);

      expect(restored.mode, TravelMode.motorbike);
    });
  });

  group(
    'JourneyProgress — fromJson degrades safely on corrupt input (B-4)',
    () {
      test('missingRequiredNumericKey_throwsFormatException', () {
        final json = _sample().toJson()..remove('distanceKm');

        expect(() => JourneyProgress.fromJson(json), throwsFormatException);
      });

      test('wrongTypedNumericField_throwsFormatException', () {
        final json = _sample().toJson()..['distanceKm'] = 'oops';

        expect(() => JourneyProgress.fromJson(json), throwsFormatException);
      });

      test('wrongTypedDurationField_throwsFormatException', () {
        final json = _sample().toJson()..['activeTimeMs'] = 'nope';

        expect(() => JourneyProgress.fromJson(json), throwsFormatException);
      });

      test('malformedStoredDate_throwsFormatException', () {
        final json = _sample().toJson()..['storedDate'] = 'not-a-date';

        expect(() => JourneyProgress.fromJson(json), throwsFormatException);
      });

      test('outOfRangeStoredDate_throwsFormatException', () {
        final json = _sample().toJson()..['storedDate'] = '2026-13-40';

        expect(() => JourneyProgress.fromJson(json), throwsFormatException);
      });

      test('missingStoredDate_throwsFormatException', () {
        final json = _sample().toJson()..remove('storedDate');

        expect(() => JourneyProgress.fromJson(json), throwsFormatException);
      });
    },
  );
}
