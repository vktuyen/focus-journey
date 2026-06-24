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
import 'day_night_tint.dart';
import 'journey_assets.dart';
import 'journey_skins.dart';
import 'journey_sprites.dart';
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
  JourneyGame({
    int sideObjectCapacity = 24,
    double cruiseSpeed = 320.0,
    double easeDuration = 0.35,
  }) : _motion = SceneMotion(
         cruiseSpeed: cruiseSpeed,
         easeDuration: easeDuration,
       ),
       _pool = SideObjectPool(capacity: sideObjectCapacity);

  final SceneMotion _motion;
  final SideObjectPool _pool;
  final RoadPainter _painter = RoadPainter();
  late final JourneySprites _sprites;

  // --- Driven state (set only by applyState; defaults = parked/stopped). ---
  TravelMode _mode = TravelMode.motorbike;
  bool _reduceMotion = false;
  double _timeOfDayHours = 12.0;
  bool _hasReceivedState = false;

  // Cosmetic vehicle bob phase (advances only while visibly moving).
  double _bobPhase = 0;

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
    _pool.advance(scrollDelta);
    // Bob advances with eased velocity so it ramps in/out with motion and is
    // exactly frozen when stopped or reduce-motion (velocity == 0).
    if (_motion.velocity > 0) {
      final JourneySkin skin = JourneySkins.of(_mode);
      _bobPhase += dt * skin.bobFrequencyHz;
    }
  }

  @override
  void render(Canvas canvas) {
    final Size s = Size(size.x, size.y);
    final Color sky = DayNightTint.skyFor(_timeOfDayHours);
    _painter
      ..paintBackground(canvas, s, sky)
      ..paintRoad(canvas, s, _motion.offset)
      ..paintSideObjects(canvas, s, _pool.slots, _sprites.imageForKind)
      ..paintVehicle(canvas, s, _vehicleImage(), _bob())
      ..paintTint(canvas, s, DayNightTint.tintFor(_timeOfDayHours));
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
