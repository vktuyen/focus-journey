// Unit tests for the vehicle-picker AppSettings.vehiclePreference field
// (vehicle-picker AC-5 / AC-7, TC-607). Pure-Dart, no Flutter binding, no I/O.
//
// Pins:
//   * the toJson/fromJson round-trip for a SET value (enum .name) and for null
//     (key OMITTED, so a fresh store has no key to misparse) — AC-7;
//   * the copyWith sentinel semantics: OMIT = unchanged, explicit null = clear,
//     a value = set — distinguishing the three so a clear is not ambiguous;
//   * fromJson DEGRADES safely on an absent key, a wrong-typed value, and an
//     unknown enum name → null, never throwing (AC-7);
//   * the field participates in Equatable equality (props).
//
// Complements json_round_trip_test.dart (which predates the field) by isolating
// the new nullable preference's three-way copyWith + degrade-safe load path.

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/stats/domain/app_settings.dart';

void main() {
  group('AppSettings.vehiclePreference JSON round-trip (AC-5 / AC-7)', () {
    test('roundTrip_restoresASetPreferenceByEnumName', () {
      const original = AppSettings(vehiclePreference: TravelMode.car);
      final restored = AppSettings.fromJson(original.toJson());
      expect(restored.vehiclePreference, TravelMode.car);
      expect(restored, original); // Equatable equality holds through the trip.
    });

    test('toJson_storesThePreferenceAsTheEnumName', () {
      expect(
        const AppSettings(vehiclePreference: TravelMode.ship).toJson()['vehiclePreference'],
        'ship',
      );
    });

    test('toJson_omitsTheKeyEntirelyWhenNoPreference', () {
      // A fresh store has NO vehiclePreference key to misparse (AC-7).
      expect(
        const AppSettings().toJson().containsKey('vehiclePreference'),
        isFalse,
      );
    });

    test('roundTrip_withNoPreference_restoresNull', () {
      const original = AppSettings(); // vehiclePreference == null
      final restored = AppSettings.fromJson(original.toJson());
      expect(restored.vehiclePreference, isNull);
      expect(restored, original);
    });

    test('everyTravelMode_roundTripsByName', () {
      for (final TravelMode mode in TravelMode.values) {
        final restored = AppSettings.fromJson(
          AppSettings(vehiclePreference: mode).toJson(),
        );
        expect(restored.vehiclePreference, mode, reason: 'round-trip of $mode');
      }
    });
  });

  group('AppSettings.copyWith — three-way sentinel for vehiclePreference', () {
    test('omittingTheArgument_leavesThePreferenceUnchanged', () {
      const start = AppSettings(vehiclePreference: TravelMode.bicycle);
      // Change a DIFFERENT field; the preference must survive untouched.
      final next = start.copyWith(notificationsEnabled: false);
      expect(next.vehiclePreference, TravelMode.bicycle);
    });

    test('passingExplicitNull_clearsThePreference', () {
      const start = AppSettings(vehiclePreference: TravelMode.car);
      final next = start.copyWith(vehiclePreference: null);
      expect(next.vehiclePreference, isNull);
    });

    test('passingAValue_setsThePreference', () {
      const start = AppSettings(); // null
      final next = start.copyWith(vehiclePreference: TravelMode.run);
      expect(next.vehiclePreference, TravelMode.run);
    });

    test('clearVsUnchanged_areDistinct_fromASetStartingValue', () {
      const start = AppSettings(vehiclePreference: TravelMode.walk);
      // OMIT keeps walk; explicit null clears — the two are NOT the same op.
      expect(start.copyWith().vehiclePreference, TravelMode.walk);
      expect(start.copyWith(vehiclePreference: null).vehiclePreference, isNull);
    });

    test('copyWith_doesNotTouchOtherFieldsWhenSettingThePreference', () {
      const start = AppSettings(
        idleThreshold: Duration(minutes: 10),
        notificationsEnabled: false,
        onboardingSeen: true,
      );
      final next = start.copyWith(vehiclePreference: TravelMode.ship);
      expect(next.idleThreshold, const Duration(minutes: 10));
      expect(next.notificationsEnabled, isFalse);
      expect(next.onboardingSeen, isTrue);
      expect(next.vehiclePreference, TravelMode.ship);
    });
  });

  group('AppSettings.fromJson — degrades safely to null, never throws (AC-7)', () {
    test('absentKey_resolvesToNull', () {
      final restored = AppSettings.fromJson(<String, dynamic>{
        'idleThresholdMs': 300000,
      });
      expect(restored.vehiclePreference, isNull);
    });

    test('emptyBlob_resolvesToNull', () {
      expect(
        AppSettings.fromJson(<String, dynamic>{}).vehiclePreference,
        isNull,
      );
    });

    test('unknownEnumName_resolvesToNull_noThrow', () {
      final restored = AppSettings.fromJson(<String, dynamic>{
        'vehiclePreference': 'spaceship',
      });
      expect(restored.vehiclePreference, isNull);
    });

    test('wrongTypedValue_number_resolvesToNull_noThrow', () {
      final restored = AppSettings.fromJson(<String, dynamic>{
        'vehiclePreference': 42,
      });
      expect(restored.vehiclePreference, isNull);
    });

    test('wrongTypedValue_map_resolvesToNull_noThrow', () {
      final restored = AppSettings.fromJson(<String, dynamic>{
        'vehiclePreference': <String, dynamic>{'mode': 'car'},
      });
      expect(restored.vehiclePreference, isNull);
    });

    test('corruptPreferenceWithValidOtherFields_keepsTheOtherFields', () {
      // A garbage preference must not poison the rest of the restore.
      final restored = AppSettings.fromJson(<String, dynamic>{
        'idleThresholdMs': 600000,
        'vehiclePreference': 'not-a-mode',
      });
      expect(restored.vehiclePreference, isNull);
      expect(restored.idleThreshold, const Duration(minutes: 10));
    });
  });

  group('AppSettings — vehiclePreference is in Equatable props', () {
    test('differingOnlyByVehiclePreference_areNotEqual', () {
      expect(
        const AppSettings(vehiclePreference: TravelMode.car),
        isNot(const AppSettings(vehiclePreference: TravelMode.ship)),
      );
    });

    test('setVsNullPreference_areNotEqual', () {
      expect(
        const AppSettings(vehiclePreference: TravelMode.car),
        isNot(const AppSettings()),
      );
    });

    test('sameVehiclePreference_withAllElseEqual_areEqual', () {
      expect(
        const AppSettings(vehiclePreference: TravelMode.motorbike),
        const AppSettings(vehiclePreference: TravelMode.motorbike),
      );
    });
  });
}
