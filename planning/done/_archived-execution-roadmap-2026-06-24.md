# Execution Roadmap — How to actually build Vietnam Focus Journey

> Personal "what do I do next" guide. Combines the **6 phases**, the **v1/v2/v3 waves**, and the
> **epic → child slices** structure into one checklist. For the canonical high-level roadmap see
> [roadmap.md](roadmap.md); for the full phase reference see
> [../docs/guides/development-workflow.md](../docs/guides/development-workflow.md).

_Last updated: 2026-06-24 (**🎉 Wave 2 (v2) — `mini-window` SHIPPED (macOS-verified).** All 6 phases done: spec approved · ADR-0003 single-window two-mode · built (spike-gate PASS, Lucide ISC tray icons, self-review B1/NFR-1 fixed) · `/review-code` `approved` · `/privacy-audit` PASS · `/execute-tests` `green` (92 in-scope + 559/559; report `20260624-152719`) · `/ship` (18 ACs + 9 NFRs ticked, spec `shipped`, moved to `planning/done/`). Carried before public/Windows release: review Medium #1 Windows tray-icon authoring + Windows runtime (NFR-9) · macOS manual legs TC-M1/M2/M3/M4 · NFR-2 fps · runtime privacy TC-022/TC-M-PRIV. **Next: start the next v2 slice — `journey-energy-model` / `map-geographic` / `team-leaderboard`.** Superseded prior Phase-5 entry below.)_

_(prior) 2026-06-24 (**🚀 Wave 2 (v2) — `mini-window` Phase 2 (Spec) COMPLETE; Phase 3 (Build) NEXT.** Spec **approved**: YouTube-style user-invoked, mutually-exclusive PiP + always-present menu-bar icon (hide-to-tray, keep tracking) + fixed compact size; launch-at-startup OUT (`local-stats` owns it). Wiring settled by `system-architect` → **single window, two modes**, recorded in **ADR-0003** (`overview.md` v2 model updated). `product-domain-expert` gave **18 ACs + 9 NFRs**; `test-case-designer` gave **28 test cases** + manual checklist (full AC/NFR→TC traceability). **Next: `/implement mini-window` — run the ADR-0003 macOS spike-gate FIRST.** Superseded prior entries below.)_

_(prior) 2026-06-24 (**🎉 `local-stats` SHIPPED 2026-06-24 — Wave 1 (v1) is COMPLETE: all 5 slices shipped.** Green report `20260624-132008` (191/191 in-scope, whole-package 484/484, stats coverage 88.5%); all 21 ACs + 5 NFRs ticked; `/privacy-audit` PASS; spec `shipped`; planning moved to `planning/done/`. Carried deferred legs: TC-022 runtime privacy socket-check · TC-NF5 real-OS launch/toast legs · TC-NF4 goldens · MSIX `launch_at_startup` TODO. **Next: begin Wave 2 (v2)** — promote its slugs with `/capture-idea`/`/new-feature` (`map-geographic` already unblocked). Superseded prior entry below.)_

_(prior) 2026-06-24 (**`local-stats` Phase 3 (Build) COMPLETE** — Kevin approved the spec (all 5 OQs resolved); `flutter-app-developer` built the full `lib/features/stats/` slice (domain/data/presentation) + `ActivityTicker.onSnapshot` seam + `main.dart` wiring (shipped engine untouched); `launch_at_startup` + `local_notifier` behind interfaces. `unit-test-writer` +137 tests; `test-script-author` widget/integration + manual checklist. `/self-review` found+fixed 2 blockers (B1 backwards-clock double-count, B2 emit-after-close) w/ regression tests, plus an AC-19 closed-across-midnight daily-zero defect. analyze clean, format clean, **473 tests green**. **Next: `/review-code local-stats` + `/privacy-audit`.** Wave 1: **4/5 shipped, 5th in review**.)_

---

## 1. The mental model (read this once)

The key insight: **the 6 phases run per-slug, and a "wave" (v1/v2/v3) is just a batch of slugs
you push through those phases.** There is no separate "start v2" button — v1 *is* running Wave-1's
5 slugs through the pipeline.

```
EPIC (Vietnam Focus Journey)        ← captured once (Phase 0/1) — DONE
 │
 ├─ WAVE 1 (v1)  = { activity-detection, journey-engine, journey-view, route-progress, local-stats }
 ├─ WAVE 2 (v2)  = { mini-window, journey-energy-model, map-geographic, team-leaderboard }
 └─ WAVE 3 (v3)  = { ai-coach, signed-distribution }

Each SLUG runs the 6-phase pipeline on its own:
  Phase 1 Capture → 2 Spec → 3 Build → 4 Review → 5 Test → 6 Ship
       (done once for the epic)    └──────── you repeat this per slug ────────┘
```

**Rules of the road:**
- **Wave discipline** — finish *all* of Wave 1 before starting Wave 2. Child files for Waves 2–3
  don't exist yet; they're created when their wave starts.
- **Enhancing a shipped slug = a NEW slug in a later wave** (e.g. `journey-energy-model` enhances
  the shipped `journey-engine`), tagged `[blocked by: <slug>]`. Never re-run `/implement` on a
  shipped slug to add new behaviour.
- **Validate the loop cheaply** — local-only v1 before any backend / AI / code-signing investment.
- **Privacy-first, always** — read only aggregate idle time; never keystrokes/screen/files.

---

## 2. Where I am right now

- [x] Phase 0/1 — epic captured; 5 Wave-1 child slices sit in `planning/backlog/`
- [x] Architecture bootstrapped — `docs/architecture/overview.md` filled + `ADR-0002` (stack) written
- [x] **`activity-detection` Phase 2 (Spec) COMPLETE** — spec `approved`; 11 ACs; 20 test cases (TC-001..020); `test-plan.md` written
- [x] **`activity-detection` Phase 3 (Build) COMPLETE** — repo pinned to fvm Flutter 3.38.10; `/flutter-bootstrap` scaffolded `src/focus_journey`; spike → custom platform-channel plugin; `ActivityPlugin` (interface + macOS Swift + Windows C++ + mock + DI) built; 30 unit tests + integration/manual harness; self-review Blocking fixed; analyze clean, suite green
- [x] **`activity-detection` Phase 4 (Review) COMPLETE** — `/review-code`: changes-requested (0 blocking); `/privacy-audit` **PASS**. Findings m1/m2/m3 accepted as documented limits (L1/L2)
- [x] **`activity-detection` Phase 5 (Test) COMPLETE** — `/execute-tests` **GREEN 36/36** on macOS device (`reports/activity-detection/20260623-170514/`)
- [x] **`activity-detection` Phase 6 (Ship) COMPLETE — SHIPPED 2026-06-23 (macOS-verified)** — moved to `planning/done/`; spec `shipped`. **Windows runtime verification deferred (L3)** — AC-2/AC-5/AC-3/AC-9 + parity NFR remain to be checked on Windows hardware before any Windows release
- [x] **`journey-engine` Phase 2 (Spec) COMPLETE** — spec `approved`; 16 ACs; 22 test cases (TC-001..022). Kevin resolved 4 product decisions (two-knob grace/threshold · raw-active streak · reset-no-reconstruct · grace-stays-travel); fixed spec/upstream mismatch (no sleep boolean — inferred). `planning/active/journey-engine.md` created.
- [x] **`journey-engine` Phase 3 (Build) COMPLETE** — pure-Dart `JourneyEngine` + `JourneyProgress`/`JourneyRepository` + `SharedPreferencesJourneyRepository` + `Clock` under `src/focus_journey/lib/features/journey/`; 63 deterministic unit tests (all 22 TCs). `/self-review` fixed 2 blockers (B-1 sleep keyed on idle not delta + `maxTickDelta` clamp; B-4 corrupt-JSON load returns null) + S-2 constructor validation. analyze + format clean; full suite **94/94 green**.
- [x] **`journey-engine` Phase 4 (Review) COMPLETE** — `/review-code` verdict **`approved`** (no Critical/High; 2 Medium follow-ups: M-1 sleep-inference diverges from AC-8 `delta` clause → ratify w/ Kevin + doc edit; M-2 `tickFromPlugin` error policy → `flutter-app-developer`; test gaps → `unit-test-writer`). `/privacy-audit` **PASS** (aggregate idle + lock only; persistence aggregate-only; no taps/hooks/screen/clipboard). No fixes applied (review-only).
- [x] **`journey-engine` Phase 5 (Test) COMPLETE** — `/execute-tests` **GREEN 63/63** (`fvm flutter test test/features/journey/`, 0 failures/flakes, ~3s). All TC-001..TC-022 mapped to passing tests; no coverage gaps. Report at `tests/_runner/reports/journey-engine/20260623-181042/` (`verdict: green`).
- [x] **`journey-engine` Phase 6 (Ship) COMPLETE — SHIPPED 2026-06-23.** Kevin ratified review **M-1** (sleep inferred from a large *idle* reading only; a large `delta` alone is clamped to `maxTickDelta`, never slept). Reworded spec + AC-5/AC-6 + AC header + TC-007 to match; AC-8's both-large case unaffected & tested. All 21 ACs ticked; spec `Status: shipped (2026-06-23)`; `planning/active/journey-engine.md` → `planning/done/`. Green report `20260623-181042` (63/63) covers the shipped code (M-1 was docs-only). Non-blocking follow-ups carried: **M-2** `tickFromPlugin` error policy → `flutter-app-developer`; test hardening (null-restore, `tickFromPlugin`) → `unit-test-writer`; `kmPerActiveHour` seam → `route-progress`.
- [x] **`journey-view` Phase 2 (Spec) COMPLETE** — spec `approved`; AC-1..AC-14 + non-functional; 27 test cases (TC-001..027) in `tests/cases/journey-view.md`. Kevin resolved all 6 open questions (short ease · binary scroll speed · injected-clock day/night · generic "Paused — idle" copy · distance counter is a sibling Flutter widget · Kenney CC0 asset pack) + 4 domain-expert defaults (idle≡paused visual · honour reduce-motion · first-frame parked · graceful missing-asset). `planning/active/journey-view.md` created.
- [x] **`journey-view` Phase 3 (Build) COMPLETE** — Flame scene + `JourneyViewState`/`JourneyCubit`/`ActivityTicker` (M-2) /`JourneyScreen` + `main.dart`; 12/13 Kenney CC0 sprites. 166 tests green. `/self-review` Blocking **B-1** (orphaned asset future) **FIXED**.
- [x] **`journey-view` Phase 4 (Review) COMPLETE** — `/review-code` changes-requested → **resolved** (H-1 dart-format gate green; H-2 narrowed — 3 unrendered background layers dropped, manifest 13→10); `/privacy-audit` **PASS** (TC-026).
- [x] **`journey-view` Phase 5 (Test) COMPLETE** — `/execute-tests` **GREEN 167/167** (`reports/journey-view/20260624-092732/`). Goldens TC-022/023/025 + on-device perf TC-015/016 deferred (documented).
- [x] **`journey-view` Phase 6 (Ship) COMPLETE — SHIPPED 2026-06-24 (macOS-verified live).** All 14 functional ACs + 6 NFRs ticked; spec `shipped`; `planning/active/journey-view.md` → `planning/done/`. Live run confirmed road/objects/vehicle/counter render with no asset errors. **⚠️ Deferred carry-over: on-device fps (TC-015/016 "frame-rate" NFR) unmeasured — run on macOS+Windows before public release.** Polish (P-1 scroll-speed, P-2 motorbike size/blur) + self-review (S-1..S-5/M-1/L-1) follow-ups carried.
- [x] **`route-progress` Phase 2 (Spec) COMPLETE** — spec **approved**; **22 ACs**; all **5 open questions** resolved at approval (per-route offset · route owns `totalChainKm≈2000`+injected rate 250 · distance-based full-chain % · block off-direction tips · curated ~10–15 checkpoints); **24 test cases**; `test-plan.md` filled.
- [x] **`route-progress` SHIPPED 2026-06-24** — full slice built (pure domain resolver + 13-node/2000 km chain · `shared_preferences` repo · custom-painted map/picker/cubit) wired via an `ActivityTicker.onDistance` **scalar** seam — route cubit holds **no engine reference** (AC-16/17 by construction), shipped engine untouched (`kmPerActiveHour` injected = 250). Mid-build surfaced & ratified an AC-8-vs-AC-11 contradiction (arrival=complete, full-chain honest %); `/self-review` + `/review-code` blockers (B-1 stale test) fixed; `/privacy-audit` **PASS** (zero new surface); `/execute-tests` **green** (145/145 in-scope incl. integration on-device, 308/308 regression; report `20260624-113456`). All 18 ACs + 4 NFRs ticked; spec `shipped`; moved to `planning/done/`. **Unblocks v2 `map-geographic`.**
- [x] **`local-stats` Phase 2 (Spec) COMPLETE** — `/new-feature local-stats` scaffolded `specs/local-stats/`; **26 ACs** + **26 test cases** + `test-plan.md`. **Kevin approved** (2026-06-24); all 5 open questions resolved to recommended defaults (data-driven badge catalogue · 2 notification types w/ no-nag · best-focus = longest contiguous raw-active run · ~90d history cap · windowed badges reset Mon–Sun).
- [x] **`local-stats` Phase 3 (Build) COMPLETE** — `/implement`: full `lib/features/stats/` slice (domain stats/weekly/streak/badge math + best-focus tracker · 3 `shared_preferences` stores + 2 OS-interface adapters `launch_at_startup`/`local_notifier` · StatsCubit/SettingsCubit + stats/badges/settings/onboarding screens). Only shipped-code edits: `ActivityTicker.onSnapshot` sink + `main.dart` wiring (engine logic untouched). +137 unit/cubit tests (`unit-test-writer`) + widget/integration tests + manual checklist (`test-script-author`). `/self-review` fixed 2 blockers (B1 backwards-clock double-count · B2 emit-after-close) + AC-19 closed-across-midnight daily-zero defect, all w/ regression tests. analyze clean, format clean, **473 tests green**.
- [x] **🎉 Wave 1 (v1) COMPLETE 2026-06-24** — all 5 slices shipped, in `planning/done/`.
- [x] **Wave 2 (v2) — `mini-window` ✅ SHIPPED 2026-06-24 (macOS-verified)** — all 6 phases done: spec approved · ADR-0003 single-window two-mode · built (spike-gate PASS, Lucide ISC tray icons, self-review B1 fixed) · `/review-code` `approved` · `/privacy-audit` PASS · `/execute-tests` `green` (92 in-scope + 559/559; report `20260624-152719`) · `/ship` (all ACs ticked, spec `shipped`, moved to `planning/done/`).
- 👉 **Next action:** start the next Wave-2 slice — `journey-energy-model`, `map-geographic`, or `team-leaderboard` via `/capture-idea <slug>` → `/new-feature <slug>`. See §7.

> **Start every new session with `/status`** — it reads the on-disk artifacts and prints the exact
> next command for each active slug.

---

## 3. The per-slug command loop (memorize this)

For **each** slug, run these 5 commands in order. Each is one phase; each has a gate you must pass
before moving on.

| # | Command | Phase | Gate before moving on |
|---|---|---|---|
| 1 | `/new-feature <slug>` | 2 Spec | I review the spec and set `spec.md` → `status: approved` |
| 2 | `/implement <slug>` | 3 Build | All ACs have code; unit tests pass locally |
| 3 | `/review-code <slug>` | 4 Review | Verdict `ready`; no open P0/P1 findings |
| 4 | `/execute-tests <slug>` | 5 Test | Verdict `green`; P0 ACs ticked `[x]` |
| 5 | `/ship <slug>` | 6 Ship | Machine-checks the green report, archives to `planning/done/` |

Project-specific helpers fire **automatically** inside these phases (I don't call them directly):
- First-ever `/implement` triggers one-time **`/flutter-bootstrap`** (scaffolds `src/`, desktop,
  `flutter_bloc`, Clean-Arch skeleton).
- `/implement` also uses `/source-assets` (free art) and `/self-review` (before review).
- `/review-code` also runs **`/privacy-audit`** (the trust promise gate).

---

## 4. Wave 1 (v1 MVP) — the checklist

Recommended order follows the dependencies in [roadmap.md](roadmap.md).

- [ ] **0. Idle spike** _(before any `activity-detection` custom-plugin work)_
  - Prove real system idle-seconds in a throwaway Flutter window.
  - **Check pub.dev for an existing idle/activity package FIRST** — it may remove the native work.
  - Everything else is gated on this working. Not a formal command — do it as the first thing in
    `activity-detection`'s build, or as a quick standalone experiment.

- [x] **1. `activity-detection`** (native idle/lock/sleep plugin + `ActivityPlugin` + mock source) — **✅ SHIPPED 2026-06-23 (macOS-verified)**
  - [x] Phase 2 Spec complete — spec `approved`; 11 ACs; 20 test cases; test-plan
  - [x] Phase 3 Build complete — bootstrap + custom plugin (interface/macOS/Windows/mock/DI) + 30 unit tests + integration/manual harness; self-review fixed; analyze clean
  - [x] Phase 4 Review — `/review-code` changes-requested (0 blocking); `/privacy-audit` PASS; findings accepted as limits L1/L2
  - [x] Phase 5 Test — `/execute-tests` GREEN 36/36 (macOS)
  - [x] Phase 6 Ship — SHIPPED macOS-verified; `planning/done/`
  - ⚠️ **L3 carry-over:** Windows never run (no device / MSVC-blocked) + manual checklist 0/6 → AC-2/AC-3/AC-5/AC-9 + parity NFR unverified. **Must clear before a Windows release.**

- [x] **2. `journey-engine`** (pure-Dart core loop: active/idle → distance, modes, persistence) — **✅ SHIPPED 2026-06-23**
  - [x] Phase 2 Spec — spec `approved`; 16 ACs; 22 test cases (TC-001..022); 4 product decisions resolved.
  - [x] Phase 3 Build — engine + persistence + `Clock` seam; 63 unit tests; self-review fixed 2 blockers (B-1/B-4) + S-2; analyze + format clean; suite 94/94 green.
  - [x] Phase 4 Review — `/review-code` **`approved`** (2 Medium follow-ups, no blockers); `/privacy-audit` **PASS**.
  - [x] Phase 5 Test — `/execute-tests` **GREEN 63/63** (report `20260623-181042`).
  - [x] Phase 6 Ship — **SHIPPED**; M-1 ratified (idle-only sleep + clamp), all 21 ACs ticked, spec `shipped`, moved to `planning/done/`.
  - ↪ **Follow-ups carried (non-blocking):** M-2 `tickFromPlugin` error policy; test hardening (null-restore, `tickFromPlugin`); `kmPerActiveHour` seam with `route-progress`.
  - **✅ Unblocks slices 3, 4, 5.**

- [x] **3. `journey-view`** (Flame POV road scene) — **✅ SHIPPED 2026-06-24 (macOS-verified live)** — `[blocked by: journey-engine]`
  - [x] Phase 2 Spec — approved; AC-1..AC-14; 27 test cases.
  - [x] Phase 3 Build — Flame scene + Cubit/ticker + 12/13 Kenney CC0 assets; 166 tests green; self-review B-1 fixed.
  - [x] Phase 4 Review — `/review-code` changes-requested → **resolved** (H-1 dart-format gate green; H-2 narrowed — 3 background layers deferred, manifest 13→10); `/privacy-audit` **PASS** (TC-026). 166 tests green.
  - [x] Phase 5 Test — `/execute-tests` **GREEN** (167 passed / 0 failed; report `20260624-092732`). Goldens TC-022/023/025 + perf TC-015/016 deferred (documented).
  - [x] Phase 6 Ship — **SHIPPED 2026-06-24**; spec `shipped`, moved to `planning/done/`. ⚠️ Carry-over: on-device fps NFR (TC-015/016) unmeasured — run on macOS+Windows before public release. Polish P-1/P-2 carried.

- [x] **4. `route-progress`** (Vietnam province-chain + custom-painted map) — **✅ SHIPPED 2026-06-24** — `[blocked by: journey-engine ✅]`
  - [x] Phase 2 Spec — spec **approved**; 22 ACs; all 5 open questions resolved (per-route offset · route owns totalChainKm≈2000 + injected rate 250 · distance-based full-chain % · block off-direction tips · curated ~10–15 checkpoints); 24 test cases; test-plan filled.
  - [x] Phase 3 Build — `/implement`: full slice built (domain/data/presentation) + `ActivityTicker.onDistance` scalar wiring (engine untouched); AC-8/AC-11 contradiction ratified; `/self-review` blockers fixed. 308 tests green.
  - [x] Phase 4 Review — `/review-code` **changes requested** (B-1 stale test — production source **approved as-is**) → **B-1 FIXED**; `/privacy-audit` **PASS** (zero new surface).
  - [x] Phase 5 Test — `/execute-tests` **GREEN** — 145 in-scope (142 unit/widget + 3 integration **on macOS device**) + 308/308 regression, 0 flakes; report `20260624-113456`.
  - [x] Phase 6 Ship — **SHIPPED 2026-06-24**; all 18 ACs + 4 NFRs ticked; spec `shipped`; moved to `planning/done/`. ⚠️ Carry-over: TC-NF2 on-device fps (macOS+Windows) before public release.
  - ↪ **Unblocks v2 `map-geographic`** (reuses this chain model + position math behind real tiles).
  - [ ] Phase 5 Test — `/execute-tests`
  - [ ] Phase 6 Ship — `/ship`

- [ ] **5. `local-stats`** (daily/weekly stats + settings + badges + onboarding/privacy) — `[blocked by: journey-engine ✅]` — **Phase 4 Review NEXT**
  - [x] Phase 2 Spec — **approved**; 26 ACs (21 functional + 5 NFR); 26 test cases; `test-plan.md`. All 5 open questions resolved to recommended defaults.
  - [x] Phase 3 Build — `/implement`: full `lib/features/stats/` slice + `ActivityTicker.onSnapshot` seam + `main.dart` wiring (engine untouched); `launch_at_startup`/`local_notifier` behind interfaces. +137 unit/cubit tests + widget/integration + manual checklist. `/self-review` fixed B1 (backwards-clock double-count) + B2 (emit-after-close) + AC-19 closed-across-midnight defect, all w/ regression tests. analyze+format clean, **473 tests green**.
  - [x] Phase 4 Review — `/review-code` changes-requested → **all findings RESOLVED**; `/privacy-audit` **PASS**. Fixed M1 (component-based DST-safe week dates, +`focus_streak` hazard), M2 (new `BadgeScope.daily` for the 2 daily focus-time badges + daily reset), M3 (serial tick queue), Low #4 (first-run gate test + comment fix), Low #5 (clamp daily distance ≥0). Re-verify: analyze clean, format 0-changed, **484 tests green**. TC-022 runtime socket-check = manual ship-gate.
  - [x] Phase 5 Test — `/execute-tests` **GREEN** (191/191 in-scope: 176 unit/widget + 15 e2e; whole-package 484/484; stats coverage 88.5%; report `20260624-132008`, `verdict: green`). Integration files run individually (macOS batch-relaunch limitation). Carried (non-blocking): TC-022 manual privacy-audit, TC-NF4 goldens deferred, TC-NF5 real-OS legs.
  - [x] Phase 6 Ship — **✅ SHIPPED 2026-06-24**; all 21 ACs + 5 NFRs ticked; spec `shipped`; `planning/active/local-stats.md` → `planning/done/`.

✅ **All 5 Wave-1 slices shipped → v1 is DONE.** 🎉

---

## 5. After v1 — starting Wave 2 (v2)

1. Capture/create the Wave-2 child slices (they don't exist yet — wave discipline).
2. Update `roadmap.md`: move Wave 2 from **Later** to **Next**.
3. Run the same 5-command loop per slug.

Wave 2 candidates: `mini-window` (always-on-top PiP + tray) · `journey-energy-model` (strategic
energy/fuel model) · `map-geographic` (`flutter_map` + real tiles) · `team-leaderboard` (needs a
backend — its own epic).

Wave 3 (v3): `ai-coach` · `signed-distribution` (Apple Developer signing/notarization + installer).

---

## 6. Optional housekeeping before building

- [ ] Pin the **coding-standards baseline** as an ADR via `/add-adr` — Clean Architecture
  (presentation/domain/data) + SOLID + DI + Effective Dart. The plan asks for this so every agent
  reads the same rules. *Recommended before the first `/implement`.*

---

## 7. My immediate next action

**Wave 1 (v1) is COMPLETE** — all five slices (`activity-detection` · `journey-engine` · `journey-view` ·
`route-progress` · `local-stats`) shipped and in `planning/done/`.

**🎉 `mini-window` is SHIPPED (2026-06-24, macOS-verified) — the first Wave-2 (v2) slice.** All 6 phases done:
spec approved · ADR-0003 (single-window two-mode) · built (spike-gate PASS, single-window full ⇄ compact PiP +
always-present tray, Lucide ISC icons, self-review B1/NFR-1 fixed) · `/review-code` `approved` · `/privacy-audit`
PASS · `/execute-tests` `green` (92 in-scope + 559/559 regression; report `tests/_runner/reports/mini-window/20260624-152719/`).
All 18 ACs + 9 NFRs ticked, spec `Status: shipped`, moved to `planning/done/mini-window.md`.

**👉 Immediate next action — start the next Wave-2 slice.** v2 candidates, all unblocked (their deps shipped):
1. **`journey-energy-model`** — per-mode speeds + energy/fuel strategy (`/capture-idea <slug>` → `/new-feature <slug>`).
2. **`map-geographic`** — `flutter_map` + real OSM tiles; reuses route-progress's shipped chain model + position math.
3. **`team-leaderboard`** — needs a backend (its own sub-epic).
Pick one, then run the per-slug 5-command loop. (No child backlog files exist yet — `/capture-idea` frames each.)

**Carried before any public / Windows release of `mini-window`** (NOT blocking the dev build — see
`planning/done/mini-window.md` + `specs/mini-window/acceptance-criteria.md` verification-status block):
- review **Medium #1** Windows tray-icon authoring (branch `setIcon` to the `*_color` icons on `Platform.isWindows`)
  + all Windows runtime legs (NFR-9) → `flutter-native-plugin-engineer`;
- macOS manual checklist TC-M1/M2/M3/M4 (real frameless drag · always-on-top over a focused app · close-intercept +
  tray render/click · tray a11y) → Kevin's on-device pass;
- NFR-2 on-device fps (TC-M-NF2); runtime privacy socket check (TC-022 / TC-M-PRIV);
- non-blocking polish: throttle per-tick tray menu rebuild · two-phase tray seed · rename `TrayController.setState` ·
  drop stale `TODO(ui-asset-curator)` doc comments → `flutter-app-developer`.

**Before any public v1 release, clear the carried deferred-verification legs** (none block the internal/dev
build): activity-detection Windows runtime (L3) · journey-view on-device fps (TC-015/016) · route-progress
on-device fps (TC-NF2) · local-stats TC-022 runtime privacy check + TC-NF5 real-OS launch/toast legs. See §4
and the per-slice docs in `planning/done/`.

**Carry to ship/release (non-blocking):** TC-022 (`/privacy-audit` runtime socket-check via packet-capture/`lsof`
on the real macOS/Windows build) + TC-NF5 (real launch-at-startup registration + real toast delivery) are the
manual legs in `tests/cases/local-stats-manual-checklist.md`. Goldens (TC-NF4) deferred (no repo harness, as with
journey-view). `TODO(local-stats)` in `main.dart`: pass MSIX identity to `launch_at_startup.setup` for a packaged
Windows build.

**Carried follow-ups (non-blocking — fold into the relevant later slice/edit, NOT a re-`/implement`):**
- **route-progress:** TC-NF2 on-device frame-rate unmeasured (macOS + Windows) before public release → `test-executor` + `flutter-app-developer`. Review Lows/Nit (L-1 fire-and-forget completion save · L-2 `startNewRoute` cumulative mutation · N-1 `destinationOf` unused param) — cosmetic, no change required.
- **journey-view:** P-1 scroll speed · P-2 motorbike size/blur · self-review S-1..S-5/M-1/L-1 · on-device fps (TC-015/016).
- **journey-engine:** `kmPerActiveHour` seam **CLOSED** by route-progress (route owns total, engine takes injected rate 250).
- **activity-detection (L3):** Windows runtime never verified — clear before any Windows release.

**Carried follow-ups (non-blocking — fold into the relevant later slice/edit, NOT a re-`/implement` of a shipped slug):**
- **journey-view visual polish (Kevin's live run 2026-06-24):** **P-1** scroll speed too fast (`cruiseSpeed 320`→~150) · **P-2** motorbike too big + blurry (shrink draw rect + `FilterQuality.none`). → `flame-game-developer`
- **journey-view from review/self-review:** M-1/S-2 `BlocSelector` for distance-tick rebuilds · S-1 large-dt ease test · S-3 single pause/resume predicate · S-4 pass 3 values to the Cubit · S-5 CC0 side-view ship or drop `TravelMode.ship` · L-1 `_drawImageFit` alloc claim · M-3 golden infra (if a stable approach exists).
- **journey-engine:** `kmPerActiveHour` seam → closed naturally when `route-progress` lands (shipped default 250 is a documented placeholder). (M-2 + ticker hardening were absorbed by journey-view's `ActivityTicker`.)

⚠️ **Deferred-verification carry-overs — do not lose (clear before the respective public release):**
- **journey-view (L4):** on-device **frame rate** (TC-015/016, the "Performance — frame rate" NFR) was never measured by instrumentation — the perf cases are opt-in (`--dart-define=run-perf=true`) and didn't run in the green session. Live macOS run looked smooth; no-jank proven deterministically (TC-006/024); but ~60 fps / ≥30 fps floor is **unverified on macOS + Windows**. Owner: `test-executor` + `flame-game-developer`.
- **activity-detection (L3):** shipped **macOS-only-verified**. Windows backend authored + reviewed + privacy-audited but **never run** (no Windows device, MSVC-blocked); manual checklist (`tests/cases/activity-detection-manual-checklist.md`) 0/6 → AC-2/AC-3/AC-5/AC-9 + parity NFR unverified. Before any **Windows release**: build + run on Windows hardware, execute the manual checklist on both OSes, then check those ACs. Owner: `flutter-native-plugin-engineer` + `test-executor`.
