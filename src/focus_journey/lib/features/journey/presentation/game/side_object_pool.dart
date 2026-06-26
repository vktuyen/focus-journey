/// Presentation layer (Flame). A bounded, recycling pool of parallax side
/// objects. Pure Dart only (no Flutter, no Bloc, no engine, no OS).
///
/// Performance contract (NFR-1 / journey-view TC-017/TC-018):
///  * Fixed capacity — [_slots] is allocated ONCE at construction; the pool
///    never grows. Off-screen objects are recycled, never re-`new`ed.
///  * The hot [advance] path performs **no heap allocations**: it mutates
///    existing slot fields in place and reuses a pre-seeded deterministic
///    sequence for re-spawn parameters (no `Random`, so it is also frame-
///    deterministic for tests/goldens).
///  * [liveCount] is the test seam for the "bounded plateau" assertion.
///
/// Depth model: each object has a normalised depth `z` in `(0, 1]` where `z→0`
/// is the far horizon (small, slow) and `z=1` is the near camera (large, fast).
/// Advancing increases `z` proportionally to the shared scroll delta, scaled by
/// the object's parallax factor, so nearer objects sweep past faster. When `z`
/// exceeds `1` the slot is recycled back to the horizon.
///
/// EVEN SPACING ALONG THE CURVE (journey-scene-v2 #12 / AC-7, intensified by
/// journey-dynamic-curve AC-5/AC-6): objects spawn on a fixed ARC-LENGTH cadence
/// ([_spawnEveryArcPx]) along the curving centre-line and each records the
/// [SideObject.spawnWorldDistance] at which it appeared. The road centre-line is
/// sampled by world distance (see `RoadGeometry`); with the journey-scene-v2
/// GENTLE bend a fixed *longitudinal* cadence kept arc-length gaps within ±20%
/// for free, but the journey-dynamic-curve SHARPER bend (≈2.25× peak slope) made
/// the arc-length contribution large enough at wide viewports to break the ±20%
/// bound (measured: ~22% at 1280px, ~41% at 1920px with a fixed longitudinal
/// cadence). So the cadence is now ARC-LENGTH-AWARE (AC-6 rework fork): each
/// frame's longitudinal scroll delta is converted to an arc-length delta via the
/// geometry's closed-form slope (`ds = √(1 + (ampPx · slope)²) · dworld`) and a
/// spawn is emitted on equal arc-length increments. This keeps consecutive
/// arc-length gaps even (±20%, AC-5) at ANY viewport width, and stays O(1) /
/// allocation-free per spawn (one `sqrt` per frame, no growing loop — NFR-1).
library;

import 'dart:math' as math;

import 'road_geometry.dart';

/// The kind of side object (selects which sprite the renderer draws). Kept as a
/// small enum so the pool carries no sprite/`Image` references itself.
///
/// journey-scene-v2 #11 / AC-8: the set is the richer cohesive scenery —
/// forest, countryside, city houses, and people — all CC0 in `assets/CREDITS.md`.
///
/// journey-scene-art-v3 / AC-3 + AC-6: the v1 four kinds (tree/house/streetLight/
/// sign — from the retired Redux + Pixel-Vehicle packs) are RETIRED in the
/// wholesale re-source; their roadside roles are covered by the forest/city/
/// countryside kinds. The net-new side-view ANIMAL kinds (water buffalo / dog /
/// chicken / bird) are ADDED here and enter the spawn rotation automatically:
/// `_spawnAtHorizon` picks `SideObjectKind.values[(s*[_kindStride]) % length]`,
/// so adding enum values auto-includes them; the fixed arc-length
/// `spawnEveryArcPx` cadence keeps the AC-7/AC-5 even-spacing guarantee intact
/// regardless of how many kinds exist.
///
/// REACHABILITY INVARIANT: every kind is reachable iff [_kindStride] is coprime
/// with `SideObjectKind.values.length` (the stride generates the full residue
/// ring mod length). The P1-dead-weight fix added 5 net-new variety kinds
/// (personWoman/personWomanWave/palm/houseGableAlt/houseSmallAlt), taking the
/// length 16 → 21. `gcd(7, 21) == 7 ≠ 1` would strand all but indices {0,7,14},
/// so the stride was changed 7 → 11; `gcd(11, 21) == 1`, restoring full
/// reachability. There is a runtime assert in [SideObjectPool] guarding this.
enum SideObjectKind {
  // --- journey-scene-v2 richer scenery (#11 / AC-8) ---
  /// Pine / conifer (highland forest).
  pine,

