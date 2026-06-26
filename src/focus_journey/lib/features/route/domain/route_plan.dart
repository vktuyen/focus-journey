/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
///
/// THE PERSISTED AUTHORED-ROUTE DESCRIPTOR (ADR-0005 decision 4). A [RoutePlan]
/// is the user-authored route: an **ordered list of province ids** in travel
/// order (start → end — the authoritative authored sub-path after any review-
/// screen edits/segment-merges), the per-route [routeStartOffsetKm] (route-
/// progress decision 1), and a **3-state lifecycle** (`active`/`completed`/
/// `abandoned` — ADR-0005 decision 5).
///
/// `RoutePlan` is a NEW descriptor type, not an extension of `RouteSelection`
/// (which encodes the now-superseded start+direction model + a binary `completed`
/// flag — ADR-0005 decision 4). `RouteSelection` is retained internally as the
/// per-sub-chain input the **unchanged** resolver/projector still take; a
/// [RoutePlan] DERIVES one (first node + implied direction) via [RoutePlanner],
/// so AC-7's "unchanged" holds.
library;

import 'package:equatable/equatable.dart';

import 'journey_direction.dart';
import 'province_chain.dart';
import 'province_geography.dart';
import 'route_planner.dart';
import 'route_selection.dart';

/// The 3-state lifecycle of an authored route (ADR-0005 decision 5).
///
/// Persisted by enum `name` so the round-trip is stable across builds (mirrors
/// `JourneyDirection` persistence in [RouteSelection]).
enum RouteLifecycle {
  /// In progress — the live route the traveller is on.
  active,

  /// Reached its end (`routeDistanceKm >= subPathKm`). Fires the arrival
  /// celebration (AC-8). Terminal until the user starts a new route.
  completed,

  /// Abandoned mid-journey (AC-10). A DISTINCT terminal state from [completed]:
  /// it does NOT fire the arrival celebration, and the engine's lifetime distance
  /// is never reset (abandon = a new offset over the never-reset cumulative).
  abandoned,
}

/// A user-authored route: the ordered node-id sub-path + offset + lifecycle.
///
/// Immutable [Equatable] value object. Persisted via the existing `RouteRepository`
/// JSON seam (no new store — AC-12). The ordered id list is the authoritative
/// authored route; `start`/`direction` are *derivable* from it (first id + whether
/// the list ascends or descends the canonical index), so storing the list avoids a
/// redundant, drift-prone second field (ADR-0005 decision 4).
class RoutePlan extends Equatable {
  /// Creates a plan from its persisted fields. Prefer [RoutePlan.fromResolved]
  /// for a freshly-authored route so the ids come straight from the resolver.
  const RoutePlan({
    required this.orderedNodeIds,
    required this.routeStartOffsetKm,
    this.lifecycle = RouteLifecycle.active,
  });

  /// Builds a plan from a resolver-produced [ResolvedRoute] (the authored sub-
  /// path) + the captured [routeStartOffsetKm]. The ids are the travel-order
  /// sub-path (start → end).
  factory RoutePlan.fromResolved(
    ResolvedRoute resolved, {
    required double routeStartOffsetKm,
    RouteLifecycle lifecycle = RouteLifecycle.active,
  }) {
    return RoutePlan(
      orderedNodeIds: List<String>.unmodifiable(resolved.orderedNodeIds),
      routeStartOffsetKm: routeStartOffsetKm,
      lifecycle: lifecycle,
    );
  }

  /// The authored sub-path node ids in travel order (start → end). At least two
  /// ids (AC-2). The authoritative authored route after edits/merges.
  final List<String> orderedNodeIds;

  /// The engine's cumulative `distanceKm` captured when this route began
  /// (route-progress decision 1). The resolver keys off
  /// `routeDistanceKm = cumulative − routeStartOffsetKm`.
  final double routeStartOffsetKm;

  /// The route's lifecycle (ADR-0005 decision 5).
  final RouteLifecycle lifecycle;

  /// Whether the route is the live, in-progress one.
  bool get isActive => lifecycle == RouteLifecycle.active;

  /// Whether the route reached its end (fires the celebration — AC-8).
  bool get isCompleted => lifecycle == RouteLifecycle.completed;

  /// Whether the route was abandoned (NO celebration — AC-10).
  bool get isAbandoned => lifecycle == RouteLifecycle.abandoned;

