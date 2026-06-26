/// Domain layer — the PURE segment→geometry seam of map-experience (Decision C).
/// Framework-free Dart: no Flutter, no `latlong2`, no I/O, no network. Reads the
/// `idle-accounting` segment record + `route-progress` offset and maps the
/// CURRENT route's idle spans onto the projected polyline (TC-201..TC-208,
/// TC-214). Deterministic; resolves identically twice (TC-207).
///
/// SEPARATION / PRIVACY INVARIANT (AC-12 / TC-227): reads existing segment data
/// + the route offset as-is. Makes NO active-vs-idle decision, NO re-classification
/// (it keeps each segment's recorded [SegmentClassification]/[SegmentCause]
/// untouched), and accrues NO distance. It imports no `ActivityPlugin`, no
/// platform channel, no OS/idle/lock/sleep API.
library;

import 'package:equatable/equatable.dart';

import '../../journey/domain/activity_segment.dart';
import 'geo_polyline.dart';
import 'route_polyline_projector.dart';

/// A single idle stretch to paint red: the projected [polyline] geometry plus
/// the recorded [cause] (so the painter can apply the AC-9 non-colour cue —
/// solid vs hatched — without re-deciding anything). Pure value object.
class IdleStretch extends Equatable {
  /// Creates an idle stretch from its projected [polyline] and recorded [cause].
  const IdleStretch({required this.polyline, required this.cause});

  /// The projected red geometry (route-distance span → polyline sub-path).
  final GeoPolyline polyline;

  /// The recorded cause (voluntary vs lock/sleep) — drives the non-colour cue
  /// only; never re-decided here (AC-12).
  final SegmentCause cause;

  @override
  List<Object?> get props => <Object?>[polyline, cause];
}

/// Maps the `idle-accounting` segment record (keyed by ABSOLUTE cumulative km)
/// onto the CURRENT route's red stretches (Decision C).
///
/// The seam in one place: segments are absolute-cumulative-km; the map shows the
/// current route only. For each idle segment we
///   1. re-base to route distance by subtracting [routeStartOffsetKm],
///   2. clip to the current route window `[0, routeLengthKm]` (drop fully-outside
///      segments — prior routes/days; trim partially-outside ones — TC-214),
///   3. project the trimmed span through [projector.stretchBetween] (which
///      follows the road across boundaries — TC-202/TC-203).
/// Active segments are skipped entirely (never red — AC-6). A zero-idle route
/// yields an empty list (AC-7 / TC-213). The result count matches the number of
/// in-window idle segments with drawable (non-zero-width) geometry (TC-204).
///
/// ## Idle segment geometry — the `{fromKm, toKm}` contract (AC-6 / TC-201)
/// This mapper is a PURE function of each segment's recorded `{fromKm, toKm,
/// classification, cause}` — exactly the contract AC-6 names ("the segment's
/// `[start, end)`") and the TC-201..TC-208 fixtures key off. It paints the road
/// stretch from `fromKm` to `toKm`, NEVER re-deriving the span from anything else
/// (no re-classification, no accrual — AC-12).
///
/// NOTE on the engine's idle width: in the shipped `idle-accounting` engine an
/// *idle* span accrues no distance, so a recorded idle `ActivitySegment` has
/// `fromKm == toKm` (a zero-width point at the road position where the drift
/// happened) — such a segment maps to an empty stretch (nothing drawn), which is
/// the honest result (a momentary stop the traveller resumed from leaves no road
/// behind). The TC fixtures supply idle segments with `fromKm < toKm` to exercise
/// the *span* mapping geometry across legs/boundaries; the mapper handles both
/// identically (it just projects `[fromKm, toKm)`), so the algorithm is verified
/// independently of how wide a given idle segment happens to be.
abstract final class IdleTraceMapper {
  /// Resolves the current-route red stretches.
  ///
  /// [segments] is the engine's distance-keyed record (absolute cumulative km).
  /// [routeStartOffsetKm] re-bases absolute km to route km (locked decision 1 /
  /// AC-14). [projector] supplies the route geometry + clamping. Stretches with
  /// no drawable geometry (zero-length after clipping) are omitted.
  static List<IdleStretch> resolve({
    required List<ActivitySegment> segments,
    required double routeStartOffsetKm,
    required RoutePolylineProjector projector,
  }) {
    final stretches = <IdleStretch>[];
    final routeLength = projector.routeLengthKm;
    for (final segment in segments) {
      if (segment.classification != SegmentClassification.idle) {
        continue; // active spans are never red (AC-6).
      }
      // Re-base absolute cumulative km → route km (TC-212: key off route km,
      // never raw cumulative).
      final fromRoute = segment.fromKm - routeStartOffsetKm;
      final toRoute = segment.toKm - routeStartOffsetKm;
      // Clip to the current-route window. Fully-outside segments (a prior route
      // or a previous day's record) are dropped; partially-outside ones are
      // trimmed by the projector's own clamping (TC-214).
      final clippedFrom = fromRoute < 0 ? 0.0 : fromRoute;
      final clippedTo = toRoute > routeLength ? routeLength : toRoute;
      if (clippedTo <= clippedFrom) {
        continue; // entirely before the route, or zero-length after clipping.
      }
      final polyline = projector.stretchBetween(clippedFrom, clippedTo);
      if (polyline.isEmpty) {
        continue;
      }
      stretches.add(IdleStretch(polyline: polyline, cause: segment.cause));
    }
    return List<IdleStretch>.unmodifiable(stretches);
  }
}