  /// Round broadleaf tree.
  treeRound,

  /// Tall slim tree.
  treeTall,

  /// Small sapling (near-road fill).
  sapling,

  /// Roadside bush / paddy-edge greenery.
  bush,

  /// Alternate bush shape (spacing variety).
  bushAlt,

  /// Wooden field/paddy fence.
  fence,

  /// Iron fence variant.
  fenceIron,

  /// Generic gable house (city).
  houseGable,

  /// Small house (city).
  houseSmall,

  /// Generic standing person (roadside).
  person,

  /// Waving/pointing person (roadside variety).
  personWave,

  /// Standing woman (roadside variety; P1 dead-weight fix — net-new variety).
  personWoman,

  /// Waving/pointing woman (roadside variety; P1 dead-weight fix — net-new).
  personWomanWave,

  /// Palm tree (tropical Vietnam roadside read; P1 dead-weight fix — net-new
  /// forest variety).
  palm,

  /// Alternate gable house (city; P1 dead-weight fix — net-new variety).
  houseGableAlt,

  /// Alternate small house (city; P1 dead-weight fix — net-new variety).
  houseSmallAlt,

  // --- journey-scene-art-v3 side-view animals (#/AC-6; net-new) ---
  /// Side-view water buffalo (Vietnam paddy icon).
  waterBuffalo,

  /// Side-view dog.
  dog,

  /// Side-view chicken.
  chicken,

  /// Side-view bird.
  bird,
}

/// One pooled object. Mutable struct reused across re-spawns; never discarded.
class SideObject {
  /// Whether this slot currently holds a live (renderable) object.
  bool active = false;

  /// Normalised depth in `(0, 1]`; `0`→horizon, `1`→near camera.
  double z = 0;

  /// `-1` = left verge, `1` = right verge. Horizontal side of the road.
  double side = 1;

  /// Lateral spread from the road edge (0 = at the edge, 1 = far out).
  double lateral = 0;

  /// Per-object depth speed multiplier (parallax). Slight variation keeps the
  /// stream from looking lock-stepped.
  double parallax = 1;

  /// Which sprite to draw.
  SideObjectKind kind = SideObjectKind.pine;

  /// World distance (logical px) at which this object spawned at the horizon.
  /// journey-scene-v2 #12 / AC-7: the spacing test reads consecutive objects'
  /// spawn distances to verify even arc-length gaps along the curving road.
  double spawnWorldDistance = 0;
}

