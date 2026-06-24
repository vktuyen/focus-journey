/// Presentation layer. The immutable view state the [StatsCubit] emits and the
/// stats / badges screens render.
///
/// SEPARATION INVARIANT (TC-026): holds NO engine reference, NO OS signal, NO
/// activity logic — only projected aggregates, the weekly aggregate, the streak
/// length, and the earned/locked badge lists. Derived purely from the engine's
/// exposed scalars + route position + persisted state.
library;

import 'package:equatable/equatable.dart';

import '../domain/badge.dart';
import '../domain/daily_stats.dart';
import '../domain/weekly_stats.dart';

/// A flattened, immutable view of the stats + badges surfaces.
class StatsViewState extends Equatable {
  /// Creates a view state.
  const StatsViewState({
    required this.daily,
    required this.weekly,
    required this.currentStreakDays,
    required this.earnedBadgeIds,
    required this.catalogue,
  });

  /// The pre-data default (zeros, empty week, no badges) before the first tick.
  StatsViewState.initial()
    : daily = DailyStats(
        activeTime: Duration.zero,
        rawActiveTime: Duration.zero,
        distanceKm: 0,
        idleTime: Duration.zero,
        bestFocusPeriod: Duration.zero,
      ),
      weekly = const WeeklyStats.empty(),
      currentStreakDays = 0,
      earnedBadgeIds = const <String>{},
      catalogue = const <BadgeDefinition>[];

  /// Today's projected daily view (AC-1/AC-2).
  final DailyStats daily;

  /// The current Mon–Sun weekly aggregate (AC-4).
  final WeeklyStats weekly;

  /// The current consecutive-qualifying-day streak length (AC-16).
  final int currentStreakDays;

  /// The set of currently-earned badge ids (AC-13/AC-18).
  final Set<String> earnedBadgeIds;

  /// The full badge catalogue (for rendering earned vs locked; AC-13).
  final List<BadgeDefinition> catalogue;

  /// The earned badges, in catalogue order.
  List<BadgeDefinition> get earnedBadges =>
      catalogue.where((b) => earnedBadgeIds.contains(b.id)).toList();

  /// The locked badges, in catalogue order.
  List<BadgeDefinition> get lockedBadges =>
      catalogue.where((b) => !earnedBadgeIds.contains(b.id)).toList();

  /// Returns a copy with the given fields overridden.
  StatsViewState copyWith({
    DailyStats? daily,
    WeeklyStats? weekly,
    int? currentStreakDays,
    Set<String>? earnedBadgeIds,
    List<BadgeDefinition>? catalogue,
  }) {
    return StatsViewState(
      daily: daily ?? this.daily,
      weekly: weekly ?? this.weekly,
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
      earnedBadgeIds: earnedBadgeIds ?? this.earnedBadgeIds,
      catalogue: catalogue ?? this.catalogue,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    daily,
    weekly,
    currentStreakDays,
    earnedBadgeIds,
    catalogue,
  ];
}
