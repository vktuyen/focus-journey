# Local Stats, Settings, Badges & Onboarding/Privacy

**Status:** shipped (2026-06-24)
**Owner:** Kevin (Tuyen Vo)
**Last updated:** 2026-06-24 (shipped — Wave 1 / v1; green report `20260624-132008`; **completes v1**)

## Problem
The three upstream v1 slices are shipped: `journey-engine` produces honest scalars
(`distanceKm`, `activeTimeToday` = journey time, `rawActiveTime` = true input time, `idleTimeToday`,
`state`, `mode`), `route-progress` turns distance into *place* (provinces passed, % of country,
`routeDistanceKm`), and `journey-view` renders the POV road. What's still missing is the **user-facing
surface that closes the v1 loop** — the screens that let a person *understand their focus, tune the
app, feel rewarded, and trust it*:

- **Stats** — daily and weekly numbers (active time, distance, idle time, best focus period), with
  **raw active time shown separately from journey time** so the app can never quietly overstate how
  much the user "worked." This is the product's headline honesty rule made visible.
- **Settings** — a user-configurable **idle threshold** (which changes engine behaviour), plus
  **launch-at-startup** and **notifications**.
- **Milestone badges** — local, offline achievements ("100 km this week", "halfway across Vietnam",
  "crossed N provinces", focus streaks, best-focus-period) that turn raw progress into reward.
- **Onboarding / privacy screen** — a first-run screen that states the trust promise in plain language,
  whose claims **must match what `privacy-guardian` can verify in the code**. This is the slice the
  privacy-skeptical teammate judges the whole product by.

Without this slice the v1 app can travel and show a map but gives the user no way to *reflect on*,
*configure*, *be rewarded by*, or *trust* their journey. This slice is a **near-pure consumer** of the
shipped engine + route-progress state — it owns presentation, the settings store, a small daily-history
store, badge rules, and the onboarding copy; it adds **zero new activity logic** and **zero new privacy
surface** beyond the single new setting the engine already supports (the idle threshold).

## User & outcome
- **The focused individual** (developer / student / remote worker) — the primary beneficiary. They get
  to *see their day and week* (active time, distance, idle, best focus period), *tune* the idle
  threshold to their work rhythm, *earn* badges that make progress feel like a game, and *opt in* to
  launch-at-startup and gentle notifications. Success = at a glance they understand today vs this week,
  and the badges/streaks give them a reason to come back.
- **The privacy-skeptical teammate** — judges the product here. The onboarding/privacy screen states
  exactly what is and isn't read (aggregate system idle time + lock/sleep state only; never keystrokes,
  screen, clipboard, files, browser, mouse-position history, window titles), and that claim is
  **verifiable** — `privacy-guardian` confirms the code matches the copy. Stats reinforce trust by
  showing **raw active time separately from (and lower than) journey time**.

**Observable success:** with the engine + route-progress fed a deterministic sequence, the stats screen
shows today's active time, distance, idle time and best focus period — with raw active time reported
distinctly from journey time; the weekly view aggregates the correct local calendar week (Mon–Sun) from
stored per-day history; changing the idle threshold in settings changes the engine's pause behaviour on
the next tick; the qualifying badges unlock at their thresholds and persist across restart; and the
onboarding privacy claims pass a `privacy-guardian` audit with no API/dependency contradicting the copy.

## Scope
### In
- **Daily stats** — for the current local day: **active time** (journey time, incl. grace),
  **raw active time** (true input, no grace — shown *separately* and labelled honestly), **distance**
  (today's km), **idle time**, and **best focus period** (the longest continuous raw-active stretch of
  the day). All derived from engine state + the daily-history store; no new accrual logic.
- **Weekly stats** — aggregates over the **local calendar week (Mon–Sun)**: active time, raw active
  time, distance, idle time, days active, and the week's best focus period — computed from a stored
  **per-day history**.
- **Per-day history store** — a bounded local history (default keep ~90 days) of each day's counters
  (date, activeTime, rawActiveTime, distanceKm-for-day, idleTime, bestFocusPeriod), persisted as JSON
  via the **existing `shared_preferences`/JSON repository seam**. Source of truth for weekly stats and
  streak counting. Bounded so storage can't grow without limit (oldest days pruned beyond the cap).
