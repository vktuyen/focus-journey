/// Presentation layer (Flame). The journey POV road scene as a pure VIEW.
///
/// SEPARATION INVARIANT (AC-9/AC-10/TC-009/TC-010): this file and its siblings
/// import ONLY `dart:*`, `package:flame/*`, and the pure-Dart domain
/// [TravelMode] enum. They MUST NOT import `flutter_bloc`, the `JourneyEngine`,
/// any `ActivityPlugin`, any `MethodChannel`/platform channel, or read OS idle/
/// lock signals. The scene takes plain values via [applyState] and never
/// decides active-vs-idle, never accrues distance, never mutates journey state.
///
/// Motion is governed ONLY by the `moving` flag (binary speed — AC-7) through a
/// short bounded ease (AC-6). `timeOfDayHours` is cosmetic tint ONLY (AC-12) and
/// is a passed-in value — the scene reads no clock itself. Before the first
/// [applyState] the scene renders the parked/stopped look (AC-13).
library;

import 'dart:ui';

import 'package:flame/game.dart';

import '../../domain/travel_mode.dart';
import 'cockpit_painter.dart';
import 'day_night_tint.dart';
import 'journey_assets.dart';
import 'journey_skins.dart';
import 'journey_sprites.dart';
import 'road_geometry.dart';
import 'road_painter.dart';
import 'scene_motion.dart';
import 'side_object_pool.dart';

/// The Flame game embedded in the journey screen. Drive it exclusively via
/// [applyState]; everything else is rendering and read-only test seams.
class JourneyGame extends FlameGame {
  /// Creates the game.
  ///
  /// [sideObjectCapacity] bounds the recycling pool. [cruiseSpeed] /
  /// [easeDuration] tune the single shared scroll speed and the bounded ease.
  ///
  /// journey-scene-v2 #3 / AC-1: [cruiseSpeed] defaults to the v2 cosmetic
  /// playback rate [kV2CruiseSpeed] (≈0.33× of the pinned v1 [kV1CruiseSpeed]),
  /// so the rendered scroll reads ~3× slower while the engine's journey truth
  /// (distanceKm / progress / elapsed) is computed elsewhere and UNCHANGED.
  JourneyGame({
    int sideObjectCapacity = 24,
    double cruiseSpeed = kV2CruiseSpeed,
    double easeDuration = 0.35,
  }) : _motion = SceneMotion(
         cruiseSpeed: cruiseSpeed,
         easeDuration: easeDuration,
       ),
       _painter = RoadPainter(geometry: _sharedGeometry),
       // journey-dynamic-curve AC-6: the pool spawns on an ARC-LENGTH cadence
       // using the SAME centre-line model the painter renders, so spacing is
       // even along the actual curve at any viewport width (AC-5).
       _pool = SideObjectPool(
         capacity: sideObjectCapacity,
         geometry: _sharedGeometry,
       );

  // One shared centre-line model for the painter (render) and the pool
  // (arc-length spawn cadence). Built once so both sample identical geometry.
  static final RoadGeometry _sharedGeometry = RoadGeometry();

  final SceneMotion _motion;
  final SideObjectPool _pool;
  final RoadPainter _painter;
  final CockpitPainter _cockpit = CockpitPainter();
  late final JourneySprites _sprites;

  // --- Driven state (set only by applyState; defaults = parked/stopped). ---
  TravelMode _mode = TravelMode.motorbike;
  bool _reduceMotion = false;
  double _timeOfDayHours = 12.0;
  bool _hasReceivedState = false;

  // Cosmetic vehicle bob phase (advances only while visibly moving).
  double _bobPhase = 0;

  // --- journey-cockpit-lean: the eased, bounded, scroll-deterministic roll. ---
  // The applied (smoothed) cockpit roll angle in radians, signed INTO the turn.
  // A pure function of the SMOOTHED SCROLL-PHASE history (AC-5): each frame it
  // eases toward the raw target by an amount derived from `scrollDelta` (not
  // dt / wall-clock), so replaying the same `roadScrollOffset` sequence yields
  // the identical angle sequence. Reset to 0 by reduce-motion (AC-6).
  double _appliedLean = 0.0;

  // === Pinned lean build decisions (journey-cockpit-lean) ===

