/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'package:equatable/equatable.dart';

import 'province.dart';

/// The immutable, fully-resolved position of a traveller along the chain — the
/// deterministic output of [RouteProgressResolver.resolve] (no side effects, no
/// I/O, no timers).
///
/// Every field is derived purely from `(routeDistanceKm, selection, chain)`, so
/// the same inputs always yield an equal [RoutePosition] (Determinism NFR /
/// TC-NF1). [Equatable] lets the painter's `shouldRepaint` cheaply skip redraws
/// when nothing relevant changed (smooth-paint NFR / TC-NF2).
class RoutePosition extends Equatable {
  /// Creates a resolved position from already-computed values.
  const RoutePosition({
    required this.passed,
    required this.next,
    required this.distanceToNextKm,
    required this.currentSegmentFrom,
    required this.currentSegmentTo,
    required this.percentOfCountry,
    required this.isCompleted,
    required this.destination,
    required this.routeDistanceKm,
    required this.distanceToDestinationKm,
    required this.fractionAlongRoute,
  });

  /// Checkpoints already reached, in travel order — the origin plus every
  /// checkpoint whose cumulative-from-start distance is `<= routeDistanceKm`
  /// (a checkpoint reached at exactly its distance counts as passed; AC-3).
  /// Always non-empty (contains at least the origin; AC-2).
  final List<Province> passed;

  /// The first un-passed checkpoint ahead, or `null` once the destination has
  /// been reached (completed; AC-11).
  final Province? next;

  /// Remaining km to [next] (`next`'s cumulative-from-start − routeDistanceKm).
  /// `0` when completed (no next).
  final double distanceToNextKm;

  /// The "from" end of the current segment — the last passed checkpoint.
  final Province currentSegmentFrom;

  /// The "to" end of the current segment — [next], or [destination] when
  /// completed (the segment collapses onto the final pin; AC-12).
  final Province currentSegmentTo;

  /// Percent of the country covered, distance-based against the **full** chain:
  /// `(routeDistanceKm / totalChainKm) * 100`, clamped to [0, 100] (locked
  /// decision 5 / AC-8). Never reports > 100 (AC-11).
  final double percentOfCountry;

  /// Whether the route has reached its destination tip (`routeDistanceKm >=`
  /// distance-to-destination; AC-11).
  final bool isCompleted;

  /// The destination tip for the selection's direction (AC-8).
  final Province destination;

  /// The route distance this position was resolved at (cumulative − offset),
  /// clamped to `[0, distanceToDestinationKm]` for display so the marker never
  /// overshoots the final pin (AC-12). The engine's raw cumulative is untouched.
  final double routeDistanceKm;

  /// The total distance from start to destination for this route (the
  /// completion threshold; structural, AC-11).
  final double distanceToDestinationKm;

  /// `routeDistanceKm / distanceToDestinationKm`, clamped to [0, 1] — the
  /// marker's position along the route polyline for the painter (1 == on the
  /// destination pin). Distinct from [percentOfCountry] (full-chain denominator).
  final double fractionAlongRoute;

  /// The most recently reached checkpoint (the origin until the first is
  /// passed). Convenience for readouts.
  Province get lastPassed => passed.last;

  @override
  List<Object?> get props => <Object?>[
    passed,
    next,
    distanceToNextKm,
    currentSegmentFrom,
    currentSegmentTo,
    percentOfCountry,
    isCompleted,
    destination,
    routeDistanceKm,
    distanceToDestinationKm,
    fractionAlongRoute,
  ];
}
