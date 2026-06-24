/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'package:equatable/equatable.dart';

/// One completed (or in-progress) local day's aggregate counters.
///
/// **Privacy by construction (P0 / TC-027):** this carries ONLY aggregate
/// counters and a date — never any raw signal (no idle samples, no input data,
/// no window titles). It is the unit persisted to the bounded per-day history
/// store and the input to weekly aggregation + streak counting (AC-4/AC-16).
///
/// Durations serialise as integer milliseconds; the date serialises as an ISO
/// `yyyy-MM-dd` string (date only) — exactly the `JourneyProgress` convention
/// so a restore on a later local day stays detectable (AC-5/AC-19).
class DayStats extends Equatable {
  /// Creates a day entry. [date] is normalised to a date-only value (midnight,
  /// local) so only the calendar day is compared/keyed.
  DayStats({
    required DateTime date,
    required this.activeTime,
    required this.rawActiveTime,
    required this.distanceKmForDay,
    required this.idleTime,
    required this.bestFocusPeriod,
  }) : date = DateTime(date.year, date.month, date.day);

  /// The local calendar date (date-only) these counters belong to.
  final DateTime date;

  /// Journey time for the day, **including** grace (AC-1). `>= rawActiveTime`.
  final Duration activeTime;

  /// True input time for the day, **excluding** grace — the streak-qualifying
  /// metric (AC-2/AC-16). Always `<= activeTime` (honesty invariant).
  final Duration rawActiveTime;

  /// Distance accrued during the day (km) — today's delta, not cumulative.
  final double distanceKmForDay;

  /// Idle/paused time for the day.
  final Duration idleTime;

  /// The day's longest continuous raw-active stretch (AC-3).
  final Duration bestFocusPeriod;

  /// The date as an ISO `yyyy-MM-dd` string (date only).
  String get dateIso =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Serialises to a JSON-compatible map. Durations as `inMilliseconds` ints;
  /// the date as an ISO `yyyy-MM-dd` string.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'date': dateIso,
    'activeTimeMs': activeTime.inMilliseconds,
    'rawActiveTimeMs': rawActiveTime.inMilliseconds,
    'distanceKmForDay': distanceKmForDay,
    'idleTimeMs': idleTime.inMilliseconds,
    'bestFocusPeriodMs': bestFocusPeriod.inMilliseconds,
  };

  /// Reconstructs an entry from [toJson]'s output, **degrading safely** — a
  /// corrupt/partial/wrong-typed blob throws [FormatException] so the data
  /// layer's `load()` can drop it (fresh start) rather than crash startup,
  /// exactly like `JourneyProgress.fromJson` (B-4).
  factory DayStats.fromJson(Map<String, dynamic> json) {
    return DayStats(
      date: _parseIsoDate(json['date']),
      activeTime: Duration(
        milliseconds: _readInt(json['activeTimeMs'], 'activeTimeMs'),
      ),
      rawActiveTime: Duration(
        milliseconds: _readInt(json['rawActiveTimeMs'], 'rawActiveTimeMs'),
      ),
      distanceKmForDay: _readDouble(
        json['distanceKmForDay'],
        'distanceKmForDay',
      ),
      idleTime: Duration(
        milliseconds: _readInt(json['idleTimeMs'], 'idleTimeMs'),
      ),
      bestFocusPeriod: Duration(
        milliseconds: _readInt(json['bestFocusPeriodMs'], 'bestFocusPeriodMs'),
      ),
    );
  }

  static double _readDouble(Object? value, String field) {
    if (value is num) {
      return value.toDouble();
    }
    throw FormatException('Field "$field" is missing or not a number', value);
  }

  static int _readInt(Object? value, String field) {
    if (value is int) {
      return value;
    }
    throw FormatException('Field "$field" is missing or not an int', value);
  }

  /// Parses an ISO `yyyy-MM-dd` string into a date-only [DateTime], throwing a
  /// [FormatException] on anything malformed so a corrupt date never escapes as
  /// a raw `RangeError`/`TypeError` past the data layer's guard (B-4). Mirrors
  /// `JourneyProgress._parseIsoDate`.
  static DateTime _parseIsoDate(Object? value) {
    if (value is! String) {
      throw FormatException('date is missing or not a string', value);
    }
    final parts = value.split('-');
    if (parts.length != 3) {
      throw FormatException('date is not yyyy-MM-dd', value);
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      throw FormatException('date has non-numeric parts', value);
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      throw FormatException('date has out-of-range parts', value);
    }
    return DateTime(year, month, day);
  }

  @override
  List<Object?> get props => <Object?>[
    date,
    activeTime,
    rawActiveTime,
    distanceKmForDay,
    idleTime,
    bestFocusPeriod,
  ];
}
