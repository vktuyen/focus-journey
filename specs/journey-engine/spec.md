# Journey Engine

**Status:** shipped (2026-06-23)
**Owner:** Kevin (Tuyen Vo)
**Last updated:** 2026-06-23

## Problem
Vietnam Focus Journey turns real focus time into a virtual road trip up/down Vietnam's province
chain. Something has to be the **core loop** that converts "the user is actively working" into
"the traveller moved N kilometres" — and does it *honestly*, *deterministically*, and in a way the
rest of the app (Flame scene, map, stats) can trust.

That core loop is the `JourneyEngine`. Today there is nothing between the raw OS signal (delivered
by the shipped `activity-detection` slice as idle-seconds + lock state) and the things the user
sees. Without it: distance can't accrue, daily progress can't persist across restarts, and there is
no separation between **journey time** (drives distance, includes the idle grace) and **raw active
time** (drives stats/streaks) — the single most important honesty rule of the product.

This slice delivers that loop as **pure, framework-free Dart**: an engine that takes an **injected
clock** and an **injected `ActivityPlugin`**, advances on **real elapsed-time deltas** (computed
from the last-tick timestamp, never an assumed fixed interval), survives sleep/wake gaps correctly,
and persists/restores daily progress locally. Being framework-free, it is fully unit-testable with
no real timers, no Flame, and no native code.

## User & outcome
- **The focused individual** (developer / student / remote worker) — benefits indirectly but
  decisively: the distance they see reflects *genuine* focus. When they stop, travel stops; when
  they resume, it resumes; their daily progress is still there after a restart.
- **The privacy-skeptical teammate** — benefits from the honesty seam: stats are driven by **raw
  active time**, reported separately from (and lower than) the grace-inflated journey time, so the
  numbers can't quietly overstate how much they "worked."

**Observable success:** given a deterministic test clock and a mock `ActivityPlugin`, feeding the
engine a sequence of ticks produces exactly the expected `distanceKm`, `activeTimeToday`,
`rawActiveTime`, and `idleTimeToday` — including across a simulated idle-grace window, a sleep/wake
gap, and a local-midnight rollover — with no real time passing in the test.

## Scope
### In
- **`JourneyEngine`** — pure Dart, *domain* layer. Holds and exposes at least: `distanceKm`,
  `activeTimeToday` (journey time, includes grace), `rawActiveTime` (true input time, no grace),
  `idleTimeToday`, `state` (active | idle | paused), and `mode` (cosmetic travel skin).
- **Tick API driven by elapsed-time deltas.** `tick(delta)` (or equivalent) advances state by a
  caller-supplied `Duration` computed as `now − lastTickTimestamp`. The engine never reads
  `DateTime.now()` or owns a real timer internally.
- **Injected clock + injected `ActivityPlugin`.** Both are constructor-injected behind interfaces so
  the engine is deterministic and swappable (real ↔ mock) with no change to calling code.
- **Active/idle/paused decision policy** — two **independent, configurable** knobs (Kevin's decision,
  2026-06-23): a **grace window** `G` (how long idle still earns travel) and an **idle threshold** `T`
  (when the journey hard-pauses), with `G ≤ T`. **Default `G = T = 5 min`** so default behaviour
  matches the epic (travel until 5 min, then stop+pause); they diverge only when tuned. Applied to the
  two signals the upstream `ActivityPlugin` actually exposes — `getSystemIdleSeconds()` and
  `isScreenLocked()`. **There is no sleep boolean** — sleep is *inferred from a large idle-seconds reading*
  (at/above a configured `sleepIdleThreshold`) or screen lock ⇒ treat as idle, never travel. **A large tick
  `delta` alone is NOT sleep** (a stalled/slow ticker can produce a large `delta` while the user is genuinely
  active); an over-sized *travelling* tick is instead **clamped** to `maxTickDelta`, so neither real work is
  discarded nor a stall over-credits. (Kevin ratified the idle-only inference + clamp on 2026-06-23 — review
  finding M-1.) Bands by true-idle elapsed `s` (with a small active floor `F`):
  - `s ≤ F` (genuine input) AND unlocked → **active**: accrues `distanceKm` + `activeTimeToday`
    (journey) + `rawActiveTime`.
  - `F < s ≤ G` (**grace**, unlocked) → **travelling**: accrues `distanceKm` + `activeTimeToday`, but
    **not** `rawActiveTime`.
  - `G < s ≤ T` → **idle** (vehicle stopped, no distance): accrues `idleTimeToday` only; `state = idle`.
  - `s > T`, OR screen locked, OR a large idle reading (sleep-inferred) → **paused**: accrues `idleTimeToday` only;
    `state = paused`. (Lock/sleep override the grace immediately — they win even inside `[F, G]`.)
  - **Note (confirm at review):** beyond the grace, the threshold `T`'s only role is the `state`
    distinction `idle` → `paused` (drives the "Paused — idle" UI and session-break downstream);
    accounting is identical for both. Distance/journey time stop at `G`, not `T`.
