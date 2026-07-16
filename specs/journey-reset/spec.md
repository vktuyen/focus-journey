# Journey reset — factory reset + resume-or-start-over on launch

**Status:** shipped (2026-07-15, dev build — macOS-verified; NFR-1 on-device instant-feel + NFR-3 real screen-reader + Windows runtime carried to the manual checklist)
**Owner:** Kevin (Tuyen Vo)
**Last updated:** 2026-07-15
**Wave:** refine-app-ui-ux (Wave 1 · opening slice)

## Problem
Today a user has no explicit, in-control way to start their journey fresh. The only "reset" is a silent
route abandonment buried in the engine — there is no way to (a) wipe all local data back to a clean
first-run state, or (b) choose, on reopening the app, whether to continue the journey in progress or begin
a new one. This hurts the two v1 personas: the **focused individual** who wants to retire a stale route and
pick a new vehicle/start/end without losing hard-earned lifetime progress, and the **privacy-skeptical
teammate** who wants a single, obvious control that provably erases everything stored locally — a concrete,
visible expression of the local-only privacy promise.

## User & outcome
- **Focused individual:** on reopen, is offered **Resume** or **Start over**; Start over lets them author a
  new route (vehicle/start/end) while lifetime distance, stats, streaks, and badges are **preserved**.
- **Privacy-skeptical teammate:** finds a **Factory reset** in Settings that, after an explicit confirmation,
  clears *all* local data and returns the app to a true first-run state.
- Observable success: reset genuinely wipes everything (next launch = onboarding); the launch prompt appears
  only when a journey is in progress; Resume restores the exact prior position; Start over keeps lifetime
  stats while replacing the route.

## Scope
### In
- A **Factory reset** action in the Settings tab: explicit destructive confirmation → clears every persisted
  key → app returns to first-run onboarding.
- A launch-time **Resume vs Start over** prompt, shown only when an `active` journey/route exists.
- **Start over** = author a new route via the existing `abandoned` route lifecycle (ADR-0005), keeping
  lifetime distance / stats / streaks / badges.
- A single aggregating **reset seam** so every repository's data is cleared (no half-reset), plus correct
  in-memory re-initialisation after a wipe so nothing re-persists stale state.

### Out
- No new persistence technology (stays on `shared_preferences`/JSON).
- No change to the engine's accrual model, the distance/stats split (BR-6), or route geography.
- No cloud/backup/export of the data being cleared — local only.
- No team, online, leaderboard, or AI features (out of product scope per the roadmap guardrail).

## Constraints & assumptions
- **Reuse, don't reinvent:** Start over must route through the shipped ADR-0005 `abandoned` lifecycle
  (new `routeStartOffset` over the never-reset engine distance), not a parallel path.
- **BR-8 carve-out:** BR-8 guarantees cumulative distance/streak/badges persist across *automatic*
  resets/restarts; a *user-initiated Factory reset* is a deliberate exception that clears them. This must be
  documented and surfaced so the user isn't surprised by the asymmetry (Start over keeps them, Factory reset
  wipes them).
- **Privacy (BR-1) unchanged:** no new reads or network; this feature only *deletes* local data.
- Persisted keys in scope for the full wipe: `app_settings_v1`, `journey_progress_v1`, `route_plan_v1`,
  legacy `route_selection_v1`, `stats_history_v1`, earned-badges, and the two `mini_window` keys
  (compact-window position, hide-to-tray hint).

## Acceptance criteria

- [x] AC-1: Given the user is in the Settings tab, when they open the Factory reset action, then an explicit destructive confirmation dialog appears (clearly labelled irreversible, distinct from Start over) and no data is touched until they confirm.
- [x] AC-2: Given the Factory reset confirmation dialog is open, when the user cancels (or dismisses) it, then all local data remains intact and the app stays in its current state.
- [x] AC-3: Given a user with an active journey plus lifetime distance, streaks, and badges, when they confirm Factory reset, then every persisted key is cleared — `app_settings_v1`, `journey_progress_v1`, `route_plan_v1`, legacy `route_selection_v1`, `stats_history_v1`, earned-badges, and both `mini_window` keys (compact-window position and hide-to-tray hint).
- [x] AC-4: Given Factory reset has just completed, when the app re-initialises, then the in-memory engine, ticker, and Blocs are reconstructed to a zero state so no stale value re-persists (no half-reset, no phantom journey rehydrated on the next save).
- [x] AC-5: Given Factory reset has completed, when the app is next launched, then it shows true first-run onboarding (choose vehicle, start point, end point) with zero prior stats/streaks/badges and the window/tray restored to first-run defaults — and the Resume vs Start over prompt is suppressed.
- [x] AC-6: Given the app is reopened while an `active` journey/route exists, when the launch flow runs, then a Resume vs Start over prompt is shown before entering the journey.
- [x] AC-7: Given the app is reopened on a fresh install or with no `active` route (completed or abandoned), when the launch flow runs, then the prompt does not appear and the app goes straight to onboarding/route-authoring.
- [x] AC-8: Given an in-progress journey at a known progress point (route, vehicle, distance/position), when the user reopens and chooses Resume, then the journey continues from the identical prior position with no loss or drift.
- [x] AC-9: Given an in-progress journey and existing lifetime stats/streaks/badges, when the user chooses Start over, then the current route is marked `abandoned` via the ADR-0005 lifecycle (fresh `routeStartOffset` over the never-reset engine distance) and they are handed to route authoring to pick a new vehicle/start/end.
- [x] AC-10: Given the user completes a Start over, when the new route is authored, then only `route_plan_v1` (and legacy `route_selection_v1`) is replaced while `stats_history_v1`, cumulative lifetime distance, streaks, earned badges, and `app_settings_v1` are all retained unchanged.
- [x] AC-11: Given the user has just done a Start over, when the app is reopened with the new route `active`, then the launch flow offers Resume on that new route.
- [x] AC-12: Given identical starting lifetime stats/streaks/badges, when the user does a Start over versus a Factory reset, then the cumulative values survive the Start over but are cleared by the Factory reset — an observable asymmetry surfaced in-product so the user is not surprised (documented BR-8 carve-out).

### Non-functional
- [ ] NFR-1 Performance: The full wipe + in-memory re-init and the launch-gate decision each complete fast enough to feel instant (no perceptible spinner/stall on reset confirmation or on reopen). _(Carried: on-device instant-feel TC-M-NF1 — no automated timing measurement.)_
- [x] NFR-2 Security/Privacy: The feature only deletes local data — it introduces no new reads and no network surfaces, leaving BR-1 intact (and no cloud/backup/export of the cleared data). _(privacy-audit PASS, 2026-07-15.)_
- [ ] NFR-3 Accessibility: Both the Factory reset confirmation dialog and the launch Resume/Start over prompt are fully keyboard-navigable and screen-reader reachable, with the destructive Factory reset action clearly labelled and visually distinguished from the non-destructive Start over. _(Deterministic Semantics/keyboard tested — TC-725 green; real screen-reader TC-M-A11Y carried.)_

## Open questions
- [ ] Factory-reset confirmation UX — wording + does Start over get a lighter confirm than the destructive full wipe? — owner: product-domain-expert / Kevin
- [ ] Does the launch prompt offer Resume on the *new* route after a Start over (yes, expected)? — owner: product-domain-expert

## Related
- Backlog framing: [planning/backlog/journey-reset.md](../../planning/backlog/journey-reset.md) _(consumed on promotion)_
- Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md) — BR-1, BR-6, BR-8, BR-10
- Architecture: [docs/architecture/](../../docs/architecture/) — ADR-0005 (route lifecycle)