  /// AC-3 clamp ceiling — the bounded maximum roll (rad). Pinned at ~3°
  /// (`0.0523599 rad`), the spec-proposed "physical but calm" ceiling, well
  /// under nausea-grade roll. `|appliedLeanAngle|` never exceeds this for any
  /// curve sample at the shipped `journey-dynamic-curve` curvature.
  static const double maxLeanRadians = 0.0523599; // 3°

  /// AC-1/AC-10 lean gain — maps the signed near-camera slope
  /// (`RoadGeometry.lateralSlopeAt`, in normalised-lateral-units per world px)
  /// to a target roll angle. The sharpest shipped near-camera bend reaches
  /// `|slope| ≈ 0.00335` (measured: `cos(phase)·heading·maxHeading` at the peak
  /// offset, where `cos(phase)` is slightly below 1 at the `|heading|=0.95`
  /// segment). At this gain the raw target there is `≈0.060 rad`, comfortably
  /// PAST [maxLeanRadians] (`0.0524`), so the clamp is genuinely EXERCISED at the
  /// sharpest bend (TC-504 — the cap is reached, not vacuous) while the magnitude
  /// stays MONOTONIC in `|slope|` below saturation (TC-503). Pinned at 18.0;
  /// reviewer may retune the feel (re-pin TC-503/TC-504 bands if changed).
  static const double leanGain = 18.0;

  /// AC-4 smoothing length (logical px of scroll). The applied angle eases
  /// toward the raw target by `lerp(applied, target, scrollDelta /
  /// leanSmoothingLengthPx)` — keyed on SCROLL DISTANCE, not dt, so it is
  /// DETERMINISTIC (AC-5). At cruise (`kV2CruiseSpeed·1/60 ≈ 1.76 px/frame`) the
  /// worst-case per-frame change is `≈ (1.76/60)·maxLeanRadians ≈ 0.0015 rad`
  /// (~0.084°/frame) — comfortably under the ~0.2°/frame (~0.0035 rad)
  /// smoothness cap, so the angle never snaps even when the raw slope jumps.
  static const double leanSmoothingLengthPx = 60.0;

  /// AC-1 SIGN CONVENTION (pinned — a flip is a TC-501/TC-502 failure):
  /// `RoadGeometry.lateralAt` is positive when the road centre swings RIGHT
  /// (the painter adds `centreLineOffset` to `cx`, so +offset → centre moves to
  /// larger x → right). Its derivative `lateralSlopeAt > 0` therefore means the
  /// road ahead bends RIGHT. On screen (y-down) a POSITIVE canvas rotation is
  /// CLOCKWISE = the frame rolls RIGHT — which is INTO a right turn. So a right
  /// bend (+slope) → +angle (lean right) and a left bend (−slope) → −angle (lean
  /// left): `appliedAngle = +leanGain · slope` leans INTO the turn with NO
  /// negation. If a future change flips `lateralSlopeAt`'s sign, negate here so
  /// the lean stays into the turn (and TC-501/TC-502 will catch the flip).
  static const double leanSignConvention = 1.0;

  // ===========================================================================
  // PUBLIC CONTRACT — the UI agent calls exactly this.
  // ===========================================================================