- **Settings screen** with:
  - **Idle threshold** — selectable 3 / 5 / 10 min / custom (default 5). Persisted, and applied to the
    engine's pause decision so a change takes effect on the next tick (engine already supports this knob).
  - **Launch-at-startup** — OS "open at login" toggle (macOS + Windows) via the `launch_at_startup`
    package. Persisted; reflects/sets the real OS state.
  - **Notifications** — a master enable/disable plus per-type toggles; local OS toasts via the
    `local_notifier` package. v1 triggers: **milestone/badge earned** and a **daily streak reminder**
    (configurable). Local only — no push, no network.
- **Milestone badges** (all four families; offline, local, persisted once earned):
  - **Distance** — e.g. "100 km this week", cumulative-distance thresholds (consumes engine `distanceKm`
    / route `routeDistanceKm`).
  - **Journey progress** — "halfway across Vietnam", "crossed N provinces", route-complete (consumes
    route-progress position: % of country, provinces passed).
  - **Focus streaks** — consecutive-day streaks (e.g. 3 / 7 / 30 days), a day qualifying on
    **raw active time ≥ 25 min** (the locked upstream rule; counted here from the daily-history store).
  - **Focus-time** — "best focus period today", daily-goal-met, total raw-active-hours thresholds
    (consumes `rawActiveTime`).
  - A **badges/achievements view** listing earned + locked badges. Earned permanent badges persist;
    windowed ones ("100 km this week") follow their window's reset.
- **Onboarding / privacy screen** — a first-run flow stating the trust promise in plain language: what
  the app reads (aggregate system idle time + lock/sleep state), what it never reads
  (keystrokes/content, screen, clipboard, files, browser, mouse-position history, window titles), that
  it is fully local/offline with no account, and how active vs journey time differ. Shown on first run,
  re-openable from settings. **Its claims are the contract `privacy-guardian` audits against the code.**
- **Day-boundary handling for the surfaces** — daily stats/badges reset at local midnight (incl. the
  app-closed-across-midnight case) consistent with the engine; cumulative position, streaks, and earned
  permanent badges persist. The history store records the prior day before the daily counters zero.

### Out
- **Distance / activity / active-idle accrual** — owned by the shipped `journey-engine`; this slice only
  *reads* its exposed values. No idle-seconds reading, no active/idle decision, no distance accrual here.
- **The native idle/lock plugin** — `activity-detection` (shipped). The only native additions in this
  slice are **launch-at-startup** and **notifications** (`launch_at_startup`, `local_notifier`).
- **Province chain / position math / map screen** — `route-progress` (shipped). Badges *consume* its
  position; this slice does not re-implement geography.
- **POV road scene** — `journey-view` (shipped).
- **Tray / menu-bar / always-on-top mini-window** — v2 (`mini-window`).
- **Cloud sync, accounts, leaderboards, push notifications** — no network in v1; leaderboard is v2.
  Notifications here are **local OS toasts only**.
- **Per-mode speeds / energy** — v2 (`journey-energy-model`).
- **Configurable streak threshold / per-mode goals** — v1 uses the locked 25-min raw-active rule and a
  single daily goal; tuning UI is out.

## Constraints & assumptions
- **Near-pure consumer (hard constraint).** Reads engine + route-progress state; adds no activity logic
  and no new privacy surface beyond the idle-threshold setting (already an engine knob) and the
  launch-at-startup / notification OS toggles. Stats/badge computations are pure, deterministic functions
  of (engine state, daily-history, route position) — unit-testable with no real timers.
- **Honest accounting is visible.** Raw active time is always presented **separately from and labelled
  distinctly from** journey time; the UI must never conflate them or show raw > journey. (Headline rule.)
- **Streaks qualify on raw active time ≥ 25 min/day** (locked upstream, journey-engine Resolved decisions
  / AC-15) — counted here from the daily-history store, not re-derived from live signals.
