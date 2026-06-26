# Test cases: idle-accounting

Spec: [specs/idle-accounting/spec.md](../../specs/idle-accounting/spec.md)
Upstream engine (shipped): [specs/journey-engine/spec.md](../../specs/journey-engine/spec.md)
Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md)

## Coverage note

These cases verify the **idle-accounting** slice layered onto the shipped pure-Dart `JourneyEngine`:
Option B attribution (whole-tick accounting **plus** an Active→Idle/Paused state-change timestamp), the
new ordered **activity-segment record** (`{from, to, classification, cause}`, distance-keyed, persisted,
merged, day-split), and the honesty invariant (never over-credit active). All behaviour is driven by a
**deterministic scripted clock** and a **mock `ActivityPlugin`** (surface = `getSystemIdleSeconds()` +
`isScreenLocked()` only — no sleep flag, no input content). No real timers, no wall-clock waits.

Layer → AC mapping:

| AC | What it asserts | Covering layer(s) | Cases |
| --- | --- | --- | --- |
| **AC-1** | Idle onset honoured within one tick after Active→Idle/Paused; active never increases after `T` | Unit (deterministic engine) | TC-101, TC-102, TC-103 |
| **AC-2** | UI idle counter vs accounting accumulator agree with **divergence 0** across Active↔Idle↔Paused | Unit | TC-104, TC-105, TC-106 |
| **AC-3** | Segments reconstruct route losslessly + contiguously; durations sum to elapsed | Unit | TC-107, TC-108, TC-114 |
| **AC-4** | Segment labels correct + cause-tagged (voluntary vs lock/sleep); lock/sleep segment starts at lock instant | Unit | TC-109, TC-110, TC-111 |
| **NFR-1** | No new OS signal; segments aggregate-only; `/privacy-audit` PASS | Unit (assertable part) + **review/audit** (gate) | TC-112 (unit-assertable subset) + audit gate (see below) |
| **NFR-2** | `delta <= 0` / clock step-back / future stored date defined + clamped to zero, no accrual | Unit (negative) | TC-113, TC-115 |

Also exercised (spec In-scope / Decisions, traceable to the ACs they protect):

| Behaviour | Cases | Primary AC |
| --- | --- | --- |
| Pre-fix repro pinned (Decision (a)) before "from that moment" lands | TC-100 | AC-2 (regression baseline) |
| Grace-stays-travel preserved — grace not retro-converted to idle (Decision (d)) | TC-116 | AC-1, AC-3 |
| Day-boundary rollover splits a segment (Decision (c)) | TC-117 | AC-3 |
| Merge of consecutive same-classification segments — growth bound (Decision (c)) | TC-118 | AC-3 |
| Segment persistence across restart (Decision (c)) | TC-119 | AC-3 |
| End-to-end mixed-day composition | TC-120 | AC-1..AC-4 |

**Risky / under-covered areas (flagged for review / test-script-author):**

- **NFR-1 privacy is partly non-automatable.** A unit test (TC-112) can assert the segment record's
  *shape* (only aggregate fields, no raw key/mouse content) and that no new `ActivityPlugin` method is
  consumed. But "no new OS signal introduced" and "`/privacy-audit` PASS" are a **review/audit gate**,
  not a unit assertion — surface this to `privacy-guardian` via `/privacy-audit`. Marked **Manual /
  audit** on TC-112's notes.
- **"Divergence 0" hinges on a contract definition** of *exactly what value the UI would show* at a
  tick boundary under Option B. Cases assume the displayed idle counter == the engine's `idleTimeToday`
  accumulator sampled at the same tick boundary (Option B anchors both to the state-change stamp). If the
  Bloc applies any independent rounding/smoothing before display, AC-2 must be re-checked at the Bloc
  layer (widget test) — currently **out of this pure-engine suite**. Flagged on TC-104.