  /// Drives the entire scene from plain values — no Bloc, no engine, no OS.
  ///
  /// * [moving]: `true` → scroll/animate; `false` → ease to a stop + park.
  /// * [mode]: cosmetic skin; swaps the vehicle sprite; NEVER changes speed.
  /// * [reduceMotion]: honour OS reduce-motion — suppress scroll, still convey
  ///   state (parked-vs-running pose + overlay handled by the wrapper widget).
  /// * [timeOfDayHours]: `0.0..24.0`, cosmetic day/night tint ONLY.
  void applyState({
    required bool moving,
    required TravelMode mode,
    required bool reduceMotion,
    required double timeOfDayHours,
  }) {
    _hasReceivedState = true;
    _mode = mode;
    _reduceMotion = reduceMotion;
    _timeOfDayHours = timeOfDayHours;
    _motion
      ..setReduceMotion(reduceMotion)
      ..setMoving(moving);
  }

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  @override
  Future<void> onLoad() async {
    // Route all journey art under assets/journey/ (see JourneyAssets).
    images.prefix = JourneyAssets.assetPrefix;
    // Use the SAME bundle Flame's image cache reads from for the manifest
    // pre-check, so "exists in bundle" and "loadable by Flame" agree.
    _sprites = JourneySprites(
      images,
      bundle: images.bundle,
      assetPrefix: images.prefix,
    );
    // Graceful: loadAll never throws; failures become placeholders (AC-14).
    await _sprites.loadAll();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (paused) {
      return; // suspended off-screen (AC perf / TC-018): no motion work.
    }
    final double prevOffset = _motion.offset;
    _motion.advance(dt);
    final double scrollDelta = _motion.offset - prevOffset;
    // journey-dynamic-curve AC-6: feed the pool the live near-camera curve
    // amplitude (px) so its arc-length spawn cadence matches the bend the scene
    // actually renders at this viewport size (AC-5 even spacing at any width).
    // Computed inline (no Size allocation on the hot path — NFR-1).
    _pool.advance(
      scrollDelta,
      curveAmpPx: size.x * RoadPainter.curveAmplitudeFrac,
    );
    // Bob advances with eased velocity so it ramps in/out with motion and is
    // exactly frozen when stopped or reduce-motion (velocity == 0).
    if (_motion.velocity > 0) {
      final JourneySkin skin = JourneySkins.of(_mode);
      _bobPhase += dt * skin.bobFrequencyHz;
    }
    // journey-cockpit-lean: advance the eased cockpit roll off `scrollDelta`
    // (NOT dt) so the angle is a deterministic function of the scroll phase
    // (AC-5). O(1), allocation-free (NFR-1).
    _advanceLean(scrollDelta);
  }

  /// Eases [_appliedLean] toward the raw curve-derived target by an amount keyed
  /// on the scroll distance covered this frame ([scrollDelta]). Reduce-motion is
  /// a HARD ZERO (AC-6): the target AND the smoothed state are forced to exactly
  /// `0.0` so the cockpit never starts or stays tilted. Only car/motorbike lean
  /// (AC-8); other modes settle the angle to 0 too. Pure scroll-phase math — no
  /// clock, no `Random` (AC-5). O(1), allocation-free (NFR-1).
  void _advanceLean(double scrollDelta) {
    if (_reduceMotion ||
        (_mode != TravelMode.car && _mode != TravelMode.motorbike)) {
      // Hard zero from the first frame (AC-6) / no cockpit to tilt (AC-8): zero
      // both the target and the smoothed state so it is exactly level.
      _appliedLean = 0.0;
      return;
    }
    // AC-10 lean signal: the SIGNED near-camera slope of the SAME winding curve
    // the road body renders, sampled at the camera (t≈1) via the painter's own
    // near→world conversion (no duplicated world-distance math).
    final double worldAtCam = _painter.worldAtCamera(_motion.offset);
    final double slope = _sharedGeometry.lateralSlopeAt(worldAtCam);
    // AC-1 sign + AC-2 monotonic-in-|slope| + AC-3 clamp.
    double target = leanSignConvention * leanGain * slope;
    if (target > maxLeanRadians) {
      target = maxLeanRadians;
    } else if (target < -maxLeanRadians) {
      target = -maxLeanRadians;
    }
    // AC-4 eased low-pass keyed on SCROLL DISTANCE (deterministic — AC-5).
    double k = scrollDelta / leanSmoothingLengthPx;
    if (k < 0.0) {
      k = 0.0; // scroll never runs backwards, but guard the lerp factor.
    } else if (k > 1.0) {
      k = 1.0;
    }
    _appliedLean += (target - _appliedLean) * k;
    // AC-7: the lerp converges asymptotically; snap to the target once the gap
    // is negligible so a SETTLED straight-road angle is EXACTLY 0.0 (and a
    // settled curving angle exactly its clamped value), as the cases assert with
    // `== 0.0`. The threshold is far below any visible difference and far below
    // a single eased-cruise step, so it never corrupts the monotonic ramp.
    if ((target - _appliedLean).abs() < 1e-9) {
      _appliedLean = target;
    }
  }

