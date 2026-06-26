/// Domain layer — pure, deterministic, framework-free Dart. No Flutter, no
/// `flame`, no `latlong2`, no `Timer`, no `DateTime.now()`, no I/O, no network.
/// Fully unit-testable (mirrors [RouteProgressResolver] / [RoutePolylineProjector]
/// purity — route-planner-v2 NFR-1: a small in-memory recompute, never a disk or
/// network round-trip).
///
/// THE AUTO-INSERT / SUB-CHAIN BUILDER (ADR-0005 decision 2). Given the full
/// curated spine ([ProvinceChain] + [ProvinceGeography]) and a user's authored
/// endpoints + optional marked stops, this resolves the **contiguous sub-path**
/// of the spine the user travels, materialised as a SMALLER [ProvinceChain] +
/// derived [ProvinceGeography] sub-view, so the **unchanged** resolver/projector/
/// mapper run literally over it (AC-7 — preserves ADR-0004's single canonical-km
/// axis).
///
/// PRIVACY (NFR-2 — CRITICAL/gating): reads ONLY the static `fullChain` /
/// `fullGeography` reference data. It imports no `ActivityPlugin`, no platform
/// channel, no geolocation/GPS, makes no network call, and reads nothing about
/// the user's device or position — it only slices static reference geography.
library;

import 'province.dart';
import 'province_chain.dart';
import 'province_geography.dart';

/// The fully-resolved output of [RoutePlanner.resolve]: a contiguous spine
/// sub-path materialised so the unchanged route-progress/map machinery can run
/// over it (ADR-0005 decision 1).
///
/// Pure value object (no Flutter, no equality needed — it wraps already-validated
/// value objects). [subChain] is the derived smaller chain (≥2 nodes, strictly
/// south→north canonical order); [subGeography] positions it from the SAME static
/// coordinate lookup; [canonicalOriginKm] is the cumulative-from-south-tip km of
/// the sub-path's south-most node on the FULL chain (the presentation layer adds
/// it to `effectiveDistance` for country % — ADR-0005 decision 3).
class ResolvedRoute {
  /// Bundles the derived [subChain] + [subGeography] with the [orderedNodes] in
  /// the user's travel order (start → end) and the [canonicalOriginKm] offset of
  /// the sub-path origin within the full chain.
  ResolvedRoute({
    required this.subChain,
    required this.subGeography,
    required this.orderedNodes,
    required this.canonicalOriginKm,
  });

  /// The derived sub-chain (a smaller [ProvinceChain]) — what the unchanged
  /// [RouteProgressResolver] / [RoutePolylineProjector] are handed (AC-7).
  final ProvinceChain subChain;

  /// The geography sub-view over [subChain], built from the full geography's
  /// coordinate lookup (no new coordinates invented — build-once-consume-many).
  final ProvinceGeography subGeography;

  /// The authored route's checkpoints in **travel order** (start → end). For a
  /// north-bound route this is the sub-chain's canonical order; for a south-bound
  /// route it is the reverse. The persisted `RoutePlan.orderedNodeIds` mirror it.
  final List<Province> orderedNodes;

  /// The cumulative km from the full chain's south tip to the sub-path's
  /// south-most node (the sub-chain's `southTip`). Added to the route's
  /// `effectiveDistance` to compute country % at the presentation layer
  /// (ADR-0005 decision 3). 0 when the sub-path starts at the south tip.
  final double canonicalOriginKm;

  /// The total length (km) of the sub-path — the route's own distance and its
  /// completion threshold (AC-5/AC-8). Equal to `subChain.totalChainKm` by
  /// construction (ADR-0005 decision 1).
  double get subPathKm => subChain.totalChainKm;

  /// The travel-order node ids (start → end) — the authoritative authored route
  /// persisted by `RoutePlan` (ADR-0005 decision 4).
  List<String> get orderedNodeIds => <String>[
    for (final node in orderedNodes) node.id,
  ];
}

