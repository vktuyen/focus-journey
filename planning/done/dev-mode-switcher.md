# Dev mode switcher — debug-only travel-mode dropdown

**Promoted from backlog:** 2026-06-26 (quick-change — no backlog item; inline stub spec)
**Target:** dev tooling for eyeballing `journey-cockpit-lean`
**Spec:** [specs/dev-mode-switcher/](../../specs/dev-mode-switcher/spec.md)

> **REMOVED 2026-06-26** (Kevin's request) — superseded by the production **`vehicle-picker`** (Wave 3, the
> real icon-based selector). The debug dropdown + its `onDevModeSelected` wiring (`journey_screen.dart`,
> `main.dart`) and `dev_mode_switcher_test.dart` were deleted; `analyze` clean, affected suites green. The
> slice served its purpose (live mode-switching to eyeball the cockpit lean) and is no longer needed now
> that users can pick a vehicle for real. This record is kept for history.

## Goal
A `kDebugMode`-gated top-center dropdown on the full journey screen that flips `TravelMode` live (sets
`engine.mode` + republishes via the cubit), so the cockpit/sprite swaps immediately; absent in release builds.

## Phase ledger
**This is a `/quick-change`** — the 6-phase pipeline is collapsed to one lean pass. Phase 2 (Spec) was the
inline stub (approved on confirm — no separate review round-trip); phases 3→4→5→6 run as the single command.

| ✓ | Phase | Command | Date | Verdict / note |
|---|-------|---------|------|----------------|
| [x] | 2 · Spec (inline stub) | `/quick-change` | 2026-06-26 | Stub spec + 4 inline ACs; placement confirmed (top-center, full window); `Status: approved` |
| [x] | 3 · Build + unit-test + self-review | `/quick-change` | 2026-06-26 | flutter-app-developer: `JourneyScreen.onDevModeSelected` + `kDebugMode`-gated top-center `_DevModeSwitcher` (`Key('dev-mode-switcher-dropdown')`); `main.dart` callback `_engine.mode = m; _cubit.updateFromEngine(_engine)`. unit-test-writer: 6 tests. analyze clean. |
| [x] | 4 · Review | `/quick-change` (flutter-code-reviewer) | 2026-06-26 | verdict: **approved-with-suggestions**, 0 Blocking. Applied the one actionable item (`dart format` test file); `/privacy-audit` N/A (reads no OS signal). |
| [x] | 5 · Test | `/quick-change` | 2026-06-26 | verdict: **green** — 16/16 (6 switcher + 10 journey_screen regression). Report `tests/_runner/reports/dev-mode-switcher/20260626-102703/summary.md`. |
| [x] | 6 · Ship | `/quick-change` | 2026-06-26 | spec `Status: shipped`; AC-1..4 all `[x]`; moved to `planning/done/`. |

**Current phase:** SHIPPED (2026-06-26)   **Next:** none — `fvm flutter run -d macos` (debug) to use the top-center switcher.

## Decisions made along the way
- Debug-only via `kDebugMode` (not the production `vehicle-picker`, which is Wave-3 + needs a precedence ADR).
- Write happens in `main.dart`'s callback (`_engine.mode = m; _cubit.updateFromEngine(_engine)`) so
  `JourneyCubit` keeps its "never writes the engine" purity; `JourneyScreen` gains optional `onDevModeSelected`.
- Top-center overlay, full window only (no PiP).
