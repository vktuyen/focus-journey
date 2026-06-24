/// Presentation layer. Pure mapping from the journey Bloc's view state onto the
/// tray surface's [TrayActivityState] + status line (AC-11/AC-13). It reads ONLY
/// the already-decided view state — it makes no activity decision and accrues no
/// distance (AC-10).
library;

import '../../journey/presentation/journey_view_state.dart';
import '../domain/tray_state.dart';

/// Maps a [JourneyViewState] onto the tray surface values.
abstract final class JourneyTrayMapper {
  /// The tray icon/tooltip state (AC-11): travelling → [TrayActivityState.active],
  /// parked (idle/paused, or the pre-state default) → [TrayActivityState.paused].
  static TrayActivityState stateFor(JourneyViewState s) {
    return s.motion == JourneyMotion.moving
        ? TrayActivityState.active
        : TrayActivityState.paused;
  }

  /// The optional tray status line (AC-13), e.g. "Travelling — 1,240 km" /
  /// "Paused — 1,240 km". Consistent with the Bloc's `state` and `distanceKm`.
  static String statusLineFor(JourneyViewState s) {
    final String verb = s.motion == JourneyMotion.moving
        ? 'Travelling'
        : 'Paused';
    return '$verb — ${s.distanceKm.toStringAsFixed(1)} km';
  }
}
