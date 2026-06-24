/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'badge.dart';
import 'calendar_week.dart';
import 'earned_badges.dart';

/// The result of one evaluation pass: the next earned-badge state plus the ids
/// **newly** earned this pass (so the caller can fire one badge-earned toast per
/// new badge; AC-12).
class BadgeEvaluation {
  /// Creates the result.
  const BadgeEvaluation({required this.earned, required this.newlyEarned});

  /// The updated earned-badge state (to persist + render).
  final EarnedBadges earned;

  /// The ids that transitioned locked → earned in this pass (empty if none).
  final List<String> newlyEarned;
}

/// Pure badge evaluation over the data-driven catalogue (AC-13). Stateless,
/// deterministic; keys window resets off an injected `today`.
abstract final class BadgeEvaluator {
  /// Evaluates [catalogue] against [context], starting from [current] earned
  /// state, with windowed badges reset first if [today] is a new Mon–Sun week
  /// and daily badges reset if [today] is a new local day (AC-17/AC-18).
  /// Returns the next state + the newly-earned ids.
  ///
  /// A badge transitions locked → earned the first time its predicate is true;
  /// once earned it stays earned for its scope's window (permanent forever;
  /// weekly until the next week boundary; daily until the next midnight). The
  /// predicate is read-only over the consumed [context] — no OS read, no engine
  /// write (TC-026).
  static BadgeEvaluation evaluate({
    required List<BadgeDefinition> catalogue,
    required BadgeContext context,
    required EarnedBadges current,
    required DateTime today,
  }) {
    final windowedIds = catalogue
        .where((b) => b.scope == BadgeScope.weekly)
        .map((b) => b.id)
        .toSet();
    final dailyIds = catalogue
        .where((b) => b.scope == BadgeScope.daily)
        .map((b) => b.id)
        .toSet();

    // Reset windowed badges if we've crossed into a new week, and daily badges
    // if we've crossed into a new day (AC-17/AC-18), before evaluating.
    final base = current
        .resetWindowedIfNewWeek(today, windowedIds)
        .resetDailyIfNewDay(today, dailyIds);

    final nextIds = Set<String>.of(base.earnedIds);
    final newly = <String>[];
    DateTime? windowMonday = base.windowWeekMonday;
    DateTime? dailyDay = base.dailyDay;

    for (final badge in catalogue) {
      if (nextIds.contains(badge.id)) {
        continue;
      }
      if (badge.isEarned(context)) {
        nextIds.add(badge.id);
        newly.add(badge.id);
        switch (badge.scope) {
          case BadgeScope.weekly:
            windowMonday = CalendarWeek.mondayOf(today);
          case BadgeScope.daily:
            dailyDay = DateTime(today.year, today.month, today.day);
          case BadgeScope.permanent:
            break;
        }
      }
    }

    return BadgeEvaluation(
      earned: EarnedBadges(
        earnedIds: nextIds,
        windowWeekMonday: windowMonday,
        dailyDay: dailyDay,
      ),
      newlyEarned: newly,
    );
  }
}
