# Test cases: journey-engine

Spec: [specs/journey-engine/spec.md](../../specs/journey-engine/spec.md)
Acceptance criteria: [specs/journey-engine/acceptance-criteria.md](../../specs/journey-engine/acceptance-criteria.md)

## Scope of these cases

These cases verify the **pure, framework-free `JourneyEngine`** — the domain core loop that turns
genuine focus into honest distance. They exercise the engine in isolation against its exposed
values (`distanceKm`, `activeTimeToday`, `rawActiveTime`, `idleTimeToday`, `state`, `mode`) after
feeding a deterministic `tick(delta)` sequence with an **injected clock** and an **injected mock
`ActivityPlugin`**.

They deliberately do NOT exercise: real OS idle/lock acquisition (that is the shipped
`activity-detection` slice, consumed here via the mock), the real periodic ticker / `Timer` (an
app-layer concern — the engine is driven by deltas directly), province-chain mapping / "% of
country" (`route-progress`), stats/streak counting or UI (`local-stats` — the engine only
**exposes** `rawActiveTime`), Flame rendering (`journey-view`), or per-mode speeds / energy
(v2 `journey-energy-model`).

Unlike the sibling `activity-detection` cases (many of which are Manual / per-OS), **almost every
case here is a deterministic unit test** — no real timers, no real waits, no `DateTime.now()`, no
native code, no Flame, no UI. Sleep/wake, midnight rollover, and grace windows are all simulated by
scripting the injected clock and the mock `ActivityPlugin` and feeding synthetic deltas.

## Conventions used by these cases

- **Deterministic by construction:** the engine reads no wall clock and owns no timer. Every "time
  passes" in these cases is a value fed to `tick(delta)` or a value scripted on the injected clock;
  no test awaits real time.
- **Mock `ActivityPlugin` surface:** the mock exposes ONLY `getSystemIdleSeconds()` and
  `isScreenLocked()` — caller-driven, returned exactly (see `activity-detection` TC-012/TC-013).
  **There is no sleep boolean.** Sleep is *inferred* by the engine from a large idle-seconds reading
  (≥ `sleepIdleThreshold`) or lock — **not** from a large tick `delta` alone (a large `delta` is clamped
  to `maxTickDelta`, never slept; Kevin ratified 2026-06-23, review M-1). No case sets a "sleeping" flag.
- **Two-knob decision model (Kevin, 2026-06-23):** grace window `G` and idle threshold `T`,
  `G ≤ T`, **default `G = T = 5 min`**. Bands by true-idle elapsed `s` with active floor `F`:
  `s ≤ F` → **active** (distance + journey + raw); `F < s ≤ G` → **grace/travelling**
  (distance + journey, NOT raw); `G < s ≤ T` → **idle** (stopped, `idleTimeToday` only, `state = idle`);
  `s > T` OR locked OR sleep-inferred → **paused** (`idleTimeToday` only, `state = paused`).
  Distance + journey time stop at `G`, not `T`. Lock/sleep override the grace immediately.
- **Active floor `F`:** the small idle-seconds ceiling below which a tick is treated as genuine
  recent input (the *active* band). At/below `F` ⇒ active; above `F` ⇒ grace or beyond. `F` is a
  configured constant, small relative to `G`.
- **Whole-tick attribution (confirm-pending — spec open question §4):** the engine classifies an
  **entire** tick from the idle-seconds reading at tick time. `rawActiveTime` accrues per-tick **only
  on active ticks** (idle ≤ `F`), never during grace; `activeTimeToday` (journey) accrues on active +
  grace ticks; `idleTimeToday` on idle/paused ticks. Cases assume this rule; review must confirm it.
- **Floating-point distance tolerance:** where a case asserts an exact `distanceKm` (or time)
  accrual, "within tolerance" means **±1e-6 km** (resp. ±1e-6 h) unless stated otherwise, to absorb
  `Duration`→hours conversion rounding. Cases that compare two sequences for equality assert
  equality within the same ±1e-6.
- **Distance formula:** while travelling (active or grace), `distanceKm += kmPerActiveHour ×
  (delta in hours)`. `kmPerActiveHour` is taken as injected config/constant (its source-of-truth seam
  with `route-progress` is a spec open question — flagged where relevant).
- **Test layer:** all cases except where noted are deterministic unit tests under the engine's test
  suite (per `docs/architecture/overview.md`). None require a device or per-OS run.

## Cases

### Case: Active tick accrues distance at exactly kmPerActiveHour
**ID:** TC-001
**Priority:** P0
**Type:** happy-path
**Covers:** AC-1