/// Builds a [ResolvedRoute] (the derived sub-chain) from a user's authored
/// endpoints + optional marked stops (ADR-0005 decision 2). Stateless and pure.
abstract final class RoutePlanner {
  /// Resolves the contiguous spine sub-path for the authored route.
  ///
  /// - [start] / [end] are the user's chosen endpoints on [fullChain]. Direction
  ///   is implied by which one sits earlier in the canonical (south→north) order
  ///   (AC-1). [start] == [end] is rejected ([ArgumentError]) — a route can never
  ///   be zero-length (AC-2).
  /// - [markedStops] (optional) are provinces the user cares about. A stop INSIDE
  ///   the `[start, end]` span is already auto-included (every spine checkpoint
  ///   between the endpoints is filled in spine order — AC-3); a stop OUTSIDE the
  ///   span **extends the span** so the stop becomes the new extreme endpoint in
  ///   its direction (AC-4).
  /// - [removedStops] (optional, the review screen's edit — AC-5) are interior
  ///   checkpoints the user skipped. Removing an interior node MERGES its two
  ///   adjacent segments (sums their km) when deriving the sub-chain, so
  ///   `subPathKm` and the canonical axis stay exact and the polyline draws
  ///   straight between the survivors (ADR-0005 decision 1 consequence). The two
  ///   extreme endpoints are NEVER removable below the 2-node minimum (AC-2/AC-5).
  ///
  /// Reads ONLY [fullChain] / [fullGeography] static reference data (NFR-2). The
  /// result is always a single contiguous spine sub-path of ≥2 adjacent (after
  /// any merge) nodes in travel order.
  static ResolvedRoute resolve({
    required ProvinceChain fullChain,
    required ProvinceGeography fullGeography,
    required Province start,
    required Province end,
    List<Province> markedStops = const <Province>[],
    Set<String> removedStops = const <String>{},
  }) {
    final startIndex = fullChain.indexOf(start);
    final endIndex = fullChain.indexOf(end);
    if (startIndex < 0) {
      throw ArgumentError.value(start, 'start', 'not part of the full chain');
    }
    if (endIndex < 0) {
      throw ArgumentError.value(end, 'end', 'not part of the full chain');
    }
    if (startIndex == endIndex) {
      throw ArgumentError.value(
        end,
        'end',
        'start == end: a route can never be zero-length (AC-2)',
      );
    }

    final ascending = endIndex > startIndex;

    // AC-4: a marked stop outside the [start, end] span extends the span to the
    // farther endpoint in its direction. We extend the canonical-index window to
    // cover every marked stop (and the endpoints), so the span is the inclusive
    // min..max of {start, end, ...markedStops}.
    var lowIndex = startIndex < endIndex ? startIndex : endIndex;
    var highIndex = startIndex > endIndex ? startIndex : endIndex;
    for (final stop in markedStops) {
      final stopIndex = fullChain.indexOf(stop);
      if (stopIndex < 0) {
        throw ArgumentError.value(
          stop,
          'markedStops',
          'not part of the full chain',
        );
      }
      if (stopIndex < lowIndex) {
        lowIndex = stopIndex;
      }
      if (stopIndex > highIndex) {
        highIndex = stopIndex;
      }
    }

    // The inclusive canonical slice [lowIndex..highIndex] in spine order (AC-3).
    // A marked stop is never removable, so removals only apply to interior nodes
    // that are NOT a survivor endpoint or a marked stop.
    final markedIds = <String>{for (final s in markedStops) s.id};

    // Build the surviving canonical node list + the merged segment list. A
    // removed interior node is dropped and its two adjacent segments are summed
    // into the survivor's leg (ADR-0005 decision 1 consequence), preserving the
    // canonical axis exactly.
    final survivingNodes = <Province>[];
    final survivingSegmentsKm = <double>[];
    // The cumulative km from the FULL chain's south tip to each full-chain node,
    // so a merged leg's km is the difference between two survivors' cumulatives
    // (which equals the sum of the merged adjacent segments — no float drift).
    final canonicalOriginKm = _cumulativeFromSouthTip(fullChain, lowIndex);

    for (var i = lowIndex; i <= highIndex; i++) {
      final node = fullChain.nodes[i];
      final isEndpoint = i == lowIndex || i == highIndex;
      final isMarked = markedIds.contains(node.id);
      final isRemoved = removedStops.contains(node.id);
      // Endpoints and marked stops are protected (AC-2/AC-4/AC-5); only an
      // unprotected interior node may be skipped.
      if (isRemoved && !isEndpoint && !isMarked) {
        continue; // dropped — its segments merge into the surviving neighbours.
      }
      if (survivingNodes.isNotEmpty) {
        // The leg from the previous survivor to this node = the difference of
        // their cumulative-from-south-tip distances (= the sum of every skipped
        // interior segment in between), so merges are exact (no drift).
        final prevCumulative = _cumulativeFromSouthTip(
          fullChain,
          fullChain.indexOf(survivingNodes.last),
        );
        final thisCumulative = _cumulativeFromSouthTip(fullChain, i);
        survivingSegmentsKm.add(thisCumulative - prevCumulative);
      }
      survivingNodes.add(node);
    }

    if (survivingNodes.length < 2) {
      // Defensive: the endpoints are always retained, so the slice has ≥2 nodes.
      throw ArgumentError(
        'resolved sub-chain has fewer than two checkpoints (AC-2 minimum)',
      );
    }

    final subChain = ProvinceChain(
      nodes: List<Province>.unmodifiable(survivingNodes),
      segmentsKm: List<double>.unmodifiable(survivingSegmentsKm),
    );
    final subGeography = ProvinceGeography(
      chain: subChain,
      coordinates: <String, GeoCoordinate>{
        for (final node in survivingNodes)
          node.id: fullGeography.coordinateOf(node),
      },
    );

    // Travel order: canonical (south→north) for a north-bound route, reversed
    // for a south-bound one (AC-1 — direction implied by which endpoint is the
    // start).
    final orderedNodes = ascending
        ? List<Province>.from(survivingNodes)
        : survivingNodes.reversed.toList();

    return ResolvedRoute(
      subChain: subChain,
      subGeography: subGeography,
      orderedNodes: List<Province>.unmodifiable(orderedNodes),
      canonicalOriginKm: canonicalOriginKm,
    );
  }

