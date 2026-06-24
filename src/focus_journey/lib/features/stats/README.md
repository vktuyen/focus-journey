# `stats` feature — local stats, settings, badges, onboarding/privacy

The v1-closing slice: daily/weekly stats, settings, milestone badges, and the
first-run onboarding/privacy screen. A **near-pure consumer** of the shipped
`journey-engine` aggregates + `route-progress` position — it adds **zero** new
activity logic and **zero** new privacy surface beyond the idle-threshold knob
and two OS toggles (launch-at-startup, local notifications).

## Layering (Clean Architecture)

- **`domain/`** — pure Dart (`library;`, no Flutter, no I/O):
  - `day_stats.dart` — one day's aggregate counters (the history unit).
  - `daily_stats.dart` — the daily projection + the **honesty invariant**
    (`rawActiveTime <= activeTime`, enforced in all builds; AC-2).
  - `best_focus_tracker.dart` — incremental longest raw-active stretch (AC-3).
  - `calendar_week.dart` / `weekly_stats.dart` — Mon–Sun aggregation (AC-4).
  - `focus_streak.dart` — streak counting on the **locked** raw-active ≥ 25 min
    rule (AC-16).
  - `badge.dart` / `badge_catalogue.dart` / `badge_evaluator.dart` — the
    **data-driven** four-family badge catalogue + pure evaluator with
    permanent-vs-windowed scope (AC-13..AC-18).
  - `earned_badges.dart` — persistable earned-badge state + week-window reset.
  - `app_settings.dart` — settings value object (only the idle threshold feeds
    the engine; AC-9).
  - `streak_reminder_policy.dart` — pure gating for the daily reminder (AC-12).
  - `route_progress_snapshot.dart` — the read-only route position the badges
    consume (no geography re-implementation; AC-15).
  - `stats_repositories.dart` — the three store interfaces + the two OS
    interfaces (`StartupController`, `Notifier`); cubits/tests depend on these.
- **`data/`** — the only place that imports `shared_preferences` /
  `launch_at_startup` / `local_notifier`. Three `SharedPreferences`+JSON repos
  (settings/history/earned-badges, corrupt-blob-safe `load()`), plus the two
  OS-package-backed interface impls.
- **`presentation/`** — `StatsCubit` (orchestrator: projects, aggregates,
  records-day-before-zero, evaluates badges, fires gated toasts), `SettingsCubit`
  (idle-threshold seam + OS toggles), and the stats / badges / settings /
  onboarding screens.

## Seams

- **Stats sink** — `ActivityTicker.onSnapshot` forwards the engine's
  `toProgress()` aggregate (a plain value object — no engine reference) to
  `StatsCubit.onTick` once per tick, mirroring the `onDistance` pattern.
- **Idle-threshold seam** — `SettingsCubit.applyIdleThreshold` (injected). The
  app composition root rebuilds the engine (preserving progress via
  `toProgress()`/`restore()`) + restarts the ticker so the next tick uses the
  new threshold (AC-8) — **no engine code change**.

## Privacy

Reads only the engine's already-audited aggregates + route position; persists
only aggregate counters, settings, and earned-badge flags. The two OS deps add
**no** input/screen/file/network capability — notifications are local toasts
only. The onboarding copy in `onboarding_screen.dart` is the contract
`privacy-guardian` audits (AC-21).