Given the engine is configured with a single shared `kmPerActiveHour`, and the mock `ActivityPlugin` reports idle-seconds at/below the active floor `F` and screen unlocked
When a single `tick(delta)` advances the engine while in the **active** state
Then `distanceKm` increases by exactly `kmPerActiveHour × (delta in hours)` (within ±1e-6 km) and `state == active`

**Notes:** Deterministic unit test. Use a delta that makes the expected distance exact (e.g. `delta = 1h`, `kmPerActiveHour = 10` ⇒ `distanceKm == 10`). Depends on the `kmPerActiveHour` seam open question (spec §"non-positive… / kmPerActiveHour source of truth") — written against the recommended default that the engine takes the rate as injected config; review must confirm the seam with `route-progress`.

---

### Case: Journey time and raw active time stay two separate accumulators
**ID:** TC-002
**Priority:** P0
**Type:** happy-path
**Covers:** AC-2

Given a mixed tick sequence containing both genuine-input ticks (idle ≤ `F`) and grace-window ticks (true idle in `F < s ≤ G`, unlocked, not sleep-inferred)
When the full sequence is fed to the engine
Then `activeTimeToday` (journey time) accrues for **both** the active and grace ticks, while `rawActiveTime` accrues **only** for the active ticks — so `rawActiveTime < activeTimeToday`, and they are never conflated

**Notes:** Deterministic unit test. Headline honesty rule. Construct the sequence so at least one grace tick is consumed, guaranteeing strict inequality (`rawActiveTime < activeTimeToday`). Also assert `rawActiveTime` equals the summed active-tick deltas exactly (±1e-6 h).

---

### Case: Active tick accrues distance + journey + raw, nothing idle
**ID:** TC-003
**Priority:** P0
**Type:** happy-path
**Covers:** AC-3

Given the mock reports idle-seconds at/below the active floor `F` (genuine recent input) and screen unlocked
When a `tick(delta)` advances the engine
Then `state == active` and that tick's `delta` adds to `distanceKm`, `activeTimeToday`, **and** `rawActiveTime`, while `idleTimeToday` is unchanged

**Notes:** Deterministic unit test. Assert `idleTimeToday` did not move (no idle accrual on an active tick). Boundary variant: also assert the case holds when idle-seconds equals exactly `F` (the active/grace boundary belongs to active).

---

### Case: Grace tick accrues distance + journey but NOT raw
**ID:** TC-004
**Priority:** P0
**Type:** happy-path
**Covers:** AC-4

Given the user has gone idle and true-idle `s` falls in the **grace band** `F < s ≤ G` (screen unlocked, not sleep-inferred)
When a `tick(delta)` advances the engine inside that grace
Then `state` remains travelling, `distanceKm` and `activeTimeToday` accrue for that tick, but `rawActiveTime` does **not** change (and `idleTimeToday` does not change either)

**Notes:** Deterministic unit test. Drive the mock with idle-seconds strictly between `F` and `G`. Pairs with TC-002 (the separation rule) and TC-009/TC-010 (the boundary at `G`).

---

### Case: Past the grace window → no travel, only idle accrues
**ID:** TC-005
**Priority:** P0
**Type:** edge
**Covers:** AC-5

Given true-idle `s` has exceeded the grace window `G` (with `G < T` so this tick lands in `G < s ≤ T`), screen unlocked, no sleep-sized delta
When a `tick(delta)` advances the engine
Then `distanceKm`, `activeTimeToday`, and `rawActiveTime` do **not** change, and only `idleTimeToday` accrues for that tick

**Notes:** Deterministic unit test. This is the "stopped" band. State assertion is covered by TC-011; here the focus is the accounting (no travel, idle only).

---

### Case: Lock overrides grace — no travel even inside the grace band
**ID:** TC-006
**Priority:** P0
**Type:** edge
**Covers:** AC-6

Given the user has just gone idle and `s` is **within** the grace band `F < s ≤ G` (which alone would still count as travel), screen reported **locked** by the mock
When a `tick(delta)` advances the engine
Then the engine treats it as non-travel immediately — `distanceKm` and `activeTimeToday` do **not** accrue, `rawActiveTime` does not accrue, only `idleTimeToday` accrues — i.e. lock wins over grace

**Notes:** Deterministic unit test. Lock asserted via `isScreenLocked() == true` on the mock. Sibling sleep-inferred variant is TC-008. Confirms lock is checked before the grace classification.

---

