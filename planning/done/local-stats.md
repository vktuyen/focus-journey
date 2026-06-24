# Local Stats, Settings, Badges & Onboarding/Privacy

**Promoted from backlog:** 2026-06-24
**Target:** Wave 1 (v1) — the v1-closing slice
**Shipped:** 2026-06-24 — **completes Wave 1 (v1)**
**Spec:** [specs/local-stats/](../../specs/local-stats/) (`Status: shipped`)
**Green report:** [tests/_runner/reports/local-stats/20260624-132008/](../../tests/_runner/reports/local-stats/20260624-132008/) (`verdict: green`)

## Goal
Ship the user-facing surface that closes the v1 loop: daily/weekly stats (raw active time shown
separately from journey time), settings (idle threshold + launch-at-startup + notifications), milestone
badges (distance / journey-progress / streaks / focus-time), and a first-run onboarding/privacy screen
whose claims pass a `privacy-guardian` audit.

## Plan
- [x] Spec drafted + reviewed/approved (`spec.md`, acceptance criteria, test plan)
- [x] Test cases designed (`tests/cases/local-stats.md`)
- [x] Implement (`/implement`) — stats/settings/badges/onboarding screens + Blocs + history/settings/badge stores
- [x] Review (`/review-code`) + privacy audit (`/privacy-audit`)
- [x] Execute tests (`/execute-tests`)
- [x] Ship (`/ship`)

## Phase ledger
- [x] Phase 2 · Spec — `spec.md` **approved (2026-06-24)**; all 5 open questions resolved to recommended defaults; 26 ACs + 26 test cases
- [x] Phase 3 · Build — `/implement` — full `lib/features/stats/` slice + ticker `onSnapshot` seam + `main.dart` wiring; `launch_at_startup` + `local_notifier` behind interfaces; `/self-review` fixed B1/B2 + AC-19 defect
- [x] Phase 4 · Review — `/review-code` changes-requested → **all findings RESOLVED**; `/privacy-audit` **PASS**
- [x] Phase 5 · Test — `/execute-tests` **GREEN** (191/191 in-scope; 484/484 whole-package; 88.5% stats coverage; report `20260624-132008`)
- [x] Phase 6 · Ship — **SHIPPED 2026-06-24**

**Current phase:** DONE (shipped 2026-06-24)   **Next command:** — (Wave 1 complete → begin Wave 2)

## What shipped
- **`lib/features/stats/` (Clean Architecture: domain / data / presentation):**
  - *Domain (pure Dart):* daily-stats projection with the **honesty invariant** (`HonestyInvariantViolation` enforces raw ≤ journey in all builds), `BestFocusTracker` (longest contiguous raw-active run from per-tick snapshots), Mon–Sun `CalendarWeek` + `WeeklyStats` aggregation, `FocusStreak` (locked ≥25-min raw-active/day), a **data-driven badge catalogue** across all four families with `BadgeScope` permanent / weekly / **daily**, `EarnedBadges` (weekly + daily window resets), `AppSettings`, `StreakReminderPolicy`, and the store/OS interfaces (`HistoryRepository`, `EarnedBadgesRepository`, settings repo, `StartupController`, `Notifier`).
  - *Data:* three `shared_preferences`/JSON repos (settings, bounded ~90-day history, earned-badges) all with corrupt-blob-safe `load()`; `launch_at_startup` + `local_notifier` adapters confined to one file each.
  - *Presentation:* `StatsCubit` (per-tick projection, record-day-before-zero on rollover, badge evaluation, gated local toasts; serial `_tickChain`), `SettingsCubit`, and the stats / badges / settings / onboarding-privacy screens.
- **Seam (only edits to shipped code):** `ActivityTicker.onSnapshot` sink forwarding `engine.toProgress()` per tick + `main.dart` wiring (new repos, cubits, onboarding first-run gate, idle-threshold→engine rebuild, nav tabs). **Engine/route/journey domain logic untouched** — this slice is a pure consumer.
- **Decisions locked at kickoff (Kevin, 2026-06-24):** full settings scope incl. notifications; local calendar week (Mon–Sun) + bounded ~90-day per-day JSON history; all four badge families; streak qualifies on raw active time ≥25 min/day (inherited from journey-engine AC-15). The 5 spec open questions were resolved to the recommended defaults at approval.
- **Quality:** 21 functional ACs + 5 NFRs verified; `/privacy-audit` **PASS** (no new privacy surface; onboarding copy ⇄ code verified clause-by-clause; the two new deps add no input/screen/file/network capability); tests **green** — 191/191 in-scope, whole-package 484/484, stats coverage 88.5%.

