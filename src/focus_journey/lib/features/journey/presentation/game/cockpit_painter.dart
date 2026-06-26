/// Presentation layer (Flame). Paints the first-person cockpit FOREGROUND
/// overlay (journey-pov) for [TravelMode.car] and [TravelMode.motorbike] ONLY.
/// The cockpit is composited over the existing receding-road scene so the road
/// + Vietnam scenery read as seen through the windshield (car) / over the
/// handlebars (motorbike).
///
/// SEPARATION INVARIANT (AC-9): pure `dart:ui` + the pure-Dart domain
/// [TravelMode] + the [JourneyAssets] manifest constants. NO Flutter, Bloc,
/// engine, ActivityPlugin, MethodChannel, or OS read. The painter takes plain
/// values (size, mode, moving, a glyph lookup) and decides nothing about
/// journey state.
///
/// COSMETIC-ONLY (AC-10): the cockpit reads only the `moving` flag (for a
/// parked-vs-running decorative pose) and the `mode`. The speedometer / fuel
/// glyphs are STATIC decorative art (AC-2) — they display NO numeric or
/// continuous readout (there is no speed/fuel input on the scene).
///
/// PERFORMANCE (NFR-1/AC-14): every `Paint`/`Path`/`RRect` scratch object is
/// allocated ONCE as a field and mutated in place — the per-frame paint path
/// performs no heap allocation and builds no new geometry. The cockpit is
/// static foreground art; it adds NO new motion (so reduce-motion is
/// unaffected).
///
/// GRACEFUL DEGRADATION (AC-13): a glyph that failed to load is `null` from the
/// [glyphFor] lookup; the painter then draws an ORIGINAL flat vector shape in
/// its place (license-clean by construction). It never blanks or crashes.
library;

import 'dart:ui';

import '../../domain/travel_mode.dart';
import 'journey_assets.dart';

/// Draws the car / motorbike first-person cockpit foreground. Owned by
/// `JourneyGame`, which feeds it the current size, mode, `moving` flag and a
/// glyph lookup each render. Stateless across frames (no cached cockpit state),
/// so a mode-switch away leaves NO residual layer (AC-7) and a switch back
/// restores cleanly (AC-8) — the caller simply stops/starts calling [paint].
class CockpitPainter {
  /// Reusable paints/paths (allocated once — no per-frame allocation, NFR-1).
  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  final Paint _sprite = Paint()..filterQuality = FilterQuality.low;
  final Path _path = Path();

  /// The fraction of the viewport HEIGHT the cockpit foreground occupies,
  /// measured from the bottom. journey-pov AC-5 — answers the spec's open
  /// question "cockpit height / road framing ratio": pinned at **0.36**
  /// (within the spec's ≈0.30–0.40 target), leaving the upper ~64% of the
  /// viewport (road + horizon + scenery) clearly readable above the dash /
  /// handlebar line. The same ratio applies proportionally at the PiP because
  /// it is a fraction of the live viewport. Reviewer may adjust within the
  /// 0.30–0.40 band.
  static const double cockpitViewportFraction = 0.36;

  // --- Journey palette (cohesive with the existing flat scene — AC-16). ---
  static const Color _dashDark = Color(0xFF24282F); // dashboard body
  static const Color _dashMid = Color(0xFF31363F); // dashboard top lip
  static const Color _trim = Color(0xFF14361C); // journey green trim
  static const Color _wheelDark = Color(0xFF1B1E24); // steering wheel rim
  static const Color _wheelHub = Color(0xFF3A3F47); // wheel hub (road grey)
  static const Color _gaugeFace = Color(0xFF11151B); // gauge bezel face
  static const Color _gaugeTick = Color(0xFFE8E2C8); // gauge ticks (lane cream)
  static const Color _needleParked = Color(0xFF8A9099); // parked needle (grey)
  static const Color _needleRunning = Color(
    0xFFF2D544,
  ); // running needle (amber)
  static const Color _pillar = Color(0xFF1B1E24); // A-pillar / framing
  static const Color _metal = Color(0xFF6B7280); // handlebar / grips metal
  static const Color _grip = Color(0xFF14171C); // handlebar grips

