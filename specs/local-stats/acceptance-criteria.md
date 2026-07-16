# Acceptance criteria

Each item is a checkable, observable statement. If it isn't testable, rewrite it.

> Driven by `specs/local-stats/spec.md`. This slice is a **near-pure consumer** of the shipped
> `journey-engine` scalars (`distanceKm`, `activeTimeToday` = journey time, `rawActiveTime` = true
> input time / no grace, `idleTimeToday`, `state`, `mode`) and the shipped `route-progress` position
> (`routeDistanceKm`, provinces passed, % of country) — the same pure-consumer pattern as
> `journey-view`. It owns **presentation** (stats / settings / badges / onboarding screens + their
> Cubits/Blocs) plus three small local stores: the **settings** store, the **bounded per-day history**
> store, and the **earned-badge** store (all on the existing `shared_preferences`/JSON repository seam).
> It adds **zero new activity logic** and **zero new privacy surface** beyond (a) the idle-threshold
> setting — already an engine knob — and (b) two OS-level toggles: **launch-at-startup**
> (`launch_at_startup`) and **notifications** (`local_notifier`, local toasts only). No idle-seconds
> reading, no active/idle decision, no distance accrual, no streak metric re-derivation happens here.
>
> **Testability posture.** Stats / badge / streak / weekly-aggregation math are written as **pure
> functions of (engine state, per-day history, route position)** — observable against Blocs/Cubits and
> pure functions with **no real timers and no real OS waits** (clock injected, OS toggles + notifier +
> repositories behind interfaces, mirroring the engine's framework-free constraint). Day-boundary and
> "current week" logic key off an **injected clock**, never `DateTime.now()`. The two native deps are
> exercised through their injected interfaces; their real-OS side is verified once by `privacy-guardian`
> + manual check, not by automated frame-rate/OS-state tests.
>
> **Pending-open-question ACs.** Where an AC depends on a spec **Open question** (the exact badge
> catalogue/thresholds, notification cadence, best-focus-period precise definition, history retention
> cap, windowed-badge rollover), it is written against the spec's **recommended default** and tagged
> `(⏳ pending OQ: …)` — exactly as the route-progress/journey-engine ACs handle their open seams. Tests
> should key off the *structure* (a data-driven badge catalogue, a window boundary, a retention cap),
> not the literal numbers, so they survive re-tuning.

**Status (2026-06-24): SHIPPED — all 21 functional ACs + 5 NFRs verified.** Implementation `approved`
(`/review-code` changes-requested → all 3 Medium + 2 Low findings resolved), `/privacy-audit` **PASS**
(onboarding copy ⇄ code verified clause-by-clause; the two new deps `launch_at_startup`/`local_notifier`
add no privacy surface), and tests **green** — 191/191 in-scope (whole-package 484/484), stats coverage
88.5%, report `tests/_runner/reports/local-stats/20260624-132008/` (`verdict: green`). All boxes below are
ticked against passing automated tests or the privacy audit. **Carried deferred-verification legs** (do not
block ship; mirror journey-view/activity-detection): **TC-022** runtime `/privacy-audit` socket-check
(AC-21/Privacy NFR are satisfied statically; runtime packet-capture/`lsof` still owed on the real build),
**TC-NF5** real-OS legs for AC-10 (launch-at-startup registration) + AC-11/AC-12 (real toast delivery) on
macOS+Windows — automated via injected fakes here, real-OS device check carried — and **TC-NF4** goldens
(deferred, no repo golden harness; structure asserted behaviourally).

## Functional — daily stats (pure projection of engine state + today's history)

- [x] AC-1 (P0) — **Daily stats surface the four headline numbers from engine state.** **Given** the
      engine reports a deterministic `activeTimeToday`, `rawActiveTime`, `idleTimeToday`, and the day's
      `distanceKm`-delta (today's km), **When** the stats Bloc/Cubit projects the daily view, **Then**
      the screen shows, for the **current local day**: active time (= journey time), distance (today's
      km), idle time, and best focus period — each derived purely from engine state + today's history,
      with **no new accrual logic** introduced in this slice. Verifiable by feeding the Bloc a fixed
      engine snapshot and asserting the projected values.

- [x] AC-2 (P0, **headline honesty rule**) — **Raw active time is shown separately from journey time and
      is never displayed as ≥ journey time.** **Given** any engine snapshot where `rawActiveTime ≤
      activeTimeToday` (the engine's invariant; equal only when zero grace was consumed), **When** the
      daily view renders, **Then** **raw active time** appears as its **own labelled value, distinct from**
      the "active time / journey time" value — the UI never conflates them into one number and never
      renders raw as greater than journey time. A snapshot with `rawActiveTime == activeTimeToday`
      (no grace) is shown as equal (allowed); any projection producing raw > journey is a **defect**
      caught by an invariant assertion in the projection function.

- [x] AC-3 (P1) — **Best focus period = the day's longest continuous raw-active stretch.** **Given** a
      day's history of contiguous active vs grace/idle ticks, **When** the best-focus-period is computed,
      **Then** it equals the **longest unbroken run of raw-active time** within the local day; a grace
      stretch **breaks** the run (raw-active-only, for honesty) and so does any idle/paused stretch. With
      no raw-active time today it reports zero. *(⏳ pending OQ "best focus period definition" — written
      against the spec's recommended default: raw-active only, grace breaks the stretch, derived from
      contiguous active ticks, not per-event data. Test keys off "longest raw-active run", not a literal
      duration.)*

## Functional — weekly stats & the per-day history store

- [x] AC-4 (P0) — **Weekly view aggregates the local calendar week Mon–Sun from the history store.**
      **Given** a per-day history store containing several days that straddle a week boundary and an
      **injected clock** placing "today" in a known week, **When** the weekly view is computed, **Then**
      it sums **only** the days whose date falls in the **current local calendar week (Monday through
      Sunday)** — active time, raw active time, distance, idle time, **days active**, and the week's best
      focus period — and excludes the prior week's days. Verifiable by seeding the history store with
      dated entries on both sides of the Monday boundary and asserting the aggregate.

- [x] AC-5 (P0) — **Each completed day is recorded to the bounded per-day history before daily counters
      zero.** **Given** the engine's daily counters are non-zero for day _D_, **When** the local day rolls
      over to _D+1_ (engine day-boundary reset, AC-9/AC-10 of journey-engine), **Then** a history entry
      for _D_ is persisted via the `shared_preferences`/JSON seam containing `{date, activeTime,
      rawActiveTime, distanceKmForDay, idleTime, bestFocusPeriod}` **before** the day's live counters are
      treated as zero for _D+1_ — so no day's totals are lost across the boundary.

- [x] AC-6 (P1) — **The history store is bounded and prunes oldest days beyond the cap.** **Given** the
      history store already holds the maximum number of days, **When** a new day is recorded, **Then** the
      oldest entry beyond the cap is pruned so storage never grows without limit, and the most recent
      _cap_ days are retained (weekly views/streaks for in-window days are unaffected). *(⏳ pending OQ
      "history retention cap" — written against the spec's recommended default ~90 days; the cap is a
      single tunable constant. Test asserts "count never exceeds cap and oldest is dropped", not the
      literal 90.)*

- [x] AC-7 (P1) — **History persists and reloads across restart with no new store type.** **Given**
      recorded history exists, **When** the app is closed and relaunched, **Then** the same per-day
      history is restored from the existing `shared_preferences`/JSON repository (no `drift`/SQLite, no
      new store) and weekly stats + streaks recompute identically from it.

## Functional — settings: idle threshold

- [x] AC-8 (P0) — **Changing the idle threshold takes effect on the engine's next tick.** **Given** the
      settings screen with a persisted idle threshold (selectable **3 / 5 / 10 min / custom**, default
      **5**), **When** the user changes it, **Then** the new value is persisted **and** applied to the
      engine's pause decision so the **next tick** classifies idle using the new threshold (the engine
      already exposes this knob; this slice only sets it). Verifiable by setting the threshold, advancing
      one tick with a fixed idle reading that crosses the new boundary, and asserting the engine's
      resulting `state`/accrual — with no change to engine code.

- [x] AC-9 (P1) — **The idle-threshold setting persists across restart and is the only engine-affecting
      setting.** **Given** a chosen threshold, **When** the app relaunches, **Then** the threshold is
      restored and re-applied to the engine; **and** no other setting in this slice alters engine accrual,
      `distanceKm`, or activity classification (launch-at-startup and notifications are OS-only and do not
      feed the engine). Verifiable by code inspection + a restore round-trip test.

## Functional — settings: launch-at-startup (real OS state)

- [x] AC-10 (P1) — **The launch-at-startup toggle reflects and sets the real OS "open at login" state.**
      **Given** the settings screen on macOS or Windows, **When** the screen opens, **Then** the toggle
      reflects the **actual** current OS open-at-login state (read via the `launch_at_startup` interface),
      and **When** the user flips it, **Then** the real OS state is enabled/disabled accordingly and the
      user-visible toggle stays consistent with it. Tested against an **injected fake** of the
      launch-at-startup interface (get/set), asserting the Bloc reads-then-writes the OS state — no real
      OS registration in automated tests.

## Functional — settings & runtime: notifications (local toasts only, no network)

- [x] AC-11 (P0) — **Notifications are local OS toasts only and respect the master toggle.** **Given**
      the notifications setting with a **master enable/disable** plus per-type toggles, **When** any
      notification would fire, **Then** it is delivered **only** as a local OS toast via the
      `local_notifier` interface, **never** via network/push, and **only** if the master toggle (and the
      relevant per-type toggle) is enabled — with the master off, **no** toast fires for any type.
      Verifiable against an injected fake notifier asserting "toast requested ⇔ enabled", and by code
      inspection asserting no network dependency.

- [x] AC-12 (P1) — **v1 fires exactly two notification types: badge-earned and a daily streak reminder.**
      **Given** notifications enabled, **When** a badge is newly earned, **Then** a "badge earned" toast
      is requested once for that badge; **and** at the configured daily-reminder time a "keep your streak"
      reminder toast is requested **only if** today does not yet qualify for the streak — and it does
      **not** nag (at most once per day) and does **not** fire while a journey is actively progressing.
      *(⏳ pending OQ "notification trigger set + cadence" — written against the spec's recommended v1
      default: (a) badge/milestone earned and (b) one daily streak reminder, respecting the master toggle
      and the "no nagging / not while actively progressing" rule. Reminder time + quiet behaviour are the
      tunable part; test keys off "fires once, gated by enable + already-qualified + active-journey", not
      a literal clock time.)*

## Functional — milestone badges (four families; data-driven catalogue)

- [x] AC-13 (P0) — **Badges are a data-driven catalogue spanning all four families; each unlocks at its
      threshold and persists once earned.** **Given** a fixed badge catalogue defined as **data** (not
      hardcoded control flow) covering **distance**, **journey-progress**, **focus-streaks**, and
      **focus-time**, **When** the relevant consumed value crosses a badge's threshold, **Then** that
      badge transitions locked → earned, is written to the earned-badge store, and a badges/achievements
      view lists it as earned (others as locked). Verifiable by driving each family's input across its
      threshold and asserting the earned set. *(⏳ pending OQ "exact badge thresholds / v1 catalogue" —
      written against the spec's recommended default: a small fixed catalogue defined as data, tunable
      without code-shape change. Tests key off catalogue structure + threshold-crossing, not literal
      numbers.)*

- [x] AC-14 (P1) — **Distance badges consume engine/route distance.** **Given** distance-family badges
      (e.g. cumulative-distance and "100 km this week" marks), **When** `distanceKm` /
      `routeDistanceKm` / the week's distance crosses a mark, **Then** the corresponding distance badge is
      earned. This slice **reads** those distances and never accrues distance itself. *(⏳ pending OQ:
      exact distance marks.)*

- [x] AC-15 (P1) — **Journey-progress badges consume route-progress position.** **Given**
      journey-progress badges ("halfway across Vietnam", "crossed N provinces", route-complete), **When**
      route-progress reports % of country / provinces passed / completion crossing a threshold, **Then**
      the matching badge is earned — consuming `route-progress` position only; this slice does **not**
      re-implement geography or position math. *(⏳ pending OQ: exact province/percent marks.)*

- [x] AC-16 (P0) — **Focus-streak badges count from history on the locked raw-active ≥ 25 min/day rule.**
      **Given** the per-day history store, **When** the streak length is computed, **Then** a day
      **qualifies** for the streak **iff** that day's `rawActiveTime` ≥ 25 min (the locked upstream rule —
      journey-engine AC-15 / Resolved decision), the streak counts **consecutive** qualifying local days,
      and streak badges (e.g. 3 / 7 / 30 days) unlock at their lengths. This slice counts streaks **from
      stored history**; it does **not** re-derive the metric from live signals and does **not** re-open the
      threshold. *(⏳ pending OQ: exact streak lengths 3/7/30; the ≥25-min qualification itself is **not**
      open — it is locked.)*

- [x] AC-17 (P1) — **Focus-time badges consume raw active time.** **Given** focus-time badges
      ("best focus period today", daily-goal-met, total raw-active-hours marks), **When** `rawActiveTime`
      (today / cumulative) or the day's best focus period crosses a mark, **Then** the matching focus-time
      badge is earned — keyed on **raw** active time, never grace-inflated journey time. *(⏳ pending OQ:
      exact focus-time marks + the single daily goal value.)*

- [x] AC-18 (P1) — **Permanent badges persist; windowed badges reset at their window boundary.**
      **Given** an earned **permanent** badge (e.g. cumulative-distance, route-complete, total-hours) and
      an earned **windowed** badge (e.g. "100 km this week"), **When** the relevant window boundary passes
      (for weekly badges, the local **Mon–Sun** calendar-week rollover), **Then** the permanent badge
      **stays earned** while the windowed badge **resets** to locked for the new window (re-earnable that
      window) — cumulative/permanent progress is never reset by a window rollover. *(⏳ pending OQ
      "windowed badges on week rollover" — written against the spec's recommended default: weekly badges
      reset at the calendar-week boundary, cumulative/permanent persist. Test keys off "windowed resets at
      its window boundary; permanent does not".)*

## Functional — day-boundary reset of the surfaces

- [x] AC-19 (P0) — **Daily surfaces reset at local midnight while cumulative state persists, including
      app-closed-across-midnight.** **Given** non-zero daily stats and earned daily/windowed state for day
      _D_, **When** the local day rolls to _D+1_ — whether the app was **running** across midnight or
      **closed across midnight** (detected from the stored date on restore, consistent with journey-engine
      AC-9/AC-10) — **Then** the **daily** stats surfaces zero for _D+1_ (after _D_ is recorded to history,
      AC-5), while **cumulative distance/position**, **streak counts**, and **earned permanent badges**
      persist unchanged. The missed day is **not** reconstructed. Verifiable with an injected clock crossing
      midnight and a restore from a store dated _D_ with the clock on _D+1_ — no real waiting.

## Functional — onboarding / privacy screen (copy ⇄ code contract)

- [x] AC-20 (P0) — **First-run onboarding states the trust promise in plain language, re-openable from
      settings.** **Given** a first launch (no prior onboarding flag), **When** the app starts, **Then**
      the onboarding/privacy screen is shown stating: what the app **reads** (aggregate system idle time +
      lock/sleep state only), what it **never reads** (keystrokes/content, screen, clipboard, files,
      browser, mouse-position history, window titles), that it is **fully local/offline with no account**,
      and **how active vs journey time differ**; **and** after completion the flag persists so it is not
      re-shown on the next launch but **is** re-openable from settings.

- [x] AC-21 (P0) — **The onboarding privacy claims match the code (release gate).** **Given** the
      onboarding copy's claims, **When** `privacy-guardian` audits the slice (`/privacy-audit`), **Then**
      no API or dependency in the slice contradicts the copy: the app reads only aggregate idle/lock/sleep
      (via the already-audited engine/`ActivityPlugin`), and the two new deps (`launch_at_startup`,
      `local_notifier`) introduce **no** capability reading input content/screen/clipboard/files/network.
      The copy ⇄ code match is a **release gate** — a contradiction fails this AC.

## Non-functional

- [x] **Privacy by construction (P0, headline).** This slice reads **only** the engine's already-audited
      aggregate signals (idle/lock/sleep via `ActivityPlugin`, surfaced as `rawActiveTime` /
      `activeTimeToday` / `idleTimeToday` / `distanceKm` / `state` / `mode`) plus route-progress position;
      it makes **no** call to `getSystemIdleSeconds()`/`isScreenLocked()` itself and reads **no**
      keystrokes, screen, clipboard, files, browser, window titles, or mouse-position history. The two new
      native deps — `launch_at_startup` + `local_notifier` — must **not widen** that surface (no input/
      screen/file/network capability); notifications are local toasts only. Persists only aggregate
      counters, settings, and earned-badge flags — never raw signals. Re-checkable by `privacy-guardian`
      (`/privacy-audit`); mirrors journey-view AC-9 / route-progress AC-16/AC-18.

- [x] **Determinism & testability (P0).** Stats / weekly-aggregation / badge / streak math are **pure,
      deterministic functions** of (engine state, per-day history, route position) — **no real timers, no
      real OS waits, no internal `DateTime.now()`**. Day-boundary and "current calendar week (Mon–Sun)"
      logic key off an **injected clock**; OS toggles, the notifier, and all three stores sit behind
      injected interfaces with fakes. Identical inputs yield identical outputs. (Mirrors the engine's
      framework-free testability constraint.)

- [x] **Honest accounting always visible (P0).** On every code path, **raw active time** is presented
      separately from and is never rendered as **≥ journey time**; no projection conflates the two or
      lets raw exceed journey. (Reinforces journey-engine AC-2; see AC-2 above.)

- [x] **No network / offline (P0).** The slice makes **no** network call: no cloud sync, no account, no
      push — notifications are **local OS toasts** via `local_notifier` only; nothing leaves the machine.

- [x] **Clean-Architecture layering (P1).** Stats/badge/streak/weekly math + the history model are
      *domain*; settings/history/earned-badge persistence is *data* (the `shared_preferences`/JSON seam,
      bounded — no new store type, no `drift`/SQLite); the stats/settings/badges/onboarding screens + their
      Cubits/Blocs are *presentation*. Dependencies are injected, never `new`-ed inside widgets/Blocs.

## Out of scope (reminder)

- **Distance / activity / active-idle accrual** — owned by the shipped `journey-engine`; this slice only
  *reads* its exposed values (`distanceKm`, `activeTimeToday`, `rawActiveTime`, `idleTimeToday`, `state`,
  `mode`). No idle-seconds reading, no active/idle decision, no distance accrual here.
- **The native idle/lock plugin** — `activity-detection` (shipped). The only native additions in this
  slice are **launch-at-startup** and **notifications** (`launch_at_startup`, `local_notifier`).
- **Province chain / position math / map screen** — `route-progress` (shipped). Badges *consume* its
  position (% of country, provinces passed); this slice does not re-implement geography.
- **The POV road scene** — `journey-view` (shipped).
- **Tray / menu-bar / always-on-top mini-window** — v2 (`mini-window`).
- **Cloud sync, accounts, leaderboards, push notifications** — no network; not planned (local single-user product).
  Notifications here are **local OS toasts only**.
- **Per-mode speeds / energy** — v2 (`journey-energy-model`). v1 is speed-only; `mode` is cosmetic.
- **Configurable streak threshold / per-mode goals** — v1 uses the locked **25-min raw-active** rule and a
  single daily goal; tuning UI is out.
