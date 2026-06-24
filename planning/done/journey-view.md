# Journey View (Flame POV road scene)

**Promoted from backlog:** 2026-06-23
**Shipped:** 2026-06-24
**Target:** Wave 1 (v1)
**Spec:** [specs/journey-view/](../../specs/journey-view/) — `Status: shipped (2026-06-24)`
**Green report shipped on:** [tests/_runner/reports/journey-view/20260624-092732/](../../tests/_runner/reports/journey-view/20260624-092732/summary.md) — `verdict: green`, 167 passed / 0 failed / 0 flaky / 5 skipped (documented deferrals)

## Goal
The main emotional screen: a stylized 2D first-person Flame road scene that scrolls/animates while the
journey is active and stops/parks while idle — driven entirely by the journey Bloc (owns no activity
logic), running smoothly on desktop, using only license-clean assets recorded in `assets/CREDITS.md`.

## Plan
- [x] Step 1 — Spec drafted + domain-framed (problem, scope, ACs)
- [x] Step 2 — Spec reviewed & approved by Kevin (6 open questions + 4 domain flags resolved)
- [x] Step 3 — Test cases designed (`tests/cases/journey-view.md` — 27 scenarios)
- [x] Step 4 — Build (Flame scene + Bloc binding + assets + tests + self-review)
- [x] Step 5 — Review (`/review-code` changes-requested → resolved; `/privacy-audit` PASS)
- [x] Step 6 — Execute tests (`/execute-tests`) — **green** 167/167 (report `20260624-092732`)
- [x] Step 7 — Ship

## Phase ledger
- [x] Phase 2 · Spec — `/new-feature` → approved 2026-06-23; AC-1..AC-14 final; 27 test cases
- [x] Phase 3 · Build — `/implement`  (analyze clean, 166 tests green; self-review B-1 fixed)
- [x] Phase 4 · Review — `/review-code`  (changes-requested → **resolved**; `/privacy-audit` **PASS**)
- [x] Phase 5 · Test — `/execute-tests`  (verdict: **green** — 167 passed, report `20260624-092732`)
- [x] Phase 6 · Ship — `/ship`  (**SHIPPED 2026-06-24, macOS-verified live**)

## What shipped
The first **rendering** slice of Vietnam Focus Journey — a Flame POV road scene plus the engine→view
wiring that makes the whole app come alive:
- **Flame scene** (`lib/features/journey/presentation/game/`): fake-3D trapezoid POV road + scrolling
  dashed centre lane (procedural), a **bounded recycling pool** of parallax roadside objects (v1: tree,
  house, street-light, sign), the cosmetic **vehicle skin** sprite per `mode`, a cosmetic injected-clock
  **day/night tint**, a short ≤0.5 s start/stop **ease** (binary speed: constant while active, zero while
  stopped), graceful **missing-asset** fallback, and off-screen `pauseEngine`. Locked public contract
  `applyState({moving, mode, reduceMotion, timeOfDayHours})` + read-only test seams; imports no
  Bloc/engine/OS — separation by construction.
- **Presentation + wiring** (`lib/features/journey/presentation/`): `JourneyViewState` (idle≡paused →
  stopped; first-frame parked), `JourneyCubit`, an app-layer **`ActivityTicker`** (elapsed = now − lastTick;
  **M-2** error policy: on `ActivityPluginException` accrue no bogus travel, stay alive, settle to stopped),
  `JourneyScreen` (drives the game, "Paused — idle" overlay in the **semantics tree**, sibling distance-counter
  widget, reduce-motion indicator, lifecycle pause/resume), and a real `main.dart` composition root honouring
  `--dart-define=mock-activity=true`. **This is the carried M-2 ticker/Cubit wiring** from journey-engine,
  landing here because journey-view is the first slice that renders.
- **Assets**: **9 shipped Kenney CC0 sprites** (6 vehicle skins + 4 roadside objects) recorded in
  `assets/CREDITS.md`; `vehicles/ship.png` intentionally absent → documented graceful placeholder.
- **Tests**: 167 passing (`fvm flutter test`) — unit (view-state/cubit/ticker), widget+static (scene motion,
  separation invariant, CREDITS cross-check, no-orphan-asset), and an integration smoke (TC-021).