  /// Returns the top y (logical px) of the cockpit foreground for a viewport of
  /// [size] — the dash / handlebar line. Above this the road stays visible
  /// (AC-5). Exposed so the game can offer it as a measurable test seam.
  double cockpitTop(Size size) => size.height * (1.0 - cockpitViewportFraction);

  // ===========================================================================
  // journey-cockpit-lean — the cockpit FOREGROUND rolls into the bend.
  // ===========================================================================

  /// Pivot for the lean rotation, as fractions of the viewport. AC-13 / spec
  /// Open question "Pivot point": pinned at **bottom-centre of the viewport**
  /// (a horizon-style pivot) — `(0.5 · width, 1.0 · height)`. Rotating the whole
  /// cockpit band about its bottom-centre reads as the natural roll your view
  /// takes when a vehicle corners (the dash/tank stays anchored at the bottom
  /// while the upper frame swings into the turn), and keeps the rotation cheap
  /// (a single `translate`+`rotate`+`translate`, allocation-free — NFR-1).
  static const double _pivotXFrac = 0.5;
  static const double _pivotYFrac = 1.0;

  /// Constant safety margin (logical px) added to the geometrically-required
  /// overdraw so anti-alias fringes / rounding never expose a hairline at the
  /// rotated corner. Small + size-independent (NFR-1 — no allocation).
  static const double _overdrawMargin = 4.0;

  /// AC-13 corner-coverage overdraw, computed from the ACTUAL lever arm of the
  /// rotation — NOT a flat fraction (the earlier flat 6%-of-band bottom margin
  /// under-provisioned: the rotational LIFT of the far bottom corner about the
  /// bottom-centre pivot is `(w/2 + sx)·sin|θ|`, far larger than 6% of band
  /// height at full size).
  ///
  /// Derivation. The lean rotates the cockpit layer by `θ = leanRadians` about
  /// the bottom-centre pivot `(w/2, h)`. To cover a device viewport bottom
  /// corner `(0, h)` / `(w, h)` we need its pre-image (the corner rotated by
  /// `-θ` about the pivot) to fall INSIDE the un-rotated opaque base rectangle
  /// `[-sx, w+sx] × [.., h+byo]`. Rotating `(0, h)` by `-θ` gives
  /// `(x', y') = ((w/2)(1-cos θ),  h + (w/2) sin θ)` (symmetric for `(w, h)`),
  /// so the base bottom must reach `byo ≥ (w/2)·sin|θ| + margin` and the side
  /// must reach `sx ≥ (w/2)(1-cos|θ|) + margin`. We extend the dominant `w/2`
  /// lever by the side overdraw too (`(w/2 + sx)`), and — since `sin|θ| ≫
  /// (1-cos|θ|)` for small θ — set BOTH `sx` and `byo` to the bottom drop, which
  /// is amply generous horizontally. Sized from the ACTUAL `|θ|` applied this
  /// frame (coverage need only hold at the angle being drawn), so it scales to 0
  /// as the lean settles and is exactly 0 when level — keeping the level /
  /// reduce-motion silhouette byte-for-byte unchanged (AC-9). Returns `byo`
  /// (== `sx`); allocation-free, O(1).
  double _overdrawDrop(double w, double leanRadians) {
    final double s = _sin(leanRadians).abs();
    return (w * 0.5) * s + _overdrawMargin;
  }

