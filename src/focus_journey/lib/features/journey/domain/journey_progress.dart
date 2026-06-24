/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'package:equatable/equatable.dart';

import 'journey_state.dart';
import 'travel_mode.dart';

/// The persistable snapshot of the [JourneyEngine]'s state.
///
/// **Privacy by construction (P0):** this carries ONLY aggregate counters,
/// cumulative position, the cosmetic mode, and the stored calendar date — never
/// any raw signal (no idle samples, no lock history, no input data). It is the
/// only thing persisted (AC-11), and the `data/` repository serialises exactly
/// these fields.
///
/// Durations serialise as integer milliseconds; the stored calendar date
/// serialises as an ISO `yyyy-MM-dd` string (date only — no clock time, so a
/// restore on a later local day is detectable, AC-9/AC-10).
class JourneyProgress extends Equatable {
  /// Creates a snapshot. [storedDate] is normalised to a date-only value
  /// (midnight, local) so only the calendar day is compared on restore.
  JourneyProgress({
    required this.distanceKm,
    required this.activeTimeToday,
    required this.rawActiveTime,
    required this.idleTimeToday,
    required this.state,
    required this.mode,
    required DateTime storedDate,
  }) : storedDate = DateTime(storedDate.year, storedDate.month, storedDate.day);

  /// Cumulative distance travelled (km). Survives day boundaries (AC-9/AC-10).
  final double distanceKm;

  /// Journey time for the stored day, **including** grace (AC-2). Daily counter.
  final Duration activeTimeToday;

  /// True input time for the stored day, **excluding** grace — the
  /// streak-qualifying metric (AC-2/AC-15). Daily counter; `≤ activeTimeToday`.
  final Duration rawActiveTime;

  /// Idle/paused time for the stored day. Daily counter.
  final Duration idleTimeToday;

  /// The traveller's motion state at snapshot time.
  final JourneyState state;

  /// The cosmetic travel skin (does not affect accrual in v1, AC-13).
  final TravelMode mode;

  /// The local calendar date (date-only) the daily counters belong to. On
  /// restore, a stored date earlier than today triggers a daily-counter reset
  /// (AC-10); a future stored date is treated as today and does NOT reset
  /// (TC-020).
  final DateTime storedDate;

  /// The stored date as an ISO `yyyy-MM-dd` string (date only).
  String get storedDateIso =>
      '${storedDate.year.toString().padLeft(4, '0')}-'
      '${storedDate.month.toString().padLeft(2, '0')}-'
      '${storedDate.day.toString().padLeft(2, '0')}';

  /// Serialises to a JSON-compatible map. Durations as `inMilliseconds` ints;
  /// the date as an ISO `yyyy-MM-dd` string; enums by name.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'distanceKm': distanceKm,
    'activeTimeMs': activeTimeToday.inMilliseconds,
    'rawActiveTimeMs': rawActiveTime.inMilliseconds,
    'idleTimeMs': idleTimeToday.inMilliseconds,
    'state': state.name,
    'mode': mode.name,
    'storedDate': storedDateIso,
  };

  /// Reconstructs a snapshot from [toJson]'s output, **degrading safely** instead
  /// of crashing a restore (B-4). Unknown enum names fall back to safe defaults
  /// (`paused` / `motorbike`). A corrupt, partial, wrong-typed, or malformed-date
  /// blob throws [FormatException] — the data layer's `load()` catches that and
  /// treats it as "no saved progress" (fresh start) rather than crashing startup.
  factory JourneyProgress.fromJson(Map<String, dynamic> json) {
    return JourneyProgress(
      distanceKm: _readDouble(json['distanceKm'], 'distanceKm'),
      activeTimeToday: Duration(
        milliseconds: _readInt(json['activeTimeMs'], 'activeTimeMs'),
      ),
      rawActiveTime: Duration(
        milliseconds: _readInt(json['rawActiveTimeMs'], 'rawActiveTimeMs'),
      ),
      idleTimeToday: Duration(
        milliseconds: _readInt(json['idleTimeMs'], 'idleTimeMs'),
      ),
      state: _stateByName(json['state'] as String?),
      mode: _modeByName(json['mode'] as String?),
      storedDate: _parseIsoDate(json['storedDate']),
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

  static JourneyState _stateByName(String? name) {
    for (final value in JourneyState.values) {
      if (value.name == name) {
        return value;
      }
    }
    return JourneyState.paused;
  }

  static TravelMode _modeByName(String? name) {
    for (final value in TravelMode.values) {
      if (value.name == name) {
        return value;
      }
    }
    return TravelMode.motorbike;
  }

  /// Parses an ISO `yyyy-MM-dd` string into a date-only [DateTime], throwing a
  /// [FormatException] on anything malformed (missing, wrong type, wrong arity,
  /// or non-numeric / out-of-range parts) so a corrupt date never escapes as a
  /// raw `RangeError`/`TypeError` past the data layer's guard (B-4).
  static DateTime _parseIsoDate(Object? value) {
    if (value is! String) {
      throw FormatException('storedDate is missing or not a string', value);
    }
    final parts = value.split('-');
    if (parts.length != 3) {
      throw FormatException('storedDate is not yyyy-MM-dd', value);
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      throw FormatException('storedDate has non-numeric parts', value);
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      throw FormatException('storedDate has out-of-range parts', value);
    }
    return DateTime(year, month, day);
  }

  @override
  List<Object?> get props => <Object?>[
    distanceKm,
    activeTimeToday,
    rawActiveTime,
    idleTimeToday,
    state,
    mode,
    storedDate,
  ];
}
