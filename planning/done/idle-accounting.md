# Idle accounting — engine idle-time correctness

**Promoted from backlog:** 2026-06-24
**Target:** Wave 2
**Shipped:** 2026-06-24
**Spec:** [specs/idle-accounting/](../../specs/idle-accounting/) (Status: shipped)
**Green report:** [tests/_runner/reports/idle-accounting/20260624-181801/](../../tests/_runner/reports/idle-accounting/20260624-181801/summary.md) (`verdict: green`, 602/602)

## Goal
Idle time counts from the moment the UI shows Idle/Paused, and the engine records ordered active-vs-idle
route segments (feeding the later idle-on-map overlay) — with UI and accounting never disagreeing.

## Phase ledger
The **single** status tracker — one row per phase.

| ✓ | Phase | Command | Date | Verdict / note |
|---|-------|---------|------|----------------|
| [x] | 2 · Spec | `/new-feature` → review & approve `spec.md` | 2026-06-24 | **APPROVED.** 4 AC + 2 NFR. Decisions: (a) repro = first build task · (b) **Option B** (whole-tick + state-change stamp, no ADR) · (c) distance-keyed/persisted/merged/day-split segments · (d) idle onset at `s>G` (lock/sleep immediate). |
| [x] | 3 · Build | `/implement` (includes self-review pass) | 2026-06-24 | **DONE.** Option B stamp + `ActivitySegment` record (distance-keyed, merged, day-split, persisted) in pure-Dart `JourneyEngine`; Cubit reconciled (`idleTimeToday` read verbatim). `fvm flutter analyze` clean; format gate clean; `fvm flutter test` **594 pass / 0 fail**. **Self-review:** 1 Blocking (B-1 `dart format` drift) **fixed**; non-blocking S-1..S-5/N-1..N-3 carried to `/review-code`. |
| [x] | 4 · Review | `/review-code` | 2026-06-24 | **verdict: READY** (after fix pass + re-review). First pass = changes requested (B-1 format, B-2 `idleSince` one tick late + S/N test gaps); all fixed → B-2 stamp = `_clock.now().subtract(delta)` (onset instant, exact consistency invariant proven), S-4/S-5/S-6 + nits closed. Re-review independently verified: analyze clean, format clean, **602/602 tests**, shipped engine suite 44/44 zero-diff, honesty invariant holds. **`/privacy-audit`: PASS** (one non-blocking Debug-only `network.server` entitlement; Release clean). |
| [x] | 5 · Test | `/execute-tests` | 2026-06-24 | **verdict: green.** `fvm flutter test --coverage` = **602/602** whole-package (no regressions) · **102/102** in-scope (TC-100..120 = 29, segment 7, progress 15, cubit 7, engine guard 44). No flakes. All P0 ACs `[x]` (NFR-1 ticked — privacy PASS). Report: `tests/_runner/reports/idle-accounting/20260624-181801/summary.md`. |
| [x] | 6 · Ship | `/ship` | 2026-06-24 | **SHIPPED.** Ship gate passed: all ACs `[x]`, no P0/P1 unimplemented, green report verified (`verdict: green`, postdates last commit). Spec → shipped; archived to `done/`. |

**Current phase:** ✅ Shipped (Wave 2 · S2)

## What shipped
- **Idle counts "from that moment"** via **Option B** (whole-tick + state-change timestamp): the displayed
  idle counter reads `idleTimeToday` verbatim, so UI and accounting agree exactly (AC-2 divergence 0). The
  shipped `journey-engine` whole-tick rule was left **byte-for-byte intact** (44/44 engine suite, zero diff) —
  no ADR needed.
- **`ActivitySegment` recording** — ordered, contiguous, gap-free `{fromKm, toKm, elapsed, classification,
  cause}` segments keyed by distance-along-route, persisted across restart, growth-bounded by merging
  consecutive same-classification segments, and split at the day boundary. cause ∈ {voluntary, lockSleep}.
  This is the **data contract for `map-experience` (#7)** idle-on-map red overlay.
- **`idleSince`** stamped at the onset instant (start of the triggering tick) as a forward display/#7
  contract anchor; honesty invariant holds (active/journey time never over-credited); `delta<=0`/clock
  step-back clamped to zero. Privacy: aggregate-only, no new OS signal, `/privacy-audit` PASS.

## What we'd do differently
- **`idleSince` is in-memory only (S-3).** If the app is killed mid-idle and relaunched same-day, the onset
  anchor restarts at the relaunch instant. Harmless today (no consumer reads it), but **`map-experience`
  (#7) is the first reader — persist `idleSince` as part of that slice before it ships.**
- **Segments carry no day key (S-1).** A tick straddling local midnight attributes its whole delta to the
  new day, so per-day idle is correct only to within one tick. Acceptable under Option B's tolerance;
  if #7 needs per-day attribution from segments, add a day marker then.
- The deferred-test-case step (`tests/cases/`) had to be run at `/implement` time because `/new-feature`
  defers it until after approval — fine, but worth remembering the ordering for the next slice.

## Decisions made along the way
- 2026-06-24: Captured (Phase 0, size M, single item).
- 2026-06-24: Approved with **Option B** — keeps the shipped engine rule intact, no ADR. Idle onset at `s>G` (lock/sleep immediate); segments distance-keyed/persisted/merged/day-split.
- 2026-06-24: Review fix pass — B-2 `idleSince` stamp corrected to the onset instant with an exact consistency invariant proven; B-1 format + S-4/S-5/S-6 + nits closed. Re-review verdict **ready**.
- **Carried to `map-experience` (#7):** persist `idleSince` (S-3); decide whether segments need a day key (S-1).