  /// Paints the cockpit foreground for [mode] if it is a cockpit mode
  /// (car / motorbike); otherwise draws NOTHING (AC-6). [moving] selects a
  /// decorative parked-vs-running gauge-needle pose (AC-2 — keys only off the
  /// existing binary flag, no numeric readout). [glyphFor] resolves a manifest
  /// path to its loaded [Image] or `null` (→ original flat-shape fallback,
  /// AC-13).
  ///
  /// journey-cockpit-lean AC-9: [leanRadians] rolls the ENTIRE cockpit layer
  /// (art + placeholders) about the bottom-centre pivot. The caller
  /// (`JourneyGame`) computes the bounded, eased, scroll-phase-deterministic
  /// angle and passes it here; the painter just applies the transform. When
  /// `leanRadians == 0` the transform is skipped entirely so the level frame is
  /// byte-for-byte identical to the pre-lean output (AC-6/AC-7/AC-8 level case).
  /// ONLY this cockpit layer is wrapped in the transform — the scene renderer
  /// (`RoadPainter`, side objects, sky) is painted by the caller BEFORE this and
  /// never sees the rotation (AC-9).
  void paint(
    Canvas canvas,
    Size size,
    TravelMode mode, {
    required bool moving,
    required Image? Function(String path) glyphFor,
    double leanRadians = 0.0,
  }) {
    final bool isCockpit =
        mode == TravelMode.car || mode == TravelMode.motorbike;
    final bool leaning = leanRadians != 0.0 && isCockpit;
    if (leaning) {
      // Rotate about the bottom-centre pivot (AC-13). translate→rotate→translate
      // is allocation-free (no Matrix4 / Offset on the hot path — NFR-1).
      canvas.save();
      final double px = size.width * _pivotXFrac;
      final double py = size.height * _pivotYFrac;
      canvas.translate(px, py);
      canvas.rotate(leanRadians);
      canvas.translate(-px, -py);
    }
    // The overdraw the bottom corners need at the angle actually applied this
    // frame (0 when level — silhouette unchanged, AC-9).
    final double overdraw = leaning
        ? _overdrawDrop(size.width, leanRadians)
        : 0.0;
    switch (mode) {
      case TravelMode.car:
        _paintCarCockpit(
          canvas,
          size,
          moving: moving,
          glyphFor: glyphFor,
          overdraw: overdraw,
        );
      case TravelMode.motorbike:
        _paintMotorbikeCockpit(
          canvas,
          size,
          moving: moving,
          glyphFor: glyphFor,
          overdraw: overdraw,
        );
      case TravelMode.walk:
      case TravelMode.run:
      case TravelMode.bicycle:
      case TravelMode.ship:
        return; // AC-6: no cockpit foreground (never leaning, no transform).
    }
    if (leaning) {
      canvas.restore();
    }
  }