- **Persistence reuses the existing seam** — settings, daily-history, and earned-badge state all go
  through the established `shared_preferences`/JSON repository pattern; bounded history (no unbounded
  growth). No new store type (no `drift`/SQLite — that's v2).
- **No network in v1.** Notifications are local OS toasts (`local_notifier`); nothing leaves the machine.
- **Onboarding copy ⇄ code is a release gate.** The privacy screen's claims must match actual API and
  dependency usage; `privacy-guardian` (`/privacy-audit`) verifies it during Phase 4 and before release.
- **New native deps stay privacy-clean.** `launch_at_startup` and `local_notifier` must not introduce any
  capability that reads input content, screen, files, or network — re-checkable by `privacy-guardian`.
- **Stack per `docs/architecture/overview.md`** — Flutter desktop (macOS + Windows), Bloc, Clean
  Architecture. Stats/badge/streak math + history model are *domain*; settings/history/badge persistence
  is *data*; the stats/settings/badges/onboarding screens + their Cubits/Blocs are *presentation*.
- **Week = local calendar week (Mon–Sun)** (Kevin, 2026-06-24) — consistent with the calendar-day streak
  rule. DST/timezone handled the same way the engine handles local-midnight boundaries.

## Resolved decisions (Kevin, 2026-06-24 — at spec kickoff)
1. **Settings scope = full set:** idle threshold + launch-at-startup + **notifications**. Notifications
   are local OS toasts via `local_notifier`; launch-at-startup via `launch_at_startup`. (Architecture
   listed the latter two as "v1-optional"; Kevin opted them **in** for v1.)
2. **Stats history model = local calendar week (Mon–Sun) + a bounded per-day JSON history** (~90 days),
   persisted via the existing `shared_preferences`/JSON seam. Weekly stats + streak counting read from
   this store.
3. **Badge families = all four:** distance, journey-progress, focus-streaks, focus-time. (Exact
   per-badge thresholds tunable; see Open questions.)
4. **Streak qualification = raw active time ≥ 25 min/day** — inherited locked rule (journey-engine
   AC-15). This slice counts streaks from the daily-history store; it does not re-open the rule.

## Open questions
> All five resolved by Kevin at spec approval (2026-06-24) to the recommended defaults below. The
> badge thresholds / notification reminder time are tunable constants (data-driven catalogue +
> config) — adjusting them must not change code shape, so they can be retuned post-implementation
> without re-opening the spec.

- [x] **Exact badge thresholds / the v1 badge catalogue** — **Resolved:** a small **fixed catalogue
      defined as data** (not hardcoded control flow), one entry per badge, spanning all four families;
      thresholds are constants the implementer picks sensible starting values for (e.g. distance:
      "100 km this week" + a cumulative mark or two; streaks: 3 / 7 / 30 days; journey-progress:
      halfway + crossed-N-provinces + route-complete; focus-time: best-focus-period + a single daily
      goal + a total-raw-hours mark). Tunable without code-shape change. — owner: product-domain-expert / Kevin
- [x] **Notification trigger set + cadence** — **Resolved:** v1 fires exactly two local toast types —
      (a) **badge/milestone earned** (once per badge) and (b) a **daily streak reminder** that fires at
      most once per day, only if today has not yet qualified for the streak, respects the master toggle,
      and does **not** fire while a journey is actively progressing. Default reminder time is a tunable
      config constant. — owner: Kevin
- [x] **Best focus period definition** — **Resolved:** the **longest continuous raw-active stretch**
      within the local day, derived from **contiguous active ticks** (no per-event data); a **grace**
      stretch **breaks** the run (raw-active only, for honesty), as does any idle/paused stretch. Zero
      when there is no raw-active time. — owner: product-domain-expert / Kevin
- [x] **History retention cap** — **Resolved:** keep the most recent **~90 days** (a single tunable
      constant); prune older entries so storage never grows without limit. — owner: Kevin
- [x] **Windowed badges on week rollover** — **Resolved:** weekly/windowed badges ("100 km this week")
      **reset at the local Mon–Sun calendar-week boundary** (re-earnable each window); cumulative /
      permanent badges (route-complete, total-hours, cumulative-distance) persist and are never reset by
      a window rollover. — owner: Kevin

## Related
- Epic: [planning/backlog/vietnam-focus-journey.md](../../planning/backlog/vietnam-focus-journey.md) · Wave 1 (v1) — the v1-closing slice
- Backlog slice: [planning/backlog/local-stats.md](../../planning/backlog/local-stats.md)
- Upstream (shipped): [specs/journey-engine/spec.md](../journey-engine/spec.md) — exposes `rawActiveTime` / `activeTimeToday` / `distanceKm` / `idleTimeToday` / `state` / `mode`; AC-15 (streak metric = raw active time)
- Upstream (shipped): [specs/route-progress/spec.md](../route-progress/spec.md) — exposes `routeDistanceKm`, provinces passed, % of country (for journey-progress badges)
- Sibling consumer (shipped): [specs/journey-view/spec.md](../journey-view/spec.md) — the pure-consumer pattern this slice mirrors
- Privacy gate: `/privacy-audit` → `privacy-guardian` — onboarding claims ⇄ code
- Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md)
- Architecture: [docs/architecture/overview.md](../../docs/architecture/overview.md) — "Local stats / settings / onboarding-privacy" in Components; ADR-0002 (stack)
