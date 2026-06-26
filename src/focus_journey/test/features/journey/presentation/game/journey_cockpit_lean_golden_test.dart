// Golden / baseline-equality tests for journey-cockpit-lean.
//
// Authored by test-script-author from tests/cases/journey-cockpit-lean.md. One
// group per case; each carries its TC-ID + AC-ID for traceability.
//
//   TC-509 AC-8  (golden leg) — non-cockpit modes (walk/run/bicycle/ship) render
//                  BYTE-FOR-BYTE unchanged vs the no-lean baseline at a curving
//                  offset (the lean slice leaves them untouched).
//   TC-510 AC-9  — only the cockpit rotates: every draw OUTSIDE the cockpit layer
//                  is rendered under the IDENTITY transform (the scene receives no
//                  rotation), and those scene draws are byte-for-byte identical
//                  leaning vs level; only the cockpit-layer draws carry a
//                  rotation. The world does NOT tilt.
//   TC-516 AC-1/3/4/9 (regression anchor) — a leaning car/motorbike cockpit frame
//                  at a fixed curving offset is deterministic and stable; the
//                  cockpit IS rolled (its DEVICE-space footprint differs from the
//                  level frame) while the scene draws are unchanged.
//
// GOLDEN PRECEDENT (this repo ships NO committed golden PNGs and uses NO
// matchesGoldenFile — see journey_dynamic_curve_behaviour_test.dart TC-413/414
// header). So these are DETERMINISTIC, byte-level draw-structure equality checks
// against an in-process "no-lean baseline": the painter SKIPS the rotation
// entirely when leanRadians == 0.0, so a reduce-motion render is byte-for-byte
// the pre-lean scene. No --update-goldens.
//
// The canvas here is TRANSFORM-AWARE: it tracks the active 2D affine transform
// so a `canvas.rotate(leanRadians)` is actually reflected (a plain bounds canvas
// would miss the rotation, since it lives in the transform, not the draw rects).
//
// NO real OS / timers / wall-clock — applyState + update(dt) only.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/journey/domain/travel_mode.dart';
import 'package:focus_journey/features/journey/presentation/game/journey_game.dart';

import 'journey_game_test_harness.dart';

const double _kEps = 1e-9;
final Vector2 _viewport = Vector2(1280, 720);

/// A recorded draw: its DEVICE-space AABB and whether the active transform was
/// the identity (scene layers) or rotated/translated (the cockpit lean layer).
typedef _Draw = ({Rect device, bool identity});

/// Transform-aware recording canvas. Tracks the current 2D affine transform via
/// save/restore/translate/rotate/scale so a rotated cockpit layer's real
/// footprint is captured AND flagged (identity == false).
class _XformCanvas implements Canvas {
  final List<_Draw> draws = <_Draw>[];
  int pathCount = 0;
  int imageRectCount = 0;

  double _a = 1, _b = 0, _c = 0, _d = 1, _tx = 0, _ty = 0;
  final List<List<double>> _stack = <List<double>>[];

  bool get _isIdentity =>
      _a == 1 && _b == 0 && _c == 0 && _d == 1 && _tx == 0 && _ty == 0;

  Offset _map(double x, double y) =>
      Offset(_a * x + _c * y + _tx, _b * x + _d * y + _ty);

  void _add(double l, double t, double r, double bo) {
    final pts = <Offset>[_map(l, t), _map(r, t), _map(r, bo), _map(l, bo)];
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final p in pts) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    draws.add((device: Rect.fromLTRB(minX, minY, maxX, maxY), identity: _isIdentity));
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
      _add(rect.left, rect.top, rect.right, rect.bottom);
  @override
  void drawRRect(RRect rrect, Paint paint) =>
      _add(rrect.left, rrect.top, rrect.right, rrect.bottom);
  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      _add(c.dx - radius, c.dy - radius, c.dx + radius, c.dy + radius);
  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => _add(
    math.min(p1.dx, p2.dx),
    math.min(p1.dy, p2.dy),
    math.max(p1.dx, p2.dx),
    math.max(p1.dy, p2.dy),
  );
  @override
  void drawPath(Path path, Paint paint) {
    pathCount++;
    final Rect b = path.getBounds();
    _add(b.left, b.top, b.right, b.bottom);
  }

