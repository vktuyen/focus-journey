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

import 'road_geometry.dart';
import 'side_object_pool.dart';

/// Geometry + drawing for one journey frame. Owned by `JourneyGame`, which
/// feeds it the current size, scroll phase, tint and sprites each render.
///
/// journey-scene-v2 #1 / AC-6: the road, lane markings and roadside objects all
/// bend along the SAME winding centre-line ([RoadGeometry]). The near→horizon
/// trapezoid (perspective narrowing) is preserved — the curve is a horizontal
/// centre-line OFFSET layered on top of the fake-3D trapezoid, strongest near
/// the camera and tucking back toward zero at the horizon.
class RoadPainter {
  /// Creates a painter. [geometry] is the shared winding-road centre-line
  /// model; defaults to a fresh model with production params. journey-dynamic-
  /// curve: the side-object pool is given the SAME geometry instance so its
  /// arc-length-aware spawn cadence and the painter's rendered bend agree.
  RoadPainter({RoadGeometry? geometry}) : geometry = geometry ?? RoadGeometry();

  /// Reusable paints/paths (no per-frame allocation).
  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  final Paint _sprite = Paint()..filterQuality = FilterQuality.low;
  // Dedicated sky paint so the sun/moon crossfade can mutate alpha without
  // disturbing the shared band/sprite paint mid-frame.
  final Paint _sky = Paint()..filterQuality = FilterQuality.low;
  final Path _path = Path();

  /// The winding-road centre-line model (#1 / AC-6). Pure, deterministic.
  final RoadGeometry geometry;

  // Tunables for the trapezoid (fractions of the viewport).
  static const double _horizonFrac = 0.42; // horizon y as fraction of height
  static const double _roadNearHalfFrac = 0.46; // near road half-width / width
  static const double _roadFarHalfFrac = 0.018; // far road half-width / width

  // How far (logical px) the centre-line may swing left/right at the camera
  // (#1 / AC-6). The swing is scaled by depth `t` so it is 0 at the horizon and
  // full near the camera — preserving the trapezoid read.
  //
  // journey-dynamic-curve / AC-2: intensified from the journey-scene-v2 baseline
  // `0.16` to `0.20` so the SHARPER model actually reaches the screen — the
  // near-camera rendered excursion grows ≈1.25× (the painter does not clamp the
  // extra curvature away). Exposed publicly as [curveAmplitudeFrac] so the
  // arc-length spacing measurement (`JourneyGame.liveCentreLinePoints`) and the
  // arc-length-aware spawn cadence track the SAME value instead of duplicating
  // a magic literal (which would silently desync the AC-5 measure).
  static const double curveAmplitudeFrac = 0.20; // of viewport width

  /// The near-camera curve amplitude in logical px for a viewport of [size] —
  /// `size.width × [curveAmplitudeFrac]`, the strongest horizontal swing the
  /// centre-line reaches (at depth `t → 1`). Exposed so the game can feed the
  /// pool the live amplitude for arc-length-aware spawning (AC-6) and so the
  /// arc-length measurement uses the painter's real amplitude (AC-5).
  static double nearCurveAmplitudePx(Size size) =>
      size.width * curveAmplitudeFrac;

  /// Horizon y for a viewport of [size]. Exposed so the vehicle/objects align.
  double horizonY(Size size) => size.height * _horizonFrac;

  /// The horizontal centre-line offset (logical px) at perspective depth [t]
  /// (0 = horizon, 1 = near camera) for the given [scrollOffset] world phase.
  /// journey-scene-v2 #1 / AC-6: lane markings AND roadside objects sample this
  /// SAME function so they follow the road's bend. The bend is scaled by `t` so
  /// it vanishes at the horizon (trapezoid read preserved) and is strongest near
  /// the camera. `worldAt(t)` maps depth to the world distance of that slice so
  /// the curve appears to flow toward the camera as the scene scrolls.
  double centreLineOffset(Size size, double scrollOffset, double t) {
    final double world = _worldAt(scrollOffset, t);
    final double amp = size.width * curveAmplitudeFrac;
    // Quadratic depth weighting: near→strong, horizon→~0 (preserve trapezoid).
    return geometry.lateralAt(world) * amp * (t * t);
  }

