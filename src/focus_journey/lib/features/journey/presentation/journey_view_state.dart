/// Presentation layer. The immutable value object the [JourneyCubit] emits and
/// the journey screen maps onto the Flame scene's `applyState`.
///
/// SEPARATION INVARIANT (AC-9/AC-10/TC-009/TC-010): this file imports ONLY the
/// pure-Dart domain enums ([JourneyState], [TravelMode]) plus `equatable`. It
/// holds NO activity logic — no idle seconds, no lock query, no `DateTime.now()`
/// for an activity decision, no distance accrual. It is a flattened, read-only
/// snapshot of `JourneyEngine`'s `state`/`mode`/`distanceKm` for the view.
library;

import 'package:equatable/equatable.dart';

import '../domain/journey_state.dart';
import '../domain/travel_mode.dart';

/// Binary motion the scene understands: it scrolls iff [moving] (AC-7).
///
/// The engine's three states collapse to two here on purpose: `active` →
/// [moving]; both `idle` and `paused` → [stopped] (AC-2/AC-3 — identical view
/// in v1). The scene never sees the idle/paused distinction.
enum JourneyMotion {
  /// The journey is travelling — the scene scrolls and the vehicle animates.
  moving,

  /// The journey is parked — the scene is stopped (`idle` or `paused`).
  stopped,
}

/// A flattened, immutable view of journey state for the Flame scene + overlays.
///
/// Equality (via [Equatable]) lets `BlocBuilder`/`BlocListener` skip redundant
/// `applyState` calls when nothing the view cares about changed.
class JourneyViewState extends Equatable {
  /// Creates a view state from already-resolved view values.
  const JourneyViewState({
    required this.motion,
    required this.mode,
    required this.distanceKm,
    required this.hasRealState,
    this.idleTimeToday = Duration.zero,
  });

  /// The first-frame / pre-state default (AC-13): parked, default skin, zero
  /// distance, and [hasRealState] `false` so the "Paused — idle" overlay does
  /// NOT show yet (TC-013 — first frame is parked WITHOUT the overlay). The
  /// scene renders its parked/stopped look until a real engine state arrives.
  const JourneyViewState.initial()
    : motion = JourneyMotion.stopped,
      mode = TravelMode.motorbike,
      distanceKm = 0,
      hasRealState = false,
      idleTimeToday = Duration.zero;

  /// Maps a real engine snapshot to the view (TC-005/TC-021).
  ///
  /// [motion] is [JourneyMotion.moving] iff `state == active`; both `idle` and
  /// `paused` map to [JourneyMotion.stopped] (AC-2/AC-3 — identical visual in
  /// v1). [hasRealState] is `true`, so a stopped real state shows the overlay.
  factory JourneyViewState.fromEngine(
    JourneyState state,
    TravelMode mode,
    double distanceKm, {
    Duration idleTimeToday = Duration.zero,
  }) {
    final JourneyMotion motion = state == JourneyState.active
        ? JourneyMotion.moving
        : JourneyMotion.stopped;
    return JourneyViewState(
      motion: motion,
      mode: mode,
      distanceKm: distanceKm,
      hasRealState: true,
      idleTimeToday: idleTimeToday,
    );
  }

  /// Whether the scene should scroll/animate (mapped to the scene's `moving`).
  final JourneyMotion motion;

  /// The cosmetic vehicle skin to display (AC-8). Never affects scroll speed.
  final TravelMode mode;

  /// Cumulative distance for the plain-Flutter counter overlay (NOT the scene).
  final double distanceKm;

  /// The displayed idle counter (idle-accounting AC-2). It is the engine's
  /// `idleTimeToday` accumulator read verbatim — the Cubit applies NO
  /// independent rounding or smoothing — so the displayed value and the
  /// accounting accumulator agree with **divergence 0** by construction (Option
  /// B anchors both to the same stamped value). Never derived from a separate
  /// wall-clock-since-onset computation that could drift.
  final Duration idleTimeToday;

  /// `true` once a real engine state has been observed; `false` only for the
  /// pre-state [JourneyViewState.initial] default. Gates the overlay so the
  /// first parked frame shows no "Paused — idle" message (TC-013).
  final bool hasRealState;

  /// Whether the "Paused — idle" overlay should be shown.
  ///
  /// Rule (explicit per TC-013): show it only when there is a *real* stopped
  /// state — i.e. [motion] is [JourneyMotion.stopped] AND [hasRealState] is
  /// `true`. The pre-state first frame is parked but shows NO overlay; a real
  /// `idle`/`paused` state is parked AND shows the overlay (AC-2/AC-3).
  bool get showPausedOverlay => motion == JourneyMotion.stopped && hasRealState;

  @override
  List<Object?> get props => <Object?>[
    motion,
    mode,
    distanceKm,
    hasRealState,
    idleTimeToday,
  ];
}