- **Sub-tick residue direction.** Option B accepts a ≤ one-tick residue in the *raw* accumulators; the
  honesty direction (residue favours idle, never active) is asserted in TC-102/TC-103, but the *exact
  residue magnitude* is intentionally not pinned (implementation-defined within one tick). Reviewers
  should confirm the residue stays ≤ one tick interval.
- **NFR-2 future-stored-date** path is inherited from `journey-engine` TC-020; re-asserted here (TC-115)
  only for the *segment record* (segments must not be corrupted / reset by clock skew). The counter
  behaviour itself is already covered upstream.

## Conventions used by these cases

- **Deterministic by construction.** The engine reads no wall clock and owns no timer. Every "time
  passes" is a value fed to `tick(delta)` or scripted on the injected clock. No case awaits real time.
- **Mock `ActivityPlugin` surface:** `getSystemIdleSeconds()` + `isScreenLocked()` only — no sleep flag,
  no input content (matches `journey-engine` cases and `activity-detection` TC-012/TC-013).
- **Bands (from `journey-engine`):** active floor `F`, grace `G`, threshold `T` (`G ≤ T`), default
  `G = T = 5 min`. `s ≤ F` → active; `F < s ≤ G` → grace/travel; `G < s ≤ T` → idle; `s > T` OR locked
  OR sleep-inferred (idle ≥ `sleepIdleThreshold`) → paused. Lock/sleep override grace immediately.
- **Option B (this slice).** Whole-tick accounting is **unchanged**; additionally the engine stamps the
  instant the reported `state` flips Active→Idle/Paused and anchors the **displayed idle counter** to
  that stamp so the UI counter and `idleTimeToday` accumulator agree exactly (max divergence 0). A
  ≤ one-tick residue may remain in raw accumulators and MUST favour idle, never active.
- **Idle-onset instant (Decision (d)).** Voluntary idle onset = the band crossing `s > G`. Lock/sleep
  onset = the lock/sleep instant (immediate, overrides grace). It is NOT the last `s = 0` input moment —
  grace already-credited as travel is never retro-converted.
- **Segment record (Decision (c)):** ordered `{from, to, classification, cause}` keyed by
  distance-along-route, contiguous (`segment[i].to == segment[i+1].from`), gap-free, merged across
  consecutive same-classification segments, split at the local-midnight rollover, persisted via the
  repository seam. `classification ∈ {active, idle}` (grace counts as active/travel for segments,
  consistent with grace-stays-travel); `cause ∈ {none, voluntary, lockSleep}`.
- **Tolerances:** time/distance equality within ±1e-6 (h / km), matching `journey-engine` cases. For
  AC-2, "divergence 0" is an **exact** equality of the two sampled values (no tolerance) because both
  derive from the same stamped accumulator.