## Deferred-verification carry-overs (do not lose — clear before public release)
- **TC-022 — runtime privacy socket-check.** `/privacy-audit` passed statically (clause-by-clause copy⇄code + grep); the runtime confirmation (packet-capture / `lsof` during a notification + startup-toggle on the real macOS/Windows build, incl. transitive native plugin code) is the manual ship-gate in [tests/cases/local-stats-manual-checklist.md](../../tests/cases/local-stats-manual-checklist.md). Owner: `privacy-guardian` + manual.
- **TC-NF5 — real-OS device legs.** Launch-at-startup registration (AC-10) and real toast delivery (AC-11/AC-12) are automated via injected fakes; the real-OS behaviour on macOS + Windows is unverified on device. Owner: `test-executor` + manual.
- **TC-NF4 — goldens deferred** (no per-OS golden harness in repo, as with journey-view); the rendered structure is asserted behaviourally in widget tests.
- **`main.dart` `TODO(local-stats)`** — pass the MSIX package identity to `launch_at_startup.setup(packageName:)` for a packaged Windows build (v1 unsigned builds use the resolved executable path, which is sufficient).

## What we'd do differently
- **Author ACs with the testability constraints baked in.** Best-focus-period had to be derived from *contiguous active ticks* (the engine exposes only aggregates, not per-event data); we caught this early, but stating the "no per-event data" constraint in the spec up front would have saved a clarification round.
- **A backwards/non-monotonic clock is a first-class case, not an afterthought.** Two of the three review Mediums were time-edge bugs (M1 DST `Duration(days:)` arithmetic; the backwards-clock double-count caught at self-review). Future time-bucketing slices should start from component-based local-midnight math and a DST/clock-skew test matrix rather than retrofitting it.
- **Pin badge `scope` semantics in the catalogue contract.** The daily focus-time badges were initially `weekly`-scoped, giving wrong reset semantics (M2). A scope→reset-window mapping documented alongside the catalogue would have prevented the miscategorisation.
- **`emit`-after-close discipline for any async Cubit driven by a fire-and-forget ticker** — the journey `ActivityTicker` already guarded this; the new `StatsCubit` didn't until B2. Worth a shared lint/convention note so the next ticker-driven cubit gets it for free.
- **The macOS desktop batch-integration relaunch limitation keeps recurring** — running integration files individually is now the norm; worth capturing in the runner docs so each slice doesn't rediscover it.

## Decisions made along the way
- 2026-06-24 (Kevin, at spec kickoff): settings = idle threshold + launch-at-startup + notifications;
  history = local calendar week (Mon–Sun) + bounded per-day JSON (~90 days); badges = all four families;
  streak qualifies on raw active time ≥25 min/day (inherited from journey-engine AC-15).
- 2026-06-24 (at spec approval): the 5 open questions resolved to recommended defaults — data-driven badge
  catalogue (tunable thresholds), 2 notification types (badge-earned + daily streak reminder, no-nag /
  not-while-active), best-focus = longest contiguous raw-active run (grace breaks it), ~90-day history cap,
  windowed badges reset at the Mon–Sun boundary.
- 2026-06-24 (review fix): added `BadgeScope.daily` (resets at local midnight, re-earnable daily) for the
  "best focus period today" / "daily goal" badges — matches the spec's own "today"/"in a day" wording.

## Status log
| Date | Note |
|------|------|
| 2026-06-24 | Promoted from backlog via `/new-feature local-stats`. Dependency `journey-engine` shipped (also `route-progress`, `journey-view`). Spec drafted; 4 decisions resolved at kickoff. Domain expert framed ACs; test-case-designer wrote cases. |
| 2026-06-24 | **Kevin approved the spec.** All 5 open questions resolved to recommended defaults. → Phase 3. |
| 2026-06-24 | **Phase 3 Build COMPLETE.** Full `lib/features/stats/` slice + `ActivityTicker.onSnapshot` seam + `main.dart` wiring (engine untouched). `unit-test-writer` +137 tests; `test-script-author` widget/integration + manual checklist. Test agents caught + fixed an AC-19 closed-across-midnight daily-zero defect. `/self-review` fixed B1 (backwards-clock double-count) + B2 (emit-after-close) w/ regression tests. analyze+format clean, 473 tests green. |
| 2026-06-24 | **Phase 4 Review.** `/review-code` **changes-requested** (no Critical/High): 3 Medium (M1 DST week math, M2 daily-badge scope, M3 async-tick re-entrancy) + 2 Low (#4 untested onboarding gate, #5 negative distance-today). `/privacy-audit` **PASS**. |
| 2026-06-24 | **Phase 4 findings RESOLVED.** `flutter-app-developer` fixed M1 (component-based dates; also fixed the same hazard in `focus_streak.dart`; DST tests), M2 (new `BadgeScope.daily` + daily reset), M3 (serial `_tickChain`), Low #5 (clamp). `unit-test-writer` closed Low #4 (`onboarding_gate_test.dart` + comment fix). Re-verify: analyze clean, format 0-changed, 484 green. |
| 2026-06-24 | **Phase 5 Test GREEN.** `/execute-tests`: 191/191 in-scope, whole-package 484/484, stats coverage 88.5%. Report `20260624-132008` (`verdict: green`). |
| 2026-06-24 | **Phase 6 SHIPPED.** All 21 ACs + 5 NFRs ticked; `spec.md` → `shipped`; planning moved to `planning/done/`. **Wave 1 (v1) is COMPLETE — all 5 slices shipped.** Carried: TC-022 runtime privacy check, TC-NF5 real-OS legs, TC-NF4 goldens, MSIX `launch_at_startup` TODO. |
