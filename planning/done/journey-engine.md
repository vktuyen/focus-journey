# Journey Engine

**Promoted from backlog:** 2026-06-23
**Shipped:** 2026-06-23 (Wave 1 / v1)
**Target:** Wave 1 (v1) — alongside `activity-detection` (shipped)
**Spec:** [specs/journey-engine/](../../specs/journey-engine/) — `Status: shipped (2026-06-23)`
**Green report shipped on:** [tests/_runner/reports/journey-engine/20260623-181042/](../../tests/_runner/reports/journey-engine/20260623-181042/summary.md) — `verdict: green`, 63/63

## Goal
A pure, framework-free Dart `JourneyEngine` — injected clock + injected `ActivityPlugin`, ticking on
real elapsed-time deltas — that honestly converts active time into virtual distance (speed-only),
tracks journey-time vs raw-active-time separately, handles sleep/wake + midnight resets, and
persists/restores daily progress. Fully unit-testable with no real timers.

## Plan
- [x] Spec drafted & ACs proposed (`product-domain-expert`)
- [x] Spec reviewed & approved by Kevin (2026-06-23)
- [x] Test cases designed (`test-case-designer` → `tests/cases/journey-engine.md`, TC-001..022)
- [x] Implement (`/implement`) — engine + persistence + 63 unit tests; self-review blockers fixed
- [x] Review (`/review-code`) — **approved** (2 Medium follow-ups, no blockers); privacy audit **pass**
- [x] Execute tests (`/execute-tests`) — **green** 63/63 (report `20260623-181042`)
- [x] Ship (`/ship`) — **SHIPPED 2026-06-23**; all 21 ACs ticked (M-1 ratified); spec `shipped`; moved to `planning/done/`

## Phase ledger
- [x] Phase 2 · Spec — `/new-feature` → review & approve `spec.md`  *(spec `approved`; 16 ACs; 22 test cases; planning created)*
- [x] Phase 3 · Build — `/implement`  *(engine + repo built; 63 journey unit tests; `/self-review` run → 2 blockers fixed; analyze + format clean; suite 94/94 green)*
- [x] Phase 4 · Review — `/review-code`  (verdict: **approved** w/ 2 Medium follow-ups; privacy audit **pass**)
- [x] Phase 5 · Test — `/execute-tests`  (verdict: **green** — 63/63, report `20260623-181042`)
- [x] Phase 6 · Ship — `/ship`  (**SHIPPED 2026-06-23**; M-1 ratified; AC-8 ticked)

**Current phase:** DONE (shipped 2026-06-23). **Unblocks:** `journey-view`, `route-progress`, `local-stats` (rest of Wave 1).

## What shipped
- **`JourneyEngine`** (pure Dart, *domain*) under `src/focus_journey/lib/features/journey/` — the core
  loop. `tick(delta, idleSeconds, screenLocked)` converts active time into distance via a single shared
  speed (`kmPerActiveHour`, default 250), tracking `distanceKm`, `activeTimeToday` (journey time, incl.
  grace), `rawActiveTime` (true input, no grace — the streak metric), `idleTimeToday`, `state`, and `mode`.
- **Two-knob decision policy** (Kevin's call): grace window `G` + idle threshold `T` (`G ≤ T`, default
  `G = T = 5 min`), plus a small active floor `F`. Bands: `active` / `grace-travelling` / `idle` / `paused`.
- **Injected clock + injected `ActivityPlugin`** — no real timers, no `DateTime.now()` in the engine;
  fully deterministic. `tickFromPlugin` is the thin async convenience seam for the (out-of-scope) ticker.
- **Sleep/wake correctness (idle-only inference + clamp)** — sleep is inferred from a **large idle reading**
  (or lock), never from `delta` alone; an over-sized travelling tick is **clamped** to `maxTickDelta` so a
  stalled ticker neither over-credits nor silently discards real work.
- **Day-boundary resets** (local midnight on tick + closed-across-midnight on restore) preserving cumulative
  distance; **persistence** via `JourneyRepository` → `SharedPreferencesJourneyRepository` (JSON, one key,
  corrupt-blob-safe `load() → null`).