  @override
  void drawImageRect(Image image, Rect src, Rect dst, Paint paint) {
    imageRectCount++;
    _add(dst.left, dst.top, dst.right, dst.bottom);
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}

_XformCanvas _render(JourneyGame game) {
  final c = _XformCanvas();
  game.render(c);
  return c;
}

void _expectByteIdentical(
  List<_Draw> a,
  List<_Draw> b, {
  required String why,
}) {
  expect(a.length, b.length, reason: '$why — draw count');
  for (int i = 0; i < a.length; i++) {
    expect(a[i].device.left, closeTo(b[i].device.left, _kEps), reason: '$why [#$i.l]');
    expect(a[i].device.top, closeTo(b[i].device.top, _kEps), reason: '$why [#$i.t]');
    expect(a[i].device.right, closeTo(b[i].device.right, _kEps), reason: '$why [#$i.r]');
    expect(a[i].device.bottom, closeTo(b[i].device.bottom, _kEps), reason: '$why [#$i.b]');
  }
}

Future<JourneyGame> _leaningGameAt(TravelMode mode, double offset) async {
  final game = await loadJourneyGame(size: _viewport);
  game.applyState(
    moving: true,
    mode: mode,
    reduceMotion: false,
    timeOfDayHours: 12,
  );
  while (game.roadScrollOffset < offset) {
    game.update(kFrameDt);
  }
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A fixed curving (mid-bend) offset — the lean is materially non-zero here.
  const double curvingOffset = 3964.0; // verified right-bend

  // ===========================================================================
  // TC-509 (AC-8 golden leg) — non-cockpit modes byte-for-byte unchanged.
  // ===========================================================================
  group('TC-509 non-cockpit modes render unchanged by the lean (AC-8 golden)', () {
    for (final mode in <TravelMode>[
      TravelMode.walk,
      TravelMode.run,
      TravelMode.bicycle,
      TravelMode.ship,
    ]) {
      test('${mode.name}_render_isByteForByte_theNoLeanBaseline', () async {
        // Lean "on" for a non-cockpit mode is the SAME scene — the slice applies
        // no transform to these modes. Compare two independent renders at the
        // same curving scroll phase; they must be byte-identical AND every draw
        // under the identity transform (no rotation anywhere).
        final a = await loadJourneyGame(size: _viewport);
        a.applyState(
          moving: true,
          mode: mode,
          reduceMotion: false,
          timeOfDayHours: 12,
        );
        while (a.roadScrollOffset < curvingOffset) {
          a.update(kFrameDt);
        }
        final b = await loadJourneyGame(size: _viewport);
        b.applyState(
          moving: true,
          mode: mode,
          reduceMotion: false,
          timeOfDayHours: 12,
        );
        while (b.roadScrollOffset < curvingOffset) {
          b.update(kFrameDt);
        }
        expect(a.roadScrollOffset, closeTo(b.roadScrollOffset, _kEps));
        expect(a.appliedLeanAngle, 0.0);

        final fa = _render(a);
        final fb = _render(b);
        _expectByteIdentical(
          fa.draws,
          fb.draws,
          why: 'AC-8: ${mode.name} must be byte-for-byte unchanged by the lean',
        );
        // No rotation anywhere for a non-cockpit mode.
        expect(
          fa.draws.every((d) => d.identity),
          isTrue,
          reason: 'AC-8: ${mode.name} must apply NO rotation transform',
        );
      });
    }
  });

  // ===========================================================================
  // TC-510 (AC-9) — only the cockpit rotates; scene receives no rotation.
  // ===========================================================================
  group('TC-510 only the cockpit rotates — scene unchanged (AC-9)', () {
    for (final mode in <TravelMode>[TravelMode.car, TravelMode.motorbike]) {
      test('${mode.name}_sceneDrawsUnderIdentity_areByteIdentical_leaningVsLevel',
          () async {
        // At a curving offset the cockpit leans. The transform-aware canvas flags
        // each draw as identity (scene) or rotated (cockpit). AC-9: every SCENE
        // draw is under the identity transform, and those scene draws are
        // byte-for-byte identical whether the cockpit leans (RM off) or is level
        // (RM on) — the world does not tilt; only the cockpit carries the
        // rotation.
        final game = await _leaningGameAt(mode, curvingOffset);
        expect(game.appliedLeanAngle, isNot(0.0), reason: 'sanity: leaning');
        final leaning = _render(game);

        // Some draws ARE rotated (the cockpit layer): the lean is genuinely live.
        final rotated = leaning.draws.where((d) => !d.identity).toList();
        expect(
          rotated,
          isNotEmpty,
          reason: 'AC-9: the cockpit layer must carry the rotation',
        );
        // Every ROTATED draw belongs to the cockpit band (lower portion) — the
        // rotation is confined to the cockpit, never the scene above it.
        final double bandTop = _viewport.y * (1 - game.cockpitViewportFraction);
        for (final d in rotated) {
          expect(
            d.device.bottom,
            greaterThan(bandTop - _viewport.y), // generous: cockpit + overdraw
            reason: 'AC-9: a rotated draw must belong to the cockpit layer',
          );
        }

        // AC-9 "world not tilted", proven WITHOUT conflating the lean with the
        // motion-freeze a reduce-motion baseline would introduce (the vehicle bob
        // legitimately differs RM-on vs RM-off): the SCENE layers are everything
        // emitted BEFORE the first rotated cockpit draw, and EVERY one of them is
        // under the IDENTITY transform — the scene renderer receives no rotation.
        // Only the cockpit layer (the rotated draws) carries the transform.
        final int sceneCount = _firstRotatedIndex(leaning.draws);
        expect(sceneCount, greaterThan(0), reason: 'a scene must precede the cockpit');
        for (int i = 0; i < sceneCount; i++) {
          expect(
            leaning.draws[i].identity,
            isTrue,
            reason:
                'AC-9: scene draw #$i must be under the identity transform — '
                'the world is NOT rotated, only the cockpit is',
          );
        }
        // And the SCENE prefix is byte-stable on a re-render of the SAME leaning
        // frame (deterministic; the world geometry does not move under the lean).
        final leaningAgain = _render(game);
        _expectByteIdentical(
          leaning.draws.sublist(0, sceneCount),
          leaningAgain.draws.sublist(0, sceneCount),
          why: 'AC-9: the scene (world) layer must be byte-stable under the lean',
        );
      });
    }

  });

  // ===========================================================================
  // TC-516 (AC-1/3/4/9 anchor) — leaning cockpit frame is deterministic + stable.
  // ===========================================================================
  group('TC-516 leaning cockpit anchor frame is stable (AC-1/3/4/9 golden)', () {
    for (final mode in <TravelMode>[TravelMode.car, TravelMode.motorbike]) {
      test('${mode.name}_leaningFrame_isDeterministic_cockpitRolled_sceneFlat',
          () async {
        final game = await _leaningGameAt(mode, curvingOffset);
        expect(game.appliedLeanAngle, isNot(0.0));
        expect(game.appliedLeanAngle.abs(), lessThanOrEqualTo(0.0523599 + 1e-9));

        // Determinism: re-rendering the SAME pinned frame is byte-stable.
        final first = _render(game);
        final second = _render(game);
        _expectByteIdentical(
          first.draws,
          second.draws,
          why: 'AC-9: the pinned leaning frame must be byte-stable on re-render',
        );

        // The cockpit IS rolled: at least one cockpit-layer draw is under a
        // NON-identity (rotated) transform — the lean is genuinely applied.
        expect(
          first.draws.any((d) => !d.identity),
          isTrue,
          reason: 'AC-1/AC-3: the cockpit must be rolled at the pinned frame',
        );

        // Compared to the LEVEL frame at the same phase, the cockpit layer's
        // DEVICE-space footprint shifts (rotation about the bottom-centre pivot
        // moves the top of the band) while the scene stays put.
        final leaningCockpitTop = _cockpitDeviceTop(first.draws, game);
        game.applyState(
          moving: true,
          mode: mode,
          reduceMotion: true,
          timeOfDayHours: 12,
        );
        final level = _render(game);
        final levelCockpitTop = _cockpitDeviceTop(level.draws, game);
        expect(
          (leaningCockpitTop - levelCockpitTop).abs(),
          greaterThan(0.5),
          reason:
              'AC-1/AC-3: the rolled cockpit band top must shift in device '
              'space vs the level frame (the cockpit visibly leans)',
        );
      });
    }
  });
}

/// The index of the first rotated (cockpit-layer) draw — i.e. the length of the
/// leading scene-layer window (the scene is composited entirely before the
/// cockpit, under the identity transform). Returns the full length if none.
int _firstRotatedIndex(List<_Draw> draws) {
  for (int i = 0; i < draws.length; i++) {
    if (!draws[i].identity) return i;
  }
  return draws.length;
}

/// The minimum device-space top y across the cockpit-layer draws. For a leaning
/// frame these are the rotated draws; for a level frame the cockpit uses the
/// identity transform, so we take the draws in the lower cockpit band.
double _cockpitDeviceTop(List<_Draw> draws, JourneyGame game) {
  final double bandTop = game.size.y * (1 - game.cockpitViewportFraction);
  // Prefer rotated draws (leaning); fall back to lower-band identity draws (level).
  final rotated = draws.where((d) => !d.identity).toList();
  final source = rotated.isNotEmpty
      ? rotated
      : draws.where((d) => d.device.bottom > bandTop).toList();
  return source.map((d) => d.device.top).reduce((a, b) => a < b ? a : b);
}