- **Test layer:** all cases are deterministic unit tests under the engine's suite unless a note marks a
  case **Manual / audit** (TC-112's audit portion).

## Cases

### Case: Pre-fix repro pins the current whole-tick discrepancy (baseline)
**ID:** TC-100
**Priority:** P0
**Type:** regression
**Covers:** AC-2

Given the shipped engine *before* the Option B stamp is applied, and a scripted Active→Idle transition that lands strictly *inside* a tick interval (the user stops between two tick boundaries)
When the displayed idle counter (UI) and the engine's `idleTimeToday` accumulator are sampled at the next tick boundary
Then the test **records** that they diverge by up to one tick interval (the present whole-tick behaviour) — this captured value is the baseline the fix must drive to 0

**Notes:** Deterministic unit test. Implements Decision (a): the first `/implement` task pins present behaviour before "correct from that moment" lands. This case is expected to show divergence > 0 against the *pre-fix* engine and is then superseded by TC-104 (divergence == 0) on the fixed engine; keep it as a documented baseline / regression anchor, not a perpetual red test. Flag to `test-script-author`: implement as a snapshot of pre-fix behaviour, not an assertion that stays failing.

---

### Case: Idle onset honoured within one tick of an Active→Idle transition
**ID:** TC-101
**Priority:** P0
**Type:** happy-path
**Covers:** AC-1

Given a scripted Active→Idle transition at instant `T0` (the moment the engine reports the Idle state the UI shows — the `s > G` band crossing for voluntary idle)
When the run continues past `T0` for some elapsed wall-time `W`
Then `idleTimeToday` equals `W` (wall-time-since-`T0`) within at most one tick interval

**Notes:** Deterministic unit test. Use round deltas so `W` is exact (e.g. tick = 10s, run 6 ticks past `T0` ⇒ `W = 60s`). Assert `|idleTimeToday − W| ≤ one tick interval`. Pairs with TC-102 for the honesty half of AC-1.

---

### Case: Active/journey time never increases after the idle transition (honesty)
**ID:** TC-102
**Priority:** P0
**Type:** edge
**Covers:** AC-1

Given the engine has accrued `rawActiveTime` and `activeTimeToday` up to a scripted Active→Idle/Paused transition at `T0`
When the run continues past `T0` (idle/paused ticks only, no new genuine input)
Then `rawActiveTime` and `activeTimeToday` are **unchanged** — neither *increases* after `T0` — so any rounding/attribution residue favours idle, never active

**Notes:** Deterministic unit test. Snapshot both active accumulators at `T0`; after every post-`T0` tick assert they are exactly equal to the snapshot (never grew). This is the honesty invariant (spec L71–73, `journey-engine` L17/L110–111).

---

### Case: Lock/sleep transition anchors idle at the lock instant (immediate, overrides grace)
**ID:** TC-103
**Priority:** P0
**Type:** edge
**Covers:** AC-1

Given the engine is travelling within the grace band (`F < s ≤ G`) and the screen is reported **locked** (or a sleep-sized idle reading arrives) partway through, at instant `Tlock`
When the run continues past `Tlock`
Then idle accrual is anchored to `Tlock` (not the next grace/tick boundary): `idleTimeToday` equals wall-time-since-`Tlock` within one tick, AND `rawActiveTime`/`activeTimeToday` do not increase after `Tlock`

**Notes:** Deterministic unit test. Lock via `isScreenLocked() == true`; sleep variant via idle ≥ `sleepIdleThreshold`. Confirms Decision (d): lock/sleep onset is immediate and beats the grace window. Pairs with TC-109 (the segment-side assertion of the same event).

---

### Case: UI idle counter and accounting accumulator agree with divergence 0
**ID:** TC-104
**Priority:** P0
**Type:** happy-path
**Covers:** AC-2

Given a scripted Active→Idle transition landing strictly inside a tick interval (the same shape as the TC-100 baseline)
When, on the **fixed** Option B engine, the displayed idle counter and the engine's `idleTimeToday` accumulator are sampled at every tick boundary after the transition
Then the two values are **exactly equal at every sample** (max divergence 0) — the Option B state-change stamp closes the whole-tick gap that TC-100 recorded

**Notes:** Deterministic unit test. This is the direct fix of TC-100. Assert exact equality (no tolerance). **Flag (risky):** "what the UI would show" is defined here as `idleTimeToday` sampled at the same boundary; if the Bloc applies independent rounding before display, AC-2 must also be checked at the Bloc/widget layer (out of this pure-engine suite).

---

### Case: No cumulative drift across an Active↔Idle↔Paused↔Active sequence
**ID:** TC-105
**Priority:** P0
**Type:** edge
**Covers:** AC-2

Given a longer scripted sequence cycling Active → grace → Idle → Paused → (resume) Active → Idle → … with multiple transitions, some landing inside ticks
When the displayed idle counter and `idleTimeToday` are sampled at every tick boundary across the whole run
Then they agree (divergence 0) at **every** boundary and the difference never accumulates — no cumulative drift after many transitions

**Notes:** Deterministic unit test. Guards the "never drift apart cumulatively" half of AC-2. Use ≥ 4 transitions so any per-transition residue would compound visibly if present.

---

### Case: Divergence stays 0 when transitions land exactly on a tick boundary
**ID:** TC-106
**Priority:** P1
**Type:** edge
**Covers:** AC-2

Given a scripted Active→Idle transition whose state-change instant coincides **exactly** with a tick boundary (no sub-tick remainder)
When the idle counter and `idleTimeToday` are sampled at and after that boundary
Then divergence is 0 (the on-boundary case must not be double-counted or off-by-one relative to the inside-tick case TC-104)

**Notes:** Deterministic unit test. Boundary complement to TC-104 (inside-tick). Confirms the stamp logic is consistent whether the transition is on or inside a tick.

---

### Case: Segments cover the run end-to-end with no gaps and no overlaps
**ID:** TC-107
**Priority:** P0
**Type:** happy-path
**Covers:** AC-3

Given a scripted run mixing active, grace, idle, and paused stretches
When the ordered activity segments are replayed
Then they cover the full run from first to last instant with `segment[i].to == segment[i+1].from` for all `i` (contiguous, gap-free), no two segments overlap, and every point on the route maps to exactly one segment

**Notes:** Deterministic unit test. Assert contiguity pairwise across the ordered list and that the first segment's `from` == run start and the last segment's `to` == run end (distance-keyed: positions, not just times).

---

### Case: Summed segment durations equal the run's total elapsed time
**ID:** TC-108
**Priority:** P0
**Type:** happy-path
**Covers:** AC-3

Given a scripted run of known total elapsed time `E`
When the durations of all activity segments are summed
Then the sum equals `E` (within ±1e-6) — no time is lost or double-counted across the segment record

**Notes:** Deterministic unit test. Use round deltas so `E` is exact. Pairs with TC-107 (spatial contiguity) — together they assert lossless reconstruction in both time and distance.

---

### Case: Lock/sleep segment starts at the lock instant, not the next grace/tick boundary
**ID:** TC-109
**Priority:** P0
**Type:** edge
**Covers:** AC-4

Given a scripted run where, while travelling in the grace band, the screen is reported **locked** (or a sleep-sized idle reading arrives) at instant `Tlock`
When the segments are inspected
Then a **paused** segment begins exactly at `Tlock` — its `from` is the position/instant of the lock, NOT the next grace boundary or the next tick — and the prior segment ends at `Tlock`

**Notes:** Deterministic unit test. Segment-side mirror of TC-103. Assert the paused segment's `from == Tlock`'s position and that no travel segment extends past `Tlock`.

---

### Case: Voluntary idle ramp is classified idle with cause = voluntary
**ID:** TC-110
**Priority:** P0
**Type:** happy-path
**Covers:** AC-4

Given a scripted voluntary idle ramp: active → grace → idle → paused via rising idle-seconds (no lock, no sleep-sized reading)
When the segments are inspected
Then the active+grace span is a segment classified **active** (travel), and the post-`G` span is a segment classified **idle** with `cause == voluntary` (the band crossing `s > G`, not the lock/sleep path)

**Notes:** Deterministic unit test. Confirms cause tagging distinguishes the voluntary ramp from lock/sleep. Note grace counts as active/travel for the segment (grace-stays-travel), so the active segment extends through the grace span up to `s > G`.

---

### Case: Every segment carries the correct classification for its span
**ID:** TC-111
**Priority:** P0
**Type:** happy-path
**Covers:** AC-4

Given a scripted run with interleaved active, grace, voluntary-idle, and lock/sleep stretches
When each segment is compared against the per-tick band classification over its span
Then every segment's `classification` (active vs idle) matches the underlying band for the whole span it covers, and each idle/paused segment's `cause` is correct (`voluntary` vs `lockSleep`); no active span is mislabelled idle or vice versa

**Notes:** Deterministic unit test. Cross-checks the segment record against the engine's per-tick band decisions (TC-110 covers the voluntary case, TC-109 the lock/sleep case; this asserts the general correspondence across a mixed run).

---

### Case: Segment record is aggregate-only — no input content, no new OS signal
**ID:** TC-112
**Priority:** P0
**Type:** edge
**Covers:** NFR-1

Given the engine produces activity segments during a scripted run
When the segment record's fields are inspected and the engine's consumption of `ActivityPlugin` is reviewed
Then each segment carries ONLY aggregate fields (`from`/`to` positions or durations, `classification`, `cause`) — no keystrokes, no mouse coordinates, no window titles, no input content — and the engine consumes only `getSystemIdleSeconds()` + `isScreenLocked()` (no new `ActivityPlugin` method)

**Notes:** Unit-assertable subset: assert the segment data class exposes only the aggregate fields and that the mock `ActivityPlugin` records no calls beyond idle-seconds + lock. **Manual / audit (gate):** "no new OS signal introduced" and "`/privacy-audit` PASS" are a review/audit gate handled by `privacy-guardian` via `/privacy-audit` — not fully expressible as a unit assertion. Mark this case's audit portion accordingly.

---

### Case: Non-positive / backwards delta is clamped to zero — no accrual, no segment corruption
**ID:** TC-113
**Priority:** P0
**Type:** negative
**Covers:** NFR-2

Given the engine is mid-run and a `tick(delta)` arrives with `delta <= 0` (zero, or negative from clock skew / NTP step-back)
When that tick is processed
Then the tick is clamped to zero / ignored: `idleTimeToday`, `activeTimeToday`, `rawActiveTime`, and `distanceKm` are unchanged (never decrease), **no segment is opened, closed, or shifted**, attribution math is never undefined, and a subsequent positive-delta tick accrues normally

**Notes:** Deterministic unit test. Extends `journey-engine` TC-019 with the **segment-record** robustness (the new surface this slice adds): assert the segment list is byte-identical before and after the non-positive tick, and that the next positive tick continues the open segment correctly.

---

### Case: Each route point maps to exactly one segment (no ambiguous boundaries)
**ID:** TC-114
**Priority:** P1
**Type:** edge
**Covers:** AC-3

Given a scripted run whose segments share exact boundary positions (`segment[i].to == segment[i+1].from`)
When an arbitrary route position is queried against the segment record
Then it resolves to exactly one segment (boundary ownership is well-defined — a shared endpoint belongs to exactly one adjacent segment, never both, never neither)

**Notes:** Deterministic unit test. Pins boundary-ownership semantics so the downstream `map-experience` overlay can colour each position unambiguously. Test the exact-boundary position specifically.

---

### Case: Future stored date on restore does not reset or corrupt the segment record
**ID:** TC-115
**Priority:** P1
**Type:** negative
**Covers:** NFR-2

Given persisted state (including the segment record) whose **stored calendar date is later than** the injected clock's current local date (clock skew moved "today" backwards)
When a fresh engine restores that state
Then the engine treats the stored date as "today" and does **not** reset the daily counters, AND the persisted segment record restores intact (not cleared, not day-split spuriously) — clock skew never corrupts segments

**Notes:** Deterministic unit test against a fake/in-memory repository. Counter behaviour inherited from `journey-engine` TC-020; this case re-asserts only the **segment** robustness this slice introduces. Distinct from TC-117 (legitimate past-midnight split).

---

### Case: Grace minutes stay travel — never retro-converted to idle (no rollback)
**ID:** TC-116
**Priority:** P0
**Type:** edge
**Covers:** AC-1, AC-3

Given the user goes idle and accrues grace-band ticks (credited as travel: distance + journey + travel-classified segment), then crosses `s > G` into idle without returning to input
When the band-crossing tick is processed
Then the earlier grace span stays **travel** — `distanceKm`/`activeTimeToday` for the grace span are unchanged, the grace span remains an **active**-classified segment, and only the post-`G` span becomes a new **idle** segment (idle accrual starts at the crossing, going forward only)

**Notes:** Deterministic unit test. Implements Decision (d) / spec L68–70 grace-stays-travel for both accumulators **and** the segment record. Snapshot the grace segment before the crossing; assert it is unchanged afterward and a distinct idle segment is appended.

---

### Case: Local-midnight rollover splits an open segment at the boundary
**ID:** TC-117
**Priority:** P1
**Type:** edge
**Covers:** AC-3

Given a single activity segment that is open and accruing as the injected clock crosses **local midnight** (day N → day N+1)
When the rollover tick is processed
Then the segment is **split** at the midnight boundary — the day-N portion is closed at the boundary and a new contiguous segment opens for day N+1 (`split.to == split2.from`), so each day's `idleTimeToday` and segment record stay correct, and cumulative `distanceKm`/position is preserved

**Notes:** Deterministic unit test. Implements Decision (c) day-split. Script the clock from 23:59 day N to 00:00 day N+1. Assert contiguity is preserved across the split (no gap/overlap) and the daily counters reset per `journey-engine` TC-016.

---

### Case: Consecutive same-classification segments merge (growth bound)
**ID:** TC-118
**Priority:** P1
**Type:** edge
**Covers:** AC-3

Given a scripted run producing many consecutive ticks of the **same** classification and cause (e.g. a long uninterrupted active stretch, or a long uninterrupted voluntary-idle stretch)
When the segment record is inspected
Then the consecutive same-classification, same-cause ticks are represented by a **single merged segment**, not one segment per tick — the segment count grows with classification *changes*, not with tick count (growth is bounded)

**Notes:** Deterministic unit test. Implements Decision (c) growth-bound-by-merge. Feed N identical-classification ticks (large N) and assert the segment count is O(number of classification changes), not O(N). Verify a classification *change* still opens a new segment (no over-merging across active↔idle).

---

### Case: Segment record persists across restart and resumes contiguously
**ID:** TC-119
**Priority:** P1
**Type:** happy-path
**Covers:** AC-3

Given the engine has built up an activity-segment record and is saved via the repository seam (in-memory/JSON mock), same local day
When a fresh engine restores that state and the next tick is processed
Then the restored segment record equals the saved one, and the next tick **continues** the record contiguously from the restored position (`restored.last.to == nextSegment.from` if a new segment opens, or extends the open segment) — no gap, no duplicate, no reset

**Notes:** Deterministic unit test against a fake/in-memory repository. Implements Decision (c) persistence. Mirrors `journey-engine` TC-018 for the new segment surface. Assert no double-count and contiguity is maintained across the save/restore seam.

---

### Case: Mixed full-day sequence honours all idle-accounting invariants end to end
**ID:** TC-120
**Priority:** P1
**Type:** regression
**Covers:** AC-1, AC-2, AC-3, AC-4

Given a single scripted day mixing active, grace, a voluntary idle ramp, a lock/sleep interval, a resume, and a midnight rollover — all via the injected clock + mock
When the whole sequence is fed to one engine
Then at the end: (1) idle was anchored from each transition instant within one tick and active never increased after any transition (AC-1); (2) the UI idle counter and `idleTimeToday` agree with divergence 0 at every boundary (AC-2); (3) the segment record is contiguous, gap-free, day-split at midnight, and its durations sum to total elapsed (AC-3); (4) every segment carries the correct classification and cause, with the lock/sleep segment starting at the lock instant (AC-4)

**Notes:** Deterministic unit test. Integration-style composition check that the per-feature rules hold together over a realistic day on one engine. Use round numbers so all totals are exactly assertable (±1e-6, except AC-2 divergence which is exact 0).
