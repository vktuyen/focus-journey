/// Presentation layer. The `CustomPainter` for the route map.
///
/// PRIVACY (AC-18 / TC-NF3): renders entirely from local custom-painted geometry
/// — NO network, NO tile provider, NO external map service. Imports only
/// `dart:math` (pure, no network/platform surface), `flutter` + the pure domain
/// types.
///
/// PERFORMANCE (smooth-paint NFR / TC-NF2): the **static** chain geometry
/// (polyline points + checkpoint pin offsets) is computed once per layout size
/// by [RouteMapGeometry] and passed in — it is NOT re-allocated per frame in
/// [paint]. [RouteMapGeometry] is value-equal on its inputs, so [shouldRepaint]
/// returns `true` only when the resolved [position] or the geometry's inputs
/// actually change — a steady marker triggers no redraw even though the screen
/// builds a fresh (but equal) geometry instance.
library;

import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../domain/province.dart';
import '../domain/province_chain.dart';
import '../domain/route_position.dart';
import '../domain/route_selection.dart';

/// Precomputed, size-dependent screen geometry for the chain. Built once per
/// layout size (hoisted out of the paint hot path) and reused across frames.
///
/// VALUE EQUALITY (smooth-paint NFR / TC-NF2): two geometries built for the same
/// [size] + ordered provinces + per-pin cumulative weights are `==`, so the
/// painter's `shouldRepaint` geometry clause is `false` across a position-only
/// rebuild. The screen still allocates a fresh instance each build, but its
/// `BlocSelector` only rebuilds the subtree when the position changes, and even
/// then the equal geometry short-circuits the repaint.
class RouteMapGeometry extends Equatable {
  /// Builds the polyline + pin offsets for [orderedProvinces] laid out along a
  /// gentle vertical S-curve within [size] (south tip at the bottom, north tip
  /// at the top), spaced by each pin's [cumulativeFractions] (cumulative km from
  /// the start, normalised to [0, 1]) so the layout is distance-proportional.
  /// Pure geometry — no per-frame allocation once built.
  RouteMapGeometry({
    required this.size,
    required this.orderedProvinces,
    required this.cumulativeFractions,
  }) : pinCenters = _layout(size, cumulativeFractions) {
    polyline = Path();
    if (pinCenters.isNotEmpty) {
      polyline.moveTo(pinCenters.first.dx, pinCenters.first.dy);
      for (var i = 1; i < pinCenters.length; i++) {
        polyline.lineTo(pinCenters[i].dx, pinCenters[i].dy);
      }
    }
  }

  /// The layout size this geometry was built for.
  final Size size;

  /// The chain provinces in travel order (index 0 = start) — drives label text.
  final List<Province> orderedProvinces;

  /// Each pin's cumulative km from the start, normalised to [0, 1] (index 0 =
  /// 0.0, last = 1.0). Drives distance-proportional pin spacing.
  final List<double> cumulativeFractions;

  /// Screen centre of each pin, in [orderedProvinces] order.
  final List<Offset> pinCenters;

  /// The chain polyline through every [pinCenters] point.
  late final Path polyline;

  /// Lays the nodes out along a vertical S-curve, positioned by each pin's
  /// cumulative-distance [fractions] (NOT by index) so a chain with unequal
  /// segments places its pins proportionally to real distance. Bottom = first.
  static List<Offset> _layout(Size size, List<double> fractions) {
    if (fractions.isEmpty) {
      return const <Offset>[];
    }
    const marginY = 48.0;
    // Clamp upper bounds defensively: at a tiny/zero canvas `size.height` can be
    // below the lower bound and `width / 2 − 24` can go negative — both would
    // make `clamp(lo, hi)` throw (hi < lo). Guard so a degenerate size never
    // throws (it just collapses the layout).
    final usableHeight = (size.height - 2 * marginY).clamp(
      0.0,
      size.height < 0 ? 0.0 : size.height,
    );
    final midX = size.width / 2;
    final amplitudeMax = (size.width / 2 - 24).clamp(0.0, double.infinity);
    final amplitude = (size.width * 0.18).clamp(0.0, amplitudeMax);
    final centers = <Offset>[];
    for (final t in fractions) {
      // Bottom (y high) = start; top (y low) = destination. `t` is the pin's
      // cumulative-km fraction, so spacing tracks distance, not index.
      final y = size.height - marginY - t * usableHeight;
      final x = midX + amplitude * _wobble(t);
      centers.add(Offset(x, y));
    }
    return List<Offset>.unmodifiable(centers);
  }

  /// A small deterministic horizontal wobble in [-1, 1] along the route.
  static double _wobble(double t) {
    // Two gentle bends; deterministic, no randomness.
    return 0.6 * math.sin(t * 2 * math.pi) + 0.4 * math.sin(t * 4 * math.pi);
  }

  // Geometry is value-equal on the inputs it is built from; `pinCenters` and
  // `polyline` are derived from these, so comparing the inputs is sufficient
  // (and avoids a `Path`, which is not value-comparable).
  @override
  List<Object?> get props => <Object?>[
    size,
    orderedProvinces,
    cumulativeFractions,
  ];
}