  // Maps a perspective depth `t` to the world distance of that slice. Nearer
  // slices (larger t) are at smaller world distances ahead of the camera, so
  // as scrollOffset grows the whole curve flows toward the camera.
  double _worldAt(double scrollOffset, double t) {
    // 1 - t so the horizon (t→0) is the farthest ahead. The 1200 px depth span
    // is the visible road length mapped across the trapezoid.
    return scrollOffset + (1.0 - t) * 1200.0;
  }

  /// The world distance (logical px) of the road slice AT THE CAMERA
  /// (perspective depth `t == 1`, the nearest slice). journey-cockpit-lean
  /// AC-10: the cockpit-lean signal samples `RoadGeometry.lateralSlopeAt` at
  /// this distance. Reuses the painter's own near→world conversion (`_worldAt`)
  /// so the lean reads the SAME bend the road body renders at the camera and the
  /// world-distance math is not duplicated. At `t == 1` this collapses to
  /// `scrollOffset`, but expose it through `_worldAt` so a future re-tuning of
  /// the depth span stays in one place.
  double worldAtCamera(double scrollOffset) => _worldAt(scrollOffset, 1.0);

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

  /// Paints the FURTHEST sky layer — the sun/moon and the drifting clouds —
  /// behind the mountain bands. Pure VIEW: this draws ONLY from already-passed-in
  /// cosmetic inputs and never reads a clock or geography (AC-5/AC-12/AC-13):
  ///  * the sun/moon are placed solely by [timeOfDayHours] (`0..24`) — the same
  ///    cosmetic value `DayNightTint` uses — arced across the sky and
  ///    crossfaded sun↔moon across dawn (~5–7 h) / dusk (~18–20 h) to match the
  ///    tint's transition. NO `DateTime.now`.
  ///  * the clouds drift by SCROLL PHASE ONLY ([scrollOffset], the same band
  ///    input the parallax bands use) at parallax factors SLOWER than the
  ///    mountain bands (0.02) so they read as the furthest layer. NO wall-clock.
  /// Each image is optional; a `null` is skipped (graceful degradation — the
  /// procedural sky painted by [paintBackground] stands in, AC-14). Allocation
  /// discipline matches the band convention: per-tile/per-disc `Rect`s only,
  /// `FilterQuality.low`, reusing the shared sky paint.
  void paintSky(
    Canvas canvas,
    Size size,
    double scrollOffset,
    double timeOfDayHours, {
    Image? sun,
    Image? moon,
    Image? cloud1,
    Image? cloud2,
    Image? cloud3,
  }) {
    final double horizon = horizonY(size);
    // --- Sun / moon: arced across the sky by the cosmetic timeOfDayHours. ---
    // `dayness` is 1 at solar noon, 0 deep at night, crossfading over dawn/dusk
    // to mirror DayNightTint exactly (sun fades out as moon fades in).
    final double dayness = _dayness(timeOfDayHours);
    if (sun != null && dayness > 0.0) {
      _paintCelestialBody(
        canvas,
        sun,
        size,
        horizon,
        // Daytime arc spans roughly the 6h→18h window; map the hour to a
        // left→right sweep so the sun rises at the east edge and sets at west.
        phase01: _arcPhase01(timeOfDayHours, riseHour: 6.0, setHour: 18.0),
        opacity: dayness,
      );
    }
    if (moon != null && dayness < 1.0) {
      _paintCelestialBody(
        canvas,
        moon,
        size,
        horizon,
        // Night arc spans the 18h→(30h=6h next day) window; the moon sweeps the
        // same left→right path over the night, offset by 12h from the sun.
        phase01: _arcPhase01(timeOfDayHours, riseHour: 18.0, setHour: 30.0),
        opacity: 1.0 - dayness,
      );
    }
    // --- Clouds: drift by SCROLL PHASE ONLY, slower than the mountain bands. ---
    // Layered at slow parallax factors (all < the slowest band's 0.02) so they
    // read as far away. Each cloud rides the same horizontal-wrap convention as
    // _paintParallaxBand but at a small band height high in the sky.
    final double skyTop = horizon * 0.10;
    if (cloud1 != null) {
      _paintCloud(
        canvas,
        cloud1,
        size,
        scrollOffset * 0.012,
        bandTop: skyTop,
        bandHeight: horizon * 0.18,
      );
    }
    if (cloud2 != null) {
      _paintCloud(
        canvas,
        cloud2,
        size,
        // Phase-shift + faster (but still slow) so the layers don't align.
        scrollOffset * 0.016 + size.width * 0.5,
        bandTop: horizon * 0.28,
        bandHeight: horizon * 0.16,
      );
    }
    if (cloud3 != null) {
      _paintCloud(
        canvas,
        cloud3,
        size,
        scrollOffset * 0.008 + size.width * 0.25,
        bandTop: horizon * 0.02,
        bandHeight: horizon * 0.14,
      );
    }
  }