- **Tests:** 63 deterministic unit tests (engine 44 · progress 4 · repository 15) covering TC-001..TC-022 +
  B-*/S-* hardening. `/review-code` **approved**, `/privacy-audit` **pass**, `/execute-tests` **green 63/63**.
- **M-1 ratified at ship (Kevin, 2026-06-23):** idle-only sleep inference adopted as the design; AC-5/AC-6,
  AC-8 note, and TC-007 reworded to drop the "or large `delta` alone" sleep clause; AC-8's both-large case
  unaffected (and tested). Docs-only change — engine/test code unchanged, so the `20260623-181042` green
  report still covers the shipped code.

## What we'd do differently
- **Tick the ACs as each phase proves them, not at ship.** All 21 ACs sat unchecked through build/review/test
  and only surfaced at the `/ship` Gate-1 check, forcing a stop. `/implement` and `/execute-tests` should
  flip AC boxes as evidence lands, so ship is a formality not a scramble.
- **Surface design divergences as an explicit decision the moment they're coded.** The idle-only sleep
  inference (M-1) was a deliberate, well-reasoned choice made during `/self-review` (B-1), but it silently
  contradicted the AC/TC wording until review caught it. A one-line "this diverges from AC-x, needs
  ratification" flag at code time would have avoided carrying an unratified divergence to the ship gate.
- **Keep AC/TC wording and the chosen design in lockstep.** "and/or large delta" lingered in four places
  (spec, AC header, AC-5/6, TC-007 + preamble) after the design settled on idle-only — easy to miss. A
  single source-of-truth sentence for the sleep rule, referenced from each doc, would cut the drift.

