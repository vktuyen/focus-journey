/// Domain layer — pure Dart. No Flutter, no platform channels, no I/O, no
/// `latlong2`. Only [GeoCoordinate] + `dart:math`.
///
/// THE ROUTE-CURVE SMOOTHER (route-real-road / AC-1/AC-5). Turns the projected,
/// travel-order province coordinates (straight chords between checkpoint
/// centres) into a DENSER, smoothly-curved path so the road reads as a natural
/// route rather than jagged straight legs. A **centripetal Catmull-Rom spline**
/// (α = 0.5) is used because, unlike the uniform variant, it never forms loops
/// or overshoots on sharp bends — it stays close to the chords. The province
/// centres already hug the coast, so a curve that passes through them and only
/// gently bows between them stays on the landmass (AC-5 — verified by a
/// dense-sampling unit test against the real bundled `containsLandmass`).
///
/// PURITY / PRIVACY (NFR-2): reads ONLY the static province coordinates passed
/// in. It imports no geolocation/GPS, no platform channel, no I/O, no network —
/// it derives geometry from static reference data alone (offline / zero-egress).
///
/// PERFORMANCE (NFR-1): pure and deterministic; callers memoize the result once
/// per route (the spline is NEVER recomputed per frame).
library;

import 'dart:math' as math;

import 'province_geography.dart';

/// The tuned curviness for the Vietnam coast route (route-real-road / AC-5).
///
/// This is the highest blend that keeps EVERY coastal leg on the drawn landmass:
/// at a higher value the spline bows a sub-km sample into the sea at the tight
/// Đà Nẵng / Huế bends; at this value the only off-landmass samples are the
/// province-chain-2026 ratified `quảng_trị→hà_tĩnh` sea residual (≤3 samples) and
/// a tiny bounded bow across the generalized NORTHERN LAND BORDER at the inland
/// `lạng_sơn→cao_bằng` tip (≤2 samples — not open sea). Pinned + documented by
/// `route_curve_test.dart` (mirrors the province-chain-2026 dense-sampling guard).
const double kRouteRoadCurviness = 0.15;

/// Smooths [points] into a denser curved path via a centripetal Catmull-Rom
/// spline that passes through every input point.
///
/// - Returns [points] unchanged when there are fewer than 3 vertices (a 0/1/2
///   point route has no bend to smooth — a 2-point road is inherently straight).
/// - [samplesPerSegment] interior samples are emitted per input segment (≥ 1);
///   the result therefore has visibly more vertices than the input (AC-1) while
///   still passing exactly through each original checkpoint coordinate.
/// - [alpha] is the knot parametrisation: 0.5 (centripetal, the default) avoids
///   loops/overshoot on sharp bends; 0 (uniform) or 1 (chordal) are available if
///   a route ever needs looser/tighter tangents. Clamped to `[0, 1]`.
/// - [curviness] in `[0, 1]` scales how far each interior sample is allowed to
///   bow off the straight chord: 1 = the full centripetal spline, 0 = the raw
///   chords. The default ([kRouteRoadCurviness]) is tuned so a sharp coastal bend
///   does not overshoot into the sea (AC-5) while the densified path still reads
///   as a smooth curved road (AC-1). Endpoints of each segment are unaffected
///   (`f = 0`/`f = 1` blend to the exact checkpoints), so the curve still passes
///   through every province centre and stays C0-continuous.
///
/// Endpoints use a reflected phantom control point so the first/last segments
/// curve naturally without an extra vertex being invented off the route.
List<GeoCoordinate> smoothCurve(
  List<GeoCoordinate> points, {
  int samplesPerSegment = 16,
  double alpha = 0.5,
  double curviness = kRouteRoadCurviness,
}) {
  if (points.length < 3) {
    return List<GeoCoordinate>.unmodifiable(points);
  }
  final steps = samplesPerSegment < 1 ? 1 : samplesPerSegment;
  final a = alpha < 0 ? 0.0 : (alpha > 1 ? 1.0 : alpha);
  final curve = curviness < 0 ? 0.0 : (curviness > 1 ? 1.0 : curviness);
  final n = points.length;
  final out = <GeoCoordinate>[points.first];

  for (var i = 0; i < n - 1; i++) {
    // The four control points for the segment p1 -> p2. Endpoints reflect the
    // adjacent point so the phantom control sits opposite it (2*p - neighbour),
    // giving a natural end tangent without inventing an off-route vertex.
    final p1 = points[i];
    final p2 = points[i + 1];
    final p0 = i == 0 ? _reflect(p1, p2) : points[i - 1];
    final p3 = i + 2 < n ? points[i + 2] : _reflect(p2, p1);

    final t0 = 0.0;
    final t1 = _knot(t0, p0, p1, a);
    final t2 = _knot(t1, p1, p2, a);
    final t3 = _knot(t2, p2, p3, a);

    // Degenerate (coincident) control points collapse a knot interval; fall back
    // to a straight subdivision for this segment to avoid a divide-by-zero.
    if (t1 <= t0 || t2 <= t1 || t3 <= t2) {
      for (var s = 1; s <= steps; s++) {
        out.add(_lerp(p1, p2, s / steps));
      }
      continue;
    }

    for (var s = 1; s <= steps; s++) {
      final f = s / steps;
      final t = t1 + (t2 - t1) * f;
      // Barry-Goldman pyramidal evaluation of the Catmull-Rom segment.
      final a1 = _lerp(p0, p1, (t - t0) / (t1 - t0));
      final a2 = _lerp(p1, p2, (t - t1) / (t2 - t1));
      final a3 = _lerp(p2, p3, (t - t2) / (t3 - t2));
      final b1 = _lerp(a1, a2, (t - t0) / (t2 - t0));
      final b2 = _lerp(a2, a3, (t - t1) / (t3 - t1));
      final spline = _lerp(b1, b2, (t - t1) / (t2 - t1));
      // Blend toward the straight chord so a sharp coastal bend does not bow off
      // the landmass (AC-5). `f = 0/1` blend to the exact endpoints regardless of
      // [curve], so the curve still hits every checkpoint and stays continuous.
      final chord = _lerp(p1, p2, f);
      out.add(curve >= 1 ? spline : _lerp(chord, spline, curve));
    }
  }

  return List<GeoCoordinate>.unmodifiable(out);
}

/// The reflected phantom control point `2*anchor - other` (mirror of [other]
/// across [anchor]) — used for the first/last segment's outer tangent.
GeoCoordinate _reflect(GeoCoordinate anchor, GeoCoordinate other) {
  return GeoCoordinate(
    latitude: 2 * anchor.latitude - other.latitude,
    longitude: 2 * anchor.longitude - other.longitude,
  );
}

/// The next centripetal knot: `t + dist(a, b)^alpha` in (lon, lat) space.
double _knot(double t, GeoCoordinate a, GeoCoordinate b, double alpha) {
  final dx = b.longitude - a.longitude;
  final dy = b.latitude - a.latitude;
  final d = math.sqrt(dx * dx + dy * dy);
  return t + math.pow(d, alpha).toDouble();
}

/// Unclamped linear interpolation (the Barry-Goldman factors legitimately leave
/// `[0, 1]`, so [GeoCoordinate.lerpTo]'s clamp cannot be used here).
GeoCoordinate _lerp(GeoCoordinate a, GeoCoordinate b, double f) {
  return GeoCoordinate(
    latitude: a.latitude + (b.latitude - a.latitude) * f,
    longitude: a.longitude + (b.longitude - a.longitude) * f,
  );
}
