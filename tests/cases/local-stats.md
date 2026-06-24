# Test cases: local-stats

Spec: [specs/local-stats/spec.md](../../specs/local-stats/spec.md)
Acceptance criteria: [specs/local-stats/acceptance-criteria.md](../../specs/local-stats/acceptance-criteria.md)
Upstream (shipped): [specs/journey-engine/spec.md](../../specs/journey-engine/spec.md) — exposes `distanceKm`, `activeTimeToday` (= journey time, incl. grace), `rawActiveTime` (true input, no grace), `idleTimeToday`, `state`, `mode`; AC-15 (streak metric = raw active time ≥ 25 min/day) and AC-9/AC-10 (local-midnight day boundary, incl. app-closed-across-midnight).
Upstream (shipped): [specs/route-progress/spec.md](../../specs/route-progress/spec.md) — exposes `routeDistanceKm`, provinces passed, % of country (the journey-progress badge inputs).
Sibling consumer (shipped): [specs/journey-view/spec.md](../../specs/journey-view/spec.md) — the pure-consumer / privacy-invariant pattern these cases mirror.

## Scope of these cases

These cases verify the **v1 user-facing surface** — daily/weekly **stats**, **settings**
(idle threshold + launch-at-startup + notifications), **milestone badges** (four families),
**day-boundary reset of the surfaces**, and the **onboarding / privacy** screen — as a **near-pure
consumer** of the shipped `journey-engine` scalars and `route-progress` position. The slice owns
**presentation** (stats / settings / badges / onboarding screens + their Cubits/Blocs), three small
local stores on the existing `shared_preferences`/JSON seam (a **settings** store, a **bounded per-day
history** store, an **earned-badge** store), the **badge catalogue (as data)**, the **stat / weekly /
streak math** (pure functions), and the onboarding copy. It exercises two new OS interfaces through
injected fakes: **launch-at-startup** (`launch_at_startup`) and **notifications** (`local_notifier`,
local toasts only). They verify the **headline honesty rule** (raw active time shown separately from
and never ≥ journey time), **local-calendar-week (Mon–Sun)** aggregation, the **record-day-before-zero**
boundary, **bounded history**, **persistence round-trips**, the **idle-threshold knob applied on the
engine's next tick**, **notification gating** (master toggle + local-only + no-nag + not-while-active),
all four **badge families** crossing thresholds with **permanent-vs-windowed** reset, **streaks on the
locked raw-active ≥ 25 min/day rule**, **first-run onboarding** + re-openable + persisted flag, and the
**`/privacy-audit` copy ⇄ code release gate**.

They deliberately do NOT re-exercise: active/idle judgment, the grace/threshold model, distance
accrual, the `kmPerActiveHour` rate, sleep/wake, or the engine's own midnight-rollover accounting (all
`journey-engine`, tested there — this slice only *reads* the resulting scalars and *sets* the idle
threshold the engine already supports); the province chain / position math / map paint
(`route-progress`); the POV road scene (`journey-view`); per-mode speeds / energy
(v2 `journey-energy-model`); tray / mini-window (v2 `mini-window`); any cloud / account / push (v2+).

## The locked decisions these cases encode (Kevin, 2026-06-24 — do not re-open)

1. **Settings scope = full set:** idle threshold + launch-at-startup + **notifications** (local OS
   toasts via `local_notifier`; launch-at-startup via `launch_at_startup`). All three are exercised.
2. **Stats history model = local calendar week (Mon–Sun) + a bounded per-day JSON history** (~90 days
   default) on the existing `shared_preferences`/JSON seam. Weekly stats + streak counting read from
   this store. *(The ~90-day cap is the pending-OQ literal; cases key off "never exceeds the cap".)*
3. **Badge families = all four:** distance, journey-progress, focus-streaks, focus-time, defined as a
   **data-driven catalogue** (not hardcoded control flow). *(Per-badge thresholds are pending OQ; cases
   key off catalogue structure + threshold-crossing, not literal numbers.)*
4. **Streak qualification = raw active time ≥ 25 min/day** — inherited locked rule (journey-engine
   AC-15). Streaks are counted here from the daily-history store; the rule is **not** re-opened. The
   `25` is a fixed constant referenced by the case, **not** a pending OQ (only the streak *lengths*
   3/7/30 are pending).

## Conventions used by these cases

- **No real timers, no real OS waits, no `DateTime.now()`.** Day-boundary and "current calendar week
  (Mon–Sun)" logic key off an **injected clock**; stat / weekly / streak / best-focus math are **pure
  functions** of `(engine snapshot, per-day history, route position)`. Cases set the clock and the
  inputs directly and assert the projection — mirroring the engine's framework-free discipline.

