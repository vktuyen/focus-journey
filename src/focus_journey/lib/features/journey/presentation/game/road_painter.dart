/// Presentation layer (Flame). Stateless-ish painter that draws the fake-3D
/// trapezoid road, scrolling lane markings, parallax side objects, and the
/// vehicle onto a canvas. Procedural geometry (NOT a sourced art asset for the
/// road itself); side objects and the vehicle use curated sprites.
///
/// Performance (AC perf / TC-017): all `Paint`/`Path`/`Rect` scratch objects
/// are allocated ONCE as fields and mutated in place — the per-frame paint
/// path performs no heap allocations. Pure `dart:ui`; no Flutter, Bloc, engine,
/// or OS.
library;

import 'dart:ui';

import 'side_object_pool.dart';

/// Geometry + drawing for one journey frame. Owned by `JourneyGame`, which
/// feeds it the current size, scroll phase, tint and sprites each render.
class RoadPainter {
  /// Reusable paints/paths (no per-frame allocation).
  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  final Paint _sprite = Paint()..filterQuality = FilterQuality.low;
  final Path _path = Path();

  // Tunables for the trapezoid (fractions of the viewport).
  static const double _horizonFrac = 0.42; // horizon y as fraction of height
  static const double _roadNearHalfFrac = 0.46; // near road half-width / width
  static const double _roadFarHalfFrac = 0.018; // far road half-width / width

  /// Horizon y for a viewport of [size]. Exposed so the vehicle/objects align.
  double horizonY(Size size) => size.height * _horizonFrac;