  /// Returns a copy with a new [lifecycle] (the only mutable field — used when
  /// completion is latched (AC-8) or the route is abandoned (AC-10)).
  RoutePlan copyWith({RouteLifecycle? lifecycle}) => RoutePlan(
    orderedNodeIds: orderedNodeIds,
    routeStartOffsetKm: routeStartOffsetKm,
    lifecycle: lifecycle ?? this.lifecycle,
  );

  /// Re-derives this plan's [ResolvedRoute] (sub-chain + sub-geography +
  /// canonical origin) over the full [chain] / [geography] (ADR-0005 decision 1).
  /// Deterministic — the same ids always rebuild the same sub-chain (AC-12).
  ResolvedRoute toResolved(ProvinceChain chain, ProvinceGeography geography) {
    return RoutePlanner.fromOrderedIds(
      fullChain: chain,
      fullGeography: geography,
      orderedNodeIds: orderedNodeIds,
    );
  }

  /// Derives the internal [RouteSelection] (start tip of the sub-chain + the
  /// direction implied by the ordered ids) the **unchanged** [RouteProgressResolver]
  /// / [RoutePolylineProjector] take (AC-7). [resolved] is this plan's sub-chain;
  /// the direction is north when the travel order ascends the sub-chain's canonical
  /// order (i.e. the first travel node is the sub-chain's south tip).
  ///
  /// Uses the **unchecked** [RouteSelection] constructor (not `.create`) so a
  /// completed/abandoned plan whose start is the sub-chain's tip-toward-destination
  /// is still re-buildable on restore — the off-direction guard is for *new* picks,
  /// not for rebuilding an already-authored plan.
  RouteSelection toSelection(ResolvedRoute resolved) {
    final firstTravelNode = resolved.orderedNodes.first;
    final direction = firstTravelNode == resolved.subChain.southTip
        ? JourneyDirection.towardHaGiang
        : JourneyDirection.towardMuiCaMau;
    return RouteSelection(
      start: firstTravelNode,
      direction: direction,
      routeStartOffsetKm: routeStartOffsetKm,
      // The resolver's own terminal-completion flag mirrors the lifecycle so a
      // restored completed plan stays frozen at arrival (AC-8 / route-progress
      // AC-13). An abandoned plan is no longer the active route, so its flag is
      // irrelevant (the cubit never resolves an abandoned plan).
      completed: lifecycle == RouteLifecycle.completed,
    );
  }

  /// Serialises to a JSON-compatible map (stable ids + lifecycle enum name).
  Map<String, dynamic> toJson() => <String, dynamic>{
    'orderedNodeIds': orderedNodeIds,
    'routeStartOffsetKm': routeStartOffsetKm,
    'lifecycle': lifecycle.name,
  };

  /// Reconstructs a plan from [toJson]'s output. Degrades safely (mirrors
  /// `RouteSelection.fromJson`): a missing/wrong-typed field, an id list shorter
  /// than two, or an unknown lifecycle name throws [FormatException] so the data
  /// layer's `load()` treats it as "no saved route" rather than crashing startup.
  factory RoutePlan.fromJson(Map<String, dynamic> json) {
    final rawIds = json['orderedNodeIds'];
    if (rawIds is! List) {
      throw FormatException('orderedNodeIds missing or not a list', rawIds);
    }
    final ids = <String>[];
    for (final id in rawIds) {
      if (id is! String) {
        throw FormatException('orderedNodeIds contains a non-string', id);
      }
      ids.add(id);
    }
    if (ids.length < 2) {
      throw FormatException('orderedNodeIds has fewer than two ids', ids);
    }
    final offset = json['routeStartOffsetKm'];
    if (offset is! num) {
      throw FormatException(
        'routeStartOffsetKm missing or not a number',
        offset,
      );
    }
    final lifecycle = _lifecycleByName(json['lifecycle']);
    return RoutePlan(
      orderedNodeIds: List<String>.unmodifiable(ids),
      routeStartOffsetKm: offset.toDouble(),
      lifecycle: lifecycle,
    );
  }

  static RouteLifecycle _lifecycleByName(Object? name) {
    for (final value in RouteLifecycle.values) {
      if (value.name == name) {
        return value;
      }
    }
    throw FormatException('unknown lifecycle', name);
  }

  @override
  List<Object?> get props => <Object?>[
    orderedNodeIds,
    routeStartOffsetKm,
    lifecycle,
  ];
}