  @override
  void render(Canvas canvas) {
    final Size s = Size(size.x, size.y);
    final Color sky = DayNightTint.skyFor(_timeOfDayHours);
    _painter
      ..paintBackground(canvas, s, sky)
      // Furthest layer: sun/moon (placed by the cosmetic _timeOfDayHours, no
      // clock) + clouds drifting by scroll phase only — drawn BEHIND the
      // mountain bands. A null sky image is skipped (procedural sky stands in).
      ..paintSky(
        canvas,
        s,
        _motion.offset,
        _timeOfDayHours,
        sun: _sprites.sun,
        moon: _sprites.moon,
        cloud1: _sprites.cloud1,
        cloud2: _sprites.cloud2,
        cloud3: _sprites.cloud3,
      )
      ..paintFarBackground(
        canvas,
        s,
        _motion.offset,
        _sprites.mountainRange,
        _sprites.hills,
        _sprites.coastBand,
        hillsLarge: _sprites.hillsLarge,
        peakA: _sprites.mountainPeakA,
        peakB: _sprites.mountainPeakB,
        peakC: _sprites.mountainPeakC,
      )
      ..paintRoad(canvas, s, _motion.offset)
      ..paintSideObjects(
        canvas,
        s,
        _motion.offset,
        _pool.slots,
        _sprites.imageForKind,
      )
      ..paintVehicle(canvas, s, _vehicleImage(), _bob())
      ..paintTint(canvas, s, DayNightTint.tintFor(_timeOfDayHours));
    // journey-pov AC-1/AC-3/AC-6: composite the first-person cockpit FOREGROUND
    // for car/motorbike ONLY. Drawn AFTER paintTint deliberately: the day/night
    // tint conveys the OUTSIDE world seen through the windshield/over the bars,
    // so it must darken the road but NOT wash out the cockpit you sit inside —
    // the cockpit stays a stable, readable interior frame at any hour. For
    // walk/run/bicycle/ship the painter draws nothing (AC-6), leaving the
    // existing side-view sprite path untouched. The cockpit holds no cached
    // per-frame state, so a mode-switch away leaves no residual layer (AC-7)
    // and a switch back restores automatically (AC-8).
    _cockpit.paint(
      canvas,
      s,
      _mode,
      moving: _motion.velocity > 0,
      glyphFor: _sprites.imageFor,
      // journey-cockpit-lean AC-9: ONLY the cockpit layer carries the rotation;
      // every scene layer above was painted with NO transform, so its output
      // for a given scroll offset is byte-for-byte the no-lean baseline.
      leanRadians: appliedLeanAngle,
    );
    super.render(canvas); // draw any child components on top (none in v1).
  }

  Image? _vehicleImage() => _sprites.imageFor(JourneySkins.of(_mode).assetPath);

  double _bob() {
    if (_motion.velocity <= 0 || _reduceMotion) {
      return 0; // parked / reduce-motion: no bob.
    }
    final JourneySkin skin = JourneySkins.of(_mode);
    // Magnitude scales with how far the ease has ramped (0..1).
    final double ramp = _motion.velocity / _motion.cruiseSpeed;
    return _sin01(_bobPhase) * skin.bobAmplitude * ramp;
  }

  double _sin01(double phase) {
    // Map phase (turns) to a sine in [-1, 1].
    return _fastSin(phase * 6.28318530718);
  }

  // ===========================================================================
  // READ-ONLY TEST SEAMS (for the test agents — do not drive state with these).
  // ===========================================================================

  /// Shared scroll offset; advances while moving, constant while stopped.
  /// (TC-001/TC-004/TC-005/TC-007.)
  double get roadScrollOffset => _motion.offset;

  /// Current eased scroll velocity (px/s); `0` exactly when fully stopped,
  /// equals cruise speed at full motion. (TC-006/TC-024.)
  double get scrollVelocity => _motion.velocity;

  /// Whether the ease is still settling toward its target. (TC-006/TC-024.)
  bool get isSettling => _motion.isSettling;

  /// The constant cruise speed (px/s) — the single shared speed. (TC-007/008.)
  double get cruiseSpeed => _motion.cruiseSpeed;

  /// The current cosmetic mode/skin being rendered. (TC-008.)
  TravelMode get currentMode => _mode;

  /// The vehicle sprite asset path currently selected for [currentMode].
  /// (TC-008 — assert the sprite swaps with mode.)
  String get currentVehicleAsset => JourneySkins.of(_mode).assetPath;

