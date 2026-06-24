/// Presentation layer. The immutable value object the [RouteProgressCubit]
/// emits and the map screen renders.
///
/// SEPARATION INVARIANT (AC-16/AC-17/TC-016/TC-017): imports ONLY pure-Dart
/// domain types + `equatable`. Holds NO activity logic, NO idle seconds, NO lock
/// query, NO distance accrual — it is a read-only snapshot derived purely from
/// the engine's cumulative `distanceKm` scalar and the user's selection.
library;

import 'package:equatable/equatable.dart';

import '../domain/route_position.dart';
import '../domain/route_selection.dart';

/// A flattened, immutable view of route progress for the map screen.
///
/// [selection] is `null` before the user has picked a start (the screen shows
/// the start picker); once chosen, [position] carries the resolved place along
/// the chain. Equality (via [Equatable]) lets the painter skip redundant redraws
/// (smooth-paint NFR / TC-NF2).
class RouteViewState extends Equatable {
  /// Creates a view state.
  const RouteViewState({
    required this.selection,
    required this.position,
    required this.cumulativeDistanceKm,
  });

  /// The pre-selection default: no route chosen yet, zero cumulative distance.
  const RouteViewState.initial()
    : selection = null,
      position = null,
      cumulativeDistanceKm = 0;

  /// The active route selection, or `null` when none has been chosen.
  final RouteSelection? selection;

  /// The resolved position along the chain, or `null` when no route is active.
  final RoutePosition? position;

  /// The engine's cumulative `distanceKm` last observed (read-only; used to
  /// capture the next route's offset when the user starts a new journey).
  final double cumulativeDistanceKm;

  /// Whether a route is active (a selection has been made).
  bool get hasRoute => selection != null && position != null;

  /// Whether the active route has reached its destination (completed; AC-11).
  bool get isCompleted => position?.isCompleted ?? false;

  @override
  List<Object?> get props => <Object?>[
    selection,
    position,
    cumulativeDistanceKm,
  ];
}
