// Unit tests for the toJson/fromJson round-trips of the three persisted domain
// value objects — DayStats, AppSettings, EarnedBadges (AC-6/AC-7 store-level,
// TC-007/TC-027). Mirrors the JourneyProgress corrupt-blob-safe style (B-4):
//   - a clean round-trip restores an equal value;
//   - DayStats / EarnedBadges throw FormatException on a corrupt/partial/
//     wrong-typed blob (so the data layer drops the entry rather than crash);
//   - AppSettings degrades to defaults on missing/wrong-typed fields (settings
//     are non-critical, a fresh default is a safe restore).
// Also pins the persisted JSON SHAPE: only aggregate counters / config / flags
// — never any raw signal (TC-027).

import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/stats/domain/app_settings.dart';
import 'package:focus_journey/features/stats/domain/day_stats.dart';
import 'package:focus_journey/features/stats/domain/earned_badges.dart';

const double _tol = 1e-6;

void main() {
  group('DayStats JSON round-trip (AC-6/AC-7)', () {
    test('roundTrip_restoresAnEqualValue', () {
      final original = DayStats(
        date: DateTime(2026, 6, 24),
        activeTime: const Duration(minutes: 45),
        rawActiveTime: const Duration(minutes: 38),
        distanceKmForDay: 12.5,
        idleTime: const Duration(minutes: 9),
        bestFocusPeriod: const Duration(minutes: 22),
      );
      final restored = DayStats.fromJson(original.toJson());
      expect(restored, original); // Equatable equality.
      expect(restored.distanceKmForDay, closeTo(12.5, _tol));
    });

    test('dateSerialisesAsIsoDateOnly_noClockTime', () {
      final day = DayStats(
        date: DateTime(2026, 6, 24, 23, 59),
        activeTime: Duration.zero,
        rawActiveTime: Duration.zero,
        distanceKmForDay: 0,
        idleTime: Duration.zero,
        bestFocusPeriod: Duration.zero,
      );
      expect(day.toJson()['date'], '2026-06-24');
    });

    test('jsonShape_carriesOnlyAggregateCounters_noRawSignals (TC-027)', () {
      final day = DayStats(
        date: DateTime(2026, 6, 24),
        activeTime: const Duration(minutes: 1),
        rawActiveTime: const Duration(minutes: 1),
        distanceKmForDay: 1,
        idleTime: Duration.zero,
        bestFocusPeriod: Duration.zero,
      );
      expect(day.toJson().keys.toSet(), <String>{
        'date',
        'activeTimeMs',
        'rawActiveTimeMs',
        'distanceKmForDay',
        'idleTimeMs',
        'bestFocusPeriodMs',
      });
    });

    test('missingField_throwsFormatException_soDataLayerCanDropIt', () {
      expect(
        () => DayStats.fromJson(<String, dynamic>{
          'date': '2026-06-24',
          // activeTimeMs missing
          'rawActiveTimeMs': 1000,
          'distanceKmForDay': 1.0,
          'idleTimeMs': 0,
          'bestFocusPeriodMs': 0,
        }),
        throwsFormatException,
      );
    });

    test('wrongTypedNumericField_throwsFormatException', () {
      expect(
        () => DayStats.fromJson(<String, dynamic>{
          'date': '2026-06-24',
          'activeTimeMs': 'oops',
          'rawActiveTimeMs': 1000,
          'distanceKmForDay': 1.0,
          'idleTimeMs': 0,
          'bestFocusPeriodMs': 0,
        }),
        throwsFormatException,
      );
    });

    test('malformedDate_throwsFormatException', () {
      expect(
        () => DayStats.fromJson(<String, dynamic>{
          'date': 'not-a-date',
          'activeTimeMs': 1000,
          'rawActiveTimeMs': 1000,
          'distanceKmForDay': 1.0,
          'idleTimeMs': 0,
          'bestFocusPeriodMs': 0,
        }),
        throwsFormatException,
      );
    });

    test('outOfRangeDateParts_throwFormatException', () {
      expect(
        () => DayStats.fromJson(<String, dynamic>{
          'date': '2026-13-40',
          'activeTimeMs': 1000,
          'rawActiveTimeMs': 1000,
          'distanceKmForDay': 1.0,
          'idleTimeMs': 0,
          'bestFocusPeriodMs': 0,
        }),
        throwsFormatException,
      );
    });
  });

  group('AppSettings JSON round-trip (AC-9, degrade-safe)', () {
    test('roundTrip_restoresAllFields', () {
      const original = AppSettings(
        idleThreshold: Duration(minutes: 10),
        launchAtStartup: true,
        notificationsEnabled: false,
        badgeNotificationsEnabled: false,
        streakReminderEnabled: false,
        onboardingSeen: true,
      );
      final restored = AppSettings.fromJson(original.toJson());
      expect(restored, original);
    });

    test('jsonShape_carriesOnlyConfigAndFlags_noRawSignals (TC-027)', () {
      expect(const AppSettings().toJson().keys.toSet(), <String>{
        'idleThresholdMs',
        'launchAtStartup',
        'notificationsEnabled',
        'badgeNotificationsEnabled',
        'streakReminderEnabled',
        'onboardingSeen',
      });
    });

    test('missingThreshold_fallsBackToDefault_notThrow', () {
      final restored = AppSettings.fromJson(<String, dynamic>{
        'launchAtStartup': true,
      });
      expect(restored.idleThreshold, AppSettings.defaultIdleThreshold);
      expect(restored.launchAtStartup, isTrue);
    });

    test('wrongTypedThreshold_fallsBackToDefault', () {
      final restored = AppSettings.fromJson(<String, dynamic>{
        'idleThresholdMs': 'oops',
      });
      expect(restored.idleThreshold, AppSettings.defaultIdleThreshold);
    });

    test('emptyBlob_yieldsTheSafeDefaults', () {
      final restored = AppSettings.fromJson(<String, dynamic>{});
      // Booleans default to the "on for notifications, off for the rest" posture.
      expect(restored.notificationsEnabled, isTrue);
      expect(restored.launchAtStartup, isFalse);
      expect(restored.onboardingSeen, isFalse);
    });

    test('notificationFlags_defaultEnabledUnlessExplicitlyFalse', () {
      // A blob that omits the per-type flags keeps notifications on by default.
      final restored = AppSettings.fromJson(<String, dynamic>{
        'idleThresholdMs': 300000,
      });
      expect(restored.badgeNotificationsEnabled, isTrue);
      expect(restored.streakReminderEnabled, isTrue);
    });
  });

  group('AppSettings — derived gating getters (AC-11/AC-12)', () {
    test('canNotifyBadge_requiresMasterAndPerTypeOn', () {
      expect(const AppSettings().canNotifyBadge, isTrue);
      expect(
        const AppSettings(notificationsEnabled: false).canNotifyBadge,
        isFalse,
      );
      expect(
        const AppSettings(badgeNotificationsEnabled: false).canNotifyBadge,
        isFalse,
      );
    });

    test('canNotifyStreak_requiresMasterAndPerTypeOn', () {
      expect(const AppSettings().canNotifyStreak, isTrue);
      expect(
        const AppSettings(notificationsEnabled: false).canNotifyStreak,
        isFalse,
      );
      expect(
        const AppSettings(streakReminderEnabled: false).canNotifyStreak,
        isFalse,
      );
    });
  });

  group('EarnedBadges JSON round-trip (AC-13/AC-18)', () {
    test('roundTrip_restoresIdsAndWindowMonday', () {
      final original = EarnedBadges(
        earnedIds: <String>{'a', 'b', 'c'},
        windowWeekMonday: DateTime(2026, 6, 22),
      );
      final restored = EarnedBadges.fromJson(original.toJson());
      expect(restored.earnedIds, original.earnedIds);
      expect(restored.windowWeekMonday, DateTime(2026, 6, 22));
    });

    test('emptyState_roundTrips', () {
      final restored = EarnedBadges.fromJson(
        const EarnedBadges.empty().toJson(),
      );
      expect(restored.earnedIds, isEmpty);
      expect(restored.windowWeekMonday, isNull);
    });

    test('jsonShape_carriesOnlyIdFlagsAndADate_noRawSignals (TC-027)', () {
      final json = EarnedBadges(
        earnedIds: <String>{'x'},
        windowWeekMonday: DateTime(2026, 6, 22),
      ).toJson();
      expect(json.keys.toSet(), <String>{'earnedIds', 'windowWeekMonday'});
    });

    test('nonListEarnedIds_throwsFormatException', () {
      expect(
        () => EarnedBadges.fromJson(<String, dynamic>{'earnedIds': 'oops'}),
        throwsFormatException,
      );
    });

    test('nonStringIdEntry_throwsFormatException', () {
      expect(
        () => EarnedBadges.fromJson(<String, dynamic>{
          'earnedIds': <dynamic>['ok', 42],
        }),
        throwsFormatException,
      );
    });

    test('wrongTypedWindowMonday_throwsFormatException', () {
      expect(
        () => EarnedBadges.fromJson(<String, dynamic>{
          'earnedIds': <dynamic>[],
          'windowWeekMonday': 12345,
        }),
        throwsFormatException,
      );
    });

    test('malformedWindowMonday_throwsFormatException', () {
      expect(
        () => EarnedBadges.fromJson(<String, dynamic>{
          'earnedIds': <dynamic>[],
          'windowWeekMonday': 'nope',
        }),
        throwsFormatException,
      );
    });
  });
}
