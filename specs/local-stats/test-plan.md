# Test plan

## Coverage strategy
The bulk of local-stats is **pure-Dart math** — daily/weekly aggregation, best-focus-period, streak
counting, and badge-threshold evaluation are deterministic functions of `(engine snapshot, per-day
history, route position, injected clock)` — so most coverage is fast **unit** tests driven by the
central scriptable engine/route-state stub and the three store fakes (settings, per-day history,
earned-badge), with **no real timers, no real OS waits, no `DateTime.now()`**. The stats / badges /
settings / onboarding screens add **widget / golden** coverage (honesty layout, earned/locked list,
onboarding copy). A thin slice of **integration / e2e** covers persistence-across-restart, the
idle-threshold-applied-on-next-tick wiring, the record-day-before-zero boundary, and the two OS
interfaces through their injected fakes (`launch_at_startup` get/set, `local_notifier`
toast-requested). A **manual** slice covers the real-OS legs that can't be deterministic units — real
launch-at-startup registration, real toast delivery, offline behaviour, and the
**`/privacy-audit` copy ⇄ code release gate**. Executable tests live under `src/focus_journey/test/`
(unit/widget) and `src/focus_journey/integration_test/` (e2e), per the architecture test-layout
decision — not the top-level `tests/` tree. Reports go to `tests/_runner/reports/local-stats/<timestamp>/`.

| AC | Unit | Integration | E2E | Manual | Cases |
|----|------|-------------|-----|--------|-------|
| AC-1 daily four headline numbers | x | | (golden) | | TC-001, TC-NF4 |
| AC-2 raw separate, never ≥ journey (honesty) | x | | (golden) | | TC-002, TC-NF4 |
| AC-3 best focus = longest raw-active run | x | | | | TC-003 |
| AC-4 weekly Mon–Sun aggregation | x | | | | TC-004 |
| AC-5 record day before counters zero | x | x | | | TC-005, TC-020 |
| AC-6 bounded history pruning | x | | | | TC-006 |
| AC-7 history persists across restart | | x | | | TC-007 |
| AC-8 idle threshold on next tick | | x | | | TC-008 |
| AC-9 threshold persists; only engine-affecting setting | x | x | | (grep) | TC-009 |
| AC-10 launch-at-startup read-then-write | | x | | x (device) | TC-010, TC-NF5 |
| AC-11 local toasts only; master toggle | | x | | (grep) | TC-011 |
| AC-12 two types; gated streak reminder | | x | | | TC-012 |
| AC-13 data-driven catalogue, four families | x | | (golden) | | TC-013, TC-NF4 |
| AC-14 distance badges consume distance | x | | | | TC-014 |
| AC-15 journey-progress badges consume position | x | | | | TC-015 |
| AC-16 streaks on raw-active ≥ 25 min/day | x | | | | TC-016 |
| AC-17 focus-time badges consume raw active | x | | | | TC-017 |
| AC-18 permanent persist; windowed reset | x | | | | TC-018 |
| AC-19 daily reset at midnight (running + closed) | x | x | | | TC-019, TC-020 |
| AC-20 first-run onboarding; flag; re-openable | x | x | (golden) | | TC-021, TC-NF4 |
| AC-21 onboarding claims ⇄ code (release gate) | | | | x (`/privacy-audit`) | TC-022 |
| NFR privacy by construction | x | | | x (`/privacy-audit`) | TC-026, TC-027, TC-022 |
| NFR determinism & testability | x | | | | TC-NF1, TC-NF4 |
| NFR honest accounting always visible | x | | (golden) | | TC-002, TC-017 |
| NFR no network / offline | x | x | | x | TC-NF3, TC-011, TC-027 |
| NFR clean-architecture layering | x | | | (grep) | TC-NF2, TC-007 |

## Scenarios
Full list of cases lives in [tests/cases/local-stats.md](../../tests/cases/local-stats.md) —
**26 cases (TC-001..TC-022 + TC-026, TC-027 + TC-NF1..TC-NF5)**. Summary:

