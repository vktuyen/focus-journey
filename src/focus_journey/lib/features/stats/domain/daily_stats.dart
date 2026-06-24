/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'package:equatable/equatable.dart';

/// The projected daily view: the four headline numbers for the current local
/// day (AC-1), with **raw active time carried as its own labelled field** that
/// is **never** `> activeTime` (AC-2, the headline honesty rule).
///
/// This is a pure value object produced by [DailyStatsProjection.project] from a
/// fixed engine snapshot — no accrual logic, no OS read (the slice is a pure
/// consumer; TC-026). Equality (via [Equatable]) makes it cheap to test
/// field-by-field and to skip redundant widget rebuilds.
class DailyStats extends Equatable {
  /// Creates a daily view. Asserts the honesty invariant in debug; the
  /// projection function below additionally enforces it in all builds. Not
  /// `const` because the assert message interpolates the runtime values.
  // ignore: prefer_const_constructors_in_immutables
  DailyStats({
    required this.activeTime,
    required this.rawActiveTime,
    required this.distanceKm,
    required this.idleTime,
    required this.bestFocusPeriod,
  }) : assert(
         rawActiveTime <= activeTime,
         'honesty invariant: rawActiveTime ($rawActiveTime) must be '
         '<= activeTime ($activeTime)',
       );

  /// Journey time today, **including** grace (AC-1). The "active / journey time"
  /// value the UI labels distinctly from [rawActiveTime].
  final Duration activeTime;

  /// True input time today, **excluding** grace — its **own** value, surfaced
  /// separately and never `> activeTime` (AC-2).
  final Duration rawActiveTime;

  /// Distance accrued today (km) — today's delta, read from the engine.
  final double distanceKm;

  /// Idle/paused time today.
  final Duration idleTime;

  /// The day's longest continuous raw-active stretch (AC-3).
  final Duration bestFocusPeriod;

  @override
  List<Object?> get props => <Object?>[
    activeTime,
    rawActiveTime,
    distanceKm,
    idleTime,
    bestFocusPeriod,
  ];
}

/// Thrown by [DailyStatsProjection.project] when an input snapshot violates the
/// engine's `rawActiveTime <= activeTimeToday` invariant. Surfacing the defect
/// (rather than silently rendering raw > journey) is the load-bearing AC-2 rule
/// in **all** builds, not just behind `assert`.
class HonestyInvariantViolation implements Exception {
  /// Creates the violation carrying the offending values for diagnostics.
  const HonestyInvariantViolation(this.rawActiveTime, this.activeTime);

  /// The raw-active value that was reported greater than [activeTime].
  final Duration rawActiveTime;

  /// The journey-time value the raw value exceeded.
  final Duration activeTime;

  @override
  String toString() =>
      'HonestyInvariantViolation: rawActiveTime ($rawActiveTime) > '
      'activeTime ($activeTime) — raw active time may never exceed journey time '
      '(AC-2).';
}

/// Pure projection of an engine snapshot + today's best-focus-period into the
/// daily view. Stateless, deterministic, framework-free (Determinism NFR).
abstract final class DailyStatsProjection {
  /// Projects today's daily view from the engine's already-decided scalars.
  ///
  /// Throws [HonestyInvariantViolation] if `rawActiveTime > activeTime` — the
  /// projection never emits a view that conflates the two or shows raw as
  /// greater (AC-2). A snapshot with `rawActiveTime == activeTime` (no grace
  /// consumed) is allowed and projected as equal.
  static DailyStats project({
    required Duration activeTime,
    required Duration rawActiveTime,
    required double distanceKm,
    required Duration idleTime,
    required Duration bestFocusPeriod,
  }) {
    if (rawActiveTime > activeTime) {
      throw HonestyInvariantViolation(rawActiveTime, activeTime);
    }
    return DailyStats(
      activeTime: activeTime,
      rawActiveTime: rawActiveTime,
      distanceKm: distanceKm,
      idleTime: idleTime,
      bestFocusPeriod: bestFocusPeriod,
    );
  }
}
