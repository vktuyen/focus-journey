// journey-cockpit-lean AC-13 / NFR-3 two-surface band-coverage (TC-514).
//
// Authored by test-script-author from tests/cases/journey-cockpit-lean.md.
//
// ADR-0003: the full window and the always-on-top mini-window PiP render the
// SAME JourneyGame instance, so the lean flows to BOTH surfaces for free. We
// model the two surfaces by rendering the one shared game at the two sizes
// (onGameResize -> render), exactly as the per-surface render path does
// (mirrors integration_test/cockpit_two_surface_test.dart's harness).
//
// TC-514 (AC-13, NFR-3): at a representative PiP size and a full-window size,
// sweep the curve across a full cycle and assert:
//   (a) the lean appears on BOTH surfaces (appliedLeanAngle non-zero at curving
//       frames at each size), and
//   (b) at every offset in the sweep INCLUDING the peak-clamp angle, the rotated
//       cockpit's PAINTED region still fully covers the cockpit band — the
//       bottom-centre rotation does NOT expose un-painted canvas corners or
//       reveal the scene where the cockpit should be.
//
// We assert (b) by recording each painted draw as its ACTUAL device-space QUAD
// (the four corners mapped through the active transform) — NOT an axis-aligned
// bounding box. A rotated base is a SKEWED quad whose AABB is a loose
// over-approximation: the AABB can overlap a viewport corner the real quad
// leaves exposed (the original B2 defect — a loose AABB check stayed green while
// a ~21.6px scene wedge was exposed at full size). The tightened assertion
// requires a single painted quad to geometrically CONTAIN each viewport bottom
// corner (0,h)/(w,h) after rotation, via a point-in-convex-quad test, at the
// WORST-CASE clamp angle. A dedicated non-vacuity guard reconstructs the OLD
// flat-6%-of-band overdraw base and proves the new check goes RED against it.
// This is the band-coverage geometry; the live frameless always-on-top PiP
// visual is the manual [REAL-OS] TC-M-PIP.
//
// NO real OS / timers / wall-clock — applyState + update(dt) only.
//   fvm flutter test integration_test/journey_cockpit_lean_two_surface_test.dart
//   fvm flutter test integration_test/journey_cockpit_lean_two_surface_test.dart -d macos

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_game.dart';
import 'package:integration_test/integration_test.dart';

final Vector2 kFullViewport = Vector2(1280, 800);
final Vector2 kPipViewport = Vector2(360, 220);

const double kFrameDt = 1 / 60;
const double _cycle = 16 * 900.0;
const double _maxRollCap = 0.0523599;

/// A painted draw recorded as its ACTUAL device-space QUAD (the four local
/// corners mapped through the active transform, in order TL,TR,BR,BL) — NOT an
/// axis-aligned bounding box. A rotated draw is a skewed quad; its AABB is a
/// loose over-approximation that can claim to cover a corner the real quad
/// leaves exposed (the B2 defect). Keeping the true quad lets us do an exact
/// point-in-convex-quad containment test against the viewport corners.
typedef _Quad = List<Offset>; // [TL, TR, BR, BL] in device space

/// A transform-aware recording canvas: it tracks the current 2D affine transform
/// (translate / rotate / scale / save / restore) and records each painted draw's
/// real DEVICE-space QUAD, so a rotated cockpit's true on-screen footprint is
/// measured (a plain bounds canvas, or an AABB, would miss/over-approximate the
/// rotation).
class _DeviceQuadCanvas implements Canvas {
  final List<_Quad> quads = <_Quad>[];

  // Current transform as [a, b, c, d, tx, ty] mapping (x,y) ->
  // (a*x + c*y + tx, b*x + d*y + ty). Saved/restored on a stack.
  double _a = 1, _b = 0, _c = 0, _d = 1, _tx = 0, _ty = 0;
  final List<List<double>> _stack = <List<double>>[];

  Offset _map(double x, double y) =>
      Offset(_a * x + _c * y + _tx, _b * x + _d * y + _ty);

  void _addLocalRect(double l, double t, double r, double bo) {
    // The four corners, mapped, in TL,TR,BR,BL order (preserves the quad shape).
    quads.add(<Offset>[_map(l, t), _map(r, t), _map(r, bo), _map(l, bo)]);
  }