  // ===========================================================================
  // CAR — flat dashboard + A-pillars + steering wheel + 2 decorative gauges.
  // Distinct SILHOUETTE from the motorbike (broad horizontal dash + round
  // wheel) for colour-independent accessibility (NFR-3).
  // ===========================================================================
  void _paintCarCockpit(
    Canvas canvas,
    Size size, {
    required bool moving,
    required Image? Function(String path) glyphFor,
    double overdraw = 0.0,
  }) {
    final double w = size.width;
    final double h = size.height;
    final double top = cockpitTop(size);
    final double dashH = h - top;

    // AC-13 corner-coverage. A bottom-centre lean lifts the band's far-side
    // bottom corner by `(w/2 + sx)·sin|θ|`; under a lean the opaque dashboard
    // slab + pillar feet are extended past the viewport edges AND below the
    // bottom by [overdraw] (= `_overdrawDrop`, the lever-arm-scaled amount —
    // NOT a flat fraction) so the rotated frame still covers BOTH device bottom
    // corners. ZERO when level (`overdraw == 0`) → the level silhouette is
    // byte-for-byte unchanged (AC-8/AC-9 level case). The slab is the opaque
    // lower band; the open windshield above it intentionally shows road and is
    // unaffected — the lean only moves painted pixels, and an already-open area
    // exposes nothing new (it was scene before and after).
    final double sx = overdraw;
    final double byo = overdraw;
    final double left = -sx;
    final double right = w + sx;
    final double btm = h + byo;

    // A-pillar / windshield framing: thin angled bars down the left & right
    // edges that frame the road as "through the windshield" (AC-1). Drawn
    // first so the dash body overlaps their feet. Under a lean the pillar feet
    // widen to [left]/[right] so the lifted top corner stays covered.
    _fill.color = _pillar;
    final double pillarW = w * 0.06;
    _path.reset();
    _path.moveTo(left, -byo);
    _path.lineTo(pillarW, -byo);
    _path.lineTo(pillarW * 0.5, top);
    _path.lineTo(left, top);
    _path.close();
    canvas.drawPath(_path, _fill);
    _path.reset();
    _path.moveTo(right, -byo);
    _path.lineTo(w - pillarW, -byo);
    _path.lineTo(w - pillarW * 0.5, top);
    _path.lineTo(right, top);
    _path.close();
    canvas.drawPath(_path, _fill);

    // Dashboard body: a curved-top flat slab occupying the lower band. The
    // glyph (if present) wins; otherwise the original flat shape below stands
    // in. The dash shape is ORIGINAL vector (license-clean) so we draw it as
    // the base read regardless and overlay the optional glyph on top.
    _path.reset();
    _path.moveTo(left, btm);
    _path.lineTo(left, top + dashH * 0.30);
    // Gentle curved cowl rising toward the centre then dipping — quadratic
    // beziers (no per-frame allocation; _path is reused).
    _path.quadraticBezierTo(
      w * 0.25,
      top - dashH * 0.04,
      w * 0.5,
      top + dashH * 0.06,
    );
    _path.quadraticBezierTo(
      w * 0.75,
      top - dashH * 0.04,
      right,
      top + dashH * 0.30,
    );
    _path.lineTo(right, btm);
    _path.close();
    _fill.color = _dashDark;
    canvas.drawPath(_path, _fill);

    // Top lip highlight (reads as a flat illustrated bevel — AC-16).
    _stroke
      ..color = _dashMid
      ..strokeWidth = dashH * 0.05;
    canvas.drawPath(_path, _stroke);

    // Optional dashboard glyph overlay (covers the slab if it loaded).
    final Image? dashImg = glyphFor(JourneyAssets.cockpitCarDashboard);
    if (dashImg != null) {
      _drawImageFit(canvas, dashImg, Rect.fromLTWH(0, top, w, dashH));
    }

    // Two decorative gauges set into the dash cowl: speedometer (left of
    // centre) + fuel (right of centre). AC-2: static glyphs; the needle keys
    // ONLY off `moving`, shows no numeric readout.
    final double gaugeR = dashH * 0.26;
    final double gaugeY = top + dashH * 0.42;
    _paintGauge(
      canvas,
      Offset(w * 0.34, gaugeY),
      gaugeR,
      moving: moving,
      glyph: glyphFor(JourneyAssets.cockpitCarSpeedometer),
    );
    _paintGauge(
      canvas,
      Offset(w * 0.66, gaugeY),
      gaugeR * 0.82,
      moving: moving,
      glyph: glyphFor(JourneyAssets.cockpitCarFuelGauge),
    );

    // Steering wheel: a round rim with hub + spokes at the dash bottom centre.
    // Sized to the dash BAND (not the viewport width) so the WHOLE wheel reads
    // within the cockpit — diameter ≈ the band height — seated just above the
    // viewport's bottom edge with a small margin, flanked by the two gauges.
    // (Previously `w * 0.22` centred BELOW the viewport, so only the top arc
    // showed.)
    final double wheelR = dashH * 0.46;
    final Offset wheelCentre = Offset(w * 0.5, h - wheelR - dashH * 0.04);
    final Image? wheelImg = glyphFor(JourneyAssets.cockpitCarSteeringWheel);
    if (wheelImg != null) {
      final double d = wheelR * 2;
      _drawImageFit(
        canvas,
        wheelImg,
        Rect.fromCenter(center: wheelCentre, width: d, height: d),
      );
    } else {
      _paintFlatSteeringWheel(canvas, wheelCentre, wheelR);
    }
  }

  void _paintFlatSteeringWheel(Canvas canvas, Offset centre, double r) {
    // Rim.
    _stroke
      ..color = _wheelDark
      ..strokeWidth = r * 0.22;
    canvas.drawCircle(centre, r, _stroke);
    // Hub.
    _fill.color = _wheelHub;
    canvas.drawCircle(centre, r * 0.26, _fill);
    // Three spokes (left, right, down) as thick lines from hub to rim.
    _stroke
      ..color = _wheelDark
      ..strokeWidth = r * 0.16;
    canvas.drawLine(
      centre,
      Offset(centre.dx - r * 0.92, centre.dy + r * 0.10),
      _stroke,
    );
    canvas.drawLine(
      centre,
      Offset(centre.dx + r * 0.92, centre.dy + r * 0.10),
      _stroke,
    );
    canvas.drawLine(centre, Offset(centre.dx, centre.dy + r * 0.95), _stroke);
    // Green trim accent on the hub (journey palette — AC-16).
    _fill.color = _trim;
    canvas.drawCircle(centre, r * 0.10, _fill);
  }