- **Scriptable engine / route-state stub.** The engine + route-progress are replaced by a
  **deterministic, scriptable stub** exposing settable `activeTimeToday`, `rawActiveTime`,
  `idleTimeToday`, `distanceKm`, `state`, `mode` and route `routeDistanceKm` / provinces-passed /
  % of country, **plus a settable idle-threshold knob and a one-tick advance** (for AC-8). Cases set
  the snapshot and read the projection; the stub records any write to engine state (none expected).

- **Three store fakes + two OS-interface fakes.** The **settings**, **per-day history**, and
  **earned-badge** stores are faked in-memory over the `shared_preferences`/JSON seam (a "restart" =
  construct a fresh Bloc/Cubit that restores from the saved blob — no new store type, no `drift`).
  The **launch_at_startup** interface (get/set open-at-login) and the **local_notifier** interface
  (toast-requested) are faked, recording reads/writes/toast-requests — no real OS registration and no
  real toast in automated tests.

- **Structure, not literals (pending-OQ cases).** Where a case rests on a spec Open question — the
  exact badge catalogue/thresholds, notification cadence, the precise best-focus-period definition, the
  retention cap, or the windowed-rollover set — the assertion keys off **structure** (a threshold
  crossing, a window boundary, a cap, "fires once / gated"), **never** the literal number, and the case
  notes the pending-OQ dependency so it survives re-tuning. Tagged `(⏳ pending OQ: …)`.

- **Honesty invariant (fixed).** On every path that projects daily/weekly stats, the projection
  function asserts `rawActiveTime ≤ activeTimeToday` and surfaces raw as its **own labelled value**.
  Any projection producing raw > journey, or conflating the two into one number, is a **defect** caught
  by an invariant assertion — not a tunable.

- **Test layer per `docs/architecture/overview.md`.** Executable tests live under
  `src/focus_journey/`: pure stat/weekly/streak/badge math + catalogue integrity → **unit tests**
  (`src/test/`); the stats / badges / settings / onboarding screens → **widget / golden tests**
  (`src/test/`); persistence-across-restart, the idle-threshold-on-next-tick wiring, and notifier/OS
  fakes end to end → **integration tests** (`src/integration_test/`); real launch-at-startup, real
  toast delivery, offline behaviour, and the privacy promise → **manual / device + `/privacy-audit`**.
  `tests/cases/` (this file) holds the human-readable scenarios only; no executable test is placed
  under the top-level `tests/` tree. Reports go to `tests/_runner/reports/local-stats/<timestamp>/`.

- **Time/float tolerance.** Durations and distances compare within **±1e-6** (seconds / km) unless a
  case states otherwise, to absorb rounding; percentage/readout assertions tolerate the documented
  display rounding and state the underlying value so they survive display-format changes.

## Cases

### Case: Daily stats project the four headline numbers from a fixed engine snapshot
**ID:** TC-001
**Priority:** P0
**Type:** happy-path
**Covers:** AC-1

