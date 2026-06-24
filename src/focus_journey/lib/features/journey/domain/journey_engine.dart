/// Domain layer — pure, framework-free Dart. No `flutter`, no `flame`, no real
/// `Timer`, and no `DateTime.now()` (the clock is injected). Deterministic and
/// fully unit-testable by feeding scripted ticks (Determinism NFR / AC-7/AC-12).
library;

import '../../activity/domain/activity_plugin.dart';
import 'clock.dart';
import 'journey_progress.dart';
import 'journey_repository.dart';
import 'journey_state.dart';
import 'travel_mode.dart';

/// The core loop that converts genuine focus time into honest distance.
///
/// ## Design choices (cite spec open questions)
///
/// - **Synchronous-snapshot tick (chosen form).** `tick` takes the current
///   signal as a *snapshot* (`idleSeconds` + `screenLocked`) rather than awaiting
///   [ActivityPlugin] itself. This keeps the engine pure, synchronous, and
///   trivially deterministic — a test feeds a deterministic tick sequence with no
///   async. The app-layer ticker (OUT OF SCOPE here) reads the plugin and passes
///   the snapshot. A convenience [tickFromPlugin] is provided for that wiring.
/// - **`kmPerActiveHour` seam (spec open item).** Taken as **injected config**;
///   its numeric source of truth is `route-progress` (chain length ÷ ~8 active
///   hours ⇒ ~250 virtual km/h, plan §11). No magic number is baked in — the
///   constructor takes it with a documented default ([defaultKmPerActiveHour]).
/// - **Whole-tick `rawActiveTime` (spec open item, confirm-pending).** The engine
///   sees only aggregate idle-seconds, not discrete input events, so it classifies
///   an **entire** tick from the idle reading at tick time. `rawActiveTime` accrues
///   **only** on active ticks (idle ≤ `F`), never during grace (AC-2/AC-4).
/// - **Non-positive / backwards delta (spec open item).** A `delta <= 0` (clock
///   skew / NTP step-back) is **ignored** — no accrual, no state change, never a
///   negative or bogus value; the engine stays usable for later positive ticks
///   (TC-019).
/// - **Sleep inference keys on the IDLE signal, not `delta` (no sleep boolean, AC-8).**
///   A tick is treated as sleep/paused — and therefore never travel — when its
///   `idleSeconds` reading is at/above [sleepIdleThreshold] (or simply beyond the
///   threshold `T`), or the screen is locked. A large `delta` **alone** is NOT
///   sleep: a stalled/slow app-layer ticker can produce a large `delta` while the
///   user is genuinely active (`idleSeconds ≈ 0`), and dumping that gap to idle
///   would silently discard real travel — the opposite of the honesty promise. A
///   real sleep/wake always produces a large idle reading (upstream
///   `activity_plugin.dart` / activity-detection AC-9 guarantees idle is large
///   after wake), so keying on idle alone still satisfies TC-007 (large idle inside
///   grace ⇒ non-travel) and TC-008 (large delta AND large idle ⇒ idle wins).
///   Sleep maps to the `paused` state and accrues `idleTimeToday` only.
/// - **Over-sized travelling tick is clamped, never discarded ([maxTickDelta]).**
///   To prevent the opposite failure — a stalled ticker over-crediting on resume —
///   when a tick classifies as travelling (active or grace) but its `delta` exceeds
///   [maxTickDelta] (the max-plausible span a single tick may credit), the accrued
///   delta is **clamped** to [maxTickDelta] rather than discarded. So neither real
///   work is lost nor a stall over-credits.
/// - **Day-boundary reset (AC-9).** The engine owns no timer; it detects a local
///   midnight crossing only **on the next tick** (and on [restore]) by comparing
///   the injected clock's local date to the stored `currentDay`. On a new day the
///   three daily counters reset to zero; cumulative `distanceKm` is preserved
///   (TC-016).
class JourneyEngine {
  /// Creates the engine with injected dependencies and config.
  ///
  /// [grace] (`G`) and [threshold] (`T`) are the two independent knobs with the
  /// invariant `G <= T`. Default `G = T = 5 min` reproduces the epic's
  /// "travel until 5 min, then stop+pause" (the `(G, T]` idle band is then empty,
  /// TC-010). [activeFloor] (`F`) is the small idle ceiling below which a tick is
  /// genuine recent input (the *active* band); it must be `< G`.
  ///
  /// Construction fails loudly (throws [ArgumentError]) on misconfigured wiring —
  /// `kmPerActiveHour <= 0`, `grace > threshold`, or `activeFloor >= grace` — so a
  /// bad injection surfaces even in release builds, not just behind `assert`.
  JourneyEngine({
    required Clock clock,
    required ActivityPlugin activityPlugin,
    this.kmPerActiveHour = defaultKmPerActiveHour,
    this.grace = const Duration(minutes: 5),
    this.threshold = const Duration(minutes: 5),
    this.activeFloor = const Duration(seconds: 5),
    Duration? maxTickDelta,
    Duration? sleepIdleThreshold,
    this.mode = TravelMode.motorbike,
  }) : _clock = clock,
       _activityPlugin = activityPlugin,
       maxTickDelta =
           maxTickDelta ?? threshold * _defaultMaxTickDeltaMultiplier,
       sleepIdleThreshold =
           sleepIdleThreshold ?? threshold * _defaultSleepIdleMultiplier {
    if (kmPerActiveHour <= 0) {
      throw ArgumentError.value(
        kmPerActiveHour,
        'kmPerActiveHour',
        'must be > 0',
      );
    }
    if (grace > threshold) {
      throw ArgumentError.value(
        grace,
        'grace',
        'invariant G <= T violated (grace > threshold)',
      );
    }
    if (activeFloor >= grace) {
      throw ArgumentError.value(
        activeFloor,
        'activeFloor',
        'active floor F must be smaller than grace G',
      );
    }
    _currentDay = _dateOf(_clock.now());
  }