  /// `true` when the vehicle shows its running pose (visibly moving), `false`
  /// when parked. (TC-001/TC-002/TC-013.)
  bool get isVehicleRunning => _motion.velocity > 0;

  /// `true` when fully at rest: zero velocity AND not settling. Convenience for
  /// the "stopped" assertion. (TC-002/TC-004/TC-006.)
  bool get isStopped => _motion.velocity == 0 && !_motion.isSettling;

  /// Live (renderable) side-object count; recycled from a bounded pool. Test
  /// seam for the plateau assertion. (TC-017.)
  int get liveSideObjectCount => _pool.liveCount;

  /// Max side-object pool capacity (the count can never exceed this). (TC-017.)
  int get sideObjectCapacity => _pool.capacity;

  /// Paths whose sprite failed to load and are shown as placeholders. Empty
  /// when all curated assets loaded. (TC-014.)
  Set<String> get failedAssetPaths => _sprites.failedPaths;

  /// Whether any element is being rendered as a placeholder. (TC-014.)
  bool get hasPlaceholderAssets => _sprites.hasPlaceholders;

  /// The cosmetic time-of-day (hours) currently applied to the tint. (TC-012.)
  double get timeOfDayHours => _timeOfDayHours;

  /// The ambient tint colour currently applied. (TC-012/TC-025.)
  Color get currentTint => DayNightTint.tintFor(_timeOfDayHours);

  /// Whether [applyState] has been called at least once. `false` → the scene
  /// is showing the first-frame parked/stopped default. (TC-013.)
  bool get hasReceivedState => _hasReceivedState;

  /// Whether the scene is honouring reduce-motion. (TC-019.)
  bool get reduceMotion => _reduceMotion;

  /// The current rendered cruise speed (logical px/s) — the cosmetic playback
  /// rate. journey-scene-v2 AC-1: production wires this to [kV2CruiseSpeed]
  /// (≈0.33× of the pinned [kV1CruiseSpeed]). (TC-001.)
  double get renderedCruiseSpeed => _motion.cruiseSpeed;

  /// The winding-road centre-line horizontal offset (logical px) at perspective
  /// depth [t] (0 = horizon, 1 = near camera) for the CURRENT scroll phase.
  /// journey-scene-v2 #1 / AC-6: non-constant over `t` (curve) and over the
  /// scroll phase (it meanders); lane markings + side objects sample the same
  /// function. (TC-007.)
  double centreLineOffsetAt(double t) {
    final Size sz = Size(size.x, size.y);
    return _painter.centreLineOffset(sz, _motion.offset, t);
  }

  /// The spawn world-distances (logical px) of the live side objects, in spawn
  /// order. journey-scene-v2 #12 / AC-7: consecutive gaps are the FIXED spawn
  /// cadence, so arc-length spacing along the curve is even. (TC-008.)
  List<double> get liveSpawnDistances {
    final List<double> out = <double>[];
    for (final SideObject o in _pool.slots) {
      if (o.active) {
        out.add(o.spawnWorldDistance);
      }
    }
    out.sort();
    return out;
  }

  /// The fixed world-distance gap between consecutive scenery spawns. (TC-008.)
  double get spawnEveryWorldPx => _pool.spawnEveryWorldPx;

