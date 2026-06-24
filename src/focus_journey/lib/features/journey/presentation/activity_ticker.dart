/// App-service layer (presentation-adjacent). The periodic driver that turns
/// real elapsed time into engine ticks and republishes the result to the view.
///
/// This is the ONLY journey-view-side component allowed to touch the engine's
/// async plugin path (`tickFromPlugin`) — it is the app-service seam, NOT the
/// scene/screen (which read only `state`/`mode`/`distanceKm`). It still reads no
/// OS signal directly: the `JourneyEngine` owns the plugin and all activity
/// logic; the ticker only schedules ticks and forwards the result to the Cubit.
///
/// Per `docs/architecture/overview.md` ("Activity ticker"): each tick computes
/// `delta = clock.now() − lastTick` (NOT a fixed interval) via the injected
/// [Clock], then calls `engine.tickFromPlugin(delta)`. This keeps accrual honest
/// when the timer fires late (a slow/stalled host); the engine clamps an
/// over-sized travelling delta itself.
library;

import 'dart:async';

import '../domain/clock.dart';
import '../domain/journey_engine.dart';
import '../domain/journey_progress.dart';
import 'journey_cubit.dart';

/// Signature for the injectable periodic-timer factory, so tests can drive ticks
/// without real time (call [ActivityTicker.tickOnce] directly instead).
typedef PeriodicTimerFactory =
    Timer Function(Duration interval, void Function(Timer) callback);

/// Optional sink for diagnostic messages (e.g. the M-2 swallowed error). Kept
/// abstract so production can log and tests can assert without a real logger.
typedef TickerLog = void Function(String message);

/// Optional sink for the engine's cumulative distance after each tick. Used to
/// feed route-progress its single scalar (`distanceKm`) on the SAME cadence as
/// the journey view — WITHOUT coupling the ticker to the route feature. The
/// ticker forwards only a `double`; it imports nothing from `features/route`,
/// keeping route-progress a pure scalar-consumer (AC-16) and this ticker's
/// single responsibility (schedule ticks, republish) intact.
typedef DistanceSink = void Function(double cumulativeDistanceKm);

/// Optional sink for the engine's aggregate snapshot after each tick. Feeds the
/// local-stats slice its per-tick aggregates on the SAME cadence as the journey
/// view — WITHOUT coupling the ticker to the stats feature. Only a plain
/// [JourneyProgress] value object crosses this seam (no engine reference), so
/// the stats slice stays a pure aggregate-consumer (local-stats AC-1/TC-026),
/// exactly as `DistanceSink` keeps route-progress a pure scalar-consumer.
typedef SnapshotSink = void Function(JourneyProgress snapshot);

/// Drives [JourneyEngine.tickFromPlugin] on a periodic timer and republishes the
/// engine snapshot to [JourneyCubit].
class ActivityTicker {
  /// Creates the ticker with injected dependencies (no `new`-ing inside).
  ///
  /// [interval] is the wall-clock cadence of the timer; the *credited* delta is
  /// always the measured `clock.now() − lastTick`, never the interval, so a late
  /// fire credits the real elapsed time (overview "Activity ticker").
  /// [timerFactory] defaults to [Timer.periodic]; inject a fake in tests. [log]
  /// defaults to a no-op.
  ActivityTicker({
    required JourneyEngine engine,
    required Clock clock,
    required JourneyCubit cubit,
    Duration interval = const Duration(seconds: 1),
    PeriodicTimerFactory timerFactory = Timer.periodic,
    TickerLog? log,
    DistanceSink? onDistance,
    SnapshotSink? onSnapshot,
  }) : _engine = engine,
       _clock = clock,
       _cubit = cubit,
       _interval = interval,
       _timerFactory = timerFactory,
       _log = log ?? _noop,
       _onDistance = onDistance,
       _onSnapshot = onSnapshot;

  final JourneyEngine _engine;
  final Clock _clock;
  final JourneyCubit _cubit;
  final Duration _interval;
  final PeriodicTimerFactory _timerFactory;
  final TickerLog _log;
  final DistanceSink? _onDistance;
  final SnapshotSink? _onSnapshot;

  Timer? _timer;
  DateTime? _lastTick;

  static void _noop(String _) {}

  /// `true` while the periodic timer is running.
  bool get isRunning => _timer != null;

  /// Starts the periodic timer. Idempotent — a second call is ignored while
  /// already running. The first measured delta is taken from `start()` time.
  void start() {
    if (_timer != null) {
      return;
    }
    _lastTick = _clock.now();
    _timer = _timerFactory(_interval, (_) {
      // Fire-and-forget: the periodic callback can't be async, and a slow tick
      // must not stall the timer. Errors are handled inside tickOnce.
      unawaited(tickOnce());
    });
  }

  /// Performs exactly one tick. Exposed for deterministic tests (drive it
  /// directly, no real timer) and used internally by the periodic callback.
  ///
  /// Computes `delta = clock.now() − lastTick`, advances the engine, then
  /// republishes the snapshot to the Cubit.
  ///
  /// M-2 error policy (carried follow-up): if [JourneyEngine.tickFromPlugin]
  /// throws an [Object] (e.g. an `ActivityPluginException` because a signal is
  /// unavailable/denied), the tick is treated as paused/idle — the ticker does
  /// NOT crash and does NOT accrue bogus travel (no `engine.tick` is called with
  /// a fabricated idle value; the engine simply did not advance). We log/swallow
  /// the error, keep the timer alive, and still republish the engine's current
  /// (unchanged) snapshot so the view settles to a stopped presentation.
  Future<void> tickOnce() async {
    final DateTime now = _clock.now();
    final DateTime previous = _lastTick ?? now;
    final Duration delta = now.difference(previous);
    _lastTick = now;
    try {
      await _engine.tickFromPlugin(delta);
    } catch (error) {
      // Signal unavailable/denied (or any read failure): do not crash, do not
      // accrue bogus travel. The engine did not advance this tick. Surface a
      // diagnostic and fall through to republish the unchanged snapshot — which
      // reflects the last real state (the engine moves to paused on its own when
      // a genuine large-idle/lock reading later succeeds).
      _log('ActivityTicker: tick skipped (treated as paused): $error');
    }
    // Always republish: keeps the view in sync with the engine after each tick,
    // whether it advanced or was skipped.
    if (!_cubit.isClosed) {
      _cubit.updateFromEngine(_engine);
    }
    // Forward the cumulative distance scalar to any route-progress consumer on
    // the same cadence. Only a `double` crosses this seam — no engine reference
    // leaks to route-progress, so it stays a pure scalar-consumer (AC-16).
    _onDistance?.call(_engine.distanceKm);
    // Forward the aggregate snapshot to any stats consumer on the same cadence.
    // Only a JourneyProgress value object crosses — no engine reference leaks,
    // so the stats slice stays a pure aggregate-consumer (local-stats AC-1).
    _onSnapshot?.call(_engine.toProgress());
  }

  /// Stops the periodic timer. Safe to call when not running.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Cancels the timer and releases references. Call from the owner's dispose.
  void dispose() {
    stop();
  }
}
