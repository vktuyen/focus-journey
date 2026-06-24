/// Presentation layer (Flame). Computes a cosmetic ambient day/night tint from
/// `timeOfDayHours` ONLY. Pure function of its input — it never reads a clock,
/// never gates or alters motion (AC-12/TC-012/TC-025). The colour is a function
/// of time-of-day alone, so day vs night differ while motion stays identical.
library;

import 'dart:ui';

/// Stateless helper that maps an hour-of-day to an overlay colour drawn over
/// the whole scene. Daytime → near-transparent warm; night → translucent deep
/// blue. Dawn/dusk interpolate smoothly between the bands.
abstract final class DayNightTint {
  /// Returns the ambient overlay colour for [timeOfDayHours] (`0.0..24.0`).
  /// Out-of-range values are wrapped into the day, so a bad input still yields
  /// a valid, motion-neutral tint (never throws).
  static Color tintFor(double timeOfDayHours) {
    final double h = _wrap24(timeOfDayHours);
    // 0 = full day (clear), 1 = full night (dark blue).
    final double nightness = _nightness(h);
    // Night overlay: deep blue at up to ~55% opacity.
    const int nightR = 8;
    const int nightG = 14;
    const int nightB = 48;
    final double alpha = 0.55 * nightness;
    return Color.fromRGBO(nightR, nightG, nightB, alpha);
  }

  /// Daytime sky base colour for [timeOfDayHours]; used to clear the canvas so
  /// the horizon reads warm by day and dim by night. Cosmetic only.
  static Color skyFor(double timeOfDayHours) {
    final double h = _wrap24(timeOfDayHours);
    final double nightness = _nightness(h);
    final Color day = const Color(0xFF8FD0F0); // bright midday sky
    final Color night = const Color(0xFF0B1230); // deep night sky
    return Color.lerp(day, night, nightness) ?? day;
  }

  /// `0.0` at solar noon, `1.0` deep at night, smoothly ramping across
  /// dawn (~5–7 h) and dusk (~18–20 h). Pure, deterministic.
  static double _nightness(double h) {
    // Full day window: 7..18. Full night: 20..5. Linear ramps between.
    if (h >= 7 && h <= 18) {
      return 0;
    }
    if (h > 18 && h < 20) {
      return (h - 18) / 2.0; // dusk ramp up
    }
    if (h > 5 && h < 7) {
      return 1.0 - (h - 5) / 2.0; // dawn ramp down
    }
    return 1; // 20..24 and 0..5
  }

  /// Wraps any double into `[0, 24)`.
  static double _wrap24(double hours) {
    if (hours.isNaN || hours.isInfinite) {
      return 12;
    }
    final double m = hours % 24.0;
    return m < 0 ? m + 24.0 : m;
  }
}