  /// The positions of the live side objects along the curving road centre-line,
  /// in along-road order, as points `(world, lateral)`. journey-scene-v2 AC-7 /
  /// TC-008.
  ///
  /// Coordinating note (added per the AC-7 review gap): [liveSpawnDistances]
  /// exposes only the FIXED `spawnEveryWorldPx` cadence, so a variance check on
  /// it is even by construction and can never fail. This seam instead gives each
  /// object's REAL position on the curving centre-line:
  ///  * `world`  — its fixed longitudinal world coordinate on the road
  ///    (`spawnWorldDistance`); the object stays put in world space while the
  ///    camera advances, so this is where it actually sits along the road.
  ///  * `lateral` — the road's horizontal bend at that world coordinate
  ///    (`RoadGeometry.lateralAt(world)` scaled by the near-camera curve
  ///    amplitude), i.e. how far the centre-line has swung there.
  ///
  /// The ARC-LENGTH gap between consecutive points therefore combines the
  /// longitudinal cadence with the lateral curve contribution — spacing
  /// measured ALONG the curving road (per the AC-7 "along the curve"
  /// convention), not screen-space. A sharp enough bend between two objects
  /// pushes their arc-length gap past the ±20% bound, so this measure can
  /// genuinely FAIL — it is not the always-true spawn cadence.
  ///
  /// READ-ONLY TEST SEAM (do not drive state with it) — kept un-annotated to
  /// match the other seams above and preserve this file's separation invariant
  /// (no `package:flutter`/`package:meta` import).
  List<({double world, double lateral})> get liveCentreLinePoints {
    // Near-camera curve amplitude in logical px — the strongest bend the
    // centre-line reaches. Tracks RoadPainter.curveAmplitudeFrac exactly (no
    // duplicated literal) so the arc-length measure reflects the road's real
    // rendered horizontal swing even when the amplitude is retuned
    // (journey-dynamic-curve raised it 0.16 → 0.20).
    final double amp = RoadPainter.nearCurveAmplitudePx(Size(size.x, size.y));
    final List<({double world, double lateral})> out =
        <({double world, double lateral})>[];
    for (final SideObject o in _pool.slots) {
      if (!o.active) {
        continue;
      }
      final double world = o.spawnWorldDistance;
      final double lateral = _painter.geometry.lateralAt(world) * amp;
      out.add((world: world, lateral: lateral));
    }
    out.sort((a, b) => a.world.compareTo(b.world));
    return out;
  }

  // --- journey-pov cockpit seams (read-only; do not drive state with them). ---

  /// `true` exactly when [currentMode] is a first-person cockpit mode (car or
  /// motorbike) — i.e. when the cockpit foreground is composited over the road.
  /// journey-pov AC-1/AC-3/AC-6/AC-7/AC-8. Stateless: derived from [currentMode]
  /// each call, so it flips cleanly on every mode switch.
  bool get isCockpitActive =>
      _mode == TravelMode.car || _mode == TravelMode.motorbike;

  /// The cockpit glyph asset paths REQUESTED for [currentMode], in draw order,
  /// or an empty list for a non-cockpit mode. journey-pov AC-1/AC-3/AC-17 seam:
  /// assert the car/motorbike cockpit paths are requested and that each has a
  /// CREDITS entry. (A subset may be in [failedAssetPaths] when not yet sourced
  /// — the painter then draws its original flat-shape fallback, AC-13.)
  List<String> get cockpitAssetPaths {
    switch (_mode) {
      case TravelMode.car:
        return JourneyAssets.cockpitCar;
      case TravelMode.motorbike:
        return JourneyAssets.cockpitMotorbike;
      case TravelMode.walk:
      case TravelMode.run:
      case TravelMode.bicycle:
      case TravelMode.ship:
        return const <String>[];
    }
  }

  /// The fraction of the viewport HEIGHT the cockpit foreground occupies
  /// (measured from the bottom). journey-pov AC-5 — the pinned framing ratio
  /// (≈0.36, within the spec's 0.30–0.40 band). The upper `1 - this` of the
  /// viewport keeps the road/horizon readable above the dash/handlebar line.
  double get cockpitViewportFraction => CockpitPainter.cockpitViewportFraction;

  /// The cockpit glyph paths for the current mode that FAILED to load and are
  /// being drawn as original flat-shape fallbacks. journey-pov AC-13: empty
  /// when every cockpit glyph for the mode is present; otherwise a non-fatal
  /// degraded subset (also surfaced via [failedAssetPaths]).
  Set<String> get failedCockpitAssetPaths {
    final Set<String> failed = _sprites.failedPaths;
    return <String>{
      for (final String p in cockpitAssetPaths)
        if (failed.contains(p)) p,
    };
  }

  /// The current far-background theme index, cycled by SCROLL PHASE ONLY
  /// (journey-scene-art-v3 / AC-5): `0` = highland (mountains+hills), `1` =
  /// beach/coast. Read-only test seam for TC-305 — assert the beach theme is
  /// reachable purely from the scroll phase and that varying mock activity /
  /// mode / time inputs does not change which theme appears (only scroll does).
  int get backdropThemeIndex =>
      RoadPainter.backdropThemeIndexFor(_motion.offset);

