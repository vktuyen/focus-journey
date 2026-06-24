/// Presentation layer. The Cubit that turns the engine's cumulative `distanceKm`
/// scalar + the user's [RouteSelection] into a resolved [RouteViewState] for the
/// map screen.
///
/// SEPARATION / PRIVACY INVARIANT (AC-16/AC-17/TC-016/TC-017) — TRUE BY
/// CONSTRUCTION: this cubit holds **no** `JourneyEngine` reference. It consumes a
/// plain `double` cumulative distance via [updateFromDistance] (fed by the
/// app-service ticker on the same cadence as the journey view). It therefore
/// *cannot* read OS signals, cannot touch a platform channel, and cannot mutate
/// engine state — it only maps a given scalar onto the chain via the pure
/// [RouteProgressResolver]. It imports neither `ActivityPlugin` nor any
/// `MethodChannel`.
///
/// DISTANCE-SOURCE SEAM (for tests): drive [updateFromDistance] directly with a
/// scripted cumulative value — no real engine, no timers. `routeDistanceKm =
/// cumulative − selection.routeStartOffsetKm` (locked decision 1 / AC-14).
library;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/journey_direction.dart';
import '../domain/province.dart';
import '../domain/province_chain.dart';
import '../domain/route_progress_resolver.dart';
import '../domain/route_repository.dart';
import '../domain/route_selection.dart';
import 'route_view_state.dart';

/// Emits [RouteViewState] snapshots for the map screen.
class RouteProgressCubit extends Cubit<RouteViewState> {
  /// Creates the cubit with the injected [chain] geometry and [repository]
  /// persistence seam. Optionally seed with a restored [initialSelection]
  /// (loaded at startup; AC-9/AC-10).
  RouteProgressCubit({
    required ProvinceChain chain,
    required RouteRepository repository,
    RouteSelection? initialSelection,
  }) : _chain = chain,
       _repository = repository,
       super(const RouteViewState.initial()) {
    if (initialSelection != null) {
      _selection = initialSelection;
      _emitResolved();
    }
  }

  final ProvinceChain _chain;
  final RouteRepository _repository;

  RouteSelection? _selection;
  double _cumulativeDistanceKm = 0;

  /// Receives the engine's latest cumulative `distanceKm` (a plain scalar — the
  /// only thing this slice reads from the engine; AC-16). Re-resolves and emits.
  ///
  /// Completion is terminal (AC-13): once the active selection is flagged
  /// completed, further increasing distance produces no forward progress — the
  /// resolver clamps to the destination and we persist the completed flag once.
  void updateFromDistance(double cumulativeDistanceKm) {
    _cumulativeDistanceKm = cumulativeDistanceKm;
    _emitResolved();
  }

  /// Starts a new route from [start] heading [direction], capturing the engine's
  /// current cumulative `distanceKm` as the per-route offset (locked decision 1
  /// / AC-14) so the new route restarts at `routeDistanceKm = 0` while the
  /// engine's cumulative keeps climbing. Validates the (tip, off-direction) pair
  /// (locked decision 4) via [RouteSelection.create]. Persists the selection.
  ///
  /// Pass [currentCumulativeKm] to override the captured offset (defaults to the
  /// last value seen via [updateFromDistance]).
  Future<void> startNewRoute(
    Province start,
    JourneyDirection direction, {
    double? currentCumulativeKm,
  }) async {
    final offset = currentCumulativeKm ?? _cumulativeDistanceKm;
    if (currentCumulativeKm != null) {
      _cumulativeDistanceKm = currentCumulativeKm;
    }
    final selection = RouteSelection.create(
      start: start,
      direction: direction,
      routeStartOffsetKm: offset,
      chain: _chain,
    );
    _selection = selection;
    _emitResolved();
    await _repository.save(selection);
  }

  /// Resolves the current selection against the current cumulative distance and
  /// emits. No-op (stays at the pre-selection default) when no route is active.
  void _emitResolved() {
    final selection = _selection;
    if (selection == null) {
      emit(
        RouteViewState(
          selection: null,
          position: null,
          cumulativeDistanceKm: _cumulativeDistanceKm,
        ),
      );
      return;
    }
    final routeDistanceKm =
        _cumulativeDistanceKm - selection.routeStartOffsetKm;
    final position = RouteProgressResolver.resolve(
      routeDistanceKm: routeDistanceKm,
      selection: selection,
      chain: _chain,
    );

    // Latch completion into the persisted selection exactly once, so the
    // completed state survives a restart (AC-10) and stays terminal (AC-13).
    if (position.isCompleted && !selection.completed) {
      final completedSelection = selection.copyWith(completed: true);
      _selection = completedSelection;
      emit(
        RouteViewState(
          selection: completedSelection,
          position: position,
          cumulativeDistanceKm: _cumulativeDistanceKm,
        ),
      );
      // Persist the latched completion (fire-and-forget — load is corrupt-safe).
      _repository.save(completedSelection);
      return;
    }

    emit(
      RouteViewState(
        selection: selection,
        position: position,
        cumulativeDistanceKm: _cumulativeDistanceKm,
      ),
    );
  }
}
