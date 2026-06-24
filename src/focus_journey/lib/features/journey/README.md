# journey — the pure-Dart core loop (`JourneyEngine`)

Implements the **`journey-engine`** slice: the honest, deterministic core loop that turns genuine
focus time into virtual distance. Spec: [`specs/journey-engine/`](../../../../../specs/journey-engine/).

The engine is **pure, framework-free Dart** in the `domain/` layer — no `flutter`, no `flame`, no
real `Timer`, no `DateTime.now()`. The clock and the `ActivityPlugin` are constructor-injected, so it
is fully unit-testable by feeding a scripted tick sequence with no wall-clock waits (AC-7 / AC-12).

## Layers (Clean Architecture)

```
domain/   clock.dart                 injectable Clock abstraction + SystemClock (pure Dart)
          journey_state.dart         JourneyState enum (active | idle | paused)
          travel_mode.dart           TravelMode enum (cosmetic skins, AC-13)
          journey_progress.dart      equatable persistable snapshot + toJson/fromJson
          journey_repository.dart    JourneyRepository interface (persistence seam)
          journey_engine.dart        the JourneyEngine — the core loop
data/     shared_preferences_journey_repository.dart   the ONLY shared_preferences importer
```

`domain/` has zero Flutter / Flame / channel imports. The engine depends only on the `Clock` and
`ActivityPlugin` *interfaces* and the `JourneyRepository` *interface* (dependency inversion) — swapping
real ↔ mock requires no engine change.

## Two-knob band model (Kevin, 2026-06-23)

Two **independent** knobs with the invariant `G <= T`:

- **Grace `G`** — how long idle still earns travel.
- **Threshold `T`** — when the journey hard-pauses.
- **Active floor `F`** — the small idle ceiling below which a tick is *genuine recent input*.

Default **`G = T = 5 min`**, `F = 5 s` (defaults; all injectable). With `G == T` the `(G, T]` idle band
is empty, so travel goes straight to `paused` at 5 min (the epic's "travel until 5 min, then stop+pause",
TC-010).

Bands by the per-tick idle reading `s` (whole-tick classification):

| Condition | State | distanceKm | activeTimeToday | rawActiveTime | idleTimeToday | AC |
|---|---|---|---|---|---|---|
| `s <= F`, unlocked, not sleep | `active` | + | + | + | — | AC-1/AC-3 |
| `F < s <= G`, unlocked, not sleep | `active` (grace) | + | + | — | — | AC-4 |
| `G < s <= T` | `idle` | — | — | — | + | AC-5/AC-16 |
| `s > T` **or** locked **or** sleep | `paused` | — | — | — | + | AC-5/AC-6/AC-8/AC-16 |

Lock / sleep-inference **override the grace immediately** — they win even inside `[F, G]` (AC-6,
TC-006/TC-007). The threshold `T`'s only role beyond `G` is the `idle` → `paused` state distinction;
accounting is identical in both bands (AC-16). Distance and journey time stop at `G`, never `T`.

## The two accumulators (headline honesty rule, AC-2)

- **`activeTimeToday`** (journey time) — accrues on **active + grace** ticks; drives `distanceKm`.
- **`rawActiveTime`** (true input) — accrues on **active ticks only** (idle `<= F`), never during grace;
  this is the **streak-qualifying metric** downstream `local-stats` reads (AC-15). Invariant:
  `rawActiveTime <= activeTimeToday` always.

## Snapshot-tick design choice

`tick(delta, {required idleSeconds, required screenLocked})` takes the current signal as a **snapshot**
rather than awaiting the `ActivityPlugin` itself — chosen so the engine core is **synchronous and
deterministic** (matches "feed a deterministic tick sequence"; tests need no async). The app-layer
ticker (out of scope here) reads the plugin and supplies the snapshot; the thin async convenience
`tickFromPlugin(delta)` wires that for production.

## Distance & elapsed

While travelling: `distanceKm += kmPerActiveHour * (delta in hours)`, computed from
`delta.inMicroseconds` for precision (AC-1). Elapsed always comes from the **caller-supplied `delta`**
(real `now − lastTick`), never an assumed fixed interval — so `1×60s == 6×10s` (AC-7, TC-009).

**`kmPerActiveHour` seam:** injected config, default `250` (sized so ~2,000 km / ~8 active hours, plan
§11). The authoritative number is owned by `route-progress`; override via the constructor when wiring.

## Resolved spec open items (as implemented)

- **Non-positive / backwards delta** — a `delta <= 0` (clock skew / NTP step-back) is **ignored**: no
  accrual, no state change, never negative (TC-019). The engine stays usable for later positive ticks.
- **Whole-tick `rawActiveTime`** — accrues only on active ticks (idle `<= F`); the engine sees aggregate
  idle-seconds, not discrete input events (spec §4 confirm-pending default).
- **Sleep inference keys on the idle signal, not `delta` (no sleep boolean)** — a tick is sleep/paused
  when `idleSeconds >= sleepIdleThreshold` (default `2 × T`), or `idle > T`, or the screen is locked.
  A **large `delta` alone is NOT sleep**: a stalled/slow app-layer ticker can produce a large `delta`
  while the user is genuinely active (`idleSeconds ≈ 0`); dumping that gap to idle would silently
  discard real travel. A real sleep/wake always returns a large idle reading (upstream guarantee,
  activity-detection AC-9), so keying on idle alone still catches TC-007 (large idle inside grace) and
  TC-008 (large delta **and** large idle). Sleep ⇒ `paused`, `idleTimeToday` only, never travel (AC-8).
- **Over-sized travelling tick is clamped (`maxTickDelta`, default `2 × T`)** — to stop a stalled ticker
  over-crediting on resume, when a tick classifies as travelling (active/grace) but its `delta` exceeds
  `maxTickDelta`, the accrued delta is **clamped** to `maxTickDelta` rather than discarded. So neither
  real work is lost (the failure of keying sleep on a large `delta`) nor a stall over-credits.
- **Future stored date on restore** — treated as "today"; daily counters are **not** reset (TC-020).
  A stored date **before** today resets daily counters, preserves distance, no reconstruction
  (AC-10, TC-017).

## Day-boundary reset (AC-9)

The engine owns no timer. A local-midnight crossing is detected **only on the next `tick`** (and on
`restore`) by comparing the injected clock's local date to the stored `currentDay`. On a new day the
three daily counters reset to zero; cumulative `distanceKm`/position is preserved (TC-016).

## Privacy by construction (P0)

The engine only ever observes an aggregate idle duration + a lock boolean (via `ActivityPlugin`), and
persists only the `JourneyProgress` snapshot (aggregate counters + position + date). No raw signals are
stored. No dependency widens that surface.
