/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

/// Pure local-calendar-week (**Mon–Sun**) math, keyed off an injected date.
///
/// All boundary logic keys off a supplied `DateTime` (the injected clock's
/// `now()` at the call site) — never an internal `DateTime.now()` — so weekly
/// aggregation stays deterministic (Determinism NFR / AC-4). Dates are compared
/// date-only (local midnight), DST handled the same local-midnight way the
/// engine handles its day boundary.
abstract final class CalendarWeek {
  /// The local-midnight **Monday** that starts the calendar week containing
  /// [date] (Mon–Sun). Dart's `DateTime.weekday` is 1 (Mon) … 7 (Sun).
  ///
  /// Computed by **date components**, not `Duration`-day arithmetic: subtracting
  /// a fixed-24h `Duration` across a local DST transition would land the result
  /// at 23:00/01:00 instead of midnight, so two same-week days could compare
  /// unequal (M1). Letting `DateTime(y, m, d - n)` overflow the day field makes
  /// the constructor normalise to local **midnight** of the correct calendar
  /// day, DST-safe by construction.
  static DateTime mondayOf(DateTime date) => DateTime(
    date.year,
    date.month,
    date.day - (date.weekday - DateTime.monday),
  );

  /// The local-midnight **Sunday** that ends the calendar week containing
  /// [date] (inclusive of the whole Sunday). Component-based (M1, DST-safe).
  static DateTime sundayOf(DateTime date) {
    final monday = mondayOf(date);
    return DateTime(monday.year, monday.month, monday.day + 6);
  }

  /// Whether [date] falls within the same Mon–Sun calendar week as [reference].
  static bool isSameWeek(DateTime date, DateTime reference) =>
      mondayOf(date) == mondayOf(reference);
}
