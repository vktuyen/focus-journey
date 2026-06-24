/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'package:equatable/equatable.dart';

/// The minimal, read-only slice of route-progress position the badge logic
/// consumes (AC-15). A plain value object so only data — never a cubit or engine
/// reference — crosses into the stats slice, keeping it a pure consumer that
/// re-implements no geography (TC-026).
class RouteProgressSnapshot extends Equatable {
  /// Creates a route snapshot.
  const RouteProgressSnapshot({
    required this.percentOfCountry,
    required this.provincesPassed,
    required this.completed,
  });

  /// The empty default — no route active.
  const RouteProgressSnapshot.none()
    : percentOfCountry = 0,
      provincesPassed = 0,
      completed = false;

  /// % of country covered, `[0, 100]`.
  final double percentOfCountry;

  /// Checkpoints passed beyond the origin.
  final int provincesPassed;

  /// Whether the route has reached its destination.
  final bool completed;

  @override
  List<Object?> get props => <Object?>[
    percentOfCountry,
    provincesPassed,
    completed,
  ];
}
