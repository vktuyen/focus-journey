/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'badge.dart';

/// The v1 milestone-badge catalogue, defined as **data** (AC-13): one entry per
/// badge across all four families. The thresholds below are **named tunable
/// constants** — retuning them is a one-line edit that does NOT change the
/// evaluator's code shape (the data-driven requirement; pending OQ "exact badge
/// thresholds"). Tests key off the catalogue *structure* + threshold-crossing,
/// not these literals.
abstract final class BadgeThresholds {
  // --- Distance (AC-14) ---
  /// "First 100 km" cumulative mark (km).
  static const double distanceFirst100Km = 100;

  /// "500 km traveller" cumulative mark (km).
  static const double distance500Km = 500;

  /// "Halfway home" cumulative mark — roughly half the ~2000 km chain (km).
  static const double distance1000Km = 1000;

  /// "Century week" — 100 km within the current Mon–Sun week (km).
  static const double weekDistance100Km = 100;

  // --- Journey progress (AC-15) ---
  /// "Halfway across Vietnam" — percent of country.
  static const double halfwayPercent = 50;

  /// "Five provinces in" — checkpoints passed beyond the origin.
  static const int crossedProvinces = 5;

  // --- Focus streaks (AC-16) ---
  /// Short streak length (days).
  static const int streakShort = 3;

  /// Week-long streak length (days).
  static const int streakWeek = 7;

  /// Month-long streak length (days).
  static const int streakMonth = 30;

  // --- Focus time (AC-17) ---
  /// "Deep focus" — a single uninterrupted raw-active stretch today.
  static const Duration bestFocusGoal = Duration(minutes: 50);

  /// The single daily raw-active goal (AC-17, "daily-goal-met").
  static const Duration dailyRawActiveGoal = Duration(hours: 2);

  /// "Ten hours focused" — total cumulative raw-active hours.
  static const double totalRawHoursGoal = 10;
}

/// The catalogue itself. Order is the display order in the achievements view.
abstract final class BadgeCatalogue {
  /// The full v1 badge list (data-driven; AC-13).
  static final List<BadgeDefinition> badges = <BadgeDefinition>[
    // --- Distance family ---
    BadgeDefinition(
      id: 'distance_first_100km',
      title: 'First 100 km',
      description: 'Travel 100 km in total.',
      family: BadgeFamily.distance,
      scope: BadgeScope.permanent,
      isEarned: (c) =>
          c.cumulativeDistanceKm >= BadgeThresholds.distanceFirst100Km,
    ),
    BadgeDefinition(
      id: 'distance_500km',
      title: '500 km traveller',
      description: 'Travel 500 km in total.',
      family: BadgeFamily.distance,
      scope: BadgeScope.permanent,
      isEarned: (c) => c.cumulativeDistanceKm >= BadgeThresholds.distance500Km,
    ),
    BadgeDefinition(
      id: 'distance_1000km',
      title: '1000 km milestone',
      description: 'Travel 1000 km in total.',
      family: BadgeFamily.distance,
      scope: BadgeScope.permanent,
      isEarned: (c) => c.cumulativeDistanceKm >= BadgeThresholds.distance1000Km,
    ),
    BadgeDefinition(
      id: 'distance_century_week',
      title: 'Century week',
      description: 'Travel 100 km within a single Mon–Sun week.',
      family: BadgeFamily.distance,
      scope: BadgeScope.weekly,
      isEarned: (c) => c.weekDistanceKm >= BadgeThresholds.weekDistance100Km,
    ),

    // --- Journey-progress family (consumes route-progress position only) ---
    BadgeDefinition(
      id: 'journey_halfway',
      title: 'Halfway across Vietnam',
      description: 'Reach 50% of the country on your current route.',
      family: BadgeFamily.journeyProgress,
      scope: BadgeScope.permanent,
      isEarned: (c) => c.percentOfCountry >= BadgeThresholds.halfwayPercent,
    ),
    BadgeDefinition(
      id: 'journey_crossed_provinces',
      title: 'Province hopper',
      description: 'Cross 5 provinces on your current route.',
      family: BadgeFamily.journeyProgress,
      scope: BadgeScope.permanent,
      isEarned: (c) => c.provincesPassed >= BadgeThresholds.crossedProvinces,
    ),
    BadgeDefinition(
      id: 'journey_route_complete',
      title: 'Journey complete',
      description: 'Reach the destination of your route.',
      family: BadgeFamily.journeyProgress,
      scope: BadgeScope.permanent,
      isEarned: (c) => c.routeCompleted,
    ),

    // --- Focus-streak family (locked raw-active >= 25 min/day rule) ---
    BadgeDefinition(
      id: 'streak_3_days',
      title: '3-day streak',
      description: 'Focus 25+ minutes on 3 days in a row.',
      family: BadgeFamily.focusStreak,
      scope: BadgeScope.permanent,
      isEarned: (c) => c.currentStreakDays >= BadgeThresholds.streakShort,
    ),
    BadgeDefinition(
      id: 'streak_7_days',
      title: '7-day streak',
      description: 'Focus 25+ minutes on 7 days in a row.',
      family: BadgeFamily.focusStreak,
      scope: BadgeScope.permanent,
      isEarned: (c) => c.currentStreakDays >= BadgeThresholds.streakWeek,
    ),
    BadgeDefinition(
      id: 'streak_30_days',
      title: '30-day streak',
      description: 'Focus 25+ minutes on 30 days in a row.',
      family: BadgeFamily.focusStreak,
      scope: BadgeScope.permanent,
      isEarned: (c) => c.currentStreakDays >= BadgeThresholds.streakMonth,
    ),

    // --- Focus-time family (keyed on RAW active time, never journey time) ---
    BadgeDefinition(
      id: 'focus_deep_stretch',
      title: 'Deep focus',
      description: 'A single 50-minute uninterrupted focus stretch today.',
      family: BadgeFamily.focusTime,
      // Daily: the predicate reads TODAY's best stretch, so it re-earns each day
      // and resets at local midnight (M2 / AC-17), not at the week boundary.
      scope: BadgeScope.daily,
      isEarned: (c) => c.todayBestFocusPeriod >= BadgeThresholds.bestFocusGoal,
    ),
    BadgeDefinition(
      id: 'focus_daily_goal',
      title: 'Daily goal met',
      description: 'Reach 2 hours of raw focus time in a day.',
      family: BadgeFamily.focusTime,
      // Daily: the predicate reads TODAY's raw focus, so it re-earns each day
      // and resets at local midnight (M2 / AC-17).
      scope: BadgeScope.daily,
      isEarned: (c) => c.todayRawActive >= BadgeThresholds.dailyRawActiveGoal,
    ),
    BadgeDefinition(
      id: 'focus_total_10h',
      title: 'Ten hours focused',
      description: 'Accumulate 10 hours of raw focus time in total.',
      family: BadgeFamily.focusTime,
      scope: BadgeScope.permanent,
      isEarned: (c) =>
          c.totalRawActiveHours >= BadgeThresholds.totalRawHoursGoal,
    ),
  ];
}