Given the scriptable engine stub reports a deterministic snapshot for the current local day — `activeTimeToday` (journey time, incl. grace), `rawActiveTime` (no grace), `idleTimeToday`, and the day's `distanceKm`-delta (today's km) — and the injected clock places "now" inside that local day
When the stats Bloc/Cubit projects the daily view
Then the screen shows, for the current local day: **active time** (= journey time), **distance** (today's km), **idle time**, and **best focus period** — each derived **purely** from engine state + today's history, with **no new accrual logic** introduced in this slice

**Notes:** Pure-function / Bloc unit test (`src/test/`). Feed a fixed snapshot, assert the projected fields field-by-field. Companion widget/golden pins the rendered daily card. The "no new accrual" clause is reinforced by the purity case TC-026.

---

### Case: Headline honesty — raw active time shown separately and never ≥ journey time
**ID:** TC-002
**Priority:** P0
**Type:** happy-path
**Covers:** AC-2, NF — Honest accounting always visible

Given any engine snapshot satisfying the engine invariant `rawActiveTime ≤ activeTimeToday`
When the daily view renders
Then **raw active time** appears as its **own labelled value, distinct from** the "active time / journey time" value — the UI **never** conflates them into one number and **never** renders raw as greater than journey time; a snapshot with `rawActiveTime == activeTimeToday` (zero grace consumed) is shown as **equal** (allowed)

**Notes:** Pure-function unit test for the projection (assert the invariant `raw ≤ journey` holds and raw is a separate field) plus a widget/golden asserting two distinct labelled values. Negative leg: feed a (hypothetical) snapshot with `raw > journey` and assert the projection function **throws / flags a defect** rather than rendering it. Headline rule — pairs with NF "Honest accounting always visible".

---

### Case: Best focus period = the day's longest continuous raw-active stretch; grace breaks it
**ID:** TC-003
**Priority:** P1
**Type:** edge
**Covers:** AC-3

Given a day's sequence of contiguous active-vs-grace/idle ticks (e.g. raw-active runs separated by a grace stretch and an idle/paused stretch)
When best-focus-period is computed
Then it equals the **longest unbroken run of raw-active time** within the local day; a **grace** stretch **breaks** the run (raw-active-only, for honesty) and so does any **idle/paused** stretch; with no raw-active time today it reports **zero**

**Notes:** Pure-function unit test (`src/test/`). *(⏳ pending OQ "best focus period definition" — written against the spec's recommended default: raw-active only, grace breaks the stretch, derived from contiguous active ticks, not per-event data.)* Keys off "longest raw-active run", not a literal duration. Construct ticks so two raw-active runs are separated by grace and assert the **longer** one wins and grace is **not** counted.

---

### Case: Weekly view aggregates the local calendar week (Mon–Sun) across a Monday boundary
**ID:** TC-004
**Priority:** P0
**Type:** happy-path
**Covers:** AC-4

Given a per-day history store seeded with dated entries **straddling a Monday boundary** (some in the prior week ending Sunday, some in the current week) and an **injected clock** placing "today" in a known current week
When the weekly view is computed
Then it sums **only** the days whose date falls in the **current local calendar week (Monday through Sunday)** — active time, raw active time, distance, idle time, **days active**, and the week's best focus period — and **excludes** the prior week's days

**Notes:** Pure-function unit test (`src/test/`). Seed entries on both sides of the Monday boundary; assert the aggregate equals exactly the in-week sum and the prior-week days are dropped. Run a second variant with the clock on a Sunday and a Monday to confirm the week edges are inclusive (Mon) and the boundary cut is correct. DST/timezone handled the engine's local-midnight way.

---

### Case: Each completed day is recorded to history before the daily counters zero
**ID:** TC-005
**Priority:** P0
**Type:** edge
**Covers:** AC-5

Given the engine's daily counters are non-zero for day _D_ and the injected clock is on _D_
When the local day rolls over to _D+1_ (engine day-boundary reset, journey-engine AC-9/AC-10)
Then a history entry for _D_ is **persisted** via the `shared_preferences`/JSON seam containing `{date, activeTime, rawActiveTime, distanceKmForDay, idleTime, bestFocusPeriod}` **before** the day's live counters are treated as zero for _D+1_ — so no day's totals are lost across the boundary

**Notes:** Unit / integration test (`src/test/`, `src/integration_test/`) with the injected clock and the in-memory history fake. Assert ordering: the record-write for _D_ happens **before** the daily projection reads zero for _D+1_ (e.g. fake records call order, or assert the saved blob contains _D_'s non-zero totals after the rollover). Pairs with TC-019/TC-024 (boundary + persistence).

---

### Case: History store is bounded — oldest day pruned beyond the cap
**ID:** TC-006
**Priority:** P1
**Type:** edge
**Covers:** AC-6

Given the history store already holds the maximum number of days (the cap)
When a new day is recorded
Then the **oldest** entry beyond the cap is **pruned** so storage never grows without limit, the most recent _cap_ days are retained, and weekly views/streaks for in-window days are unaffected

**Notes:** Pure-function / store unit test (`src/test/`). *(⏳ pending OQ "history retention cap" — written against the recommended default ~90 days; the cap is a single tunable constant.)* Assert "count never exceeds cap and the oldest is dropped", **not** the literal 90 — set the cap small in the test (e.g. 3) and overflow it.

---

### Case: History persists and reloads across restart with no new store type
**ID:** TC-007
**Priority:** P1
**Type:** edge
**Covers:** AC-7, NF — Clean-Architecture layering

Given recorded per-day history exists in the in-memory `shared_preferences`/JSON fake
When the app is closed and relaunched (a fresh Bloc/Cubit restores from the saved blob)
Then the **same** per-day history is restored from the existing seam (no `drift`/SQLite, **no new store**), and weekly stats + streaks **recompute identically** from it

**Notes:** Integration test (`src/integration_test/`); the restore path is also unit-testable. Assert restored history == saved history and that a same-input weekly/streak recompute matches the pre-restart result. Assert no new store/key namespace beyond the established pattern.

---

### Case: Changing the idle threshold takes effect on the engine's next tick
**ID:** TC-008
**Priority:** P0
**Type:** happy-path
**Covers:** AC-8

Given the settings screen with a persisted idle threshold (selectable **3 / 5 / 10 min / custom**, default **5**) and the scriptable engine stub exposing the idle-threshold knob + a one-tick advance
When the user changes the threshold and one tick is advanced with a fixed idle reading that crosses the **new** boundary
Then the new value is **persisted** **and** applied to the engine's pause decision so the **next tick** classifies idle using the new threshold — the engine's resulting `state`/accrual reflects the new value, with **no change to engine code** (this slice only sets the knob)

**Notes:** Integration test against the engine stub (`src/integration_test/`). Set threshold, feed an idle reading between the old and new boundary, advance one tick, assert the engine classified per the new threshold. The engine's own classification logic is tested in journey-engine — here assert only that the knob was set and observed on the next tick.

---

### Case: Idle threshold persists across restart and is the only engine-affecting setting
**ID:** TC-009
**Priority:** P1
**Type:** edge
**Covers:** AC-9, NF — Privacy by construction

Given a chosen idle threshold persisted via the settings fake
When the app relaunches
Then the threshold is **restored** and re-applied to the engine; **and** no other setting in this slice (launch-at-startup, notifications) alters engine accrual, `distanceKm`, or activity classification — they are OS-only and do **not** feed the engine

**Notes:** Restore round-trip unit/integration test + static inspection (`src/test/`, grep). Assert (a) threshold round-trips and re-applies, (b) toggling launch-at-startup / notifications causes **zero** writes to the engine stub. Reinforced by TC-027 (privacy audit).

---

### Case: Launch-at-startup toggle reads then sets the real OS open-at-login state (injected fake)
**ID:** TC-010
**Priority:** P1
**Type:** edge
**Covers:** AC-10

Given the settings screen on macOS or Windows with an **injected fake** of the `launch_at_startup` interface
When the screen opens, Then the toggle reflects the fake's current open-at-login state (read); and When the user flips it, Then the fake's state is enabled/disabled accordingly (write) and the user-visible toggle stays consistent with it
Then the Bloc is observed to **read** the OS state on open and **write** it on flip — with **no real OS registration** in the automated test

**Notes:** Bloc/integration test against the injected fake (`src/integration_test/`). Assert read-on-open then write-on-flip and toggle/state consistency. The **real** OS registration is a manual/device check (see TC-NF5) — not a deterministic automated unit.

---

### Case: Notifications are local OS toasts only and respect the master toggle
**ID:** TC-011
**Priority:** P0
**Type:** happy-path
**Covers:** AC-11, NF — No network / offline

Given the notifications setting with a **master enable/disable** plus per-type toggles and an injected fake `local_notifier`
When any notification would fire
Then it is delivered **only** as a local OS toast via the `local_notifier` interface, **never** via network/push, and **only** if the master toggle (and the relevant per-type toggle) is enabled — with the master **off**, **no** toast fires for **any** type

**Notes:** Integration test against the injected notifier fake (`src/integration_test/`) asserting "toast requested ⇔ enabled" for both the master-on and master-off paths, plus static inspection asserting **no** network dependency in the notification path. Reinforced by TC-027 / TC-NF4.

---

### Case: v1 fires exactly two notification types — badge-earned and a gated daily streak reminder
**ID:** TC-012
**Priority:** P1
**Type:** edge
**Covers:** AC-12

Given notifications enabled and the injected notifier fake
When a badge is newly earned, Then a "badge earned" toast is requested **once** for that badge; and at the configured daily-reminder time a "keep your streak" reminder is requested **only if** today does **not** yet qualify for the streak, and it does **not** nag (at most once per day) and does **not** fire while a journey is **actively progressing**
Then the notifier records exactly those gated requests — no toast on an already-qualified day, no second nag, none while active

**Notes:** Integration test against the notifier fake + injected clock (`src/integration_test/`). *(⏳ pending OQ "notification trigger set + cadence" — written against the recommended v1 default: (a) badge/milestone earned, (b) one daily streak reminder. Reminder time + quiet behaviour are the tunable part.)* Keys off "fires once, gated by enable + already-qualified + active-journey", **not** a literal clock time. Drive: badge-earn → assert 1 toast; reminder with today-already-qualified → assert 0; reminder with `state == actively progressing` → assert 0; reminder unqualified+idle → assert 1, then re-trigger same day → assert still 1 (no nag).

---

### Case: Data-driven badge catalogue spans all four families; each unlocks at threshold and persists
**ID:** TC-013
**Priority:** P0
**Type:** happy-path
**Covers:** AC-13

Given a fixed badge catalogue defined as **data** (not hardcoded control flow) covering **distance**, **journey-progress**, **focus-streaks**, and **focus-time**, with the earned-badge store faked in-memory
When the relevant consumed value crosses a badge's threshold
Then that badge transitions **locked → earned**, is **written** to the earned-badge store, and the badges/achievements view lists it as **earned** (others as **locked**)

**Notes:** Unit + widget test (`src/test/`). *(⏳ pending OQ "exact badge thresholds / v1 catalogue" — written against the recommended default: a small fixed catalogue defined as data, tunable without code-shape change.)* Keys off **catalogue structure + threshold-crossing**, not literal numbers — use a test catalogue with a known small threshold per family. Assert each family yields at least one earnable badge and the earned set persists to the store. Companion golden pins the earned/locked list.

---

### Case: Distance badges consume engine/route distance (no accrual here)
**ID:** TC-014
**Priority:** P1
**Type:** edge
**Covers:** AC-14, NF — Privacy by construction

Given distance-family badges (e.g. cumulative-distance and "100 km this week" marks)
When `distanceKm` / `routeDistanceKm` / the week's distance crosses a mark (driven via the stub)
Then the corresponding **distance** badge is earned — and this slice **reads** those distances and never accrues distance itself (the stub records **zero** distance writes)

**Notes:** Unit test (`src/test/`). *(⏳ pending OQ: exact distance marks.)* Keys off a threshold-crossing in the test catalogue, not literals. Assert the stub observed no distance write (write-free consumer, pairs with TC-026).

---

### Case: Journey-progress badges consume route-progress position (no geography re-implementation)
**ID:** TC-015
**Priority:** P1
**Type:** edge
**Covers:** AC-15

Given journey-progress badges ("halfway across Vietnam", "crossed N provinces", route-complete) and the route-state stub
When route-progress reports % of country / provinces passed / completion crossing a threshold
Then the matching **journey-progress** badge is earned — consuming `route-progress` position **only**; this slice does **not** re-implement geography or position math

**Notes:** Unit test (`src/test/`). *(⏳ pending OQ: exact province/percent marks.)* Keys off a threshold-crossing in the route-state stub's reported position. Assert the badge logic reads only the exposed position fields (no chain/position math present here — overlaps the purity case TC-026).

---

### Case: Focus-streak badges count from history on the locked raw-active ≥ 25 min/day rule
**ID:** TC-016
**Priority:** P0
**Type:** happy-path
**Covers:** AC-16

Given the per-day history store seeded with dated entries, each with a `rawActiveTime`
When the streak length is computed
Then a day **qualifies iff** that day's `rawActiveTime` **≥ 25 min** (the locked upstream rule — journey-engine AC-15), the streak counts **consecutive** qualifying local days, and streak badges (e.g. 3 / 7 / 30 days) unlock at their lengths; a day with `rawActiveTime < 25 min` **breaks** the streak

**Notes:** Pure-function unit test (`src/test/`). The **≥ 25 min** qualification is a **fixed constant**, not an OQ — assert a day at exactly 25 min qualifies and one at 24 min does not. *(⏳ pending OQ: exact streak **lengths** 3/7/30; key the badge-unlock off "streak ≥ catalogue length", not literals.)* Counts **from stored history**, never re-derived from live signals. Seed a run with a gap day to assert the streak resets at the gap.

---

### Case: Focus-time badges consume raw active time (never grace-inflated journey time)
**ID:** TC-017
**Priority:** P1
**Type:** edge
**Covers:** AC-17, NF — Honest accounting always visible

Given focus-time badges ("best focus period today", daily-goal-met, total raw-active-hours marks)
When `rawActiveTime` (today / cumulative) or the day's best focus period crosses a mark
Then the matching **focus-time** badge is earned — keyed on **raw** active time, **never** grace-inflated journey time

**Notes:** Unit test (`src/test/`). *(⏳ pending OQ: exact focus-time marks + the single daily goal value.)* Keys off a raw-active threshold-crossing. Negative leg: feed a snapshot where journey time crosses the mark but raw does not — assert the badge does **not** earn (honesty: keyed on raw, not journey).

---

### Case: Permanent badges persist; windowed badges reset at the week (Mon–Sun) boundary
**ID:** TC-018
**Priority:** P1
**Type:** edge
**Covers:** AC-18

Given an earned **permanent** badge (e.g. cumulative-distance, route-complete, total-hours) and an earned **windowed** badge (e.g. "100 km this week"), with the injected clock in week _W_
When the clock advances past the local **Mon–Sun** calendar-week rollover into week _W+1_
Then the **permanent** badge **stays earned**, while the **windowed** badge **resets to locked** for the new window (re-earnable that window) — cumulative/permanent progress is **never** reset by a window rollover

**Notes:** Unit test (`src/test/`) with the injected clock. *(⏳ pending OQ "windowed badges on week rollover" — written against the recommended default: weekly badges reset at the calendar-week boundary, cumulative/permanent persist.)* Keys off "windowed resets at its window boundary; permanent does not", not the literal badge list. Pairs with TC-004 (week boundary) and TC-024 (persistence).

---

### Case: Daily surfaces reset at local midnight while cumulative persists — running across midnight
**ID:** TC-019
**Priority:** P0
**Type:** edge
**Covers:** AC-19

Given non-zero daily stats and earned daily/windowed state for day _D_, the app **running** across midnight, with the injected clock crossing from _D_ to _D+1_
When the local day rolls to _D+1_
Then after _D_ is recorded to history (TC-005), the **daily** stats surfaces **zero** for _D+1_, while **cumulative distance/position**, **streak counts**, and **earned permanent badges** persist **unchanged**; the missed/prior day is **not** reconstructed

**Notes:** Unit / integration test with the injected clock (`src/test/`, `src/integration_test/`). No real waiting. Assert daily = 0, cumulative/streak/permanent unchanged, and _D_ present in history. Pairs with TC-020 (closed-across-midnight) and TC-018.

---

### Case: Daily surfaces reset across midnight when the app was CLOSED across midnight (restore on _D+1_)
**ID:** TC-020
**Priority:** P0
**Type:** edge
**Covers:** AC-19, AC-5

Given a saved store dated day _D_ (non-zero daily totals + earned daily/windowed state) and the app launched with the injected clock on _D+1_ (detected from the stored date on restore, consistent with journey-engine AC-9/AC-10)
When the app restores
Then the **daily** stats surface **zero** for _D+1_ (after _D_ is recorded to history), while **cumulative distance/position**, **streaks**, and **earned permanent badges** persist; the missed day is **not** reconstructed

**Notes:** Integration test (`src/integration_test/`) restoring from a _D_-dated blob with the clock on _D+1_ — no real waiting. The closed-across-midnight twin of TC-019. Assert the prior day's totals land in history exactly once (no double-record) and daily reads zero on _D+1_.

---

### Case: First-run onboarding states the trust promise; flag persists; re-openable from settings
**ID:** TC-021
**Priority:** P0
**Type:** happy-path
**Covers:** AC-20

Given a first launch with **no prior onboarding flag** in the settings fake
When the app starts
Then the onboarding/privacy screen is **shown** stating: what the app **reads** (aggregate system idle time + lock/sleep state only), what it **never reads** (keystrokes/content, screen, clipboard, files, browser, mouse-position history, window titles), that it is **fully local/offline with no account**, and **how active vs journey time differ**; and after completion the flag **persists** so it is **not** re-shown next launch but **is** re-openable from settings

**Notes:** Widget + integration test (`src/test/`, `src/integration_test/`). Three legs: (a) no-flag → screen shown with all required claim sections present (assert the copy lists the read/never-read/offline/active-vs-journey items); (b) after completion → flag saved, next launch does **not** show it; (c) the settings "view privacy" entry re-opens it. Companion golden pins the onboarding screen. The copy's *claims* are checked against code by TC-022.

---

### Case: Onboarding privacy claims match the code — `/privacy-audit` release gate
**ID:** TC-022
**Priority:** P0
**Type:** negative
**Covers:** AC-21, NF — Privacy by construction

Given the onboarding copy's claims and all local-stats source (stats/settings/badges/onboarding screens + Cubits/Blocs, the three stores, the badge catalogue, and the two new deps `launch_at_startup` + `local_notifier`)
When `privacy-guardian` runs `/privacy-audit`
Then it confirms **no** API or dependency in the slice contradicts the copy: the app reads **only** aggregate idle/lock/sleep (via the already-audited engine/`ActivityPlugin`, never called directly here), and the two new deps introduce **no** capability reading input content / screen / clipboard / files / network — notifications are local toasts only; a contradiction **fails** this AC

**Notes:** **Manual audit case, NOT an automated assertion** (mirrors route-progress TC-018 / journey-view's `/privacy-audit` case). A fail here **blocks ship** regardless of other passes. Reinforced by the static-inspection cases TC-026/TC-027. Re-run on any change to the slice's source or its dependency set.

---

### Case: Read-only consumer — slice makes no direct OS/activity call and writes no engine state
**ID:** TC-026
**Priority:** P0
**Type:** negative
**Covers:** NF — Privacy by construction, NF — Clean-Architecture layering

Given all local-stats source (stats/weekly/streak/best-focus math, badge logic, Cubits/Blocs, screens, store wiring)
When inspected statically (and exercised at runtime through any input sequence via the stub)
Then it reads the engine's exposed scalars + route position + its own persisted settings/history/badge state **only**, and contains **none** of: `ActivityPlugin`, `getSystemIdleSeconds`, `isScreenLocked`, any `MethodChannel`/platform channel for idle/lock/sleep, nor any active-vs-idle decision, distance accrual, or streak-metric re-derivation logic; and driving the stub through any sequence leaves the engine's exposed values **untouched** (zero writes)

**Notes:** Static-inspection (grep / source review over the slice's files) + a runtime guard using the stub that records write attempts and asserts none. Mirrors journey-view TC-009/TC-010 and route-progress TC-016/TC-017. Re-run on any change. Reinforced by TC-022 (`/privacy-audit`).

---

### Case: Persists only aggregate counters / settings / earned-badge flags — never raw signals
**ID:** TC-027
**Priority:** P0
**Type:** negative
**Covers:** NF — Privacy by construction, NF — No network / offline

Given the three stores (settings, per-day history, earned-badge) and their JSON blobs
When the slice writes and reloads
Then the persisted data contains **only** aggregate counters (`activeTime`, `rawActiveTime`, `distanceKmForDay`, `idleTime`, `bestFocusPeriod`, dates), settings values, and earned-badge flags — **never** raw per-event signals (no keystrokes, no idle-second traces, no window titles), and **no** network call is made on any path

**Notes:** Static inspection of the persisted JSON shape + import/dependency grep for any network package (`src/test/`, grep). Overlaps TC-011/TC-026. Assert the saved blob schema matches the AC-5 field set and nothing more. Reinforced by TC-022.

---

### Case: Determinism — same (engine snapshot, history, route position, clock) → same outputs
**ID:** TC-NF1
**Priority:** P0
**Type:** nfr
**Covers:** NF — Determinism & testability

Given identical inputs `(engine snapshot, per-day history, route position, injected clock)`
When any stat / weekly-aggregation / best-focus / streak / badge function is invoked twice (and/or re-executed at a different real-world wall-clock time, on a different machine)
Then every output is **identical** across invocations — the functions read **no** real timer, **no** `DateTime.now()`, **no** real OS wait, no Flutter, no I/O; output depends **only** on the injected inputs

**Notes:** Pure-function unit test (`src/test/`). Mirrors journey-engine TC-012 / route-progress TC-NF1. Run the same input twice and assert field-by-field equality; advancing the real clock between runs must change nothing. Underpins TC-001..TC-006, TC-013..TC-018.

---

### Case: Clean-Architecture layering — domain math / data stores / presentation, all injected
**ID:** TC-NF2
**Priority:** P1
**Type:** nfr
**Covers:** NF — Clean-Architecture layering

Given the slice's layering
When inspected statically
Then stat/badge/streak/weekly math + the history model are **domain**; settings/history/earned-badge persistence is **data** (the `shared_preferences`/JSON seam, bounded — **no** new store type, no `drift`/SQLite); the stats/settings/badges/onboarding screens + their Cubits/Blocs are **presentation**; and dependencies (clock, stores, OS interfaces) are **injected**, never `new`-ed inside widgets/Blocs

**Notes:** Static-inspection / dependency-direction case (`src/test/`, grep + review). Assert domain has no Flutter/`shared_preferences` import, presentation does not contain math, and the clock + stores + OS interfaces arrive via constructor/DI. Pairs with TC-007 (no new store).

---

### Case: No network / offline — the entire slice makes no network call
**ID:** TC-NF3
**Priority:** P0
**Type:** nfr
**Covers:** NF — No network / offline

Given the slice running with no network connectivity (and its source + dependency set inspected)
When stats render, badges evaluate, settings save, and notifications fire end to end
Then **no** network call is made — no cloud sync, no account, no push; notifications are **local OS toasts** via `local_notifier` only, and nothing leaves the machine

**Notes:** Static inspection of imports/dependencies for any network package (overlaps TC-011/TC-027) plus an `integration_test` smoke with networking disabled asserting stats/badges/settings/notifications all work. Encodes the v1 "local only" scope.

---

### Case: Golden determinism for the stats / badges / onboarding screens
**ID:** TC-NF4
**Priority:** P1
**Type:** nfr
**Covers:** NF — Determinism & testability (rendering), AC-1, AC-2, AC-13, AC-20

Given the stats card (daily + weekly), the badges/achievements grid, and the onboarding/privacy screen
When rendered against fixed inputs (a fixed engine snapshot, a fixed history, a fixed earned-badge set, the injected clock)
Then each screen renders **deterministically** to its golden frame with the two-distinct-values honesty layout (raw vs journey, TC-002), the earned/locked badge list (TC-013), and the full onboarding claim copy (TC-021) visible — with per-OS tolerance

**Notes:** Widget/golden tests (`src/test/`). Determinism discipline: fixed inputs, fixed clock, fixed fonts/sizes; per-OS (macOS + Windows) tolerance like journey-view's goldens. Pins the visual structure that TC-001/TC-002/TC-013/TC-021 assert behaviourally.

---

### Case: Real launch-at-startup registration and real toast delivery (manual / device)
**ID:** TC-NF5
**Priority:** P1
**Type:** nfr
**Covers:** AC-10 (real-OS leg), AC-11 (real-OS leg)

Given a real macOS and a real Windows build
When the user enables launch-at-startup and triggers a badge-earned/streak-reminder notification
Then the app is **actually** registered to open at login (verifiable in OS settings) and a **real** local OS toast is delivered — and disabling/launching again reflects the real state consistently
Then there is **no** network traffic for either (offline-verifiable)

**Notes:** **Manual / device check, NOT a deterministic automated unit** (the automated legs are the injected-fake cases TC-010 / TC-011). Note device + OS in the report. Mirrors journey-view's deferred device-level NFRs. The fakes prove the Bloc wiring; this proves the real-OS side once per release.

---

## Coverage table (AC / non-functional item → covering case IDs)

| Item | Description | Covered by |
|---|---|---|
| AC-1 | daily stats project the four headline numbers from engine state | TC-001, TC-NF4 |
| AC-2 | raw active time shown separately, never ≥ journey time (headline honesty) | TC-002, TC-NF4 |
| AC-3 | best focus period = longest continuous raw-active stretch; grace breaks it | TC-003 |
| AC-4 | weekly view aggregates local calendar week (Mon–Sun) from history | TC-004 |
| AC-5 | completed day recorded to history before daily counters zero | TC-005, TC-020 |
| AC-6 | history store bounded; oldest pruned beyond the cap | TC-006 |
| AC-7 | history persists/reloads across restart, no new store type | TC-007 |
| AC-8 | idle-threshold change takes effect on engine's next tick | TC-008 |
| AC-9 | idle threshold persists; only engine-affecting setting | TC-009 |
| AC-10 | launch-at-startup reads-then-writes real OS state (fake; real-OS manual) | TC-010, TC-NF5 |
| AC-11 | notifications local toasts only; respect master toggle | TC-011 |
| AC-12 | v1 two types: badge-earned + gated daily streak reminder (no-nag / not-while-active) | TC-012 |
| AC-13 | data-driven catalogue, all four families; unlock at threshold + persist | TC-013, TC-NF4 |
| AC-14 | distance badges consume engine/route distance | TC-014 |
| AC-15 | journey-progress badges consume route-progress position | TC-015 |
| AC-16 | focus-streak badges count from history on raw-active ≥ 25 min/day | TC-016 |
| AC-17 | focus-time badges consume raw active time (not journey time) | TC-017 |
| AC-18 | permanent persist; windowed reset at the window (Mon–Sun) boundary | TC-018 |
| AC-19 | daily surfaces reset at local midnight; cumulative persists (running + closed) | TC-019, TC-020 |
| AC-20 | first-run onboarding; flag persists; re-openable from settings | TC-021, TC-NF4 |
| AC-21 | onboarding privacy claims match code — `/privacy-audit` release gate | TC-022 |
| NF — Privacy by construction | reads only audited aggregates; no new surface; persists no raw signals | TC-026, TC-027, TC-022, TC-009, TC-014 |
| NF — Determinism & testability | pure functions; injected clock; same inputs → same outputs | TC-NF1, TC-NF4 |
| NF — Honest accounting always visible | raw separate from / never ≥ journey on every path | TC-002, TC-017 |
| NF — No network / offline | no network call; local toasts only | TC-NF3, TC-011, TC-027 |
| NF — Clean-Architecture layering | domain math / data stores / presentation; injected deps | TC-NF2, TC-007, TC-009 |

Every AC (AC-1..AC-21) and every non-functional item maps to at least one case. No AC is orphaned.

## Notes / risks tail

- **Central test doubles must be built first.** Almost every case needs (a) the **scriptable engine /
  route-state stub** (settable scalars + route position + idle-threshold knob + one-tick advance,
  recording engine writes), (b) the three **store fakes** (settings, per-day history, earned-badge over
  the in-memory `shared_preferences`/JSON seam), and (c) the two **OS-interface fakes**
  (`launch_at_startup` get/set, `local_notifier` toast-requested). Build these before the case suite.
- **Golden determinism (TC-NF4).** The stats / badges / onboarding goldens need fixed inputs, a fixed
  clock, and per-OS tolerance (like journey-view's goldens) or they flake.
- **`/privacy-audit` (TC-022) is a manual ship-blocker**, not an automated assertion; TC-026/TC-027 lean
  partly on grep/static inspection rather than runtime assertions.
- **Real launch-at-startup + real toast (TC-NF5)** are manual/device checks per OS, not deterministic
  units — the automated coverage is the injected-fake cases TC-010/TC-011.
- **Pending-OQ cases key off structure, not literals.** TC-003 (best-focus def), TC-006 (retention cap),
  TC-012 (notification cadence), TC-013/TC-014/TC-015/TC-017 (badge catalogue/thresholds), TC-016
  (streak *lengths*), and TC-018 (windowed-rollover set) all assert thresholds/boundaries/caps
  structurally so they survive re-tuning. The **≥ 25-min streak qualification** (TC-016) and the
  **raw ≤ journey honesty rule** (TC-002) are **locked**, not OQ.