- **Speed-only distance model.** `distanceKm += kmPerActiveHour × delta` while travelling. v1 uses a
  **single shared `kmPerActiveHour`** for all modes; `mode` is a cosmetic skin only.
- **Sleep/wake correctness.** A sleep gap counts as **neither** journey nor active time: the OS reports a
  **large idle** value on wake (`activity-detection` AC-9), which the engine reads as sleep/idle. Because
  elapsed is computed from the last-tick timestamp, the missed-tick gap is attributed correctly (idle), not
  silently accrued as travel. **Sleep is inferred from the large idle reading, not from `delta`** — a large
  `delta` alone is clamped to `maxTickDelta`, not slept (Kevin ratified 2026-06-23) — and the engine has no
  dedicated sleep signal.
- **Per-tick attribution rule (load-bearing).** The engine classifies an entire tick from the
  idle-seconds reading at tick time (whole-tick classification): a tick is *active* when idle-seconds
  is below a small floor, *grace* when idle-seconds is between the floor and the threshold, *idle/paused*
  otherwise (or locked, or a large idle reading). `rawActiveTime` accrues only on *active* ticks;
  `activeTimeToday` (journey time) accrues on *active* and *grace* ticks; `idleTimeToday` on *idle* ticks.
- **Local persistence of daily progress** — save/restore `distanceKm`, the day's counters, `state`,
  `mode`, and the stored calendar date, via a repository seam (`shared_preferences`/JSON per the
  architecture). Restoring within the same local day resumes; crossing local midnight resets the
  **daily** counters while preserving cumulative position.
- **Day-boundary reset** at local midnight: `activeTimeToday`, `rawActiveTime`, `idleTimeToday` reset;
  cumulative `distanceKm`/position persists. Includes the "app was closed across midnight" case
  (detected from the stored date on restore).

### Out
- **Raw signal acquisition** — reading OS idle-seconds / lock state. That is the shipped
  `activity-detection` slice; this engine *consumes* its `ActivityPlugin` interface.
- **The periodic driver / ticker.** The app-service "activity ticker" that computes `now − lastTick`
  on a real `Timer` and calls `engine.tick()` is wiring that lives at the app layer, not in the pure
  engine. (The engine is tested by feeding deltas directly.)
- **Province chain / start-province / direction / map / "% of country"** — that is `route-progress`.
  The engine produces a scalar `distanceKm`; mapping it onto the chain is downstream.
- **Stats UI, streaks, badges, settings screen, onboarding** — that is `local-stats`. The engine only
  exposes the honest `rawActiveTime` those features consume.
- **Flame scene / any rendering** — that is `journey-view`.
- **Per-mode speeds / energy / fuel model** — v2 (`journey-energy-model`). v1 is speed-only.
- **Route-completion celebration/summary** — depends on the chain, so it lives with `route-progress`.

## Constraints & assumptions
- **Framework-free & deterministic (hard constraint).** No `flutter`, `flame`, real `Timer`, or
  `DateTime.now()` inside the engine. Clock + `ActivityPlugin` are injected. Unit tests run with no
  real timers and no wall-clock waits.
- **Elapsed-from-timestamp, never fixed interval.** Each advance uses real elapsed time since the
  last tick — robust to timer drift, missed ticks, and sleep/wake.
- **Two separate accumulators.** Journey time (incl. grace) drives distance; raw active time (true
  input only) drives stats/streaks. They must never be conflated. (Headline honesty rule.)
- **Speed-only, single `kmPerActiveHour`.** Modes are cosmetic in v1; the rate is tuned so ~8 active
  hours covers the chain (the exact value's source of truth is the route-progress province data; the
  engine takes it as configuration / injected constant).
- **Privacy by construction.** The engine only ever sees an aggregate idle duration + lock/sleep
  boolean (via `ActivityPlugin`) — never input content. No new dependency may widen that surface.