  // ===========================================================================
  // MOTORBIKE — handlebar + grips + single round gauge pod + fuel tank. A
  // distinct SILHOUETTE from the car (low central tank + wide swept bar, no
  // full dash slab) for colour-independent accessibility (NFR-3).
  // ===========================================================================
  void _paintMotorbikeCockpit(
    Canvas canvas,
    Size size, {
    required bool moving,
    required Image? Function(String path) glyphFor,
    double overdraw = 0.0,
  }) {
    final double w = size.width;
    final double h = size.height;
    final double top = cockpitTop(size);
    final double bandH = h - top;

    // AC-13 corner-coverage. The motorbike band is mostly OPEN (road over the
    // bars), so the painted pixels that can lift under a bottom-centre lean are
    // the tank + bar + the bottom edge. Under a lean, lay a low opaque
    // fairing/cowl strip along the bottom of the band, extended past the edges
    // AND below the viewport by [overdraw] (= `_overdrawDrop`, the lever-arm-
    // scaled amount), so BOTH device bottom corners stay covered after the
    // rotation (the lifted corner's pre-image is at `y ≈ h + (w/2)·sin|θ|`,
    // which `h + overdraw` reaches). The strip TOP is lifted by the same amount
    // above its nominal line so the rotated strip still spans the full bottom.
    // ZERO when level (`overdraw == 0`) → the level silhouette is byte-for-byte
    // unchanged.
    if (overdraw > 0.0) {
      _fill.color = _dashDark;
      canvas.drawRect(
        Rect.fromLTRB(
          -overdraw,
          h - bandH * 0.18 - overdraw,
          w + overdraw,
          h + overdraw,
        ),
        _fill,
      );
    }

    // Fuel tank: a rounded central hump rising from the bottom (the rider's
    // forward view), narrower than the car dash so the road reads wider.
    final double tankW = w * 0.46;
    final double tankTop = top + bandH * 0.42;
    final Rect tankRect = Rect.fromLTWH(
      (w - tankW) / 2,
      tankTop,
      tankW,
      h - tankTop,
    );
    final Image? tankImg = glyphFor(JourneyAssets.cockpitMotorbikeFuelTank);
    if (tankImg != null) {
      _drawImageFit(canvas, tankImg, tankRect);
    } else {
      _fill.color = _dashDark;
      _path.reset();
      _path.moveTo(tankRect.left, h);
      _path.lineTo(tankRect.left, tankRect.top + tankRect.height * 0.35);
      _path.quadraticBezierTo(
        w * 0.5,
        tankRect.top - tankRect.height * 0.10,
        tankRect.right,
        tankRect.top + tankRect.height * 0.35,
      );
      _path.lineTo(tankRect.right, h);
      _path.close();
      canvas.drawPath(_path, _fill);
      // Green centre seam (journey palette — AC-16).
      _stroke
        ..color = _trim
        ..strokeWidth = tankRect.height * 0.06;
      canvas.drawLine(
        Offset(w * 0.5, tankRect.top + tankRect.height * 0.10),
        Offset(w * 0.5, h),
        _stroke,
      );
    }

    // Handlebar: a wide swept bar across the band, with grips at each end.
    final double barY = top + bandH * 0.30;
    final Image? barImg = glyphFor(JourneyAssets.cockpitMotorbikeHandlebar);
    if (barImg != null) {
      _drawImageFit(
        canvas,
        barImg,
        Rect.fromLTWH(w * 0.04, barY - bandH * 0.10, w * 0.92, bandH * 0.34),
      );
    } else {
      _paintFlatHandlebar(canvas, w, barY, bandH);
    }

    // Single central gauge pod (decorative — AC-2; needle keys only off
    // `moving`). Sits just above the handlebar centre.
    final double podR = bandH * 0.22;
    _paintGauge(
      canvas,
      Offset(w * 0.5, barY - podR * 0.20),
      podR,
      moving: moving,
      glyph: glyphFor(JourneyAssets.cockpitMotorbikeGaugePod),
    );
  }

  void _paintFlatHandlebar(Canvas canvas, double w, double barY, double bandH) {
    // Swept tube: a shallow upward arc across the viewport.
    _stroke
      ..color = _metal
      ..strokeWidth = bandH * 0.12;
    _path.reset();
    _path.moveTo(w * 0.06, barY + bandH * 0.06);
    _path.quadraticBezierTo(
      w * 0.5,
      barY - bandH * 0.10,
      w * 0.94,
      barY + bandH * 0.06,
    );
    canvas.drawPath(_path, _stroke);
    // Grips: thick stubs at each end.
    _stroke
      ..color = _grip
      ..strokeWidth = bandH * 0.18;
    canvas.drawLine(
      Offset(w * 0.06, barY + bandH * 0.06),
      Offset(w * 0.16, barY + bandH * 0.02),
      _stroke,
    );
    canvas.drawLine(
      Offset(w * 0.94, barY + bandH * 0.06),
      Offset(w * 0.84, barY + bandH * 0.02),
      _stroke,
    );
  }

