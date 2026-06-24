/// Domain layer — the PURE HEART of route-progress. Framework-free Dart: no
/// Flutter, no flame, no `Timer`, no `DateTime.now()`, no I/O. Deterministic and
/// fully unit-testable (Determinism NFR / TC-NF1).
///
/// SEPARATION / PRIVACY INVARIANT (AC-16/AC-17/TC-016/TC-017): this resolver
/// reads ONLY the scalar `routeDistanceKm` plus its own [RouteSelection] and
/// [ProvinceChain] geometry. It imports no `ActivityPlugin`, no platform channel,
/// no OS/idle/lock/sleep API; it makes NO active-vs-idle decision and accrues NO
/// distance — it only *maps* a given distance onto the chain.
library;

import 'province.dart';
import 'province_chain.dart';
import 'route_position.dart';
import 'route_selection.dart';

/// Resolves a route distance into a [RoutePosition] along the chain.
///
/// Stateless and pure: a single static [resolve] encodes the position math for
/// AC-1..AC-8 and AC-11..AC-14. The boundary rule is fixed: a checkpoint reached
/// at **exactly** its cumulative-from-start distance counts as **passed**, and
/// `next` advances to the following checkpoint (AC-3).
abstract final class RouteProgressResolver {
  /// Resolves position from the per-route [routeDistanceKm] (already
  /// `cumulative − offset`; AC-14), the [selection] (start + direction +
  /// completed flag), and the [chain] geometry.
  ///
  /// Math (all keyed off [routeDistanceKm], never raw cumulative — TC-014b):
  /// - **clamp negatives**: a negative `routeDistanceKm` (e.g. a tip/off-direction
  ///   selection that slipped past the picker guard) is treated as 0 so the model
  ///   never reports backward movement;
  /// - **distance-to-destination** is structural (sum of remaining segments in
  ///   the chosen direction; TC-011);
  /// - **completed** when `routeDistanceKm >= distanceToDestination` OR the
  ///   persisted [RouteSelection.completed] flag is set (completion is terminal;
  ///   AC-13). Once completed, completion clamps ALL derived outputs to arrival
  ///   at the destination — `effectiveDistance` becomes the destination
  ///   distance, freezing the marker, the passed list (destination included),
  ///   `next` (null), `distanceToNext` (0), the % and the fraction (1.0). A
  ///   mid-chain route therefore freezes at its honest arrival % (< 100), never
  ///   drifting upward (AC-13: no further forward progress);
  /// - **passed** = origin + every checkpoint whose cumulative-from-start
  ///   distance `<= effectiveDistance` (boundary = passed; AC-3);
  /// - **% of country** = `effectiveDistance / totalChainKm`, clamped to [0,100]%
  ///   — full-chain denominator (locked decision 5 / AC-8 / AC-11 cap).
  static RoutePosition resolve({
    required double routeDistanceKm,
    required RouteSelection selection,
    required ProvinceChain chain,
  }) {
    final start = selection.start;
    final direction = selection.direction;

    // Defensive guard (locked decision 4 / TC-015's negative-leg assertion): if
    // an invalid (tip, off-direction) selection reaches the resolver, the
    // destination equals the start and distance-to-destination is <= 0. We surface
    // it as an immediately-completed, zero-length route rather than a
    // zero-checkpoints-ahead *in-progress* state — the picker is the primary
    // guard; this never lets the model sit "in-progress with nothing ahead".
    final destination = chain.destinationOf(start, direction);
    final distanceToDestination = chain.distanceToDestination(start, direction);

    // Sanitise the scalar before any arithmetic: a non-finite (NaN/±Infinity)
    // `routeDistanceKm` — should never occur from the engine, but the resolver
    // is the model boundary — is treated as 0 so it can never produce an
    // internally inconsistent position (e.g. `isCompleted=false` yet `next=null`
    // and `fraction=1.0`, the "in-progress with nothing ahead" state this doc
    // forbids). NaN fails every comparison, so without this guard it would slip
    // past the negative clamp and the >= threshold check below.
    final sanitizedDistance = routeDistanceKm.isFinite ? routeDistanceKm : 0.0;

    // Clamp out-of-range distance: never negative, never beyond the destination
    // for display purposes (AC-12 — marker clamped to the final pin).
    final clampedToDest = distanceToDestination <= 0
        ? 0.0
        : sanitizedDistance.clamp(0.0, distanceToDestination);
    // `routeDistanceKm` clamped only at the low end for the % readout (so a
    // negative never yields a negative %); the high end is handled by the cap.
    final nonNegativeDistance = sanitizedDistance < 0 ? 0.0 : sanitizedDistance;

    final reachedEnd =
        distanceToDestination <= 0 ||
        nonNegativeDistance >= distanceToDestination;
    // Completion is terminal: once the selection is flagged completed (or the
    // end is reached), it stays completed regardless of further distance (AC-13).
    final isCompleted = selection.completed || reachedEnd;

    // Completion clamps ALL derived outputs to *arrival at the destination*,
    // frozen — not just the displayed marker (AC-13: no further forward
    // progress). Below the destination this is `clampedToDest`, so in-progress
    // outputs are byte-identical to before; the only behavioural change is at
    // and past completion (incl. a persisted-completed selection whose distance
    // sits below its destination — issue 3). The destination distance is the
    // upper bound, so `effectiveDistance` is also the arrival % numerator.
    final effectiveDistance = isCompleted
        ? distanceToDestination
        : clampedToDest;

    // Walk the checkpoints ahead in travel order, classifying passed vs not.
    final ahead = chain.checkpointsAhead(start, direction);
    final passed = <Province>[start];
    Province? next;
    var lastPassed = start;
    for (final node in ahead) {
      final cumulative = chain.distanceFromStartTo(start, node, direction);
      if (cumulative <= effectiveDistance) {
        // Reached at exactly its distance counts as passed (AC-3 boundary rule).
        passed.add(node);
        lastPassed = node;
      } else {
        next = node;
        break;
      }
    }

    // current segment: lastPassed → next, or → destination when completed.
    final segmentTo = next ?? destination;
    final distanceToNext = next == null
        ? 0.0
        : (chain.distanceFromStartTo(start, next, direction) -
              effectiveDistance);

    // % of country — full-chain denominator, clamped [0,100] (decision 5 /
    // AC-11). Frozen at the arrival value once completed (a mid-chain route
    // honestly completes at < 100% and never drifts upward; AC-13), since
    // `effectiveDistance` is the destination distance at/after completion.
    final percent = chain.totalChainKm <= 0
        ? 0.0
        : ((effectiveDistance / chain.totalChainKm) * 100).clamp(0.0, 100.0);

    final fraction = distanceToDestination <= 0
        ? 1.0
        : (effectiveDistance / distanceToDestination).clamp(0.0, 1.0);

    return RoutePosition(
      passed: List<Province>.unmodifiable(passed),
      next: next,
      distanceToNextKm: distanceToNext,
      currentSegmentFrom: lastPassed,
      currentSegmentTo: segmentTo,
      percentOfCountry: percent.toDouble(),
      isCompleted: isCompleted,
      destination: destination,
      routeDistanceKm: effectiveDistance,
      distanceToDestinationKm: distanceToDestination,
      fractionAlongRoute: fraction.toDouble(),
    );
  }
}
