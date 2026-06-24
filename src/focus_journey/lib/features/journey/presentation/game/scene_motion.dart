/// Presentation layer (Flame). The scene's motion model: binary target speed
/// with a short bounded ease. Pure Dart, frame-driven (`advance(dt)`), no
/// timers, no `DateTime.now()`. Single-purpose and fully unit-testable.
///
/// Invariants it enforces:
///  * **Binary speed (AC-7/TC-007):** the *target* velocity is exactly
///    [cruiseSpeed] while moving and exactly `0` while stopped — never
///    proportional to any engine number.
///  * **Short ease (AC-6/TC-006/TC-024):** velocity ramps toward the target
///    linearly over at most [easeDuration]; per-frame offset deltas shrink
///    monotonically while decelerating, and after the ramp motion is *exactly*
///    zero. Accelerate-from-rest is the symmetric ramp.
///  * **Reduce motion:** when enabled the offset never advances (velocity is
///    pinned to zero) so motion-sensitive users get no scroll; state is
///    conveyed by other means (vehicle pose / overlay).
library;

/// Drives a single scalar scroll `offset` from a binary moving/stopped target
/// through a capped linear ease. Reused by the road, lane markings and side
/// objects so they all share one phase and one shared speed.
class SceneMotion {
  /// Creates a motion model.
  ///
  /// [cruiseSpeed] is the single constant scroll speed (logical px/s) used
  /// while moving. [easeDuration] caps the ramp (≤ ~0.5 s per the spec).
  SceneMotion({this.cruiseSpeed = 320.0, this.easeDuration = 0.35})
    : assert(cruiseSpeed > 0, 'cruiseSpeed must be positive'),
      assert(easeDuration > 0, 'easeDuration must be positive');

  /// The one constant scroll speed while moving (logical px/s). Shared by all
  /// skins (cosmetic-only invariant).
  final double cruiseSpeed;

  /// Maximum ease ramp length in seconds (the bounded ≤ ~0.5 s deceleration /
  /// acceleration window).
  final double easeDuration;

  double _offset = 0;
  double _velocity = 0;
  bool _movingTarget = false;
  bool _reduceMotion = false;

  /// Accumulated forward scroll offset (logical px). Advances while moving,
  /// constant while stopped. Test seam for "moving vs stopped" assertions.
  double get offset => _offset;

  /// Current scroll velocity (logical px/s). `0` exactly when fully stopped;
  /// equals [cruiseSpeed] at cruise. Test seam for the ease ramp.
  double get velocity => _velocity;

  /// Whether the model is still ramping (velocity not yet at its target).
  /// Test seam: `true` only during the brief settle, `false` at rest or cruise.
  bool get isSettling => (_velocity - _targetVelocity).abs() > _epsilon;

  /// The instantaneous target velocity given the current command.
  double get _targetVelocity {
    if (_reduceMotion || !_movingTarget) {
      return 0;
    }
    return cruiseSpeed;
  }

  static const double _epsilon = 1e-9;

  /// Sets the binary command: `true` → ease toward [cruiseSpeed], `false` →
  /// ease toward zero. Idempotent; safe to call every state emission.
  void setMoving(bool moving) => _movingTarget = moving;

  /// Honour the OS reduce-motion preference. When `true`, the target velocity
  /// is pinned to zero so the offset never scrolls. The model still eases
  /// (bounded) to a stop rather than snapping, preventing a jump.
  void setReduceMotion(bool reduceMotion) => _reduceMotion = reduceMotion;

  /// Advances the model by [dt] seconds, ramping velocity toward the target at
  /// a bounded rate and integrating the offset. Per-frame offset deltas shrink
  /// monotonically while decelerating (no jank); after the ramp the offset is
  /// truly constant.
  void advance(double dt) {
    if (dt <= 0) {
      return;
    }
    final double target = _targetVelocity;
    if (_velocity != target) {
      // Capped linear ramp: cover the full speed range in at most easeDuration.
      final double maxDelta = (cruiseSpeed / easeDuration) * dt;
      final double diff = target - _velocity;
      if (diff.abs() <= maxDelta) {
        _velocity = target;
      } else {
        _velocity += maxDelta * diff.sign;
      }
      // Snap tiny residuals so a stopped scene is unambiguously zero.
      if (_velocity.abs() < _epsilon) {
        _velocity = 0;
      }
    }
    _offset += _velocity * dt;
  }

  /// Resets to the parked/stopped default (zero offset, zero velocity, not
  /// moving). Used for the first-frame default and for test isolation.
  void reset() {
    _offset = 0;
    _velocity = 0;
    _movingTarget = false;
  }
}