### Case: Sleep-inferred overrides grace — large idle inside grace band
**ID:** TC-007
**Priority:** P1
**Type:** edge
**Covers:** AC-6

Given the engine is travelling and the next tick arrives with a **large** idle-seconds reading at/above the configured `sleepIdleThreshold` (sleep inferred — there is no sleep flag), screen unlocked
When that `tick(delta)` is processed
Then the engine treats it as non-travel — `distanceKm`, `activeTimeToday`, and `rawActiveTime` do **not** accrue, only `idleTimeToday` accrues — sleep-inferred (large idle) wins over any grace

**Notes:** Deterministic unit test. Distinct from TC-008 (whole-gap attribution after being active): here the point is the *override* of grace specifically. **Sleep inference keys on the IDLE reading only (≥ `sleepIdleThreshold`), not on `delta`** — ratified by Kevin 2026-06-23 (review M-1). A large `delta` **alone** (with a small idle reading, e.g. a stalled ticker while genuinely active) is **not** sleep: that tick stays *travelling* and its accrual is **clamped** to `maxTickDelta` so a stall can't over-credit nor silently discard real work (covered by the `largeDeltaIdleSmall_isActive_creditClampedToMaxTickDelta` test). Assert against the configured idle threshold.

---

### Case: Sleep/wake gap counts as neither journey nor active
**ID:** TC-008
**Priority:** P0
**Type:** edge
**Covers:** AC-8

Given the engine was active, then a long real-time gap passes (machine asleep), and the next `tick(delta)` arrives with a **large** `delta` and the mock reporting a **large idle** value (sleep inferred)
When that tick is processed
Then the entire gap is attributed to **idle** — `distanceKm`, `activeTimeToday`, and `rawActiveTime` do **not** increase for the gap, and `idleTimeToday` increases by the gap; the gap is not silently accrued as travel

**Notes:** Deterministic unit test. Consumes `activity-detection` AC-9 ("large idle after wake") interpreted here as idle. Because elapsed comes from the supplied `delta` (not an assumed interval), the missed-tick gap is correctly classified — assert it is whole-tick idle, no partial travel credit.

---

### Case: Elapsed scales from delta — 1×60s equals 6×10s
**ID:** TC-009
**Priority:** P0
**Type:** happy-path
**Covers:** AC-7

Given two active tick sequences reaching the same total elapsed time but with different per-tick deltas — one `tick(60s)` versus six `tick(10s)` calls — both with idle ≤ `F` and unlocked throughout
When each sequence is fed to a fresh engine
Then the resulting `distanceKm` and `activeTimeToday` are **equal** across the two runs (within ±1e-6), and `rawActiveTime` is equal too — the engine scales by the supplied `delta` and assumes no fixed tick period

**Notes:** Deterministic unit test. Guards against any hardcoded "per tick = N seconds" assumption. The engine must read no clock of its own to fill the gap between the 10s ticks.

---

### Case: Default G = T = 5 min makes the idle band empty (grace → straight to paused)
**ID:** TC-010
**Priority:** P1
**Type:** edge
**Covers:** AC-16, AC-5

Given the engine is configured with the **default** `G = T = 5 min` (so the `G < s ≤ T` band is empty)
When true-idle `s` crosses `G` (= `T`) and a tick is processed at `s` just above `G`
Then there is no `idle` band: `state == paused` (not `idle`), no distance/journey/raw accrues, and `idleTimeToday` accrues — i.e. travel stops at `G` and the state goes directly to `paused`

**Notes:** Deterministic unit test. Boundary case for the two-knob default. Pairs with TC-011, which uses `G < T` to exercise the non-empty middle band. Confirms the default reproduces the epic's "travel until 5 min, then stop+pause".

---

### Case: With G < T, idle (G<s≤T) and paused (s>T) differ in state but not accounting
**ID:** TC-011
**Priority:** P1
**Type:** edge
**Covers:** AC-16

Given two independent knobs with `G < T` (e.g. `G = 5 min`, `T = 10 min`, so the band `G < s ≤ T` is non-empty)
When one tick is processed with true-idle `s` in `G < s ≤ T`, and another (fresh) with `s > T`
Then the first reports `state == idle` and the second `state == paused`, and in **both** the accounting is identical — only `idleTimeToday` accrues, no distance / journey / raw

**Notes:** Deterministic unit test. Confirms the resolved `[G, T]` middle-band semantics: distance stops at `G`, not `T`; `T` only flips `idle`→`paused`. Locked / sleep-inferred should also yield `paused` regardless of `s` — assert that variant too.

---

