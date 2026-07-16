/// Domain layer — pure, framework-free Dart. No `flutter`, no `flame`, no real
/// `Timer`, and no `DateTime.now()` (the clock is injected). Deterministic and
/// fully unit-testable by feeding scripted ticks (Determinism NFR / AC-7/AC-12).
library;

import '../../activity/domain/activity_plugin.dart';
import 'activity_segment.dart';
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
///
/// ## idle-accounting (Option B + activity segments)
///
/// This slice layers two additions onto the rules above **without changing the
/// resolved whole-tick classification or the `rawActiveTime`-during-grace rule**
/// (idle-accounting Decisions (a)/(b)):
///
/// - **Option B — whole-tick + state-change timestamp.** Whole-tick accounting
///   is unchanged and is the **sole** source of truth for the daily counters.
///   Accounting always reads [idleTimeToday]; the UI also reads that same value,
///   so the two can never diverge (AC-2 divergence 0). Additionally the engine
///   stamps the instant the *displayed* `state` flips **Active→Idle/Paused**
///   ([idleSince]) — a display/forward-contract anchor only. [idleSince] does
///   **not** drive accounting and never feeds back into the counters; it exists
///   so a later reader can render "idle from that moment" consistently with
///   [idleTimeToday]. (Decision (b).)
/// - **Idle onset (Decision (d)).** Voluntary idle onset = the band crossing
///   `s > G`. Lock/sleep onset = the lock/sleep **instant** (immediate, overrides
///   grace). Grace already credited as travel is **never** retro-converted to
///   idle (grace-stays-travel preserved).
/// - **Activity segments (Decision (c)).** An ordered, contiguous, gap-free list
///   of [ActivitySegment]s keyed by **distance-along-route**, recording each
///   span's classification (active/idle) and cause (voluntary / lockSleep). The
///   list is **growth-bounded** by merging consecutive same-classification,
///   same-cause ticks into the open segment, **split at the local-midnight
///   rollover** so each day's idle stays correct **to within one tick** (the
///   crossing tick is not sub-split at the true 00:00 instant — its whole delta
///   lands in day N+1; see [_rolloverIfNewDay]), and **persisted** via the
///   repository seam ([toProgress]/[restore]). It is the contract for the #7
///   `map-experience` red overlay.
///
/// **Honesty invariant (hard, AC-1/AC-2).** Segment recording and the idle stamp
/// are bookkeeping only — they never change `distanceKm`/`activeTimeToday`/
/// `rawActiveTime`. Active/journey time is never over-credited; the ≤ one-tick
/// residue Option B accepts always favours idle.
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

  /// **Test-only fallback** virtual rate (km per active hour). This is NOT the
  /// shipped pacing: production injects `kmPerActiveHour` via the constructor as
  /// `vietnamProvinceChain.totalChainKm / 8` (province-chain-2026 / AC-4 — the
  /// 34-unit great-circle total ÷ ~8 active hours, ≈395 km/h, not this literal).
  /// The value 250 is retained only as a sensible standalone default for tests
  /// that construct the engine without wiring the chain; it corresponds to the
  /// retired stylized 2000 km ÷ 8 premise and must never be relied on as the
  /// production rate.
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

  /// The ordered activity-segment record (idle-accounting Decision (c)). The
  /// last element is the *open* segment that the current tick extends; a
  /// classification/cause change appends a new open segment.
  final List<ActivitySegment> _segments = <ActivitySegment>[];

  /// Option B state-change stamp: the clock instant the displayed `state` last
  /// flipped **Active→Idle/Paused** (`null` while travelling or before any idle
  /// onset). This is the display / forward-contract anchor consumed later by the
  /// #7 map-experience reader (AC-2 / Decision (b)/(d)); it does **not** drive
  /// accounting — the counters read [idleTimeToday]. Bookkeeping only: it never
  /// alters `_distanceKm`/`_activeTimeToday`/`_rawActiveTime`, and is never an
  /// independent accumulator that could diverge. Stamped at the *onset* instant
  /// (start of the triggering tick) so `_clock.now() - _idleSince` tracks the
  /// idle stretch's accrued wall-time. Not persisted (see S-3 note in
  /// [_recordIdleTick]).
  DateTime? _idleSince;

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

  /// The ordered activity-segment record for today (idle-accounting Decision
  /// (c)). Read-only snapshot — contiguous, gap-free, distance-keyed, merged,
  /// day-split. The contract consumed by `map-experience` (#7). Returns an
  /// unmodifiable view so callers can't corrupt the engine's record.
  List<ActivitySegment> get segments =>
      List<ActivitySegment>.unmodifiable(_segments);

  /// Option B: the clock instant the displayed state last flipped
  /// **Active→Idle/Paused**, or `null` while travelling (or before any idle
  /// onset). This is the display / forward-contract anchor (consumed later by
  /// #7 map-experience) so a reader can render "idle for …" consistently with
  /// [idleTimeToday] (AC-2 / Decision (b)/(d)). It does **not** drive accounting —
  /// the counters read [idleTimeToday]; this is the honest onset anchor only.
  DateTime? get idleSince => _idleSince;

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
    // The day-boundary check runs first (even for a non-positive delta) so a
    // restored/long-gap tick still rolls the day. The rollover SPLITS the open
    // segment at midnight (Decision (c) / TC-117) before this tick accrues.
    _rolloverIfNewDay(_clock.now());

    // NFR-2 / TC-113: a non-positive delta (clock step-back / NTP skew) is
    // clamped to zero — no accrual, no state change, AND no segment is opened,
    // closed, or shifted. The guard returns BEFORE any segment mutation so the
    // record is byte-identical before and after.
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
      // Cause = lockSleep ONLY when lock/sleep is the reason (it overrides grace
      // and any voluntary ramp). A plain over-threshold idle with no lock/sleep
      // is still a voluntary ramp (Decision (d)).
      final cause = (screenLocked || sleepInferred)
          ? SegmentCause.lockSleep
          : SegmentCause.voluntary;
      _recordIdleTick(delta, cause);
      return;
    }

    // Idle (stopped): past grace G but within threshold T (empty when G == T).
    if (idle > grace) {
      _idleTimeToday += delta;
      _state = JourneyState.idle;
      // Reaching the idle band via rising idle-seconds (no lock/sleep) is the
      // voluntary ramp — onset is this `s > G` band crossing (Decision (d)).
      _recordIdleTick(delta, SegmentCause.voluntary);
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
    // Travelling clears the idle anchor; grace counts as active/travel for the
    // segment record (grace-stays-travel). The segment span uses the *credited*
    // delta so its duration matches the accrued journey time (a clamped over-
    // sized tick records the clamped span, not the raw delta).
    _idleSince = null;
    _recordActiveTick(credited);
  }

  // --- Activity-segment recording (idle-accounting Decision (c)) -----------

  /// Records an **active/travel** span of [credited] wall-time ending at the
  /// current cumulative [distanceKm]. Merges into the open segment when it is
  /// already active; otherwise appends a new active segment whose `fromKm` is
  /// the distance at the span's start (so segments are contiguous and
  /// gap-free).
  void _recordActiveTick(Duration credited) {
    _appendOrExtend(
      newToKm: _distanceKm,
      extraElapsed: credited,
      classification: SegmentClassification.active,
      cause: SegmentCause.none,
    );
  }

  /// Records an **idle** span of [delta] wall-time. Idle accrues no distance, so
  /// the span's `from`/`to` are both the current [distanceKm]. Sets/keeps the
  /// Option B idle stamp ([_idleSince]) at the *onset* instant — the moment the
  /// state first flipped to idle/paused (the `s > G` crossing for voluntary, the
  /// lock/sleep instant for forced) — not on every subsequent idle tick.
  ///
  /// The onset instant is the **start** of this triggering tick, i.e.
  /// `_clock.now().subtract(delta)`: the caller advanced the clock by [delta] *before*
  /// calling [tick], so `_clock.now()` is the END of the tick; subtracting
  /// [delta] recovers the instant the state actually flipped. Stamping the end
  /// would over-state idle onset by one tick. This keeps `idleSince` consistent
  /// with [idleTimeToday]: for one continuous idle stretch, at every tick
  /// boundary `_clock.now() - _idleSince` equals the idle wall-time accrued in
  /// that stretch (each subsequent idle tick adds the same `delta` to both
  /// `_clock.now()` and `idleTimeToday`, leaving the difference invariant).
  ///
  /// Both onset causes anchor here at the start of their triggering tick: the
  /// voluntary `s > G` band crossing and the lock/sleep detection tick. Lock and
  /// sleep are detected on the same tick they occur (overriding grace), so their
  /// onset is likewise the start of that tick.
  void _recordIdleTick(Duration delta, SegmentCause cause) {
    // NOTE (S-3, known limitation): _idleSince is in-memory only — not part of
    // JourneyProgress — so an app killed while idle and restored the same day
    // loses the onset anchor (restore() clears it). Acceptable for now because
    // idleSince has no consumer yet; persistence is tracked against the #7
    // map-experience slice, which is the first reader of this anchor.
    _idleSince ??= _clock.now().subtract(delta);
    _appendOrExtend(
      newToKm: _distanceKm,
      extraElapsed: delta,
      classification: SegmentClassification.idle,
      cause: cause,
    );
  }

  /// Extends the open segment when it has the same classification AND cause
  /// (growth bound — Decision (c) / TC-118); otherwise appends a new segment
  /// whose `fromKm` is the previous segment's `toKm` (contiguity — `seg[i].to ==
  /// seg[i+1].from`, AC-3 / TC-107). The very first segment starts at the run's
  /// distance at the span's start. A pending day boundary (set by
  /// [_rolloverIfNewDay]) forces a NEW segment even for an identical
  /// classification, so the open segment is split at midnight (TC-117).
  void _appendOrExtend({
    required double newToKm,
    required Duration extraElapsed,
    required SegmentClassification classification,
    required SegmentCause cause,
  }) {
    final splitForDay = _dayBoundaryPending;
    _dayBoundaryPending = false;

    if (_segments.isNotEmpty && !splitForDay) {
      final open = _segments.last;
      if (open.classification == classification && open.cause == cause) {
        _segments[_segments.length - 1] = open.extendedTo(
          newToKm,
          extraElapsed,
        );
        return;
      }
    }
    // First-ever segment anchors at (current distance − distance this span just
    // covered); every later segment (including a post-midnight split) anchors at
    // the previous segment's `toKm` so the record stays contiguous and gap-free.
    final fromKm = _segments.isEmpty
        ? newToKm - _kmOver(extraElapsed, classification)
        : _segments.last.toKm;
    _segments.add(
      ActivitySegment(
        fromKm: fromKm,
        toKm: newToKm,
        elapsed: extraElapsed,
        classification: classification,
        cause: cause,
      ),
    );
  }

  /// The distance covered by [elapsed] of an [active] span (0 for idle). Used
  /// only to anchor the *first* segment's `fromKm` at the run start; every
  /// later segment anchors to the previous segment's `toKm`.
  double _kmOver(Duration elapsed, SegmentClassification classification) {
    if (classification != SegmentClassification.active) {
      return 0;
    }
    return kmPerActiveHour *
        elapsed.inMicroseconds /
        Duration.microsecondsPerHour;
  }

  /// Set by [_rolloverIfNewDay] when a local-midnight crossing was just detected
  /// and there is an open segment; the next [_appendOrExtend] then forces a new
  /// segment (no cross-midnight merge) so the open span is **split** at the
  /// boundary and each day's record stays separable (Decision (c) / TC-117).
  bool _dayBoundaryPending = false;

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
    segments: List<ActivitySegment>.unmodifiable(_segments),
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
    _dayBoundaryPending = false;
    _idleSince = null;

    _segments.clear();
    if (progress.storedDate.isBefore(today)) {
      // Stored date earlier than today → a new day: reset the daily counters
      // and DROP the previous day's segment record (each day's segments belong
      // to that day; TC-117 keeps a mid-run split, this is the closed-across-
      // midnight case). distanceKm is preserved above.
      _activeTimeToday = Duration.zero;
      _rawActiveTime = Duration.zero;
      _idleTimeToday = Duration.zero;
      _state = JourneyState.paused;
    } else {
      // Same local day (or a future stored date from clock skew, treated as
      // today — TC-020/TC-115): restore the daily counters AND the segment
      // record intact, so a restart resumes contiguously (TC-119) and clock
      // skew never corrupts the segments (NFR-2 / TC-115).
      _activeTimeToday = progress.activeTimeToday;
      _rawActiveTime = progress.rawActiveTime;
      _idleTimeToday = progress.idleTimeToday;
      _state = progress.state;
      _segments.addAll(progress.segments);
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
  ///
  /// idle-accounting (Decision (c) / TC-117): on a crossing it also (1) flags a
  /// pending segment split so the open span is closed at the boundary and the
  /// next tick opens a fresh day-N+1 segment (contiguous, no cross-midnight
  /// merge), and (2) clears the Option B idle stamp so a new day's idle is
  /// anchored to its own onset, not the previous day's.
  ///
  /// S-1 (limitation): the split is at *tick granularity*, not at the true 00:00
  /// instant. A tick that straddles midnight is NOT sub-split — its entire delta
  /// is accrued into the new day (day N+1) at the next [tick], so the previous
  /// day's `idleTimeToday` is correct only **to within one tick** of the exact
  /// midnight boundary. Sub-splitting the straddling tick is deliberately not
  /// done here (non-trivial; not required by the ACs).
  void _rolloverIfNewDay(DateTime now) {
    final today = _dateOf(now);
    if (today.isAfter(_currentDay)) {
      _activeTimeToday = Duration.zero;
      _rawActiveTime = Duration.zero;
      _idleTimeToday = Duration.zero;
      _currentDay = today;
      _dayBoundaryPending = _segments.isNotEmpty;
      _idleSince = null;
    }
  }

  /// The date-only (midnight, local) part of [dateTime].
  static DateTime _dateOf(DateTime dateTime) =>
      DateTime(dateTime.year, dateTime.month, dateTime.day);
}