  /// `1.0` at solar noon (full day), `0.0` deep at night, crossfading across
  /// dawn (~5–7 h) and dusk (~18–20 h) — the inverse of `DayNightTint`'s
  /// nightness so the sun/moon swap matches the tint transition. Pure function
  /// of [timeOfDayHours] (no clock).
  double _dayness(double timeOfDayHours) {
    final double h = _wrap24(timeOfDayHours);
    if (h >= 7 && h <= 18) {
      return 1.0; // full day
    }
    if (h > 18 && h < 20) {
      return 1.0 - (h - 18) / 2.0; // dusk: day fading out
    }
    if (h > 5 && h < 7) {
      return (h - 5) / 2.0; // dawn: day fading in
    }
    return 0.0; // 20..24 and 0..5 → full night
  }

  /// Maps an [hours] value to a `0..1` sweep across an arc that rises at
  /// [riseHour] and sets at [setHour] (hours, possibly wrapping past 24 for the
  /// night arc). Clamped to `[0,1]` so a body parked just before rise / after
  /// set sits at the horizon edge rather than off-screen. Pure (no clock).
  double _arcPhase01(
    double hours, {
    required double riseHour,
    required double setHour,
  }) {
    double h = _wrap24(hours);
    // For a window that wraps past midnight (e.g. 18→30), fold early-morning
    // hours up by 24 so they fall inside [riseHour, setHour].
    if (setHour > 24.0 && h < riseHour) {
      h += 24.0;
    }
    final double span = setHour - riseHour;
    if (span <= 0) {
      return 0.5;
    }
    final double p = (h - riseHour) / span;
    return p.clamp(0.0, 1.0);
  }