- Stack per `docs/architecture/overview.md`: Flutter desktop, Bloc, Clean Architecture — the engine
  is a *domain* contract; persistence is *data*.

### Resolved decisions
- **Engine owns the active/idle/paused decision policy** (threshold + grace), consuming raw signals
  from `ActivityPlugin`. (`activity-detection` is the thermometer; the engine is the thermostat.)
- **Speed-only distance, single shared `kmPerActiveHour`**; `mode` is cosmetic. Per-mode/energy → v2.
- **Persistence via `shared_preferences`/JSON** behind a repository interface (data is tiny).
- **(Kevin, 2026-06-23) Grace and threshold are two independent knobs** (`G ≤ T`), default `G = T = 5 min`.
  See the decision policy above; the `[G, T]` middle-band semantics are the one item flagged "confirm at review."
- **(Kevin, 2026-06-23) Streak qualifies on raw active time** (≥25 min of `rawActiveTime`, no grace) —
  the engine exposes `rawActiveTime`; `local-stats` does the counting.
- **(Kevin, 2026-06-23) App-closed-across-midnight ⇒ reset daily counters, no reconstruction.** On
  restore, if the stored date < today, zero the daily counters; preserve cumulative distance/position.
- **(Kevin, 2026-06-23) Grace stays travel on timeout.** Grace minutes already credited as journey
  distance are *not* rolled back if the user later exceeds the threshold; only post-threshold time is idle.
- **(Kevin, 2026-06-23) Sleep is inferred from the idle signal only, not `delta` (ratifies review M-1).**
  A large idle reading (`≥ sleepIdleThreshold`) or screen lock ⇒ paused/idle (never travel). A large `delta`
  **alone** is **not** sleep — an over-sized *travelling* tick is **clamped** to `maxTickDelta` and still
  credited, because a stalled/slow app-layer ticker must not silently delete genuine active time (the
  opposite would violate the honesty rule). Relies on `activity-detection` AC-9 (idle is always large after
  a real wake), so AC-8's both-large case still resolves to idle. AC-6/AC-8 and TC-007 updated to match.

## Open questions
> Four product decisions resolved by Kevin on 2026-06-23 — see **Resolved decisions** above
> (two-knob grace/threshold · raw-active-time streak · reset-no-reconstruct on closed-midnight ·
> grace-stays-travel on timeout). Remaining open items:

- [x] **`[G, T]` middle-band semantics** — **Resolved (Kevin approved spec, 2026-06-23):** in
      `G < s ≤ T` the vehicle is stopped (no distance/journey accrual), `idleTimeToday` accrues, and
      `state = idle` (vs `paused` only past `T`). Distance/journey time stop at `G`, not `T`. Default
      `G = T = 5 min` makes the band empty.
- [ ] **`kmPerActiveHour` source of truth & v1 value** — does the engine take it as an injected
      constant/config, with the actual number owned by `route-progress` province data (chain length ÷
      ~8h)? Confirm the seam so the two slices agree. — owner: system-architect / Kevin
- [ ] **Non-positive / backwards delta robustness** — what does the engine do on a `delta <= 0`
      (clock skew / NTP step-back) or a stored date in the *future* on restore? (Recommend: clamp a
      non-positive delta to zero / ignore the tick; treat a future stored date as "today" and don't
      reset.) — owner: Kevin
- [ ] **`rawActiveTime` during grace (attribution precision)** — confirmed default: raw active time
      accrues *only* on active ticks (idle-seconds below the small floor), never during grace, because
      the engine sees only aggregate idle-seconds, not discrete input events. Confirm this whole-tick
      rule is acceptable for stats honesty. — owner: product-domain-expert / Kevin

## Related
- Epic: [planning/backlog/vietnam-focus-journey.md](../../planning/backlog/vietnam-focus-journey.md) · Wave 1 (v1)
- Backlog slice: [planning/backlog/journey-engine.md](../../planning/backlog/journey-engine.md)
- Upstream (shipped): [specs/activity-detection/spec.md](../activity-detection/spec.md) — provides `ActivityPlugin`
- Plan detail: `planning/backlog/vietnam_focus_journey_plan.md` §0.B.6–7 (time accounting + testability), §4 (active/idle + grace), §20 (engine draft), §0.A.4 + §11 (speed-only pacing)
- Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md)
- Architecture: [docs/architecture/overview.md](../../docs/architecture/overview.md) — `JourneyEngine` in Components; ADR-0002 (stack)