### Case: Determinism — identical inputs yield byte-for-byte identical outputs
**ID:** TC-012
**Priority:** P0
**Type:** regression
**Covers:** AC-12

Given the same injected clock script and the same mock `ActivityPlugin` value sequence
When the engine is run twice (and/or the test is re-executed at a different real-world wall-clock time)
Then every exposed value (`distanceKm`, `activeTimeToday`, `rawActiveTime`, `idleTimeToday`, `state`, `mode`) is identical across runs — output depends only on injected inputs, never on real elapsed wall-clock time

**Notes:** Deterministic unit test. Run the same scripted sequence twice in one test and assert field-by-field equality. Sleeping the real clock between runs (or running on a machine with a different system time) must not change any output.

---

### Case: mode is cosmetic — same speed and accrual for all modes
**ID:** TC-013
**Priority:** P1
**Type:** edge
**Covers:** AC-13

Given two otherwise-identical active tick sequences that differ only in the engine's `mode` (travel skin)
When each is fed to a fresh engine
Then the resulting `distanceKm` and all time accumulators are **equal**, and `mode` is preserved/exposed but does not affect `kmPerActiveHour` or any accrual (v1 is speed-only)

**Notes:** Deterministic unit test. Guards against any per-mode speed leaking in before v2 `journey-energy-model`. Assert `mode` round-trips unchanged on each engine.

---

### Case: Grace minutes stay travel after the threshold is crossed (no rollback)
**ID:** TC-014
**Priority:** P1
**Type:** edge
**Covers:** AC-14

Given the user goes idle, accrues some grace-window ticks (counted as journey time + distance), and then **exceeds** the idle threshold without returning to input
When the threshold-crossing tick is processed
Then the engine does **not** retroactively reclassify the earlier grace ticks — the grace seconds remain in `distanceKm` + `activeTimeToday`, and only subsequent (post-threshold) ticks accrue `idleTimeToday`

**Notes:** Deterministic unit test. Snapshot `distanceKm` and `activeTimeToday` after the last grace tick; after the threshold-crossing tick assert those two are **unchanged** (only `idleTimeToday` grew). Resolved decision (Kevin 2026-06-23): grace stays travel.

---

### Case: rawActiveTime is the streak-qualifying metric and ≤ journey time
**ID:** TC-015
**Priority:** P1
**Type:** happy-path
**Covers:** AC-15, AC-2

Given a tick sequence mixing active and grace ticks across a day
When downstream reads the day's streak-qualifying duration from the engine
Then the engine exposes `rawActiveTime` (true input, no grace) as that metric — distinct from and `≤ activeTimeToday` — and this slice only **exposes** it (no streak counting here)

**Notes:** Deterministic unit test. Assert the invariant `rawActiveTime ≤ activeTimeToday` holds after the sequence, and that `rawActiveTime` excludes all grace deltas. Streak counting (≥25 min threshold) belongs to `local-stats` and is out of scope here.

---

### Case: Local-midnight crossing resets daily counters, preserves cumulative distance
**ID:** TC-016
**Priority:** P1
**Type:** edge
**Covers:** AC-9

Given the engine holds non-zero `activeTimeToday`, `rawActiveTime`, `idleTimeToday`, and `distanceKm` for a given local calendar day
When the injected clock crosses **local midnight** and the next tick is processed
Then `activeTimeToday`, `rawActiveTime`, and `idleTimeToday` reset to zero, while cumulative `distanceKm` (position) is **preserved** unchanged

**Notes:** Deterministic unit test. Script the injected clock to step from 23:59 of day N to 00:00 of day N+1 (local). Verify the reset happens once at the boundary, not on every subsequent same-day tick.

---

### Case: App-closed-across-midnight detected from stored date on restore (reset, no reconstruction)
**ID:** TC-017
**Priority:** P1
**Type:** edge
**Covers:** AC-10

Given persisted state whose **stored calendar date is earlier than** the injected clock's current local date
When a fresh engine restores that state
Then the daily counters (`activeTimeToday`, `rawActiveTime`, `idleTimeToday`) are reset to zero for the new day, cumulative `distanceKm` is **preserved**, and the missed day is **not** reconstructed (no synthetic accrual for the gap)

**Notes:** Deterministic unit test. Resolved (Kevin 2026-06-23): reset, do not reconstruct. Test a multi-day gap (stored date two+ days earlier) and assert it behaves the same as a one-day gap — single reset, no per-missed-day reconstruction.

---

