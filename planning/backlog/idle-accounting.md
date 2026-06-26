# Idle accounting

**Intake date:** 2026-06-24
**Requested by:** Kevin
**Size (rough):** M
**Part of epic:** [Wave 2 feature requests](wave2-feature-requests.md) · S2

## Raw idea (verbatim)
Idle time isn't captured correctly — when the app shows **Idle/Paused**, idle time should count
**from that moment** (req #6). Also **record active-vs-idle segments** along the route so they can be
visualised later (feeds the idle-on-map red overlay, req #7, delivered in `map-experience`).

## Why
**The problem.** Idle time is mis-counted. Today the `JourneyEngine` uses **whole-tick
classification** (`specs/journey-engine/spec.md` L77–81, L156–159): each tick's *entire* `delta` is
labelled active / grace / idle from the **idle-seconds reading at tick time**. So the moment the
user actually stopped is invisible — accounting snaps only at tick boundaries, and the time that
crosses a band boundary inside one tick is attributed to a single band. With the default
`G = T = 5 min` grace, the first ~5 min after stopping still accrues travel (correct *by design*),
but req #6 asks that once the UI shows **Idle/Paused**, idle should be counted **from the moment
the state changed**, not from the next tick that happens to read idle. The two views disagree by up
to one tick interval (and by the whole grace window if "from that moment" is read literally).

**Who feels it.** The **focused individual** sees idle/active numbers that don't line up with what
the UI showed (lost trust in the stat). The **privacy-skeptical teammate** is the harder bar — any
gap that *over-credits* active time directly contradicts the headline honesty rule
(`specs/journey-engine/spec.md` L17, L110–111: raw active time must never overstate real work).

**Why now.** It is a small, high-felt correctness fix in pure-Dart domain code, and it is a
**hard prerequisite for the idle-on-map red overlay (#7)** in `map-experience` — that overlay needs
per-segment active-vs-idle data this slice must start recording. Blocking dependency for S4.

## Domain notes
**Personas touched:** the focused individual (sees the corrected idle/active split) and the
privacy-skeptical teammate (honesty: no over-credit). No new persona.

**What "from that moment" must precisely mean — needs a decision (flag for `/new-feature`):**
- **Option A — sub-tick attribution:** when a tick straddles a band boundary, split the `delta` and
  attribute each portion to its band (idle starts at the inferred transition instant, not the tick
  edge). Most "honest"; requires reconstructing *when within the tick* the transition happened from
  the idle-seconds reading (idle-seconds itself encodes "seconds since last input", so the transition
  time is derivable, not guessed).
- **Option B — state-change timestamp:** keep whole-tick accounting but stamp the
  Active→Idle/Paused transition and report idle "from that moment" in the *displayed* counter, so UI
  and accounting agree. Cheaper; may leave a fraction-of-a-tick discrepancy in the raw accumulators.
- This choice is a **possible conflict with the shipped `journey-engine` whole-tick rule** (its Open
  Question on `rawActiveTime`-during-grace was resolved *for* whole-tick, L156–159). Sub-tick
  attribution would revise that resolved decision — must be surfaced, not silently overridden.

**Key edge cases:**
- **Transition timing Active↔Idle↔Paused.** Does idle count from the band crossing (`s > G`), or
  from the user's last real input (`s = 0` moment)? The grace window means these differ by `G`.
  Req #6 likely means "from when the UI flipped to Idle/Paused" = the `s > G` crossing — confirm.
- **Grace-stays-travel invariant.** `journey-engine` resolved (L131–132) that grace minutes already
  credited as travel are **not** rolled back. "Count idle from that moment" must not reopen this —
  idle accrual starts at the band boundary going forward, it does not retro-convert grace to idle.
- **Sleep/lock vs voluntary pause.** Sleep is *inferred* from a large idle reading or screen lock
  (no sleep boolean — L54, L74–76); these jump straight to **paused** and override grace immediately.
  A voluntary user idle ramps through active→grace→idle→paused. The "from that moment" instant
  differs: lock/sleep = immediate; voluntary = at the `G` (idle) / `T` (paused) crossings. The
  recorded segments must distinguish *why* it went idle if #7 wants to colour them.
- **Clock changes / non-positive delta.** `journey-engine` has an **open** robustness question
  (L153–155) on `delta <= 0` (NTP step-back) and future stored dates. Sub-tick attribution math is
  sensitive to clock skew — this slice should pin that down (recommend: clamp non-positive delta to
  zero, no idle accrual).
- **Day-boundary rollover.** A transition that straddles local midnight: which day's `idleTimeToday`
  gets the time, and how do recorded segments span the reset (L84–88)?
- **Segment recording for #7 (feeder scope).** Need a new ordered record of `{from-distance/time,
  to-distance/time, classification}` so the map can later paint idle stretches red. Open: keyed by
  distance-along-route or by wall-clock time? Retained how long / persisted across restart? Capped?

**Repro first.** S2 note (`wave2-feature-requests.md` L41, L62) requires capturing the *current*
behaviour before defining "correct" — the spec must include a deterministic-clock repro showing the
present discrepancy.

## Candidate domain updates
> Flags only — commitment-free. `docs/domain/` is currently empty (glossary + business-rules are
> placeholder templates); these are the first candidate entries this slice surfaces.

- [ ] candidate glossary term: **Idle onset / "from that moment"** — the precise instant idle time
      begins counting (band crossing `s > G` vs last-input instant vs lock/sleep instant).
- [ ] candidate glossary term: **Activity segment** — an ordered active-vs-idle stretch along the
      route (`{start, end, classification}`) recorded for later visualisation (#7 red overlay).
- [ ] candidate glossary term: **Whole-tick vs sub-tick attribution** — how a `delta` straddling a
      band boundary is split (or not).
- [ ] candidate business rule: idle time MUST be counted from the state-change instant the user is
      shown (Idle/Paused), with accounting and UI agreeing — testable against a deterministic clock.
- [ ] candidate business rule (honesty invariant, restated): active/journey time MUST NOT be
      over-credited by tick boundaries; any rounding favours idle, never active.
- [ ] candidate business rule: lock/sleep-induced idle and voluntary idle are recorded with distinct
      cause so downstream (#7) can treat them differently.
- [ ] **CONFLICT to resolve:** sub-tick attribution (Option A) would amend the shipped
      `journey-engine` whole-tick rule (`spec.md` L77–81) and its resolved `rawActiveTime`-during-grace
      decision (L156–159). Decide whether to keep whole-tick + Option B, or formally revise the rule.

## Feasibility (high-level)
**Architectural fit — good.** This is pure-Dart **domain** work inside the shipped `JourneyEngine`
(`docs/architecture/overview.md` Components; Clean Architecture + Bloc). The engine already takes an
**injected clock** and **injected `ActivityPlugin`**, advances on caller-supplied elapsed deltas, and
is fully unit-testable with no real timers — exactly the seam this change needs. No new external
dependency, no network, no native code. The only new surface is the activity-segment record, which
fits the existing `data` persistence seam (`shared_preferences`/JSON, or kept in-memory if #7 only
needs the current session). Presentation impact is limited to making the displayed idle counter agree
with the engine (Bloc reads, no new screens). So the work lands almost entirely in one already-tested,
framework-free file plus its repository.

**Rough effort — M.** Not S because it is **not** a localized bug fix: it reopens load-bearing,
already-*resolved* accounting rules (whole-tick attribution, `rawActiveTime`-during-grace, grace-stays-
travel) and adds a brand-new ordered segment data model with its own retention/keying/persistence
questions plus a deterministic-clock repro harness. Not L/XL because there is no new subsystem, no UI
surface, no native or network work — it is bounded, pure-Dart domain logic on an existing engine with
an existing test rig. The bulk of the cost is correctness reasoning + exhaustive deterministic tests
(transition timing, lock/sleep vs voluntary, day-rollover, clock skew), not volume of code.

**Key risks.**
- **Touching shipped / resolved engine rules.** The whole-tick classification (`journey-engine` spec
  L77–81) and the resolved `rawActiveTime`-during-grace decision (L156–159) are load-bearing and were
  explicitly approved. Option A (sub-tick attribution) *revises* a resolved decision — it must be a new
  ADR superseding/amending the rule, never a silent override. Regression risk to the existing engine
  test suite is the dominant risk; that suite must be re-run and extended, not replaced.
- **Whole-tick vs sub-tick (Option A vs B) is the pivotal decision.** Option B (keep whole-tick, add a
  displayed state-change timestamp so UI + accounting agree) is markedly cheaper and lower-risk but may
  leave a sub-tick discrepancy in the raw accumulators. Option A is most honest but raises clock-skew
  sensitivity and reopens resolved rules. Effort/risk diverge sharply by choice — decide at `/new-feature`.
- **Clock-skew sensitivity.** Sub-tick attribution math depends on the idle-seconds-derived transition
  instant and on positive deltas; the engine's `delta <= 0` / future-stored-date robustness is still an
  **open** question (`journey-engine` spec L152–155). This slice should pin it down (recommend: clamp
  non-positive delta to zero, no idle accrual) — otherwise sub-tick math is undefined under NTP step-back.
- **Honesty invariant.** Any rounding/attribution change MUST favour idle, never over-credit active
  (`journey-engine` spec L17, L110–111). This is the privacy-skeptical-teammate bar and the hardest
  acceptance gate; the repro must show the fix never *increases* credited active/journey time.
- **Segment storage.** Keying (distance-along-route vs wall-clock), retention (session-only vs persisted
  across restart), cap/growth bound, day-rollover spanning, and recording the idle *cause* (lock/sleep vs
  voluntary) for #7's colouring are all undecided — these drive the data model and the persistence footprint.

**Downstream dependency.** `map-experience` (S4) **depends on the segment data this slice produces** for
the idle-on-map red overlay (#7). The segment record's shape, keying, and cause-tagging are effectively
a contract for S4 — get the model right here or S4 inherits rework. This is why the slice is a hard
(blocking) prerequisite for S4.

## Candidate ADRs
> Flags only — commitment-free. Do NOT write these now; they are surfaced for `/new-feature` / `/add-adr`
> if this slice is promoted. Several would amend the **shipped, resolved** `journey-engine` accounting
> rules and so MUST be explicit ADRs (supersede/amend, never silent override).

- [ ] **Idle-attribution model: whole-tick vs sub-tick (Option B vs Option A).** If sub-tick is chosen,
      this ADR **revises the resolved `journey-engine` whole-tick rule** (spec L77–81) and its resolved
      `rawActiveTime`-during-grace decision (L156–159) — must supersede/amend, citing the honesty invariant.
- [ ] **Definition of "idle onset / from that moment".** Pin the precise instant idle counting begins
      (band crossing `s > G` vs last-real-input instant vs lock/sleep instant) and how the *displayed*
      counter is reconciled with the engine accumulators so UI and accounting agree.
- [ ] **Activity-segment storage model & retention.** Record shape (`{start, end, classification, cause}`),
      keying (distance-along-route vs wall-clock), persistence (session-only vs across restart), cap/growth
      bound, and day-rollover spanning — this is the contract `map-experience` (S4, #7) consumes.
- [ ] **Idle-cause tagging (lock/sleep vs voluntary).** Whether segments carry a cause discriminator so #7
      can colour/treat lock-sleep idle differently from voluntary idle — affects the segment schema above.
- [ ] **Clock-skew / non-positive-delta robustness (resolves `journey-engine` open question L152–155).**
      Define behaviour on `delta <= 0` (NTP step-back) and future stored dates under sub-tick math
      (recommend: clamp non-positive delta to zero, no idle accrual). Pins a currently-open engine question.

## Headline success signals
> Observable, testable indicators of success — driven by a deterministic (scripted) clock.

- **Idle onset is honoured.** Given a scripted Active→Idle/Paused transition at instant `T` (the
  moment the UI flips to Idle/Paused), `idleTimeToday` equals wall-time-since-`T` within one tick
  interval — and the credited active/journey time never *increases* after `T` (honesty: rounding
  always favours idle, never active).
- **UI and accounting never disagree.** Across any scripted sequence of Active↔Idle↔Paused
  transitions, the idle counter shown in the UI and the accounting accumulator agree exactly at every
  tick boundary (max divergence 0 with Option B's state-change stamp; ≤ one tick sub-tick residue if
  Option A is chosen) — they never drift apart cumulatively over a run.
- **Segments reconstruct the route losslessly.** The ordered active-vs-idle segments replay to cover
  the full route end-to-end with no gaps and no overlaps: each point on the route maps to exactly one
  segment, segment boundaries are contiguous (`segment[i].to == segment[i+1].from`), and the summed
  segment durations equal the run's total elapsed time.
- **Segment labels are correct and cause-tagged.** Every segment carries the right active/idle
  classification for its span, and idle segments record *why* they went idle (voluntary ramp vs
  lock/sleep), so the later #7 red-overlay can paint and distinguish them; a scripted lock/sleep event
  produces a paused segment starting at the lock instant, not at the next grace/tick boundary.

## Signals
**Ready to promote now** — all dependencies are shipped (`[blocked by: journey-engine ✅]`); no open
blocker prevents starting the spec. Two decisions must be **settled during `/new-feature` / `/capture-idea`
intake** (they don't block promotion, but the spec can't be approved without them):
1. **Capture a repro first** — a deterministic-clock test demonstrating the *current* discrepancy, so
   "correct from that moment" is defined against observed behaviour (S2 note, `wave2-feature-requests.md` L41/L62).
2. **Pick the attribution model** — Option B (whole-tick + state-change timestamp, cheaper/lower-risk)
   vs Option A (sub-tick, most honest but revises a resolved engine rule). See Candidate ADRs.

**Downstream:** `map-experience` (S4, idle-on-map #7) is `[blocked by: idle-accounting]` — the segment
record shape defined here is a contract for S4, so land the model deliberately.

## First step
Run `/new-feature idle-accounting` to promote this into a spec bundle.