  /// Paints the sky/ground base. [skyColor] is the day/night-derived sky.
  void paintBackground(Canvas canvas, Size size, Color skyColor) {
    final double horizon = horizonY(size);
    _fill.color = skyColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, horizon), _fill);
    // Ground: a muted green that darkens with the sky's luminance.
    _fill.color = _groundFor(skyColor);
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, size.width, size.height - horizon),
      _fill,
    );
  }

  /// Paints the trapezoid road and the scrolling dashed centre lane.
  /// [scrollOffset] is the shared eased offset (constant while stopped → lanes
  /// are frozen). Freezing is driven entirely by a frozen [scrollOffset]; the
  /// painter holds no motion state of its own.
  void paintRoad(Canvas canvas, Size size, double scrollOffset) {
    final double horizon = horizonY(size);
    final double cx = size.width / 2;
    final double nearHalf = size.width * _roadNearHalfFrac;
    final double farHalf = size.width * _roadFarHalfFrac;
    final double bottom = size.height;

    // Road body trapezoid.
    _path.reset();
    _path.moveTo(cx - farHalf, horizon);
    _path.lineTo(cx + farHalf, horizon);
    _path.lineTo(cx + nearHalf, bottom);
    _path.lineTo(cx - nearHalf, bottom);
    _path.close();
    _fill.color = const Color(0xFF3A3F47);
    canvas.drawPath(_path, _fill);

    // Edge lines.
    _stroke
      ..color = const Color(0xFFE8E2C8)
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(cx - farHalf, horizon),
      Offset(cx - nearHalf, bottom),
      _stroke,
    );
    canvas.drawLine(
      Offset(cx + farHalf, horizon),
      Offset(cx + nearHalf, bottom),
      _stroke,
    );

    _paintLaneDashes(canvas, size, scrollOffset, horizon, cx, bottom);
  }

  /// Dashed centre line. Dashes are placed by perspective `t` (0 horizon → 1
  /// near) so they appear to rush toward the camera as [scrollOffset] grows.
  void _paintLaneDashes(
    Canvas canvas,
    Size size,
    double scrollOffset,
    double horizon,
    double cx,
    double bottom,
  ) {
    _fill.color = const Color(0xFFF2D544);
    const int dashCount = 9;
    // Phase in [0,1) advances with scroll so dashes flow downward (toward cam).
    final double phase = (scrollOffset / 140.0) % 1.0;
    for (int i = 0; i < dashCount; i++) {
      // Distribute dashes non-linearly so spacing compresses near the horizon.
      final double raw = (i + phase) / dashCount;
      final double t = raw * raw; // perspective compression
      final double tNext = (raw + 0.04 < 1.0)
          ? (raw + 0.04) * (raw + 0.04)
          : 1.0;
      final double yTop = horizon + (bottom - horizon) * t;
      final double yBot = horizon + (bottom - horizon) * tNext;
      final double wTop = _laneHalfWidth(size, t);
      final double wBot = _laneHalfWidth(size, tNext);
      _path.reset();
      _path.moveTo(cx - wTop, yTop);
      _path.lineTo(cx + wTop, yTop);
      _path.lineTo(cx + wBot, yBot);
      _path.lineTo(cx - wBot, yBot);
      _path.close();
      canvas.drawPath(_path, _fill);
    }
  }

  double _laneHalfWidth(Size size, double t) {
    // Dash half-width scales from thin at horizon to wider near camera.
    return (1.0 + t * 6.0);
  }

  /// Draws all live side objects, far (small) first so nearer ones overlap.
  /// [imageForKind] returns the sprite or `null` (→ placeholder rectangle).
  void paintSideObjects(
    Canvas canvas,
    Size size,
    List<SideObject> slots,
    Image? Function(SideObjectKind) imageForKind,
  ) {
    final double horizon = horizonY(size);
    final double cx = size.width / 2;
    final double bottom = size.height;
    final double nearHalf = size.width * _roadNearHalfFrac;
    final double farHalf = size.width * _roadFarHalfFrac;

    // Painter's algorithm: iterate but draw by depth. Slots are unordered, so
    // we draw in two cheap passes (far band then near band) to avoid sorting /
    // allocating. Good enough visually; no per-frame list allocation.
    for (int pass = 0; pass < 2; pass++) {
      for (final SideObject o in slots) {
        if (!o.active) {
          continue;
        }
        final bool near = o.z >= 0.5;
        if ((pass == 0) == near) {
          continue; // pass 0 draws far, pass 1 draws near
        }
        _paintOneSideObject(
          canvas,
          o,
          imageForKind(o.kind),
          horizon: horizon,
          cx: cx,
          bottom: bottom,
          nearHalf: nearHalf,
          farHalf: farHalf,
        );
      }
    }
  }

  void _paintOneSideObject(
    Canvas canvas,
    SideObject o,
    Image? image, {
    required double horizon,
    required double cx,
    required double bottom,
    required double nearHalf,
    required double farHalf,
  }) {
    final double t = o.z; // 0 horizon → 1 near
    final double y = horizon + (bottom - horizon) * t;
    final double roadHalf = farHalf + (nearHalf - farHalf) * t;
    // Place just outside the road edge, pushed further out by `lateral`.
    final double edgeX = cx + o.side * (roadHalf + roadHalf * 0.15);
    final double x = edgeX + o.side * (o.lateral * roadHalf * 1.2);
    // Scale grows with depth.
    final double scale = 0.18 + t * 1.1;
    final double w = 64.0 * scale;
    final double h = 96.0 * scale;
    final Rect dst = Rect.fromLTWH(x - w / 2, y - h, w, h);

    if (image != null) {
      _drawImageFit(canvas, image, dst);
    } else {
      // AC-14 placeholder: neutral rounded rectangle, never blank/crash.
      _fill.color = const Color(0xFF6B7280);
      canvas.drawRRect(
        RRect.fromRectAndRadius(dst, const Radius.circular(4)),
        _fill,
      );
    }
  }

  /// Draws the vehicle sprite (or placeholder) centred over the road near the
  /// camera. [bob] is the cosmetic vertical bob (0 while parked/reduce-motion).
  void paintVehicle(Canvas canvas, Size size, Image? image, double bob) {
    final double cx = size.width / 2;
    final double baseY = size.height * 0.86 - bob;
    const double vw = 150.0;
    const double vh = 110.0;
    final Rect dst = Rect.fromLTWH(cx - vw / 2, baseY - vh, vw, vh);
    if (image != null) {
      _drawImageFit(canvas, image, dst);
    } else {
      // AC-14 / AC-13 placeholder vehicle: a simple neutral shape, never blank.
      _fill.color = const Color(0xFF9CA3AF);
      canvas.drawRRect(
        RRect.fromRectAndRadius(dst, const Radius.circular(10)),
        _fill,
      );
      _fill.color = const Color(0xFF4B5563);
      final double wheelR = vw * 0.12;
      canvas.drawCircle(
        Offset(dst.left + wheelR * 1.4, dst.bottom),
        wheelR,
        _fill,
      );
      canvas.drawCircle(
        Offset(dst.right - wheelR * 1.4, dst.bottom),
        wheelR,
        _fill,
      );
    }
  }

  /// Applies the ambient day/night tint over the whole frame. Cosmetic only.
  void paintTint(Canvas canvas, Size size, Color tint) {
    if (tint.a == 0) {
      return;
    }
    _fill.color = tint;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _fill);
  }

  // Cached source rect; only re-created when an image's pixel size changes
  // (i.e. when a different-sized sprite is drawn), not every frame.
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

  Color _groundFor(Color sky) {
    // Darker, greener ground correlated with sky luminance.
    final double lum = (sky.r + sky.g + sky.b) / 3.0;
    final double k = lum.clamp(0.0, 1.0);
    return Color.lerp(const Color(0xFF14361C), const Color(0xFF3E7A3A), k) ??
        const Color(0xFF2E5A2C);
  }
}