### Case: Same-day save/restore round-trip resumes exactly, no double-count
**ID:** TC-018
**Priority:** P1
**Type:** happy-path
**Covers:** AC-11

Given the engine has accrued `distanceKm` and the day's counters and is saved via the repository seam (`shared_preferences`/JSON, mocked in-memory)
When a fresh engine restores that state with the injected clock still on the **same local day**
Then `distanceKm`, `activeTimeToday`, `rawActiveTime`, `idleTimeToday`, `state`, `mode`, and the stored date all equal the saved values, and a subsequent active tick continues accruing distance from the restored position — no double-count, no reset

**Notes:** Deterministic unit test against a fake/in-memory repository (the real `shared_preferences` impl is data-layer, out of the pure engine). Assert post-restore the first active tick adds exactly `kmPerActiveHour × delta` on top of the restored `distanceKm`.

---

### Case: Non-positive / backwards delta is clamped — never accrues negative or bogus travel
**ID:** TC-019
**Priority:** P0
**Type:** negative
**Covers:** AC-1, AC-7, AC-12

Given the engine is active (idle ≤ `F`, unlocked) and a `tick(delta)` arrives with `delta <= 0` (e.g. zero, or a negative duration from clock skew / NTP step-back)
When that tick is processed
Then the tick is clamped to zero / ignored — `distanceKm`, `activeTimeToday`, `rawActiveTime`, and `idleTimeToday` are **unchanged**, never decrease, and no bogus travel is recorded; the engine remains usable for subsequent positive-delta ticks

**Notes:** Deterministic unit test. **Maps to the spec open question** "Non-positive / backwards delta robustness" — written against the recommended default (clamp non-positive delta to zero / ignore the tick). Flag: this case's exact expected behaviour depends on Kevin confirming that default; if the resolution differs, revise. Assert a following normal positive tick accrues correctly (state not corrupted).

---

### Case: Stored date in the future on restore is treated as "today" — no reset
**ID:** TC-020
**Priority:** P1
**Type:** negative
**Covers:** AC-10, AC-11

Given persisted state whose **stored calendar date is later than** the injected clock's current local date (clock skew / NTP step-back having moved "today" backwards)
When a fresh engine restores that state
Then the engine treats the stored date as "today" and does **not** reset the daily counters — `activeTimeToday`, `rawActiveTime`, `idleTimeToday`, and `distanceKm` all restore to the saved values, and a same-day tick resumes accruing normally

**Notes:** Deterministic unit test. **Maps to the spec open question** "stored date in the future on restore" — written against the recommended default (treat future stored date as today, do not reset). Flag: depends on Kevin confirming that default. Distinct from TC-017 (past stored date → reset); here a future date must NOT trigger a reset (which would wrongly wipe progress).

---

### Case: Resume from idle/paused back to active continues travel without artifacts
**ID:** TC-021
**Priority:** P1
**Type:** regression
**Covers:** AC-3, AC-5, AC-14

Given the engine has gone idle/paused (true-idle `s` past `G`, only `idleTimeToday` accruing) with frozen `distanceKm`/`activeTimeToday`
When fresh input arrives (mock idle-seconds drops to ≤ `F`, unlocked) and the next tick is processed
Then `state` returns to `active`, distance/journey/raw resume accruing from the preserved `distanceKm`, `idleTimeToday` stops growing, and no earlier idle time is retroactively converted to travel (and no double-credit on the resume tick)

**Notes:** Deterministic unit test. Regression guard for the full idle→active round trip (the inverse of TC-014). Assert the resume tick adds exactly one tick's worth of travel, and the frozen values from before the idle period are intact.

---

### Case: Mixed full-day sequence honours all invariants end to end
**ID:** TC-022
**Priority:** P1
**Type:** regression
**Covers:** AC-2, AC-3, AC-4, AC-5, AC-8, AC-15

Given a single scripted day mixing active ticks, grace ticks, an idle/paused stretch, a lock interval, a sleep/wake gap, and a resume — all via the injected clock + mock
When the whole sequence is fed to one engine
Then at the end: `rawActiveTime` == sum of active-tick deltas only; `activeTimeToday` == active + grace deltas; `idleTimeToday` == idle + paused + locked + sleep-gap deltas; `distanceKm` == `kmPerActiveHour ×` (active + grace hours); and the invariant `rawActiveTime ≤ activeTimeToday` holds throughout

**Notes:** Deterministic unit test. Integration-style end-to-end check over one engine instance that the per-band rules compose correctly and the two accumulators never conflate across a realistic day. Use round numbers so all four totals are exactly assertable (±1e-6).