/// Fixed-capacity recycling pool of [SideObject]s.
class SideObjectPool {
  /// Creates a pool with [capacity] reusable slots, all allocated up front.
  ///
  /// [spawnEveryArcPx] is the target ARC-LENGTH gap (logical px along the
  /// curving centre-line) between consecutive spawns (journey-scene-v2 #12 /
  /// AC-7 + journey-dynamic-curve AC-5/AC-6 even spacing). On a straight road
  /// this equals the longitudinal gap; on the sharper bend the longitudinal gap
  /// shrinks where the road leans so the arc-length gap stays constant.
  /// [depthGain] converts a world-px scroll delta into a normalised-depth step.
  /// [geometry] is the centre-line model whose closed-form slope drives the
  /// arc-length conversion; defaults to a fresh model with production params.
  SideObjectPool({
    this.capacity = 24,
    double spawnEveryArcPx = 220.0,
    double depthGain = 0.0009,
    RoadGeometry? geometry,
  }) : _spawnEveryArcPx = spawnEveryArcPx,
       _depthGain = depthGain,
       _geometry = geometry ?? RoadGeometry(),
       _slots = List<SideObject>.generate(
         capacity,
         (_) => SideObject(),
         growable: false,
       ) {
    assert(capacity > 0, 'capacity must be positive');
    assert(spawnEveryArcPx > 0, 'spawnEveryArcPx must be positive');
    // REACHABILITY GUARD: the kind cycle SideObjectKind.values[(s*stride)%len]
    // visits every kind iff gcd(stride, len) == 1. If a future enum edit makes
    // the length share a factor with _kindStride, some kinds become dead — fail
    // loudly in debug rather than silently dropping scenery variety.
    assert(
      _gcd(_kindStride, SideObjectKind.values.length) == 1,
      'kind stride $_kindStride must be coprime with '
      '${SideObjectKind.values.length} so every SideObjectKind is reachable',
    );
  }

  /// Stride used to cycle through [SideObjectKind.values] on spawn. Must be
  /// coprime with `SideObjectKind.values.length` (asserted) so every kind is
  /// reachable. Currently 11 with 21 kinds (`gcd(11, 21) == 1`). Was 7, but the
  /// P1 dead-weight fix grew the enum 16 → 21 and `gcd(7, 21) == 7` would have
  /// stranded all but 3 kinds.
  static const int _kindStride = 11;

  static int _gcd(int a, int b) {
    while (b != 0) {
      final int t = b;
      b = a % b;
      a = t;
    }
    return a;
  }

  /// Total reusable slots; the live count can never exceed this.
  final int capacity;

  final double _spawnEveryArcPx;
  final double _depthGain;
  final RoadGeometry _geometry;
  final List<SideObject> _slots;

  // Deterministic, allocation-free pseudo-sequence for spawn variety.
  int _seq = 0;
  // Total world distance travelled (logical px) — the world-distance each
  // object records on spawn (its fixed longitudinal position on the road).
  double _worldDistance = 0;
  // Accumulated ARC LENGTH travelled along the curving centre-line (logical
  // px). The spawn-cadence clock: a spawn fires each time this crosses the next
  // arc-length milestone. Grows faster than _worldDistance where the road leans.
  double _arcDistance = 0;
  // Arc length at which the next object should spawn.
  double _nextSpawnAtArc = 0;
  // The near-camera curve amplitude (logical px) of the LAST advance — the live
  // viewport's `width × RoadPainter.curveAmplitudeFrac`, supplied each frame so
  // the arc-length conversion matches the amplitude the scene actually renders
  // (and the AC-5 measurement uses). Defaults to 0 (straight) until first fed.
  double _curveAmpPx = 0;

  /// Read-only view of all slots (live and free) for the renderer to iterate.
  /// The renderer must skip slots where `active == false`. No allocation.
  List<SideObject> get slots => _slots;

  /// The total world distance accumulated (logical px). Test seam.
  double get worldDistance => _worldDistance;

  /// The target ARC-LENGTH gap (logical px along the curving centre-line)
  /// between consecutive spawns. Test seam for the even-spacing assertion
  /// (AC-5/AC-6): consecutive arc-length gaps cluster around this value.
  double get spawnEveryArcPx => _spawnEveryArcPx;

  /// Backward-compatible alias retained for existing journey-scene-v2 seams.
  /// On the straight road the longitudinal and arc-length cadence coincide; on
  /// the sharper bend this is the ARC-LENGTH target (see [spawnEveryArcPx]).
  double get spawnEveryWorldPx => _spawnEveryArcPx;

  /// Number of currently live objects. Test seam for the bounded-plateau check
  /// (TC-017): this must plateau at or below [capacity], never grow unbounded.
  int get liveCount {
    int n = 0;
    for (final SideObject o in _slots) {
      if (o.active) {
        n++;
      }
    }
    return n;
  }