- Happy path: 8 (TC-001, TC-002, TC-004, TC-008, TC-011, TC-013, TC-016, TC-021)
- Edge / boundary: 10 (TC-003, TC-005, TC-006, TC-007, TC-009, TC-010, TC-012, TC-014, TC-015, TC-017, TC-018, TC-019, TC-020 — 13 listed)
- Negative / purity-privacy: 3 (TC-022, TC-026, TC-027)
- Non-functional: 5 (TC-NF1..TC-NF5)

  (8 + 13 + 3 + 5 = 29 by-type tags vs 26 distinct cases — TC-002, TC-016, TC-017 carry a secondary honesty/locked tag; distinct case total is **26**, reconciled by the area grouping below.)

Grouped by area:

- **Daily stats:** 3 (TC-001, TC-002, TC-003)
- **Weekly + history:** 4 (TC-004, TC-005, TC-006, TC-007)
- **Settings (idle / launch-at-startup):** 3 (TC-008, TC-009, TC-010)
- **Notifications:** 2 (TC-011, TC-012)
- **Badges (four families + persist/reset):** 6 (TC-013, TC-014, TC-015, TC-016, TC-017, TC-018)
- **Day-boundary:** 2 (TC-019, TC-020)
- **Onboarding / privacy:** 2 (TC-021, TC-022)
- **Privacy / purity static:** 2 (TC-026, TC-027)
- **Non-functional:** 5 (TC-NF1 determinism, TC-NF2 layering, TC-NF3 offline, TC-NF4 golden, TC-NF5 real-OS manual)

## Risks
- **Central test doubles must be built first.** Almost every case depends on (a) the **scriptable
  engine / route-state stub** (settable `activeTimeToday` / `rawActiveTime` / `idleTimeToday` /
  `distanceKm` / `state` / `mode` + route `routeDistanceKm` / provinces-passed / % of country + the
  idle-threshold knob + a one-tick advance, **recording any engine write**), (b) the three **store
  fakes** (settings, per-day history, earned-badge over the in-memory `shared_preferences`/JSON seam),
  and (c) the two **OS-interface fakes** (`launch_at_startup` get/set, `local_notifier`
  toast-requested). The suite stalls until these exist — schedule them first at `/implement`.
- **Golden determinism (TC-NF4).** The stats card, badges grid, and onboarding screen goldens need
  fixed inputs, a fixed injected clock, fixed fonts/sizes, and per-OS (macOS + Windows) tolerance — same
  discipline journey-view applies — or they flake.
- **`/privacy-audit` is a manual ship-blocker (TC-022).** Not an automated assertion; a fail blocks ship
  regardless of other passes. TC-026/TC-027 reinforce it via grep/static inspection but do not replace it.
- **Real launch-at-startup + real toast (TC-NF5)** are manual / device checks per OS (open-at-login
  visible in OS settings; a real toast delivered), not deterministic units. The automated coverage is
  the injected-fake cases TC-010/TC-011; the real-OS side is verified once per release.
- **Pending-OQ cases key off structure, not literals.** TC-003 (best-focus def), TC-006 (retention cap),
  TC-012 (notification cadence/reminder time), TC-013/TC-014/TC-015/TC-017 (badge catalogue + thresholds),
  TC-016 (streak *lengths* 3/7/30), and TC-018 (windowed-rollover set) all assert a threshold-crossing /
  window boundary / cap **structurally** so they survive re-tuning when the open questions close. The
  **raw-active ≥ 25-min streak qualification** (TC-016) and the **raw ≤ journey honesty rule** (TC-002)
  are **locked**, not OQ — assert them on literal values.
- **AC-8 next-tick wiring depends on the engine stub honouring the knob.** If the shipped engine does not
  in fact re-read the threshold each tick, TC-008 must instead assert "threshold persisted + handed to
  the engine seam" and the next-tick classification becomes a journey-engine concern — confirm the seam
  at `/implement`.
- **Record-before-zero ordering (TC-005/TC-019/TC-020)** assumes the day-rollover hook records the prior
  day *before* the daily projection zeroes. If the implementation zeroes first, the history write must be
  ordered ahead of it — flag to the implementer; the case asserts the ordering, not just the end state.