  @override
  void save() => _stack.add(<double>[_a, _b, _c, _d, _tx, _ty]);
  @override
  void saveLayer(Rect? bounds, Paint paint) =>
      _stack.add(<double>[_a, _b, _c, _d, _tx, _ty]);
  @override
  void restore() {
    if (_stack.isEmpty) return;
    final s = _stack.removeLast();
    _a = s[0];
    _b = s[1];
    _c = s[2];
    _d = s[3];
    _tx = s[4];
    _ty = s[5];
  }

  @override
  void translate(double dx, double dy) {
    _tx += _a * dx + _c * dy;
    _ty += _b * dx + _d * dy;
  }

  @override
  void rotate(double radians) {
    final double cos = math.cos(radians);
    final double sin = math.sin(radians);
    // new = current * R(radians)
    final double na = _a * cos + _c * sin;
    final double nb = _b * cos + _d * sin;
    final double nc = -_a * sin + _c * cos;
    final double nd = -_b * sin + _d * cos;
    _a = na;
    _b = nb;
    _c = nc;
    _d = nd;
  }

  @override
  void scale(double sx, [double? sy]) {
    final double syy = sy ?? sx;
    _a *= sx;
    _b *= sx;
    _c *= syy;
    _d *= syy;
  }

  @override
  void drawRect(Rect rect, Paint paint) =>
      _addLocalRect(rect.left, rect.top, rect.right, rect.bottom);
  @override
  void drawRRect(RRect rrect, Paint paint) =>
      _addLocalRect(rrect.left, rrect.top, rrect.right, rrect.bottom);
  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      _addLocalRect(c.dx - radius, c.dy - radius, c.dx + radius, c.dy + radius);
  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => _addLocalRect(
    math.min(p1.dx, p2.dx),
    math.min(p1.dy, p2.dy),
    math.max(p1.dx, p2.dx),
    math.max(p1.dy, p2.dy),
  );
  @override
  void drawPath(Path path, Paint paint) {
    final Rect b = path.getBounds();
    _addLocalRect(b.left, b.top, b.right, b.bottom);
  }

  @override
  void drawImageRect(Image image, Rect src, Rect dst, Paint paint) =>
      _addLocalRect(dst.left, dst.top, dst.right, dst.bottom);

  @override
  void noSuchMethod(Invocation invocation) {}
}

/// True if convex [quad] (4 device-space corners in winding order) CONTAINS the
/// point `p` (a small inward epsilon allows the corner to sit exactly on the
/// edge). Uses the consistent-sign cross-product test across the 4 edges.
bool _quadContains(_Quad quad, Offset p, {double eps = 0.01}) {
  if (quad.length != 4) return false;
  double? sign;
  for (int i = 0; i < 4; i++) {
    final Offset a = quad[i];
    final Offset b = quad[(i + 1) % 4];
    final double cross =
        (b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx);
    if (cross.abs() < eps) continue; // on the edge
    final double s = cross > 0 ? 1.0 : -1.0;
    if (sign == null) {
      sign = s;
    } else if (s != sign) {
      return false; // p is outside this edge -> not contained
    }
  }
  return true;
}

Future<JourneyGame> loadGame() async {
  late JourneyGame game;
  final Completer<void> done = Completer<void>();
  Object? unexpected;
  runZonedGuarded(
    () async {
      game = JourneyGame();
      await game.onLoad();
      game.onGameResize(kFullViewport);
      if (!done.isCompleted) done.complete();
    },
    (Object error, StackTrace stack) {
      if (error.toString().contains('Unable to load asset')) return;
      unexpected ??= error;
      if (!done.isCompleted) done.completeError(error, stack);
    },
  );
  await done.future;
  await Future<void>.delayed(const Duration(milliseconds: 10));
  if (unexpected != null) {
    throw StateError('Unexpected zone error during onLoad: $unexpected');
  }
  return game;
}

/// Renders [game] at [size] (resize first) into a device-quad canvas and returns
/// the recorded device-space quads (one per painted primitive).
List<_Quad> _renderAt(JourneyGame game, Vector2 size) {
  game.onGameResize(size);
  final canvas = _DeviceQuadCanvas();
  game.render(canvas);
  return canvas.quads;
}

