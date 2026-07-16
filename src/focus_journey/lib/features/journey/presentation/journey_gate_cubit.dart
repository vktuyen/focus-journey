/// App-service / presentation seam. The explicit **Start gate** for the journey.
///
/// route-real-road: the journey is DERIVED from route state — it RUNS whenever
/// there is a committed active route and is PAUSED only while the user is
/// authoring/re-authoring a route (so the old route does not accrue during
/// setup) or when there is no route at all. There is NO manual Start/Pause
/// control: the flag is `hasActiveRoute && !authoring`, driven by the runtime at
/// launch, by the confirm hook, and by the re-authoring entry points.
///
/// SEPARATION INVARIANT (ADR-0007 firewall): this cubit holds NO `JourneyEngine`
/// reference and touches NO platform channel. It is a pure flag. The owning
/// app-service runtime ([_JourneyRuntime]) LISTENS to this cubit's stream and is
/// the only thing that actually starts/stops the `ActivityTicker` — the gate is
/// never wired into the engine itself, so the pure engine stays untouched. The
/// flag is in-memory only (never persisted).
library;

import 'package:flutter_bloc/flutter_bloc.dart';

/// Emits the journey's running/paused flag (`true` == running). Starts `false`;
/// the runtime opens it at launch when a committed active route was restored.
class JourneyGateCubit extends Cubit<bool> {
  /// Creates the gate in its default: PAUSED (`false`). The runtime opens it if
  /// there is already a committed active route.
  JourneyGateCubit() : super(false);

  /// Whether the journey is currently running (the ticker is accruing distance
  /// and the scene may animate).
  bool get isRunning => state;

  /// Runs the journey (there is a committed active route). Idempotent, and a
  /// safe no-op after [close] (a re-authoring flow's `endAuthoring()` may fire
  /// in a `finally` after a mid-authoring runtime teardown / Factory reset).
  void start() {
    if (!isClosed && !state) {
      emit(true);
    }
  }

  /// Pauses the journey (freezes the odometer + parks the scene). Idempotent,
  /// and a safe no-op after [close].
  void pause() {
    if (!isClosed && state) {
      emit(false);
    }
  }

  /// A re-authoring flow OPENED while a route is still active — pause so the old
  /// route does not accrue during setup.
  void beginAuthoring() => pause();

  /// A re-authoring flow CLOSED — resume travel on the (still-active on cancel,
  /// or newly-confirmed) route. The re-authoring entry points only invoke this
  /// when a route remains active, so resuming is always correct.
  void endAuthoring() => start();
}