## Open follow-ups (non-blocking; carried forward)
- **M-2 — `tickFromPlugin` error policy** → `flutter-app-developer`. The convenience method propagates the
  typed `ActivityPluginException` with no fallback; the app-layer ticker (its caller) needs a documented
  policy (treat-as-paused / skip-tick) so one denied read can't kill the periodic loop. Lives with the
  ticker wiring (out of this slice's scope) or a small follow-up edit.
- **Test hardening** → `unit-test-writer`: add a direct assertion for the null-restore branch
  (`loadAndRestore` when `load()` returns null); `tickFromPlugin` is currently untested (folds into M-2).
- **`kmPerActiveHour` seam** → confirm with `route-progress` so both slices agree on the real rate (the
  shipped 250 is a documented placeholder default). Spec open question still open.
- **Low/Nit items from review** (day-rollover first-post-midnight attribution note; extract a single
  `_isNewDay` helper; in-memory fake vs repo corrupt-blob guard; clamp/assert negative idle) — cosmetic,
  pick up opportunistically.

## Decisions made along the way
- Engine owns the active/idle/paused decision policy (threshold + grace); `activity-detection` only provides raw signals.
- Speed-only distance, single shared `kmPerActiveHour`; `mode` cosmetic in v1 (per-mode/energy → v2 `journey-energy-model`).
- Persistence via `shared_preferences`/JSON behind a repository interface.
- **Spec/upstream fix:** the shipped `ActivityPlugin` has **no sleep boolean** (only `getSystemIdleSeconds()` + `isScreenLocked()`); sleep is **inferred** from a large idle reading. Spec + ACs corrected.
- **Kevin's calls (2026-06-23):** (1) grace & threshold are **two independent knobs** (`G ≤ T`, default `G = T = 5 min`); (2) streak qualifies on **raw active time**; (3) app-closed-across-midnight ⇒ **reset, no reconstruction**; (4) grace **stays travel** on timeout (no rollback); (5) **[G,T] middle-band** = idle (distance stops at `G`); (6) **sleep inferred from idle only, not `delta`** — large `delta` is clamped (ratifies M-1).

## Status log
| Date | Note |
|------|------|
| 2026-06-23 | Promoted from backlog via `/new-feature journey-engine`. Spec drafted; `product-domain-expert` proposed 16 ACs. Fixed spec/upstream mismatch (no sleep boolean — inferred). |
| 2026-06-23 | Kevin resolved 4 product decisions (two-knob grace/threshold · raw-active streak · reset-no-reconstruct · grace-stays-travel) and **approved the spec**. `test-case-designer` wrote 22 cases (TC-001..022) to `tests/cases/journey-engine.md`. Phase 2 complete → ready for `/implement`. |
| 2026-06-23 | **Phase 3 Build complete.** `flutter-app-developer` built the pure-Dart `JourneyEngine` + `JourneyProgress`/`JourneyRepository` + `SharedPreferencesJourneyRepository` + `Clock` seam under `src/focus_journey/lib/features/journey/`. `unit-test-writer` wrote 63 deterministic journey unit tests (all 22 TCs). `/self-review` (`flutter-code-reviewer`) found 2 blockers — **B-1** sleep inference keyed on `delta` alone could silently discard real active travel (fixed: sleep now keyed on the idle signal; `sleepGapThreshold` repurposed as a `maxTickDelta` accrual clamp), **B-4** corrupt persisted JSON crashed startup (fixed: `load()` returns null on any unreadable blob). Also S-2 (constructor `ArgumentError` validation) + format. analyze + `dart format` clean; full suite **94/94 green**. → ready for `/review-code`. |
| 2026-06-23 | **Phase 4 Review complete — verdict `approved`.** `flutter-code-reviewer` reviewed `lib/features/journey/**` (7 prod files) + 3 journey test files vs spec/ACs/cases: no Critical/High; **M-1** sleep inference keys on idle only — diverges from AC-8/TC-008 "large delta and/or large idle" (deliberate, clamp-bounded, but needs Kevin/`product-domain-expert` to ratify + doc edit); **M-2** `tickFromPlugin` has no fallback for the typed `ActivityPluginException` (route to `flutter-app-developer`); plus Lows and Nits. Test gaps → `unit-test-writer`: TC-007 large-`delta`-as-sleep path not asserted (a test asserts the *opposite*), `tickFromPlugin` entirely untested, null-restore branch not directly asserted. Architecture/Effective-Dart/DI all pass. **Privacy audit (`privacy-guardian`) → `pass`.** No fixes applied (review-only). → ready for `/execute-tests`. |
| 2026-06-23 | **Phase 5 Test complete — verdict `green`.** `test-executor` ran `fvm flutter test test/features/journey/ --reporter expanded --coverage` (Flutter 3.38.10/Dart 3.10.9): **63/63 passed**, 0 failures, 0 flakes, ~3s, exit 0. All cases TC-001..TC-022 mapped to ≥1 passing test (+ B-2/B-3/B-4, S-2/S-4/S-6 hardening). No coverage gaps; no mechanical patches. Report at `tests/_runner/reports/journey-engine/20260623-181042/` (`summary.md` → `verdict: green`). → ready for `/ship`. |
| 2026-06-23 | **`/ship` attempt #1 — HELD at Gate 1.** Green report verified, cases clean — but all 21 ACs were still `[ ]`. On Kevin's call ticked 20/21 (AC-1..7, AC-9..16, NFRs); **AC-8 held back** pending ratification of review **M-1** (idle-only sleep inference vs the AC's "large `delta`" clause). Did not ship. |
| 2026-06-23 | **M-1 ratified by Kevin → `/ship` attempt #2 COMPLETE — SHIPPED.** Kevin chose to ratify the idle-only design. Reworded spec (decision policy, sleep/wake, per-tick rule + a new Resolved-decision bullet), AC-5/AC-6 + AC header, and TC-007 (+ cases preamble) to drop "or large `delta` alone = sleep" — a large `delta` is clamped to `maxTickDelta`, never slept; AC-8's both-large case is unaffected and already tested (`wasActive_thenLargeGapTick…`). Docs-only change (engine/test code untouched), so the `20260623-181042` green report still covers shipped code. **Ticked AC-8 → all 21 ACs `[x]`.** Set spec `Status: shipped (2026-06-23)`; moved `planning/active/journey-engine.md` → `planning/done/`. Non-blocking follow-ups (M-2, test hardening, `kmPerActiveHour` seam) carried in "Open follow-ups". |