  /// Draws a sun/moon disc along a horizontal sweep ([phase01] 0=east→1=west)
  /// and a vertical arc (highest at mid-sweep). [opacity] crossfades the body.
  void _paintCelestialBody(
    Canvas canvas,
    Image image,
    Size size,
    double horizon, {
    required double phase01,
    required double opacity,
  }) {
    // Horizontal sweep across the inner 80% of the viewport width.
    final double x = size.width * (0.10 + 0.80 * phase01);
    // Vertical arc: a parabola peaking at mid-sweep (phase01 == 0.5). `arc` is
    // 1 at the peak, 0 at the horizon edges.
    final double arc = 1.0 - (2.0 * phase01 - 1.0) * (2.0 * phase01 - 1.0);
    final double topPad = horizon * 0.08;
    final double y =
        horizon - topPad - (horizon - topPad - horizon * 0.20) * arc;
    // Disc size scales with the viewport so it reads on any window.
    final double diameter = size.height * 0.10;
    final Rect dst = Rect.fromLTWH(
      x - diameter / 2,
      y - diameter / 2,
      diameter,
      diameter,
    );
    final Rect src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    _sky.color = Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0));
    canvas.drawImageRect(image, src, dst, _sky);
  }

  /// Like [_paintParallaxBand] but for the sky clouds: tiles/wraps horizontally
  /// by the scroll-derived [scroll], at a band high in the sky. Reuses the
  /// shared sprite paint; per-tile `Rect`s only (alloc-free convention).
  void _paintCloud(
    Canvas canvas,
    Image image,
    Size size,
    double scroll, {
    required double bandTop,
    required double bandHeight,
  }) {
    final double srcW = image.width.toDouble();
    final double srcH = image.height.toDouble();
    if (srcH <= 0) {
      return;
    }
    final double tileW = srcW * (bandHeight / srcH);
    if (tileW <= 0) {
      return;
    }
    // Add horizontal gaps between clouds (×2.4) so they read as discrete puffs,
    // not a solid band. The wrap period is the spaced tile width.
    final double period = tileW * 2.4;
    final double startX = -(scroll % period);
    final Rect src = Rect.fromLTWH(0, 0, srcW, srcH);
    for (double x = startX; x < size.width; x += period) {
      final Rect dst = Rect.fromLTWH(x, bandTop, tileW, bandHeight);
      canvas.drawImageRect(image, src, dst, _sprite);
    }
  }

  /// Wraps any double into `[0, 24)` (mirrors `DayNightTint._wrap24`). Pure.
  double _wrap24(double hours) {
    if (hours.isNaN || hours.isInfinite) {
      return 12.0;
    }
    final double m = hours % 24.0;
    return m < 0 ? m + 24.0 : m;
  }

  /// World-distance length (logical px) of ONE backdrop theme window before the
  /// rotation advances to the next theme. journey-scene-art-v3 / AC-5: the beach
  /// theme is reached purely as a function of the scroll phase — no clock, no
  /// geography. A long window so each theme reads as a sustained stretch of trip.
  static const double _themeWindowWorldPx = 9000.0;

  /// The number of backdrop themes in the rotation (highland → beach → …).
  static const int _themeCount = 2;

  /// The backdrop theme index for the given [scrollOffset], cycling by SCROLL
  /// PHASE ONLY (journey-scene-art-v3 / AC-5). `0` = highland (mountains+hills),
  /// `1` = beach/coast. Exposed read-only as a test seam so a test can assert
  /// the beach theme is reachable and is driven by scroll phase alone (it reads
  /// no activity / mode / time / geographic input).
  static int backdropThemeIndexFor(double scrollOffset) {
    if (scrollOffset <= 0) {
      return 0;
    }
    return (scrollOffset ~/ _themeWindowWorldPx) % _themeCount;
  }

  /// Paints the far-background parallax silhouette bands sitting on the horizon
  /// (journey-scene-v2 #11 / AC-8). Each band scrolls horizontally at a slow
  /// parallax rate derived from [scrollOffset], wrapping seamlessly. A `null`
  /// image is skipped (graceful degradation — no placeholder for background
  /// bands; the procedural sky/ground stands in).
  ///
  /// journey-scene-art-v3 / AC-5: the backdrop is a ROTATION of themes cycled by
  /// SCROLL PHASE ONLY (via [backdropThemeIndexFor]) — NO clock, NO geographic
  /// logic. The themes are:
  ///  * theme 0 — HIGHLAND: a layered far range, drawn deep → near:
  ///      [hillsLarge] (deepest, slowest) → [mountains] band → the [peakA]/
  ///      [peakB]/[peakC] foreground peaks → the near [hills] band. The extra
  ///      peaks + large-hills layers (P1 dead-weight fix) give the highland
  ///      theme genuine depth variety; all ride the SAME scroll-phase parallax
  ///      convention, NO clock/geo. A `null` layer is skipped (graceful
  ///      degradation). These are far BANDS, never pooled side-objects, so AC-7
  ///      even-spacing does not apply.
  ///  * theme 1 — BEACH/COAST: the sea/sand [coast] horizon band (closes the
  ///    journey-scene-v2 procedural-tint approximation — a REAL manifest asset).
  /// Beach is exactly ONE MORE backdrop theme among mountains/hills; it is NOT a
  /// pooled side-object (AC-7 even-spacing does not apply to it).
  void paintFarBackground(
    Canvas canvas,
    Size size,
    double scrollOffset,
    Image? mountains,
    Image? hills,
    Image? coast, {
    Image? hillsLarge,
    Image? peakA,
    Image? peakB,
    Image? peakC,
  }) {
    final double horizon = horizonY(size);
    final int theme = backdropThemeIndexFor(scrollOffset);
    if (theme == 1) {
      // BEACH/COAST theme: a single far sea/sand band on the horizon, slow
      // parallax. Cycled in purely by scroll phase (AC-5).
      if (coast != null) {
        _paintParallaxBand(
          canvas,
          coast,
          size,
          scrollOffset * 0.04,
          bandTop: horizon - size.height * 0.14,
          bandHeight: size.height * 0.20,
        );
      }
      return;
    }
    // HIGHLAND theme (default): layered far → near so nearer bands overlap.
    // Large hills: the DEEPEST layer — tallest, slowest parallax, sits highest.
    if (hillsLarge != null) {
      _paintParallaxBand(
        canvas,
        hillsLarge,
        size,
        scrollOffset * 0.02,
        bandTop: horizon - size.height * 0.26,
        bandHeight: size.height * 0.26,
      );
    }
    // Mountain range: tall, slow parallax, behind the foreground peaks.
    if (mountains != null) {
      _paintParallaxBand(
        canvas,
        mountains,
        size,
        scrollOffset * 0.04,
        bandTop: horizon - size.height * 0.22,
        bandHeight: size.height * 0.22,
      );
    }
    // Foreground peaks: three distinct silhouettes at staggered parallax rates
    // so they read as separate near peaks against the range behind them. Same
    // scroll-phase band convention; each skipped if absent.
    if (peakA != null) {
      _paintParallaxBand(
        canvas,
        peakA,
        size,
        scrollOffset * 0.05,
        bandTop: horizon - size.height * 0.18,
        bandHeight: size.height * 0.18,
      );
    }
    if (peakB != null) {
      _paintParallaxBand(
        canvas,
        peakB,
        size,
        // Phase-shift so it does not align with peakA's wrap (more variety).
        scrollOffset * 0.06 + size.width * 0.5,
        bandTop: horizon - size.height * 0.16,
        bandHeight: size.height * 0.16,
      );
    }
    if (peakC != null) {
      _paintParallaxBand(
        canvas,
        peakC,
        size,
        scrollOffset * 0.07 + size.width * 0.25,
        bandTop: horizon - size.height * 0.14,
        bandHeight: size.height * 0.14,
      );
    }
    // Hills: nearest, fastest parallax, overlap the horizon line.
    if (hills != null) {
      _paintParallaxBand(
        canvas,
        hills,
        size,
        scrollOffset * 0.08,
        bandTop: horizon - size.height * 0.10,
        bandHeight: size.height * 0.12,
      );
    }
  }

  void _paintParallaxBand(
    Canvas canvas,
    Image image,
    Size size,
    double scroll, {
    required double bandTop,
    required double bandHeight,
  }) {
    // Scale the source image to the band height, preserving aspect.
    final double srcW = image.width.toDouble();
    final double srcH = image.height.toDouble();
    if (srcH <= 0) {
      return;
    }
    final double tileW = srcW * (bandHeight / srcH);
    if (tileW <= 0) {
      return;
    }
    // Horizontal wrap start in [-tileW, 0).
    final double startX = -(scroll % tileW);
    final Rect src = Rect.fromLTWH(0, 0, srcW, srcH);
    // Draw enough tiles to cover the viewport width (+1 for the wrap edge).
    for (double x = startX; x < size.width; x += tileW) {
      final Rect dst = Rect.fromLTWH(x, bandTop, tileW, bandHeight);
      canvas.drawImageRect(image, src, dst, _sprite);
    }
  }

  /// Paints the WINDING fake-3D road and the scrolling dashed centre lane.
  /// [scrollOffset] is the shared eased offset (constant while stopped → road
  /// and lanes are frozen). Freezing is driven entirely by a frozen
  /// [scrollOffset]; the painter holds no motion state of its own.
  ///
  /// journey-scene-v2 #1 / AC-6: the road body is built from horizontal slices
  /// whose centre is shifted by [centreLineOffset]; the half-width still narrows
  /// from near→horizon (trapezoid read preserved) while the centre meanders
  /// left/right. The left/right edges and the lane dashes follow the same curve.
  void paintRoad(Canvas canvas, Size size, double scrollOffset) {
    final double horizon = horizonY(size);
    final double cx = size.width / 2;
    final double nearHalf = size.width * _roadNearHalfFrac;
    final double farHalf = size.width * _roadFarHalfFrac;
    final double bottom = size.height;

    // Number of slices across the depth span — enough for a smooth curve, few
    // enough to stay cheap. The same constant bounds both edge polylines.
    const int slices = 20;

    // Build the curved road body as a single closed path: down the right edge,
    // then back up the left edge.
    _path.reset();
    // Right edge, horizon → near.
    for (int i = 0; i <= slices; i++) {
      final double t = i / slices;
      final double y = horizon + (bottom - horizon) * t;
      final double half = farHalf + (nearHalf - farHalf) * t;
      final double centre = cx + centreLineOffset(size, scrollOffset, t);
      if (i == 0) {
        _path.moveTo(centre + half, y);
      } else {
        _path.lineTo(centre + half, y);
      }
    }
    // Left edge, near → horizon.
    for (int i = slices; i >= 0; i--) {
      final double t = i / slices;
      final double y = horizon + (bottom - horizon) * t;
      final double half = farHalf + (nearHalf - farHalf) * t;
      final double centre = cx + centreLineOffset(size, scrollOffset, t);
      _path.lineTo(centre - half, y);
    }
    _path.close();
    _fill.color = const Color(0xFF3A3F47);
    canvas.drawPath(_path, _fill);

    // Edge lines follow the same curved slices (reuse the body path outline).
    _stroke
      ..color = const Color(0xFFE8E2C8)
      ..strokeWidth = 2.0;
    canvas.drawPath(_path, _stroke);

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
      // journey-scene-v2 #1 / AC-6: dashes ride the curved centre-line, not the
      // straight cx — same geometry as the road body and the side objects.
      final double cTop = cx + centreLineOffset(size, scrollOffset, t);
      final double cBot = cx + centreLineOffset(size, scrollOffset, tNext);
      _path.reset();
      _path.moveTo(cTop - wTop, yTop);
      _path.lineTo(cTop + wTop, yTop);
      _path.lineTo(cBot + wBot, yBot);
      _path.lineTo(cBot - wBot, yBot);
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
  /// [scrollOffset] lets each object ride the curved centre-line (AC-6).
  void paintSideObjects(
    Canvas canvas,
    Size size,
    double scrollOffset,
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
          size,
          scrollOffset,
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
    Size size,
    double scrollOffset,
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
    // journey-scene-v2 #1 / AC-6: objects sit off the CURVED centre-line edge,
    // so they follow the road's bend.
    final double centre = cx + centreLineOffset(size, scrollOffset, t);
    // Place just outside the road edge, pushed further out by `lateral`.
    final double edgeX = centre + o.side * (roadHalf + roadHalf * 0.15);
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
