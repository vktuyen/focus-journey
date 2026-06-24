/// Presentation layer (Flame). A bounded, recycling pool of parallax side
/// objects. Pure Dart + `dart:ui` only (no Flutter, no Bloc, no engine, no OS).
///
/// Performance contract (AC perf / TC-017):
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
library;

/// The kind of side object (selects which sprite the renderer draws). Kept as a
/// small enum so the pool carries no sprite/`Image` references itself.
enum SideObjectKind {
  /// Roadside tree.
  tree,

  /// Roadside house.
  house,

  /// Street light.
  streetLight,

  /// Road sign.
  sign,
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
  SideObjectKind kind = SideObjectKind.tree;
}

/// Fixed-capacity recycling pool of [SideObject]s.
class SideObjectPool {
  /// Creates a pool with [capacity] reusable slots, all allocated up front.
  SideObjectPool({this.capacity = 24, double spawnEveryDepth = 0.12})
    : _spawnEveryDepth = spawnEveryDepth,
      _slots = List<SideObject>.generate(
        capacity,
        (_) => SideObject(),
        growable: false,
      ) {
    assert(capacity > 0, 'capacity must be positive');
  }

  /// Total reusable slots; the live count can never exceed this.
  final int capacity;

  final double _spawnEveryDepth;
  final List<SideObject> _slots;

  // Deterministic, allocation-free pseudo-sequence for spawn variety.
  int _seq = 0;
  double _depthSinceSpawn = 0;

  /// Read-only view of all slots (live and free) for the renderer to iterate.
  /// The renderer must skip slots where `active == false`. No allocation.
  List<SideObject> get slots => _slots;

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
  /// camera and spawning new ones at the horizon at a steady depth cadence.
  ///
  /// [scrollDelta] is `0` when the scene is stopped, so the whole field is
  /// frozen when stopped (single-source-of-truth — AC-4). No allocations.
  void advance(double scrollDelta, {double depthGain = 0.0009}) {
    if (scrollDelta <= 0) {
      return;
    }
    final double depthStep = scrollDelta * depthGain;
    for (final SideObject o in _slots) {
      if (!o.active) {
        continue;
      }
      o.z += depthStep * o.parallax;
      if (o.z > 1.0) {
        o.active = false; // recycle: slot returns to the free set.
      }
    }
    _depthSinceSpawn += depthStep;
    while (_depthSinceSpawn >= _spawnEveryDepth) {
      _depthSinceSpawn -= _spawnEveryDepth;
      _spawnAtHorizon();
    }
  }

  /// Reactivates a free slot at the horizon with deterministic varied params.
  /// No allocation — mutates an existing slot in place. If the pool is full
  /// (all slots live) it simply skips, keeping the count bounded.
  void _spawnAtHorizon() {
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
    slot.kind = SideObjectKind.values[(s ~/ 2) % SideObjectKind.values.length];
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
    _depthSinceSpawn = 0;
  }
}