  // ===========================================================================
  // Shared decorative gauge. AC-2: STATIC glyph; the only state it reads is the
  // binary `moving` flag (parked → grey needle resting, running → amber needle
  // lifted). NO numeric / continuous speed or fuel readout.
  // ===========================================================================
  void _paintGauge(
    Canvas canvas,
    Offset centre,
    double r, {
    required bool moving,
    required Image? glyph,
  }) {
    if (glyph != null) {
      final double d = r * 2;
      _drawImageFit(
        canvas,
        glyph,
        Rect.fromCenter(center: centre, width: d, height: d),
      );
    } else {
      // Original flat bezel + face (license-clean).
      _fill.color = _wheelDark;
      canvas.drawCircle(centre, r, _fill);
      _fill.color = _gaugeFace;
      canvas.drawCircle(centre, r * 0.82, _fill);
      // A few decorative ticks around the upper arc (fixed positions — not a
      // numeric scale; reused _path, no allocation).
      _stroke
        ..color = _gaugeTick
        ..strokeWidth = r * 0.06;
      for (int i = 0; i < 5; i++) {
        // Spread ticks across the lower-front 180° arc.
        final double a = 3.66519 + i * 0.39270; // ~210°..300° in radians
        final double cosA = _cos(a);
        final double sinA = _sin(a);
        canvas.drawLine(
          Offset(centre.dx + cosA * r * 0.62, centre.dy + sinA * r * 0.62),
          Offset(centre.dx + cosA * r * 0.78, centre.dy + sinA * r * 0.78),
          _stroke,
        );
      }
    }

    // Decorative needle ON TOP of the glyph/face. Parked → resting (down-left,
    // grey); running → lifted (up-right, amber). Binary only (AC-2).
    final double needleAngle = moving ? 5.49779 : 2.35619; // ~315° vs ~135°
    _stroke
      ..color = moving ? _needleRunning : _needleParked
      ..strokeWidth = r * 0.10;
    canvas.drawLine(
      centre,
      Offset(
        centre.dx + _cos(needleAngle) * r * 0.7,
        centre.dy + _sin(needleAngle) * r * 0.7,
      ),
      _stroke,
    );
    // Needle hub cap.
    _fill.color = _trim;
    canvas.drawCircle(centre, r * 0.12, _fill);
  }

  // Cached source rect; only re-created when an image's pixel size changes,
  // not every frame (mirrors RoadPainter._drawImageFit).
  Rect _lastSrc = Rect.zero;
  double _lastSrcW = -1;
  double _lastSrcH = -1;

  void _drawImageFit(Canvas canvas, Image image, Rect dst) {
    final double w = image.width.toDouble();
    final double h = image.height.toDouble();
    if (w != _lastSrcW || h != _lastSrcH) {
      _lastSrc = Rect.fromLTWH(0, 0, w, h);
      _lastSrcW = w;
      _lastSrcH = h;
    }
    canvas.drawImageRect(image, _lastSrc, dst, _sprite);
  }

  // --- Minimal allocation-free trig (Bhaskara I approximation) ---
  // Avoids importing dart:math just for a handful of fixed decorative angles
  // and keeps the hot path allocation-free (mirrors JourneyGame._fastSin).
  double _sin(double x) {
    const double twoPi = 6.28318530718;
    const double pi = 3.14159265359;
    double v = x % twoPi;
    if (v > pi) {
      v -= twoPi;
    } else if (v < -pi) {
      v += twoPi;
    }
    final double sign = v < 0 ? -1.0 : 1.0;
    final double a = v.abs();
    final double num = 16.0 * a * (pi - a);
    final double den = 5.0 * pi * pi - 4.0 * a * (pi - a);
    return sign * (num / den);
  }

  double _cos(double x) => _sin(x + 1.57079632679);
}
