/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
library;

import 'package:equatable/equatable.dart';

import 'journey_direction.dart';
import 'province.dart';
import 'province_chain.dart';

/// The user's chosen route: a [start] province, a [direction], the per-route
/// [routeStartOffsetKm] (locked decision 1), and whether it has [completed].
///
/// **Per-route offset (locked decision 1 / AC-14).** The shipped engine is never
/// reset. When a route begins, [routeStartOffsetKm] captures the engine's current
/// cumulative `distanceKm`; the resolver then keys off
/// `routeDistanceKm = cumulativeDistanceKm − routeStartOffsetKm`, so a new route
/// restarts at 0 while the engine's cumulative keeps climbing as a free lifetime
/// total.
///
/// **Off-direction tip guard (locked decision 4 / AC-15 / TC-015).** The picker
/// disables an off-chain direction for a tip province, but [RouteSelection.create]
/// adds a defensive **model-level** guard: an invalid (tip, off-direction) pair
/// is rejected ([ArgumentError]) so the model can never silently start a route
/// already-finished (zero checkpoints ahead at `routeDistanceKm = 0`). The const
/// constructor stays unchecked for cheap deserialisation of already-valid blobs;
/// callers building a *new* selection must use [RouteSelection.create].
class RouteSelection extends Equatable {
  /// Unchecked constructor (used by [fromJson] and equality). Prefer
  /// [RouteSelection.create] for new selections so the off-direction tip guard
  /// runs.
  const RouteSelection({
    required this.start,
    required this.direction,
    required this.routeStartOffsetKm,
    this.completed = false,
  });

  /// Builds a validated selection, rejecting an off-direction tip pair
  /// (locked decision 4). [chain] supplies the geometry the guard checks
  /// against; [routeStartOffsetKm] is the engine's cumulative distance captured
  /// at the moment the route begins (≥ 0).
  factory RouteSelection.create({
    required Province start,
    required JourneyDirection direction,
    required double routeStartOffsetKm,
    required ProvinceChain chain,
    bool completed = false,
  }) {
    if (chain.indexOf(start) < 0) {
      throw ArgumentError.value(start, 'start', 'not part of the chain');
    }
    if (chain.isOffDirectionTip(start, direction)) {
      throw ArgumentError.value(
        direction,
        'direction',
        'off-chain direction for tip "${start.id}" — a route can never begin '
            'already-finished (locked decision 4 / AC-15)',
      );
    }
    if (routeStartOffsetKm < 0) {
      throw ArgumentError.value(
        routeStartOffsetKm,
        'routeStartOffsetKm',
        'must be >= 0',
      );
    }
    return RouteSelection(
      start: start,
      direction: direction,
      routeStartOffsetKm: routeStartOffsetKm,
      completed: completed,
    );
  }

  /// The origin checkpoint the route starts from.
  final Province start;

  /// The travel direction (which tip is the destination).
  final JourneyDirection direction;

  /// The engine's cumulative `distanceKm` captured when this route began. The
  /// resolver subtracts it from cumulative to get `routeDistanceKm` (AC-14).
  final double routeStartOffsetKm;

  /// Whether the route has reached its destination tip. Persisted so completion
  /// survives a restart (AC-10) and is terminal until the user starts a new
  /// route (AC-13).
  final bool completed;

  /// Returns a copy with [completed] set (used when the resolver detects arrival
  /// — the cubit persists the completed selection). All other fields unchanged.
  RouteSelection copyWith({bool? completed}) => RouteSelection(
    start: start,
    direction: direction,
    routeStartOffsetKm: routeStartOffsetKm,
    completed: completed ?? this.completed,
  );

  /// Serialises to a JSON-compatible map (stable province id + enum name).
  Map<String, dynamic> toJson() => <String, dynamic>{
    'startId': start.id,
    'direction': direction.name,
    'routeStartOffsetKm': routeStartOffsetKm,
    'completed': completed,
  };

  /// Reconstructs a selection from [toJson]'s output against [chain] (needed to
  /// resolve the persisted province id back to a [Province]).
  ///
  /// Degrades safely (B-4 pattern, mirrors `JourneyProgress.fromJson`): a
  /// missing / wrong-typed field, an unknown direction name, or an id not in the
  /// chain throws [FormatException] so the data layer's `load()` treats it as
  /// "no saved selection" rather than crashing startup.
  factory RouteSelection.fromJson(
    Map<String, dynamic> json,
    ProvinceChain chain,
  ) {
    final startId = json['startId'];
    if (startId is! String) {
      throw FormatException('startId missing or not a string', startId);
    }
    final start = chain.nodes.where((p) => p.id == startId);
    if (start.isEmpty) {
      throw FormatException('startId not in chain', startId);
    }
    final direction = _directionByName(json['direction']);
    final offset = json['routeStartOffsetKm'];
    if (offset is! num) {
      throw FormatException(
        'routeStartOffsetKm missing or not a number',
        offset,
      );
    }
    final completed = json['completed'];
    if (completed is! bool) {
      throw FormatException('completed missing or not a bool', completed);
    }
    return RouteSelection(
      start: start.first,
      direction: direction,
      routeStartOffsetKm: offset.toDouble(),
      completed: completed,
    );
  }

  static JourneyDirection _directionByName(Object? name) {
    for (final value in JourneyDirection.values) {
      if (value.name == name) {
        return value;
      }
    }
    throw FormatException('unknown direction', name);
  }

  @override
  List<Object?> get props => <Object?>[
    start,
    direction,
    routeStartOffsetKm,
    completed,
  ];
}