  /// Advances all live objects by the shared scroll delta [scrollDelta]
  /// (logical px this frame, already eased), recycling any that pass the
  /// camera and spawning new ones at the horizon on a fixed ARC-LENGTH cadence
  /// along the curving centre-line (so arc-length spacing stays even at ANY
  /// curvature / viewport — AC-5/AC-6).
  ///
  /// [curveAmpPx] is the live near-camera curve amplitude in logical px
  /// (`viewport.width × RoadPainter.curveAmplitudeFrac`), supplied each frame so
  /// the arc-length conversion uses the SAME amplitude the scene renders (and
  /// the AC-5 measurement reads). `0` (the default) ⇒ a straight road, in which
  /// case arc length equals longitudinal distance (graceful before first size).
  ///
  /// [scrollDelta] is `0` when the scene is stopped, so the whole field is
  /// frozen when stopped (single-source-of-truth). No allocations; O(1) per
  /// frame (one closed-form slope + one `sqrt`), no growing loop (NFR-1).
  void advance(double scrollDelta, {double curveAmpPx = 0}) {
    if (scrollDelta <= 0) {
      return;
    }
    _curveAmpPx = curveAmpPx;
    // Convert this frame's longitudinal scroll delta into an ARC-LENGTH delta
    // along the curving centre-line: ds = √(1 + (ampPx · dLat/dworld)²) · dworld,
    // evaluated with the geometry's closed-form slope at the current world
    // distance. Constant cost; no allocation.
    final double slope = _geometry.lateralSlopeAt(_worldDistance);
    final double latRate = _curveAmpPx * slope;
    final double arcFactor = math.sqrt(1.0 + latRate * latRate);
    _worldDistance += scrollDelta;
    _arcDistance += scrollDelta * arcFactor;

    final double depthStep = scrollDelta * _depthGain;
    for (final SideObject o in _slots) {
      if (!o.active) {
        continue;
      }
      o.z += depthStep * o.parallax;
      if (o.z > 1.0) {
        o.active = false; // recycle: slot returns to the free set.
      }
    }
    // Spawn on the fixed ARC-LENGTH cadence so spawn-to-spawn arc-length gaps
    // along the curve are even (AC-5), independent of how hard the road leans.
    while (_arcDistance >= _nextSpawnAtArc) {
      _spawnAtHorizon(_worldDistance);
      _nextSpawnAtArc += _spawnEveryArcPx;
    }
  }

  /// Reactivates a free slot at the horizon with deterministic varied params.
  /// No allocation — mutates an existing slot in place. If the pool is full
  /// (all slots live) it simply skips, keeping the count bounded.
  void _spawnAtHorizon(double atWorldDistance) {
    final SideObject? slot = _firstFree();
    if (slot == null) {
      return; // bounded: never exceed capacity.
    }
    final int s = _seq++;
    slot.active = true;
    slot.z = 0.04; // just past the horizon line
    slot.side = (s & 1) == 0 ? -1.0 : 1.0;
    slot.lateral = ((s * 37) % 100) / 100.0 * 0.6; // 0..0.6 spread
    slot.parallax = 0.85 + (((s * 53) % 30) / 100.0); // 0.85..1.15
    slot.kind =
        SideObjectKind.values[(s * _kindStride) % SideObjectKind.values.length];
    slot.spawnWorldDistance = atWorldDistance;
  }

  SideObject? _firstFree() {
    for (final SideObject o in _slots) {
      if (!o.active) {
        return o;
      }
    }
    return null;
  }

  /// Clears all live objects (parked/first-frame default, test isolation).
  void reset() {
    for (final SideObject o in _slots) {
      o.active = false;
    }
    _seq = 0;
    _worldDistance = 0;
    _arcDistance = 0;
    _nextSpawnAtArc = 0;
    _curveAmpPx = 0;
  }
}