  /// Rebuilds a [ResolvedRoute] from an already-authored ordered node-id list
  /// (the persisted `RoutePlan.orderedNodeIds`), looking each id up in
  /// [fullChain] and slicing the matching segments. The list is the authoritative
  /// authored route after edits/merges (ADR-0005 decision 4), so this is the
  /// deterministic restart path — no re-derivation of intermediates.
  ///
  /// Throws [ArgumentError] if an id is not in [fullChain], if there are fewer
  /// than two ids, or if the ids are not a monotonic (all-ascending or
  /// all-descending) walk of the canonical order (a contiguous-after-merge
  /// sub-path is always monotonic; ADR-0005 decision 1).
  static ResolvedRoute fromOrderedIds({
    required ProvinceChain fullChain,
    required ProvinceGeography fullGeography,
    required List<String> orderedNodeIds,
  }) {
    if (orderedNodeIds.length < 2) {
      throw ArgumentError.value(
        orderedNodeIds,
        'orderedNodeIds',
        'a route needs at least two checkpoints (AC-2)',
      );
    }
    final byId = <String, Province>{
      for (final node in fullChain.nodes) node.id: node,
    };
    final orderedNodes = <Province>[];
    final indices = <int>[];
    for (final id in orderedNodeIds) {
      final node = byId[id];
      if (node == null) {
        throw ArgumentError.value(
          id,
          'orderedNodeIds',
          'not in the full chain',
        );
      }
      orderedNodes.add(node);
      indices.add(fullChain.indexOf(node));
    }
    // The travel order must be a strictly monotonic walk of the canonical index
    // (a contiguous sub-path; ADR-0005 decision 1). Determine the direction from
    // the first step and verify the rest agrees.
    final ascending = indices[1] > indices[0];
    for (var i = 1; i < indices.length; i++) {
      final goesUp = indices[i] > indices[i - 1];
      if (goesUp != ascending) {
        throw ArgumentError.value(
          orderedNodeIds,
          'orderedNodeIds',
          'not a monotonic sub-path of the spine',
        );
      }
    }

    // Canonical (south→north) node list = the travel-order list, reversed when
    // the route is south-bound, so the sub-chain stays in canonical order.
    final canonicalNodes = ascending
        ? List<Province>.from(orderedNodes)
        : orderedNodes.reversed.toList();
    final segmentsKm = <double>[];
    for (var i = 1; i < canonicalNodes.length; i++) {
      final prev = _cumulativeFromSouthTip(
        fullChain,
        fullChain.indexOf(canonicalNodes[i - 1]),
      );
      final cur = _cumulativeFromSouthTip(
        fullChain,
        fullChain.indexOf(canonicalNodes[i]),
      );
      segmentsKm.add(cur - prev);
    }

    final subChain = ProvinceChain(
      nodes: List<Province>.unmodifiable(canonicalNodes),
      segmentsKm: List<double>.unmodifiable(segmentsKm),
    );
    final subGeography = ProvinceGeography(
      chain: subChain,
      coordinates: <String, GeoCoordinate>{
        for (final node in canonicalNodes)
          node.id: fullGeography.coordinateOf(node),
      },
    );
    final canonicalOriginKm = _cumulativeFromSouthTip(
      fullChain,
      fullChain.indexOf(canonicalNodes.first),
    );
    return ResolvedRoute(
      subChain: subChain,
      subGeography: subGeography,
      orderedNodes: List<Province>.unmodifiable(orderedNodes),
      canonicalOriginKm: canonicalOriginKm,
    );
  }

  /// The cumulative km from [fullChain]'s south tip to `nodes[index]` (index 0 →
  /// 0). Mirrors `ProvinceChain._canonicalCumulative` (which is private), used to
  /// compute merged-leg km and the country-% origin exactly.
  static double _cumulativeFromSouthTip(ProvinceChain fullChain, int index) {
    var sum = 0.0;
    for (var i = 0; i < index; i++) {
      sum += fullChain.segmentsKm[i];
    }
    return sum;
  }
}
