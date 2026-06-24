/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'package:equatable/equatable.dart';

/// The four badge families (AC-13). The family is descriptive metadata for the
/// achievements view; the earn rule itself is the per-badge predicate.
enum BadgeFamily {
  /// Distance marks — cumulative distance + "100 km this week" (AC-14).
  distance,

  /// Journey-progress marks — halfway / crossed-N-provinces / route-complete,
  /// consuming route-progress position only (AC-15).
  journeyProgress,

  /// Focus-streak marks — consecutive qualifying days (AC-16).
  focusStreak,

  /// Focus-time marks — best focus period / daily goal / total raw hours
  /// (AC-17).
  focusTime,
}

/// Whether an earned badge is permanent or resets at a window boundary (AC-18).
enum BadgeScope {
  /// Earned once and kept forever — cumulative/permanent progress is never
  /// reset by a window rollover (AC-18). e.g. route-complete, total-hours,
  /// cumulative-distance, streak milestones.
  permanent,

  /// Re-earnable each week; reset to locked at the local Mon–Sun calendar-week
  /// boundary (AC-18). e.g. "100 km this week".
  weekly,

  /// Re-earnable each day; reset to locked at local midnight (AC-17/AC-18).
  /// For badges whose predicate reads TODAY's metrics (e.g. "50-min stretch
  /// today", "2h raw focus in a day") so they re-earn each new day rather than
  /// wrongly persisting until the week rollover.
  daily,
}

/// The inputs a badge predicate reads — a flattened, read-only snapshot of the
/// consumed engine scalars, route-progress position, and history-derived
/// aggregates. The slice is a **pure consumer**: a predicate reads only these
/// values and never an OS signal or a mutable engine reference (TC-026).
class BadgeContext extends Equatable {
  /// Creates the consumed snapshot.
  const BadgeContext({
    required this.cumulativeDistanceKm,
    required this.weekDistanceKm,
    required this.percentOfCountry,
    required this.provincesPassed,
    required this.routeCompleted,
    required this.currentStreakDays,
    required this.todayRawActive,
    required this.todayBestFocusPeriod,
    required this.totalRawActiveHours,
  });

  /// The engine's cumulative `distanceKm` (read-only; AC-14).
  final double cumulativeDistanceKm;

  /// Distance accrued in the current Mon–Sun week (km; AC-14).
  final double weekDistanceKm;

  /// Route-progress % of country, `[0, 100]` (AC-15).
  final double percentOfCountry;

  /// Count of route checkpoints passed beyond the origin (AC-15).
  final int provincesPassed;

  /// Whether the active route has reached its destination (AC-15).
  final bool routeCompleted;

  /// Current consecutive-qualifying-day streak length (AC-16).
  final int currentStreakDays;

  /// Today's raw active time — never grace-inflated journey time (AC-17).
  final Duration todayRawActive;

  /// Today's longest raw-active stretch (AC-17).
  final Duration todayBestFocusPeriod;

  /// Cumulative raw-active hours across all stored history (AC-17).
  final double totalRawActiveHours;

  @override
  List<Object?> get props => <Object?>[
    cumulativeDistanceKm,
    weekDistanceKm,
    percentOfCountry,
    provincesPassed,
    routeCompleted,
    currentStreakDays,
    todayRawActive,
    todayBestFocusPeriod,
    totalRawActiveHours,
  ];
}

/// A single catalogue entry, defined as **data** (AC-13): a stable [id], display
/// metadata, its [family]/[scope], and a pure [isEarned] predicate over a
/// [BadgeContext]. Adding/retuning a badge is a data edit — it does not change
/// the evaluator's code shape (AC-13 / the data-driven requirement).
class BadgeDefinition extends Equatable {
  /// Creates a catalogue entry.
  const BadgeDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.family,
    required this.scope,
    required this.isEarned,
  });

  /// Stable identifier persisted in the earned-badge store (never the title, so
  /// copy edits don't orphan earned state).
  final String id;

  /// Human-readable title for the achievements view.
  final String title;

  /// One-line description of what earns the badge.
  final String description;

  /// Which of the four families this badge belongs to (AC-13).
  final BadgeFamily family;

  /// Whether the badge persists forever or resets at its window (AC-18).
  final BadgeScope scope;

  /// The pure earn predicate — `true` when the consumed [BadgeContext] crosses
  /// this badge's threshold. No side effects, no I/O.
  final bool Function(BadgeContext context) isEarned;

  @override
  List<Object?> get props => <Object?>[id, title, description, family, scope];
}