  /// Default virtual rate (km per active hour). Sized so the ~2,000 km Vietnam
  /// chain is crossed in ~8 active hours (plan §11). The authoritative number is
  /// owned by `route-progress`; this is only a sensible standalone default and is
  /// expected to be overridden via the constructor when the two slices are wired.
  static const double defaultKmPerActiveHour = 250;

  /// `maxTickDelta` defaults to this multiple of `T` when not supplied.
  static const int _defaultMaxTickDeltaMultiplier = 2;

  /// `sleepIdleThreshold` defaults to this multiple of `T` when not supplied.
  static const int _defaultSleepIdleMultiplier = 2;

  final Clock _clock;
  final ActivityPlugin _activityPlugin;

  /// Single shared virtual rate for all modes in v1 (speed-only, AC-1/AC-13).
  final double kmPerActiveHour;

  /// Grace window `G`: idle up to this still earns travel (AC-4).
  final Duration grace;

  /// Idle threshold `T` (`>= G`): only flips `idle` → `paused` (AC-16).
  final Duration threshold;

  /// Active floor `F`: idle at/below this is genuine input (the *active* band).
  final Duration activeFloor;

  /// The max-plausible span a single travelling tick may credit. Sleep is NOT
  /// detected from `delta` — it is detected from the idle counter ([sleepIdleThreshold]
  /// / `T` / lock). This knob is purely an **accrual clamp**: when a tick classifies
  /// as travelling (active/grace) but its `delta` exceeds this, the accrued delta is
  /// clamped to this value instead of being lost — so neither real work is discarded
  /// (the failure of keying sleep on a large `delta`) nor a stalled ticker
  /// over-credits on resume (default `2 × T`, AC-8).
  final Duration maxTickDelta;

  /// An `idleSeconds` reading at/above this is treated as sleep → never travel
  /// (AC-8). Reflects "large idle after wake" from `activity-detection` AC-9.
  final Duration sleepIdleThreshold;

  // --- Exposed state (read-only to callers) -------------------------------

  double _distanceKm = 0;
  Duration _activeTimeToday = Duration.zero;
  Duration _rawActiveTime = Duration.zero;
  Duration _idleTimeToday = Duration.zero;
  JourneyState _state = JourneyState.paused;
  late DateTime _currentDay;

  /// The cosmetic travel skin. Settable; does not affect accrual in v1 (AC-13).
  TravelMode mode;

  /// Cumulative distance travelled (km). Preserved across day boundaries.
  double get distanceKm => _distanceKm;

  /// Journey time for today, **including** grace (drives distance; AC-2).
  Duration get activeTimeToday => _activeTimeToday;

  /// True input time for today, **excluding** grace — the streak-qualifying
  /// metric (AC-2/AC-15). Always `<= activeTimeToday`.
  Duration get rawActiveTime => _rawActiveTime;

  /// Idle/paused time accrued today.
  Duration get idleTimeToday => _idleTimeToday;

  /// The traveller's current motion state.
  JourneyState get state => _state;

  /// The local calendar date (date-only) the daily counters belong to.
  DateTime get currentDay => _currentDay;

  // --- Core loop ----------------------------------------------------------