- **Verification**: `/privacy-audit` **PASS** (no new OS surface; pure consumer of `state`/`mode`/`distanceKm`).
  Live macOS run (2026-06-24) confirmed the scene renders and scrolls — road, parallax objects, motorbike,
  live distance counter — with **no uncaught asset errors** (the B-1 fix holding in the real app).
- **All 14 functional ACs + 6 of 7 non-functional ACs ticked.** One NFR (Performance — frame rate) ships as a
  **documented deferred carry-over** (see below).

### ⚠️ Deferred verification (carry-over — clear before a public release)
- **On-device frame rate (TC-015/016, the "Performance — frame rate" NFR)** was never measured by
  instrumentation. The perf cases are opt-in (`--dart-define=run-perf=true`) and didn't run in the green
  session. The live macOS run looked smooth with no visible jank, and the no-jank ease is proven
  deterministically (TC-006/TC-024) — but the ~60 fps / ≥30 fps floor is **unverified**. Run TC-015/016 on
  macOS + Windows hardware before any public release. Owner: `test-executor` + `flame-game-developer`.
- **Goldens (TC-022/023/025)** were not authored — Flame's real-time render loop + the intentional missing
  `ship.png` make headless byte-stable goldens non-deterministic. Visual ACs are covered behaviourally
  (TC-001/002/003/012) and by the live run. Author golden infra if/when a stable approach exists.

## What we'd do differently
- **Bring the scene up under a deterministic render harness earlier.** Most of the build-time pain (and the
  B-1 orphaned-future defect) came from Flame's real-time loop + asset loading fighting headless tests. A
  thin "headless game + explicit `update(dt)`" harness should be a day-one fixture, not discovered late.
- **Validate visuals (size/feel) before the test push, not after ship.** The live run surfaced two cosmetic
  issues (P-1 scroll speed too fast, P-2 motorbike too big + blurry) only at the very end. A 5-minute
  `flutter run` mid-build would have caught both while the scene code was already open. Tuning constants
  (`cruiseSpeed`, vehicle draw rect, `FilterQuality`) deserve an explicit "does this feel right?" gate.
- **Pin the asset manifest ↔ render-path contract.** H-2 (mountains/rice-field/cloud loaded but never drawn)
  slipped through because the manifest and the renderer weren't cross-checked. A test asserting "every
  manifest entry is actually rendered by some path" would have caught it before review.
- **Decide golden strategy up front.** We deferred goldens three times; either commit to a stable
  golden approach early (fixed-phase, stubbed assets, `FilterQuality.none`) or consciously declare visual
  regression out of automated scope from the start, rather than re-deferring.

