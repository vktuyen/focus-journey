# Idle accounting

**Status:** shipped
**Owner:** Kevin
**Last updated:** 2026-06-24

## Problem
Idle time is mis-counted by the shipped `JourneyEngine`. The engine uses **whole-tick
classification** (`specs/journey-engine/spec.md` L77–81, L156–159): each tick's *entire* `delta` is
labelled active / grace / idle from the idle-seconds reading **at tick time**. The moment the user
actually stopped is therefore invisible to accounting — it snaps only at tick boundaries, and any
band boundary crossed *inside* a tick is attributed to whichever band the reading happened to land
in. Request #6 asks that once the UI shows **Idle/Paused**, idle be counted **from the moment the
state changed**, not from the next tick that happens to read idle. The UI counter and the accounting
accumulators can disagree by up to one tick interval (and by the whole grace window if "from that
moment" is read literally).

Separately, request #7 (the idle-on-map red overlay, delivered later in `map-experience`) needs
per-segment **active-vs-idle** data along the route. That ordered segment record does not exist yet,
so this slice must start producing it as a contract for the downstream overlay.

**Why now.** It is a small, high-felt correctness fix in pure-Dart domain code, and it is a hard
(blocking) prerequisite for `map-experience` (#7) — that overlay consumes the segment data this
slice introduces.

## User & outcome
- **The focused individual** — sees idle/active numbers that line up with what the UI showed. The
  observable change: the displayed idle counter and the engine's accounting never disagree, so the
  stat regains trust.
- **The privacy-skeptical teammate (the harder bar)** — the **honesty invariant** holds: raw
  active/journey time is **never over-credited** by tick boundaries. Any rounding/attribution change
  favours idle, never active (`specs/journey-engine/spec.md` L17, L110–111). The fix must
  demonstrably never *increase* credited active/journey time relative to today's behaviour.

## Scope
### In
- **Idle counted from the displayed Idle/Paused transition.** Once the engine reports the
  Active→Idle/Paused state change the user is shown, `idleTimeToday` accrual is anchored to that
  state-change instant (Option B — see Decisions), so the UI and accounting agree.
- **Ordered active-vs-idle segment recording.** A new ordered record of activity segments
  (`{start, end, classification, cause}`) along the route, contiguous and gap-free, recorded in the
  domain layer as the contract for the #7 red overlay.
- **Idle-cause tagging.** Each idle/paused segment records *why* it went idle — **voluntary** ramp
  (active→grace→idle→paused) vs **lock/sleep** (immediate paused, overrides grace) — so #7 can colour
  and treat them differently.
- **Reconciliation of the displayed idle counter** with the engine accumulators (Bloc reads only; no
  new screen).
- **Deterministic-clock repro** of the *current* discrepancy, captured before "correct from that
  moment" is finalised (S2 note, `wave2-feature-requests.md` L41/L62). (Tracked as Open question (a).)

### Out
- **The map overlay rendering itself** — painting idle stretches red on the map is `map-experience`
  (#7). This slice produces the segment data only.
- **Per-mode speeds / energy / fuel model** — that is `journey-energy-model`; distance accrual rate is
  unchanged here.
- **Raw signal acquisition** (idle-seconds / lock state) — shipped `activity-detection`; consumed
  unchanged via the injected `ActivityPlugin`.
- **The periodic ticker / app-layer driver** — wiring lives at the app layer; the engine is tested by
  feeding deltas directly.
- **Stats UI, streaks, badges, new screens.**

## Constraints & assumptions
- **Pure-Dart domain change inside `JourneyEngine`.** No `flutter`, `flame`, real `Timer`, or
  `DateTime.now()` in the engine. The change lands almost entirely in the existing framework-free
  engine file plus its repository seam.
- **Injected-clock testable & deterministic.** All behaviour is driven by a scripted clock and a mock
  `ActivityPlugin`; tests run with no real timers and no wall-clock waits.
- **Preserve grace-stays-travel** (`specs/journey-engine/spec.md` L131–132). Grace minutes already
  credited as travel are **not** rolled back; idle accrual starts at the band boundary going forward
  and does not retro-convert grace to idle.
- **Honesty invariant (hard gate).** Any rounding or attribution change MUST favour idle, never
  active — the two separate accumulators (journey time vs raw active time) are never conflated and
  active time is never over-credited (`specs/journey-engine/spec.md` L17, L110–111).
- **Privacy by construction.** No new OS signal; the engine still sees only aggregate idle duration +
  lock state via `ActivityPlugin`. Segment records are aggregate (durations/positions + classification
  + cause), never input content.
- **Re-run, don't replace, the shipped engine test suite.** Option B keeps the whole-tick rule intact,
  so the existing engine suite must continue to **pass unchanged**; new behaviour is added via new
  tests, not by amending the resolved rules. (No ADR required — see Decisions (b).)

## Acceptance criteria
Each item is a checkable, observable statement and the ship gate, driven by a **deterministic
(scripted) clock** and a mock `ActivityPlugin`. These ACs ARE the contract — `tests/cases/idle-accounting.md`
references them by ID.

- [x] **AC-1 (idle onset honoured within one tick):** Given a scripted Active→Idle/Paused transition
      at instant `T` (the moment the engine reports the state the UI shows), When the run continues
      past `T`, Then `idleTimeToday` equals wall-time-since-`T` within at most one tick interval, AND
      the credited active/journey time never *increases* after `T` (honesty: rounding favours idle).
- [x] **AC-2 (UI and accounting agree):** Given any scripted sequence of Active↔Idle↔Paused
      transitions, When sampled at every tick boundary, Then the idle counter the UI would show and the
      engine's accounting accumulator agree with **max divergence 0** (Option B state-change stamp —
      see Decisions), AND they never drift apart cumulatively over the run.
- [x] **AC-3 (segments reconstruct the route losslessly & contiguously):** Given a scripted run, When
      the ordered activity segments are replayed, Then they cover the full run end-to-end with no gaps
      and no overlaps — each point maps to exactly one segment, `segment[i].to == segment[i+1].from`
      for all `i`, and the summed segment durations equal the run's total elapsed time.
- [x] **AC-4 (segment labels correct & cause-tagged):** Given a scripted run including a voluntary idle
      ramp and a lock/sleep event, When the segments are inspected, Then every segment carries the
      correct active/idle classification for its span, each idle/paused segment records its cause
      (voluntary vs lock/sleep), AND a scripted lock/sleep event produces a paused segment starting at
      the lock/sleep instant — not at the next grace or tick boundary.

### Non-functional
- [x] **NFR-1 Privacy:** No new OS signal is introduced — the engine still consumes only aggregate
      idle-seconds + lock state via `ActivityPlugin`; segment records are aggregate-only (no input
      content). `/privacy-audit` still returns PASS. _(PASS — `/privacy-audit` 2026-06-24; TC-112 unit subset green.)_
- [x] **NFR-2 Robustness (clock skew / non-positive delta):** Behaviour on `delta <= 0` (NTP
      step-back / clock step-back) and on a future stored date is **defined and tested** — a
      non-positive delta is clamped to zero with no idle (or active) accrual, and attribution math is
      never undefined under clock skew.

## Decisions (resolved at approval, 2026-06-24)
> All four pre-approval open questions are resolved. Kevin delegated the call ("just do as your
> recommendation"); decisions below are the recommended, lower-risk options.

- [x] **(a) Capture a repro of current behaviour — YES, first build task.** `/implement` opens with a
      deterministic-clock test that pins the *present* whole-tick discrepancy, so "correct from that
      moment" is anchored to observed behaviour before the fix lands. (S2 note, `wave2-feature-requests.md`
      L41/L62.)
- [x] **(b) Attribution model → Option B (whole-tick + state-change timestamp).** Keep whole-tick
      accounting; stamp the Active→Idle/Paused transition and anchor the displayed idle counter to that
      instant so UI and accounting agree exactly (AC-2 divergence 0). **Rationale:** does **not** revise
      the shipped/approved `journey-engine` whole-tick rule (L77–81) or `rawActiveTime`-during-grace
      decision (L156–159) — so **no ADR and no regression risk to the engine suite** — and avoids the
      clock-skew sensitivity sub-tick math (Option A) introduces. Accepted trade-off: a ≤ one-tick
      residue in the raw accumulators, negligible at the engine's tick rate, and never over-crediting
      active time (honesty invariant holds).
- [x] **(c) Segment storage → distance-keyed, persisted, growth-bounded, day-split.** Segments are
      keyed by **distance-along-route** (so `map-experience` #7 paints by position), **persisted across
      restart** alongside existing journey state via the current repository seam, **growth-bounded by
      merging consecutive same-classification segments**, and **split at the day-boundary rollover**
      (`journey-engine` L84–88) so each day's `idleTimeToday` stays correct. This shape is the contract
      for `map-experience` (#7).
- [x] **(d) Idle-onset instant → the band crossing (`s > G`) for voluntary idle; the lock/sleep instant
      (immediate) for lock/sleep.** I.e. "from the moment the UI flips to Idle/Paused" — not the last
      real-input `s = 0` moment. Preserves grace-stays-travel (grace minutes already credited are not
      retro-converted).

## Related
- Backlog (Phase 0): [planning/backlog/idle-accounting.md](../../planning/backlog/idle-accounting.md)
- Upstream engine (shipped): [specs/journey-engine/spec.md](../journey-engine/spec.md) — whole-tick rule L77–81, `rawActiveTime`-during-grace L156–159, grace-stays-travel L131–132, day rollover L84–88, `delta<=0` open question L152–155, honesty invariant L17/L110–111
- Upstream signal (shipped): [specs/activity-detection/spec.md](../activity-detection/spec.md) — `ActivityPlugin` idle-seconds + lock state
- Downstream consumer: `map-experience` (#7 idle-on-map red overlay) — `[blocked by: idle-accounting]`
- Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md)
- Architecture: [docs/architecture/overview.md](../../docs/architecture/overview.md)