  /// Advances the engine by [delta] (real elapsed since the last tick, supplied
  /// by the caller — AC-7) using a *snapshot* of the current signal: [idleSeconds]
  /// (aggregate seconds since last input) and [screenLocked].
  ///
  /// Order of operations (load-bearing):
  /// 1. **Day-boundary check** against the injected clock (AC-9). This runs even
  ///    for a non-positive delta so a restored/long-gap tick still rolls the day.
  /// 2. **Non-positive delta guard** — `delta <= 0` is ignored after the day
  ///    check; nothing accrues (TC-019).
  /// 3. **Classify the whole tick** into one band and accrue accordingly. Lock
  ///    and sleep-inference override the grace immediately (AC-6/AC-8). Grace
  ///    already credited is never rolled back (AC-14) — classification is
  ///    per-tick with no rollback buffer.
  void tick(
    Duration delta, {
    required int idleSeconds,
    required bool screenLocked,
  }) {
    _rolloverIfNewDay(_clock.now());

    if (delta <= Duration.zero) {
      return;
    }

    final idle = Duration(seconds: idleSeconds);
    // Sleep/paused is inferred from the IDLE signal only — never from `delta`
    // alone. A real sleep/wake always returns a large idle reading (upstream
    // guarantee, activity-detection AC-9), so this still catches TC-007/TC-008; a
    // large `delta` with a small idle (a stalled ticker while genuinely active) is
    // NOT sleep and is instead credited as travel, clamped to [maxTickDelta] below.
    final sleepInferred = idle >= sleepIdleThreshold;

    // Paused: past threshold T, or locked, or sleep-inferred (large idle).
    if (screenLocked || sleepInferred || idle > threshold) {
      _idleTimeToday += delta;
      _state = JourneyState.paused;
      return;
    }

    // Idle (stopped): past grace G but within threshold T (empty when G == T).
    if (idle > grace) {
      _idleTimeToday += delta;
      _state = JourneyState.idle;
      return;
    }

    // Travelling: active (idle <= F) or grace (F < idle <= G), unlocked. Clamp an
    // over-sized tick's accrual to maxTickDelta so a stalled/slow ticker resuming
    // with a huge delta can't over-credit (the converse of discarding real work).
    final credited = delta > maxTickDelta ? maxTickDelta : delta;
    _distanceKm +=
        kmPerActiveHour *
        credited.inMicroseconds /
        Duration.microsecondsPerHour;
    _activeTimeToday += credited;
    if (idle <= activeFloor) {
      // Active band only: genuine recent input contributes to raw active time.
      _rawActiveTime += credited;
    }
    _state = JourneyState.active;
  }

  /// Convenience for the app-layer ticker: reads the snapshot from the injected
  /// [ActivityPlugin] and forwards to [tick]. Kept thin and async so the engine
  /// core stays synchronous/deterministic. Tests drive [tick] directly.
  Future<void> tickFromPlugin(Duration delta) async {
    final idleSeconds = await _activityPlugin.getSystemIdleSeconds();
    final screenLocked = await _activityPlugin.isScreenLocked();
    tick(delta, idleSeconds: idleSeconds, screenLocked: screenLocked);
  }

  // --- Persistence (AC-9/AC-10/AC-11) -------------------------------------

  /// The current state as a persistable snapshot (privacy: aggregate counters +
  /// position + date only — no raw signals).
  JourneyProgress toProgress() => JourneyProgress(
    distanceKm: _distanceKm,
    activeTimeToday: _activeTimeToday,
    rawActiveTime: _rawActiveTime,
    idleTimeToday: _idleTimeToday,
    state: _state,
    mode: mode,
    storedDate: _currentDay,
  );

  /// Persists the current snapshot via the injected [repository] (AC-11).
  Future<void> save(JourneyRepository repository) =>
      repository.save(toProgress());

  /// Restores state from [progress], applying the same day-boundary rule as the
  /// tick path:
  /// - stored date **earlier** than today → reset the three daily counters,
  ///   preserve `distanceKm`, do not reconstruct the gap (AC-10 / TC-017);
  /// - stored date **today or in the future** → restore the daily counters as-is
  ///   (a future stored date from clock skew is treated as "today", no reset —
  ///   TC-020).
  void restore(JourneyProgress progress) {
    final today = _dateOf(_clock.now());
    _distanceKm = progress.distanceKm;
    mode = progress.mode;
    _currentDay = today;

    if (progress.storedDate.isBefore(today)) {
      _activeTimeToday = Duration.zero;
      _rawActiveTime = Duration.zero;
      _idleTimeToday = Duration.zero;
      _state = JourneyState.paused;
    } else {
      _activeTimeToday = progress.activeTimeToday;
      _rawActiveTime = progress.rawActiveTime;
      _idleTimeToday = progress.idleTimeToday;
      _state = progress.state;
    }
  }

  /// Loads the last snapshot from [repository] and [restore]s it. No-op (keeps a
  /// fresh zero state) when nothing has been persisted yet.
  Future<void> loadAndRestore(JourneyRepository repository) async {
    final progress = await repository.load();
    if (progress != null) {
      restore(progress);
    }
  }

  // --- Internals ----------------------------------------------------------

  /// Resets the daily counters once when [now]'s local date is past
  /// [_currentDay]; preserves `distanceKm` (AC-9). Idempotent within a day.
  void _rolloverIfNewDay(DateTime now) {
    final today = _dateOf(now);
    if (today.isAfter(_currentDay)) {
      _activeTimeToday = Duration.zero;
      _rawActiveTime = Duration.zero;
      _idleTimeToday = Duration.zero;
      _currentDay = today;
    }
  }

  /// The date-only (midnight, local) part of [dateTime].
  static DateTime _dateOf(DateTime dateTime) =>
      DateTime(dateTime.year, dateTime.month, dateTime.day);
}
