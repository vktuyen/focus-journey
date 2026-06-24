/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'package:equatable/equatable.dart';

import 'calendar_week.dart';

/// The persistable earned-badge state: the set of earned badge ids plus the
/// Monday (date-only) of the week the **windowed** badges were last earned in
/// and the day (date-only) the **daily** badges were last earned in, so a week
/// rollover resets the windowed ones and a day rollover resets the daily ones,
/// while permanent badges persist (AC-17/AC-18).
///
/// **Privacy:** holds only badge id flags + dates — no raw signals (TC-027).
class EarnedBadges extends Equatable {
  /// Creates earned-badge state.
  EarnedBadges({
    required Set<String> earnedIds,
    DateTime? windowWeekMonday,
    DateTime? dailyDay,
  }) : earnedIds = Set<String>.unmodifiable(earnedIds),
       windowWeekMonday = windowWeekMonday == null
           ? null
           : DateTime(
               windowWeekMonday.year,
               windowWeekMonday.month,
               windowWeekMonday.day,
             ),
       dailyDay = dailyDay == null
           ? null
           : DateTime(dailyDay.year, dailyDay.month, dailyDay.day);

  /// The empty starting state (nothing earned yet).
  const EarnedBadges.empty()
    : earnedIds = const <String>{},
      windowWeekMonday = null,
      dailyDay = null;

  /// The set of earned badge ids (permanent + currently-earned windowed/daily).
  final Set<String> earnedIds;

  /// The Mon-anchored week the windowed badges currently belong to, or `null`
  /// when no windowed badge has been earned yet.
  final DateTime? windowWeekMonday;

  /// The local day (date-only) the currently-earned daily badges belong to, or
  /// `null` when no daily badge has been earned yet (M2 / AC-17).
  final DateTime? dailyDay;

  /// Whether [id] is currently earned.
  bool contains(String id) => earnedIds.contains(id);

  /// Serialises to a JSON-compatible map (ids list + optional week-Monday / day
  /// ISO strings).
  Map<String, dynamic> toJson() => <String, dynamic>{
    'earnedIds': earnedIds.toList(),
    if (windowWeekMonday != null) 'windowWeekMonday': _iso(windowWeekMonday!),
    if (dailyDay != null) 'dailyDay': _iso(dailyDay!),
  };

  /// Reconstructs from [toJson]'s output, degrading safely (throws
  /// [FormatException] on a malformed blob so the data layer can drop it).
  factory EarnedBadges.fromJson(Map<String, dynamic> json) {
    final rawIds = json['earnedIds'];
    if (rawIds is! List) {
      throw const FormatException('earnedIds is missing or not a list');
    }
    final ids = <String>{};
    for (final id in rawIds) {
      if (id is! String) {
        throw FormatException('earnedIds entry is not a string', id);
      }
      ids.add(id);
    }
    return EarnedBadges(
      earnedIds: ids,
      windowWeekMonday: _parseOptionalIso(
        json['windowWeekMonday'],
        'windowWeekMonday',
      ),
      dailyDay: _parseOptionalIso(json['dailyDay'], 'dailyDay'),
    );
  }

  static DateTime? _parseOptionalIso(Object? raw, String field) {
    if (raw == null) {
      return null;
    }
    if (raw is! String) {
      throw FormatException('$field is not a string', raw);
    }
    return _parseIso(raw, field);
  }

  static String _iso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime _parseIso(String value, String field) {
    final parts = value.split('-');
    if (parts.length != 3) {
      throw FormatException('$field is not yyyy-MM-dd', value);
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      throw FormatException('$field has non-numeric parts', value);
    }
    return DateTime(year, month, day);
  }

  /// Returns a copy with the windowed ids dropped if [today] is in a different
  /// Mon–Sun week than [windowWeekMonday] (AC-18). [windowedIds] is the set of
  /// ids whose scope is windowed (passed in by the evaluator from the
  /// catalogue). Permanent and daily ids are never touched here.
  EarnedBadges resetWindowedIfNewWeek(DateTime today, Set<String> windowedIds) {
    final thisMonday = CalendarWeek.mondayOf(today);
    if (windowWeekMonday == null || windowWeekMonday == thisMonday) {
      return this;
    }
    // New week: drop the currently-earned windowed ids; keep the rest.
    final kept = earnedIds.where((id) => !windowedIds.contains(id)).toSet();
    return EarnedBadges(
      earnedIds: kept,
      windowWeekMonday: null,
      dailyDay: dailyDay,
    );
  }

  /// Returns a copy with the daily ids dropped if [today] is a different local
  /// calendar day than [dailyDay] (M2 / AC-17). [dailyIds] is the set of ids
  /// whose scope is daily. Permanent and windowed ids are never touched here.
  /// Date compare is component-based via the date-only fields (M1, DST-safe).
  EarnedBadges resetDailyIfNewDay(DateTime today, Set<String> dailyIds) {
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (dailyDay == null || dailyDay == todayOnly) {
      return this;
    }
    // New day: drop the currently-earned daily ids; keep the rest.
    final kept = earnedIds.where((id) => !dailyIds.contains(id)).toSet();
    return EarnedBadges(
      earnedIds: kept,
      windowWeekMonday: windowWeekMonday,
      dailyDay: null,
    );
  }

  @override
  List<Object?> get props => <Object?>[earnedIds, windowWeekMonday, dailyDay];
}
