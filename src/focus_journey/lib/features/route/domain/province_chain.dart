/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O.
///
/// The single source of truth for the Vietnam province chain geometry: an
/// ordered list of checkpoints (south tip → north tip) plus the positive
/// inter-checkpoint segment distances. This file owns `totalChainKm`; the engine
/// takes `kmPerActiveHour` as injected config derived from `totalChainKm ÷ ~8h`.
///
/// ## province-chain-2026 (candidate ADR-0009): 34-unit great-circle spine
/// The chain is rebuilt onto Vietnam's **34 current administrative units (2026)**
/// from the single ordered source-of-record [kVietnamUnits2026]. Segment
/// distances are AUTO-COMPUTED as the [greatCircleKm] (haversine) distance
/// between consecutive administrative-centre coordinates — NOT hand-authored
/// stylized km — so `totalChainKm` reflects real 2026 geography (≈3160 km).
/// The order is a hand-curated coast-hugging south→north spine verified by the
/// dense no-sea-crossing test (AC-5). This supersedes the old stylized 13-node /
/// ~2000 km premise.
library;

import 'haversine.dart';
import 'journey_direction.dart';
import 'province.dart';
import 'vietnam_units_2026.dart';

/// An ordered chain of [Province] checkpoints with the inter-checkpoint
/// distances between each adjacent pair.
///
/// Invariants (enforced by the constructor — Chain-data integrity NFR / TC-NF4):
/// - ordered south tip → north tip (index 0 = the southernmost centre
///   `Cà Mau`; last = the northernmost current unit, the max-latitude centre);
/// - at least two nodes, no duplicate ids;
/// - exactly `nodes.length - 1` segments, **every one strictly positive**;
/// - the sum of segment distances equals [totalChainKm] (within [_sumTolerance]).
///
/// The chain stores distances in canonical (south→north) order. Direction-aware
/// helpers ([cumulativeFromStart], [destinationOf], [distanceToDestination])
/// translate a (start, direction) pair onto this canonical geometry so the
/// resolver never has to special-case direction in its arithmetic.
class ProvinceChain {
  /// Creates and validates a chain. Throws [ArgumentError] on any violated
  /// invariant so a malformed chain fails loudly at construction (even in
  /// release), not silently at paint or resolve time.
  ProvinceChain({required this.nodes, required this.segmentsKm}) {
    if (nodes.length < 2) {
      throw ArgumentError.value(
        nodes.length,
        'nodes',
        'a chain needs at least two checkpoints',
      );
    }
    if (segmentsKm.length != nodes.length - 1) {
      throw ArgumentError.value(
        segmentsKm.length,
        'segmentsKm',
        'expected ${nodes.length - 1} segments for ${nodes.length} nodes',
      );
    }
    final seenIds = <String>{};
    for (final node in nodes) {
      if (!seenIds.add(node.id)) {
        throw ArgumentError.value(node.id, 'nodes', 'duplicate province id');
      }
    }
    for (var i = 0; i < segmentsKm.length; i++) {
      if (!(segmentsKm[i] > 0)) {
        throw ArgumentError.value(
          segmentsKm[i],
          'segmentsKm[$i]',
          'every inter-checkpoint distance must be strictly positive',
        );
      }
    }
    // `totalChainKm` is derived from the segments, so the sum invariant holds by
    // construction. The assert documents the contract for tests/readers.
    assert(
      (totalChainKm - segmentsKm.reduce((a, b) => a + b)).abs() <=
          _sumTolerance,
      'totalChainKm must equal the summed segments',
    );
  }

  /// Float tolerance for the segment-sum invariant (km).
  static const double _sumTolerance = 1e-6;

  /// The checkpoints in canonical order: index 0 = south tip (`Cà Mau`), last
  /// index = north tip (the northernmost current unit — the max-latitude centre).
  final List<Province> nodes;

  /// `segmentsKm[i]` is the distance (km) from `nodes[i]` to `nodes[i + 1]`,
  /// in canonical south→north order. Length is `nodes.length - 1`.
  final List<double> segmentsKm;

  /// The south tip (`Cà Mau`) — the destination when heading south.
  Province get southTip => nodes.first;

  /// The north tip (the northernmost current unit, max-latitude centre) — the
  /// destination when heading north. (Its identity changed under the 2026 units;
  /// the `towardHaGiang` label is kept as a stable symbolic name — see
  /// [JourneyDirection].)
  Province get northTip => nodes.last;

  /// Total chain length (km) — the sum of all segments. This is the source of
  /// truth that, ÷ ~8 active hours, gives the engine's `kmPerActiveHour`.
  /// Computed from [segmentsKm] so it can never drift.
  double get totalChainKm => segmentsKm.fold<double>(0, (a, b) => a + b);