  /// Whether the beach/coast backdrop band is the active theme for the current
  /// scroll phase. journey-scene-art-v3 / AC-5 test seam.
  bool get isBeachBackdropActive => backdropThemeIndex == 1;

  /// The applied cockpit ROLL angle (radians, signed INTO the turn) for the
  /// current frame. journey-cockpit-lean — the HEADLINE read-only seam the
  /// AC-1..AC-8 suite asserts against. Properties guaranteed:
  ///  * **Signed into the turn** (AC-1): `sign` is a fixed function of
  ///    `sign(RoadGeometry.lateralSlopeAt(worldAtCamera))` — see
  ///    [leanSignConvention]. A left bend leans left, a right bend right.
  ///  * **Monotonic in |curve| up to the clamp** (AC-2) and **bounded** by
  ///    [maxLeanRadians] (AC-3).
  ///  * **Eased / low-pass** (AC-4) and a **pure deterministic function of the
  ///    smoothed scroll-phase history** (AC-5) — no clock, no `Random`.
  ///  * **Hard zero** when [reduceMotion] (AC-6) and when the mode is NOT a
  ///    cockpit mode (AC-8) — enforced HERE so it is exact from the very first
  ///    frame and the instant after [applyState], not only after the next
  ///    `update`. On a straight road the smoothed follow settles to `0.0`
  ///    (AC-7).
  ///
  /// READ-ONLY test seam — do NOT drive state with it.
  double get appliedLeanAngle {
    if (_reduceMotion) {
      return 0.0; // AC-6 hard zero from the first frame.
    }
    if (_mode != TravelMode.car && _mode != TravelMode.motorbike) {
      return 0.0; // AC-8: no cockpit to tilt.
    }
    return _appliedLean;
  }

  /// The RAW (pre-smoothing, pre-ease) target roll angle for the current scroll
  /// phase — the clamped `leanSignConvention · leanGain · lateralSlopeAt`
  /// BEFORE the low-pass follow. journey-cockpit-lean AC-2/AC-3 companion seam:
  /// lets the monotonicity-vs-`|curveSample|` and clamp-ceiling assertions read
  /// the target directly (the settled [appliedLeanAngle] converges to this), so
  /// they need not wait for the smoothing transient. Same hard-zero gates as
  /// [appliedLeanAngle] (AC-6/AC-8). READ-ONLY test seam.
  double get rawLeanTargetAngle {
    if (_reduceMotion) {
      return 0.0;
    }
    if (_mode != TravelMode.car && _mode != TravelMode.motorbike) {
      return 0.0;
    }
    final double worldAtCam = _painter.worldAtCamera(_motion.offset);
    final double slope = _sharedGeometry.lateralSlopeAt(worldAtCam);
    final double target = leanSignConvention * leanGain * slope;
    if (target > maxLeanRadians) {
      return maxLeanRadians;
    }
    if (target < -maxLeanRadians) {
      return -maxLeanRadians;
    }
    return target;
  }

  /// The distinct scenery kinds that have appeared in the live pool — the test
  /// seam for "richer scenery set is exercised" (AC-8). (TC-009.)
  Set<SideObjectKind> get liveSideObjectKinds {
    final Set<SideObjectKind> out = <SideObjectKind>{};
    for (final SideObject o in _pool.slots) {
      if (o.active) {
        out.add(o.kind);
      }
    }
    return out;
  }

  // --- Minimal allocation-free sine (Bhaskara I approximation) ---
  // Avoids importing dart:math just for a cosmetic bob and keeps the hot path
  // allocation-free. Accuracy is ample for a visual bob.
  double _fastSin(double x) {
    const double twoPi = 6.28318530718;
    const double pi = 3.14159265359;
    // Wrap into [-pi, pi].
    double v = x % twoPi;
    if (v > pi) {
      v -= twoPi;
    } else if (v < -pi) {
      v += twoPi;
    }
    // Bhaskara I: sin(x) ≈ 16x(pi-x) / (5pi^2 - 4x(pi-x)) for x in [0, pi].
    final double sign = v < 0 ? -1.0 : 1.0;
    final double a = v.abs();
    final double num = 16.0 * a * (pi - a);
    final double den = 5.0 * pi * pi - 4.0 * a * (pi - a);
    return sign * (num / den);
  }
}
