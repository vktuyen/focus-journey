/// Presentation layer. The immutable value object the [RouteProgressCubit]
/// emits and the map screen renders.
///
/// SEPARATION INVARIANT (AC-16/AC-17/TC-016/TC-017): imports ONLY pure-Dart
/// domain types + `equatable`. Holds NO activity logic, NO idle seconds, NO lock
/// query, NO distance accrual — it is a read-only snapshot derived purely from
/// the engine's cumulative `distanceKm` scalar and the user's selection.
library;

import 'package:equatable/equatable.dart';

import '../domain/province_geography.dart';
import '../domain/route_position.dart';
import '../domain/route_selection.dart';

/// A flattened, immutable view of route progress for the map screen.
///
/// [selection] is `null` before the user has picked a start (the screen shows
/// the start picker); once chosen, [position] carries the resolved place along
/// the chain. Equality (via [Equatable]) lets the painter skip redundant redraws
/// (smooth-paint NFR / TC-NF2).
///
/// ## route-planner-v2 (ADR-0005)
/// For a v2 authored route the [selection] + [position] are resolved over the
/// DERIVED SUB-CHAIN (AC-7); [subGeography] carries that sub-chain's geography so
/// the map cubit projects the polyline over the SAME sub-chain (not the full
/// spine). [countryPercent] is the full-chain % the presentation layer computes
/// (ADR-0005 decision 3 — shown alongside the resolver's route %). Both are
/// `null` on the legacy (full-chain) path, where the resolver's `percentOfCountry`
/// already IS the full-chain %.
class RouteViewState extends Equatable {
  /// Creates a view state.
  const RouteViewState({
    required this.selection,
    required this.position,
    required this.cumulativeDistanceKm,
    this.subGeography,
    this.countryPercent,
  });

  /// The pre-selection default: no route chosen yet, zero cumulative distance.
  const RouteViewState.initial()
    : selection = null,
      position = null,
      subGeography = null,
      countryPercent = null,
      cumulativeDistanceKm = 0;

  /// The active route selection (over the sub-chain for v2), or `null` when none
  /// has been chosen.
  final RouteSelection? selection;

  /// The derived sub-chain's geography for a v2 authored route (so the map cubit
  /// projects over the sub-chain — AC-7). `null` on the legacy full-chain path.
  final ProvinceGeography? subGeography;

  /// The resolved position along the (sub-)chain, or `null` when no route is
  /// active. Its `percentOfCountry` over a sub-chain IS the **route %** (AC-8).
  final RoutePosition? position;

  /// The **country %** over the FULL chain (ADR-0005 decision 3), `0..100`. Shown
  /// alongside the route % (AC-8). `null` on the legacy path.
  final double? countryPercent;

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
    subGeography,
    countryPercent,
    cumulativeDistanceKm,
  ];
}