/// Asserts the rotated opaque cockpit base ACTUALLY CONTAINS the two viewport
/// bottom corners `(0, h)` and `(w, h)` — the precise AC-13 "no exposed corner"
/// outcome. Unlike a loose AABB check, this requires a SINGLE painted quad to
/// geometrically contain each corner after rotation: the dominant opaque
/// dashboard/fairing base is a large quad spanning the band, and under a correct
/// lever-arm overdraw its rotated quad still swallows both bottom corners. A
/// flat/under-sized overdraw leaves the far corner OUTSIDE every quad → red.
void _assertBandCornersCovered(List<_Quad> quads, Vector2 size, String label) {
  final double w = size.x;
  final double h = size.y;
  final Offset bottomLeft = Offset(0, h);
  final Offset bottomRight = Offset(w, h);
  // A corner is covered iff SOME painted cockpit quad contains it. We require a
  // genuine quad (the base/pillar foot), not the union of AABBs.
  final bool leftCovered = quads.any((q) => _quadContains(q, bottomLeft));
  final bool rightCovered = quads.any((q) => _quadContains(q, bottomRight));
  expect(
    leftCovered,
    isTrue,
    reason:
        'AC-13: $label — the rotated cockpit base must CONTAIN the viewport '
        'bottom-LEFT corner (0,$h); a skewed quad whose AABB merely overlaps is '
        'NOT coverage (no exposed un-painted corner)',
  );
  expect(
    rightCovered,
    isTrue,
    reason:
        'AC-13: $label — the rotated cockpit base must CONTAIN the viewport '
        'bottom-RIGHT corner ($w,$h) (no exposed un-painted corner)',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TC-514 lean on both surfaces; rotated frame covers the band at PiP (AC-13/NFR-3)',
    (tester) async {
      for (final mode in <TravelMode>[TravelMode.car, TravelMode.motorbike]) {
        final game = await loadGame();
        game.applyState(
          moving: true,
          mode: mode,
          reduceMotion: false,
          timeOfDayHours: 12,
        );

        bool fullLeaned = false;
        bool pipLeaned = false;
        double peakAngle = 0;

        // Sweep the curve across a full cycle, checking band coverage at BOTH
        // sizes at every step (including peak lean).
        while (game.roadScrollOffset < _cycle) {
          for (int f = 0; f < 8; f++) {
            game.update(kFrameDt);
          }
          final double angle = game.appliedLeanAngle;
          if (angle.abs() > peakAngle) peakAngle = angle.abs();
          if (angle.abs() > 1e-4) {
            fullLeaned = true;
            pipLeaned = true; // the SAME shared game leans on both surfaces
          }

          // Render at BOTH sizes from the one shared game (ADR-0003) and assert
          // the rotated cockpit still covers the band corners at each.
          final full = _renderAt(game, kFullViewport);
          _assertBandCornersCovered(full, kFullViewport, '$mode FULL');
          final pip = _renderAt(game, kPipViewport);
          _assertBandCornersCovered(pip, kPipViewport, '$mode PiP');

          // The lean appears on both surfaces (same angle; the cockpit is a
          // fraction of each live viewport).
          expect(game.isCockpitActive, isTrue);
          expect(
            game.appliedLeanAngle.abs(),
            lessThanOrEqualTo(_maxRollCap + 1e-9),
            reason: 'AC-13/AC-3: lean stays within the clamp on both surfaces',
          );
        }

        expect(fullLeaned, isTrue, reason: '$mode must lean on the full window');
        expect(pipLeaned, isTrue, reason: '$mode must lean on the PiP');
        // The sweep reached the clamp ceiling — corner coverage was genuinely
        // tested at the WORST-CASE angle (θ ≈ maxLeanRadians), not only at small
        // angles where any overdraw would trivially cover.
        expect(
          peakAngle,
          closeTo(_maxRollCap, 1e-3),
          reason:
              'AC-13: corner coverage must be exercised at the worst-case clamp '
              'angle (peak $peakAngle vs cap $_maxRollCap)',
        );

        // Worst-case explicit: hold the scene at a sharp bend so the angle is at
        // the cap, and assert containment at that exact frame on BOTH sizes.
        while (game.appliedLeanAngle.abs() < _maxRollCap - 1e-4) {
          game.update(kFrameDt);
          if (game.roadScrollOffset > 4 * _cycle) break; // safety
        }
        expect(
          game.appliedLeanAngle.abs(),
          closeTo(_maxRollCap, 1e-3),
          reason: '$mode must reach the clamp for the worst-case coverage check',
        );
        _assertBandCornersCovered(
          _renderAt(game, kFullViewport),
          kFullViewport,
          '$mode FULL @clamp',
        );
        _assertBandCornersCovered(
          _renderAt(game, kPipViewport),
          kPipViewport,
          '$mode PiP @clamp',
        );
      }
    },
  );

  // ===========================================================================
  // TC-514 NON-VACUITY GUARD — proves the tightened assertion would have caught
  // the original loose / flat-overdraw defect (B2).
  // ===========================================================================
  testWidgets(
    'TC-514 guard: the OLD flat-6%-overdraw base FAILS the corner-containment check',
    (tester) async {
      // The corner LIFT about the bottom-centre pivot is `(w/2)·sin|θ|`. The old
      // behaviour extended the opaque base below the viewport by only a flat
      // fraction of the BAND height (`0.06·bandH`, bandH = cockpitViewportFraction
      // · h ≈ 0.36·h). At the worst-case clamp angle this flat drop is FAR less
      // than the required lift, so the rotated base no longer reaches the far
      // bottom corner — the very wedge AC-13 forbids.
      const double theta = _maxRollCap; // worst case
      const double bandFrac = 0.36; // CockpitPainter.cockpitViewportFraction
      const double oldFlatFrac = 0.06; // the OLD flat-of-band bottom margin

      for (final s in <Vector2>[kFullViewport, kPipViewport]) {
        final double w = s.x;
        final double h = s.y;
        // Required drop to cover the corner = its rotational lift about the pivot.
        final double requiredDrop = (w / 2) * math.sin(theta);
        // The OLD flat drop the painter used to apply.
        final double oldFlatDrop = oldFlatFrac * (bandFrac * h);

        // (a) The required drop MATERIALLY exceeds the old flat drop — so the old
        // base was genuinely under-provisioned (documents WHY the loose version
        // was wrong). At full size the shortfall is a ~20px+ exposed wedge.
        expect(
          requiredDrop,
          greaterThan(oldFlatDrop * 1.5),
          reason:
              'guard @${w.toInt()}x${h.toInt()}: the corner lift '
              '(${requiredDrop.toStringAsFixed(1)}px) must materially exceed the '
              'old flat-6% drop (${oldFlatDrop.toStringAsFixed(1)}px) — proving '
              'the old overdraw left an exposed wedge of '
              '${(requiredDrop - oldFlatDrop).toStringAsFixed(1)}px',
        );

        // (b) Construct the OLD opaque base quad (full band width, extended below
        // the viewport by only the flat drop) and ROTATE it about the
        // bottom-centre pivot by θ, exactly as the painter's transform would.
        // Assert the containment check REJECTS the far bottom corner — the new
        // assertion would have gone RED against the old code.
        final double bandTop = h * (1 - bandFrac);
        // OLD base local rect: [0, w] × [bandTop, h + oldFlatDrop] (no side
        // overdraw in the flat version either — sx was a flat fraction too).
        final _Quad oldBaseRotated = _rotateQuadAboutPivot(
          <Offset>[
            Offset(0, bandTop),
            Offset(w, bandTop),
            Offset(w, h + oldFlatDrop),
            Offset(0, h + oldFlatDrop),
          ],
          pivot: Offset(w / 2, h),
          theta: theta,
        );
        // The lean lifts ONE far bottom corner; check the one that lifts away.
        // For +θ (clockwise, device y-down) the LEFT bottom corner (0,h) lifts.
        final Offset farCorner =
            theta >= 0 ? Offset(0, h) : Offset(w, h);
        expect(
          _quadContains(oldBaseRotated, farCorner),
          isFalse,
          reason:
              'guard @${w.toInt()}x${h.toInt()}: the OLD flat-6% rotated base '
              'must NOT contain the far viewport bottom corner $farCorner — '
              'confirming the tightened assertion catches the loose-overdraw '
              'defect (it would have been RED against the old painter)',
        );
      }
    },
  );
}

/// Rotates [quad]'s corners by [theta] about [pivot] (the painter's transform:
/// translate(pivot) · rotate(theta) · translate(-pivot)). Returns the device
/// quad in the same corner order.
_Quad _rotateQuadAboutPivot(_Quad quad, {required Offset pivot, required double theta}) {
  final double c = math.cos(theta);
  final double s = math.sin(theta);
  return quad.map((p) {
    final double dx = p.dx - pivot.dx;
    final double dy = p.dy - pivot.dy;
    return Offset(
      pivot.dx + dx * c - dy * s,
      pivot.dy + dx * s + dy * c,
    );
  }).toList();
}