/// Paints the route map: chain polyline, checkpoint pins (passed vs ahead),
/// start pin, current-position marker, and destination pin.
class RouteMapPainter extends CustomPainter {
  /// Creates the painter from precomputed [geometry] and the resolved
  /// [position] (+ [selection] for the start node).
  RouteMapPainter({required this.geometry, required this.position})
    : _passedIds = position.passed.map((p) => p.id).toSet();

  /// The precomputed, size-dependent chain geometry (built outside `paint`).
  final RouteMapGeometry geometry;

  /// The resolved position — the only per-frame-varying input.
  final RoutePosition position;

  final Set<String> _passedIds;

  // Paints are fields so they are not re-allocated on every `paint` call.
  static final Paint _routePaint = Paint()
    ..color = const Color(0xFFB0BEC5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  static final Paint _passedPinPaint = Paint()..color = const Color(0xFF26A69A);
  static final Paint _aheadPinPaint = Paint()..color = const Color(0xFFCFD8DC);
  static final Paint _markerPaint = Paint()..color = const Color(0xFFE65100);
  static final Paint _markerRingPaint = Paint()
    ..color = const Color(0xFFFFF3E0)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  static final Paint _destPaint = Paint()..color = const Color(0xFFD32F2F);

  @override
  void paint(Canvas canvas, Size size) {
    final centers = geometry.pinCenters;
    if (centers.isEmpty) {
      return;
    }

    // 1. Static polyline (precomputed Path — not rebuilt here).
    canvas.drawPath(geometry.polyline, _routePaint);

    // 2. Checkpoint pins: passed (filled teal) vs ahead (pale).
    for (var i = 0; i < centers.length; i++) {
      final province = geometry.orderedProvinces[i];
      final isPassed = _passedIds.contains(province.id);
      final isDestination = province.id == position.destination.id;
      final paint = isDestination
          ? _destPaint
          : (isPassed ? _passedPinPaint : _aheadPinPaint);
      canvas.drawCircle(centers[i], isDestination ? 8 : 6, paint);
    }

    // 3. Current-position marker, interpolated along the polyline by
    //    fractionAlongRoute (clamped — never overshoots the destination, AC-12).
    final markerCenter = _markerOffset(
      centers,
      geometry.cumulativeFractions,
      position.fractionAlongRoute,
    );
    canvas.drawCircle(markerCenter, 9, _markerPaint);
    canvas.drawCircle(markerCenter, 12, _markerRingPaint);
  }

  /// Interpolates the marker position along the ordered pin centres by
  /// [fraction] in [0, 1] (0 = start pin, 1 = destination pin), where [fraction]
  /// is the route's *distance* fraction. Pins are laid out by their cumulative
  /// distance ([fractions], same scale), so the marker is located in the segment
  /// whose km-range contains [fraction] — i.e. distance-proportional, matching
  /// the production chain's unequal (80–290 km) legs.
  Offset _markerOffset(
    List<Offset> centers,
    List<double> fractions,
    double fraction,
  ) {
    if (centers.length == 1 || fraction <= 0) {
      return centers.first;
    }
    if (fraction >= 1) {
      return centers.last;
    }
    // Find the segment [i, i+1] whose cumulative km-fraction range straddles
    // `fraction`, then lerp within it by the local distance fraction.
    for (var i = 0; i < fractions.length - 1; i++) {
      final lo = fractions[i];
      final hi = fractions[i + 1];
      if (fraction <= hi) {
        final span = hi - lo;
        final localT = span <= 0 ? 0.0 : (fraction - lo) / span;
        return Offset.lerp(centers[i], centers[i + 1], localT)!;
      }
    }
    return centers.last;
  }

  @override
  bool shouldRepaint(covariant RouteMapPainter oldDelegate) {
    // Repaint only when the resolved position or the geometry changed — a steady
    // marker triggers no redraw (smooth-paint NFR / TC-NF2). `RoutePosition` is
    // Equatable so this is a cheap value comparison.
    return oldDelegate.position != position || oldDelegate.geometry != geometry;
  }
}

/// Helper exposed for the screen: the ordered chain provinces for a [selection]
/// (start → destination, in travel order) used to build [RouteMapGeometry].
List<Province> orderedProvincesFor(
  RouteSelection selection,
  List<Province> aheadInTravelOrder,
) {
  return <Province>[selection.start, ...aheadInTravelOrder];
}

/// Helper exposed for the screen: each [orderedProvinces] pin's cumulative km
/// from the start, normalised to [0, 1] against the route length, so pins are
/// laid out proportionally to real distance (the production chain's segments are
/// unequal, 80–290 km). Index 0 is always 0.0 and the destination 1.0.
List<double> cumulativeFractionsFor(
  ProvinceChain chain,
  RouteSelection selection,
  List<Province> orderedProvinces,
) {
  final routeLength = chain.distanceToDestination(
    selection.start,
    selection.direction,
  );
  if (routeLength <= 0) {
    // Degenerate (zero-length) route: collapse all pins onto the start.
    return List<double>.filled(orderedProvinces.length, 0);
  }
  return List<double>.unmodifiable(<double>[
    for (final province in orderedProvinces)
      (chain.distanceFromStartTo(
                selection.start,
                province,
                selection.direction,
              ) /
              routeLength)
          .clamp(0.0, 1.0),
  ]);
}