  /// The cumulative canonical distance (km) from the south tip to `nodes[index]`
  /// (index 0 → 0). Used internally to translate any node to a position on the
  /// shared south→north number line.
  double _canonicalCumulative(int index) {
    var sum = 0.0;
    for (var i = 0; i < index; i++) {
      sum += segmentsKm[i];
    }
    return sum;
  }

  /// The index of [province] in [nodes], or `-1` if not part of this chain.
  int indexOf(Province province) => nodes.indexOf(province);

  /// Whether [start] pointed in [direction] points OFF the chain — i.e. [start]
  /// is the tip that is already the destination for that direction, so the route
  /// would begin already-finished (locked decision 4 / AC-15).
  ///
  /// - `towardHaGiang` from the north tip is off-chain (nothing ahead).
  /// - `towardMuiCaMau` from the south tip is off-chain (nothing ahead).
  bool isOffDirectionTip(Province start, JourneyDirection direction) {
    return destinationOf(start, direction) == start;
  }

  /// The completion destination tip for [direction] (AC-8). Independent of
  /// [start]; direction alone selects the tip.
  Province destinationOf(Province start, JourneyDirection direction) {
    return switch (direction) {
      JourneyDirection.towardHaGiang => northTip,
      JourneyDirection.towardMuiCaMau => southTip,
    };
  }

  /// The signed distance (km) from [start] to [target] when travelling in
  /// [direction]. Positive means [target] lies ahead of [start] in that
  /// direction; zero means [target] == [start]; negative means it lies behind
  /// (already passed before the route began — used by the resolver's guard).
  ///
  /// Built on the canonical south→north number line: heading north, distance is
  /// `cumulative(target) − cumulative(start)`; heading south it is the negation.
  double distanceFromStartTo(
    Province start,
    Province target,
    JourneyDirection direction,
  ) {
    final startIndex = indexOf(start);
    final targetIndex = indexOf(target);
    if (startIndex < 0) {
      throw ArgumentError.value(start, 'start', 'not part of this chain');
    }
    if (targetIndex < 0) {
      throw ArgumentError.value(target, 'target', 'not part of this chain');
    }
    final delta =
        _canonicalCumulative(targetIndex) - _canonicalCumulative(startIndex);
    return switch (direction) {
      JourneyDirection.towardHaGiang => delta,
      JourneyDirection.towardMuiCaMau => -delta,
    };
  }

  /// The distance (km) from [start] to the [direction]'s destination tip — the
  /// route's full length and the completion threshold. Computed structurally
  /// (sum of remaining segments in the chosen direction), never hardcoded
  /// (TC-011).
  double distanceToDestination(Province start, JourneyDirection direction) {
    return distanceFromStartTo(
      start,
      destinationOf(start, direction),
      direction,
    );
  }

  /// The checkpoints ahead of [start] in [direction] (excluding [start]), in
  /// travel order — i.e. the order they will be reached. The first element is
  /// the immediate next checkpoint; the last is the destination tip.
  List<Province> checkpointsAhead(Province start, JourneyDirection direction) {
    final startIndex = indexOf(start);
    if (startIndex < 0) {
      throw ArgumentError.value(start, 'start', 'not part of this chain');
    }
    return switch (direction) {
      JourneyDirection.towardHaGiang => nodes.sublist(startIndex + 1),
      JourneyDirection.towardMuiCaMau =>
        nodes.sublist(0, startIndex).reversed.toList(growable: false),
    };
  }
}

/// The production curated chain (province-chain-2026 / candidate ADR-0009): all
/// **34 current administrative units (2026)** in a hand-curated coast-hugging
/// south→north spine, built from the single ordered source-of-record
/// [kVietnamUnits2026].
///
/// `nodes` are the 34 [Province]s in that order (index 0 = Cà Mau, the
/// southernmost centre; last = Cao Bằng, the northernmost / max-latitude unit).
/// `segmentsKm` are the **33** great-circle ([greatCircleKm]) distances between
/// consecutive administrative-centre coordinates, so `totalChainKm` (≈3160 km)
/// reflects real 2026 geography rather than a stylized total. The order never
/// crosses open sea on the shipped 34-province base map — verified by the dense
/// no-sea-crossing test (AC-5); fix any regression by RE-ORDERING the units in
/// [kVietnamUnits2026], never by adding a non-unit waypoint.
final ProvinceChain vietnamProvinceChain = ProvinceChain(
  nodes: List<Province>.unmodifiable(<Province>[
    for (final unit in kVietnamUnits2026)
      Province(id: unit.id, name: unit.name),
  ]),
  segmentsKm: List<double>.unmodifiable(<double>[
    for (var i = 0; i < kVietnamUnits2026.length - 1; i++)
      greatCircleKm(
        kVietnamUnits2026[i].lat,
        kVietnamUnits2026[i].lon,
        kVietnamUnits2026[i + 1].lat,
        kVietnamUnits2026[i + 1].lon,
      ),
  ]),
);