## Open follow-ups (non-blocking; carried forward)
**Visual polish (from Kevin's live run 2026-06-24):**
- **P-1** — scroll speed too fast: `cruiseSpeed 320 → ~140–180` (`game/scene_motion.dart:26`, `game/journey_game.dart:38`). → `flame-game-developer`
- **P-2** — motorbike too big + blurry: shrink draw rect (`game/road_painter.dart:204-205`) + `FilterQuality.none` in `_drawImageFit`; optionally re-source a larger side-view motorbike. → `flame-game-developer` (+ `ui-asset-curator`)

**From `/self-review` + `/review-code`:**
- **M-1 / S-2** — `JourneyScreen` rebuilds the whole `Stack` on every 1 Hz distance tick; isolate the counter with `BlocSelector`. → `flutter-app-developer`
- **S-1** — ease/no-jank only proven at fixed 1/60 s dt; clamp `dt` in `update` and/or add a large-dt test. → `flutter-app-developer` / `unit-test-writer`
- **S-3** — three uncoordinated pause sources (lifecycle + activate/deactivate); derive pause/resume from a single "should run" predicate. → `flutter-app-developer`
- **S-4** — `JourneyCubit.updateFromEngine(engine)` takes the whole mutable engine; pass the 3 values (least-privilege). → `flutter-app-developer`
- **S-5** — `TravelMode.ship` always renders a placeholder; source a CC0 side-view boat or drop `ship` from v1. → `ui-asset-curator` / `product-domain-expert`
- **L-1** — `RoadPainter._drawImageFit` per-call src-rect cache is effectively defeated frame-to-frame; the "zero per-frame allocation" claim is overstated. → `flame-game-developer`

## Decisions made along the way
- Scene is a **pure view** of the journey Bloc — no activity logic, no OS reads, zero new privacy surface. (Headline separation; verified by a static separation test + `/privacy-audit`.)
- v1 skins cosmetic, single scroll speed (per-mode speed → v2 `journey-energy-model`).
- App-layer **activity ticker** + **journey Cubit** landed here (the carried M-2 wiring from journey-engine) — the first slice that renders, so it brings the engine→view wiring.
- B-1 fix uses `package:flutter/services.dart` (AssetBundle/AssetManifest/rootBundle) **only** in `journey_sprites.dart` via an explicit `show`; the static separation test was tightened to allow exactly that while still banning all platform-channel symbols everywhere.
- **H-2 narrowing (review):** v1 ships the 4 roadside object kinds; distant background layers (mountains/rice-field/cloud) deferred to a later polish wave — so nothing ships loaded-but-unrendered.
- **Resolved at spec time (Kevin):** short ease · binary scroll · injected-clock day/night · generic "Paused — idle" copy · distance counter as a sibling Flutter widget · Kenney asset pack · idle≡paused visual · honour reduce-motion · first-frame parked · graceful missing-asset.

## Status log
| Date | Note |
|------|------|
| 2026-06-23 | Promoted from backlog via `/new-feature journey-view`. Spec drafted from epic §13 + journey-engine contract; domain-expert proposed acceptance criteria. Blocked-by journey-engine is shipped. |
| 2026-06-23 | Kevin reviewed + approved spec. Resolved all 6 open questions + 4 domain-expert defaults. ACs finalized (AC-1..AC-14). `test-case-designer` wrote 27 scenarios. Phase → Build. |
| 2026-06-24 | **Phase 3 Build complete.** `flame-game-developer` built the Flame scene; `flutter-app-developer` built `JourneyViewState`/`JourneyCubit`/`ActivityTicker` (M-2)/`JourneyScreen` + `main.dart`. `/source-assets` placed 12/13 Kenney CC0 sprites + CREDITS + pubspec. 166 tests green, analyze clean. `/self-review` → 1 Blocking **B-1** (orphaned rejected future for absent `ship.png` → uncaught async error in real app) **FIXED** (manifest pre-check + unguarded regression test). Phase → Review. |
| 2026-06-24 | **Phase 4 Review.** `/review-code` **changes-requested** (no Critical; 2 High: H-1 dart-format gate; H-2 mountains/rice-field/cloud loaded-but-never-rendered). `/privacy-audit` **PASS** (TC-026). Confirmed B-1 fix sound, separation carve-out sound, M-2 correct, TC-018 correct. |
| 2026-06-24 | **Phase 4 findings resolved (Kevin chose: narrow + format).** H-1 fixed (`fvm dart format`, gate green). H-2 fixed by narrowing — v1 → 4 roadside kinds; 3 background layers dropped from `JourneyAssets.all` (13→10), files/dir/pubspec/CREDITS/test updated; spec Scope/In + Out + AC-1 narrowed. Verified green: format gate, analyze, 166 tests, integration smoke. Phase → Test. |
| 2026-06-24 | **Phase 5 Test — GREEN.** `/execute-tests` via `fvm flutter test`: **167 passed / 0 failed / 0 flaky / 5 skipped** (TC-015/016 perf + TC-022/023/025 goldens — documented deferrals). TC-021 smoke green. Report `tests/_runner/reports/journey-view/20260624-092732/summary.md` (`verdict: green`). Phase → Ship. |
| 2026-06-24 | **Live macOS run (Kevin).** App launched with `--dart-define=mock-activity=true`; scene renders + scrolls (road, parallax objects, motorbike, distance counter at 6.8 km), no uncaught asset errors (B-1 holds live). Two cosmetic notes logged as polish: P-1 (scroll too fast), P-2 (motorbike too big + blurry). |
| 2026-06-24 | **`/ship` COMPLETE — SHIPPED.** Green report verified (`20260624-092732`, verdict green, not stale — no src change since run). Ticked all 14 functional ACs + 6 NFRs; **Performance — frame-rate NFR left as a documented deferred carry-over** (on-device fps unmeasured). Spec `Status: shipped (2026-06-24)`; moved `planning/active/journey-view.md` → `planning/done/`. Wave 1: **3 of 5 shipped**. Polish (P-1/P-2) + self-review (S-1..S-5, M-1, L-1) follow-ups carried. |
