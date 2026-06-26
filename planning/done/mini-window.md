# Mini-Window (always-on-top PiP + tray/menu-bar)

**Promoted from backlog:** 2026-06-24 (first slice of **Wave 2 / v2**)
**Target:** v2 milestone
**Status:** ✅ **SHIPPED 2026-06-24 (macOS-verified)**
**Spec:** [specs/mini-window/](../../specs/mini-window/) (`Status: shipped`)
**Green report:** [tests/_runner/reports/mini-window/20260624-152719/](../../tests/_runner/reports/mini-window/20260624-152719/) (`verdict: green`, 92 in-scope + 559/559 regression)
**Decision:** [ADR-0003 — single-window two-mode](../../docs/architecture/decisions/0003-mini-window-single-window-two-mode.md)

## Goal
A user-invoked, always-on-top mini-window (PiP) reusing the shipped Flame journey scene, plus an
always-present tray/menu-bar presence (status + Show app / Enter compact-PiP / Quit) and hide-to-tray
close behaviour — so the journey stays glanceable while the user works in another app, with tracking
continuing in the background. Pure view; zero new privacy surface.

## What shipped
A **single-window, two-mode** companion surface (per ADR-0003), built macOS-verified and green:
- **User-invoked PiP compact mode**, YouTube-style and **mutually exclusive** with the main window:
  pressing the compact control collapses the main window into a small, frameless, always-on-top view
  (the shipped `journey-view` Flame scene sized down + a distance / active-idle readout) and hides the
  main window to the dock; re-opening the main window dismisses the PiP. Fixed compact size; position
  persisted via `shared_preferences` and clamped onto a visible display on restore.
- **Always-present menu-bar / system-tray icon** (static, Lucide ISC art — `car-front`/`circle-parking`/
  `route`) reflecting journey state via icon variant + tooltip, with a menu of **Show app · Enter
  compact / PiP · Quit**. Mode-aware menu labels; status line reflects distance.
- **Hide-to-tray close**: the main window's close button hides it and keeps tracking in the background
  (only the menu-bar icon updates); the PiP is **not** auto-shown on close; **Quit** is the only full
  exit and flushes journey state first; a one-time first-run hint explains the app is still running.
- **Architecture:** ONE `FlutterEngine` / journey Bloc / activity ticker / Flame `JourneyGame`, lifted
  to a shared `AppShell` owner and rendered by whichever mode is active — so the single-source-of-truth
  invariant (AC-9) holds *structurally*, not by cross-isolate sync. Native window/tray via
  `window_manager` + `tray_manager` (+ `screen_retriever` for geometry only), behind a Dart interface
  with macOS/Windows backends + a `--mock-window` path for headless tests.
- **Quality:** `/review-code` **`approved`** (no Critical/High), `/privacy-audit` **PASS** (zero new
  user-data surface), `/execute-tests` **`green`** — 92 in-scope tests (75 unit/widget + 17 integration)
  + 559/559 whole-package regression, 0 flakes. `/self-review` caught and fixed a P0 NFR-1 blocker
  (the game kept running when hidden to tray) before review.

### Post-ship real-OS fixes (2026-06-24, same day — TC-M3 manual verification on macOS)
Kevin's on-device run surfaced 3 real-OS defects the mock path couldn't catch (the carried TC-M3 leg). All fixed + verified on a real macOS run; test suite 559 → **561**:
- **Compact PiP had no restore control** → added an expand button (`Icons.open_in_full`) in `CompactView`, layered above the drag region, calling `AppShellCubit.showApp()` → `exitFull()`.
- **Tray menu actions silently no-op'd** → the live "X.X km" status line was a menu item, so `setContextMenu` rebuilt the menu (new item IDs) every journey tick and the displayed menu's IDs no longer resolved in Dart. Fix: distance is **tooltip-only**; the menu rebuilds only on structure change (launch + mode toggle). (This was also review **Low #2** — turned out functional, not cosmetic.)
- **Close button quit the app instead of hide-to-tray (P0, AC-15)** → root cause was `AppDelegate.applicationShouldTerminateAfterLastWindowClosed` returning `true` (NOT the merged-thread mode, which was disproved). Set to `false`. Verified: close → hides + process alive + tray present + distance keeps advancing while hidden + Show app restores + Quit exits.
- **TC-M3 now VERIFIED** on macOS. Remaining manual legs (TC-M1 drag feel, TC-M2 always-on-top over a focused app, TC-M4 tray a11y, TC-M-NF2 fps, TC-M-PRIV runtime privacy) + all Windows runtime legs still carried.
- **New observation (pre-existing, out of scope):** macOS app-menu Quit / Cmd-Q calls `NSApp.terminate` directly, bypassing the `onBeforeQuit` flush (AC-16 flush runs only on **tray** Quit). Decide separately whether Cmd-Q should also flush.

### Deferred-verification carry-overs (clear before the respective public/Windows release — NOT blocking the dev build)
- **Windows (NFR-7 authoring + NFR-9 runtime):** the Windows backend is authored via the same Dart
  interface, **but review Medium #1** — the tray controller selects the macOS template icon
  unconditionally; branch to the curated `*_color` icons on `Platform.isWindows` — and **all Windows
  runtime legs** are unverified. Owner: `flutter-native-plugin-engineer` + `test-executor`.
- **macOS manual-checklist legs** (`tests/cases/mini-window-manual-checklist.md`): TC-M1 (frameless
  drag), TC-M2 / TC-M2-AOT (real always-on-top over a focused app), TC-M3 (real close-intercept + tray
  render/click), TC-M4 (tray-menu a11y) — need Kevin's on-device pass.
- **NFR-2 fps** (TC-M-NF2): no-jank determinism proven (TC-003); the ~60/≥30fps floor is unmeasured
  on-device.
- **Privacy runtime (TC-022 / TC-M-PRIV):** static + dependency audit PASS; the runtime socket/
  packet-capture check on a real build is the manual ship-gate.

### Review follow-ups (non-blocking polish — fold into a later edit, NOT a re-`/implement`)
- Throttle the per-tick tray menu rebuild driven by the status-line distance · two-phase tray seed at
  launch · rename `TrayController.setState` · drop the now-stale `TODO(ui-asset-curator)` doc comments.
  Owner: `flutter-app-developer`.

## What we'd do differently
- **Resolve the window-model UX before drafting ACs.** The early spec/ACs assumed an *independent*,
  always-floating PiP. Kevin's clarification that it should be **YouTube-style mutually exclusive** both
  simplified the architecture (single-window two-mode → no multi-window/second-isolate) and rewrote
  several ACs (AC-6/7/12/14/18). Asking "what's the relationship between the main window and the PiP?"
  up front would have saved the realign pass.
- **Model window *visibility* in the domain from day one.** The one P0 bug (`/self-review` B1: the game
  kept spinning when hidden to tray) existed because the shell only knew `full/compact` + app lifecycle,
  and `windowManager.hide()` doesn't change `AppLifecycleState` on desktop. A `isWindowVisible` /
  `windowVisibilityChanges` seam on the controller — added during the fix — should have been part of the
  initial contract.
- **Author the per-OS tray-icon selection alongside the macOS path.** Medium #1 (Windows icons exist but
  aren't selected) is a small `Platform.isWindows` branch that slipped because macOS was the only run
  target; authoring both at once would have closed NFR-7 cleanly even with Windows runtime deferred.
- **The spike-gate-first discipline paid off** — proving the `window_manager`/`tray_manager` triad built
  + wired on macOS before committing the full build meant no architectural surprises. Keep doing this for
  native-heavy slices.

## Phase ledger (final)
- [x] Phase 2 · Spec — spec **approved** (2026-06-24); 18 ACs + 9 NFRs; 28 test cases + manual checklist; ADR-0003
- [x] Phase 3 · Build — `/implement` — spike-gate PASS; `lib/features/mini_window/` + `main.dart` wiring + shared-`JourneyGame` lift; Lucide ISC tray icons; `/self-review` fixed B1 (NFR-1) + S1/N1 + visibility seam
- [x] Phase 4 · Review — `/review-code` **`approved`** (1 Medium carry, shielded by NFR-9) · `/privacy-audit` **PASS**
- [x] Phase 5 · Test — `/execute-tests` **`green`** — 92 in-scope + 559/559 regression, 0 flakes; report `20260624-152719`
- [x] Phase 6 · Ship — **SHIPPED 2026-06-24 (macOS-verified)**; all ACs ticked (deferred-manual legs documented); spec `shipped`; moved to `planning/done/`

## Status log
| Date | Note |
|------|------|
| 2026-06-24 | Wave 2 started. `/new-feature mini-window`: copied template → `specs/mini-window/`. Kevin made 4 scoping decisions (compact Flame scene · tray status+actions · hide-to-tray close · remember-position + always-on-top toggle + draggable/frameless; launch-at-startup explicitly OUT — `local-stats` owns it). Spec problem/scope/constraints drafted; 6 open questions logged. `product-domain-expert` proposed 18 ACs + 9 NFRs + surfaced 6 more open questions. |
| 2026-06-24 | Kevin reviewed + clarified UX: **YouTube-style PiP** — PiP is **user-invoked** and **mutually exclusive** with the main window (enter PiP → main hides to dock; open main → PiP dismissed). Menu-bar icon is **always present** (wifi/battery-style), updates state even after main window closed. All other surfaced OQs → recommended defaults. Spec updated; ACs realigned (AC-6 user-invoked+mutual-exclusion, AC-7 always-on-top→P2, AC-12/14 menu items, AC-18 PiP-not-auto-shown). Mutual exclusivity **simplifies wiring** → single-window two-mode. Delegated wiring to `system-architect`. |
| 2026-06-24 | `system-architect` confirmed **Option A — single window, two modes** (one engine/Bloc/scene; lift `JourneyGame` to a shared owner). Option B (second window/isolate) rejected. Kevin: **PiP = fixed compact size** + **write ADR now**. `/add-adr` → **ADR-0003**; overview v2 window model updated. **All open questions resolved.** |
| 2026-06-24 | **Phase 2 (Spec) COMPLETE.** Kevin approved → spec `approved`. `test-case-designer` wrote `tests/cases/mini-window.md` (**28 cases**) + `mini-window-manual-checklist.md` (6 real-OS legs incl. ADR-0003 macOS spike-gate triad + privacy ship-gate + Windows-deferred block). Full AC/NFR→TC traceability. |
| 2026-06-24 | **Phase 3 (Build) COMPLETE.** `flutter-native-plugin-engineer` ran the ADR-0003 macOS **spike-gate → PASS** and built the window/tray layer (interface + real `window_manager`/`tray_manager` + mock + `--mock-window` factory). `flutter-app-developer` wired single-window two-mode: `AppShell` owns the ONE lifted `JourneyGame`, full⇄compact mutually exclusive, tray actions + hide-to-tray + Quit-flush + one-time hint in `main.dart`. `ui-asset-curator` sourced **Lucide ISC** static tray icons → `assets/tray/` + CREDITS. `unit-test-writer` +38, `test-script-author` +17 integration. `/self-review` found **B1 (P0, NFR-1: game spun when hidden-to-tray)** + S1/S3/N1 → FIXED via a `WindowModeController` visibility seam folded into the pause predicate, guarded call sites, `Equatable` state, + B1 regression test. **559 unit/widget + 17 integration green; analyze + format clean.** |
| 2026-06-24 | **Phase 4 (Review) COMPLETE.** `/review-code` (`flutter-code-reviewer`) **`approved`** — no Critical/High; B1/S1/S3/N1 fixes verified resolved. **Medium #1 (carry):** Windows tray-icon authoring (`Platform.isWindows` icon branch) — shielded by NFR-9. Lows/Nits: per-tick tray menu rebuild, two-phase seed, `setState` naming, stale TODOs. `/privacy-audit` (`privacy-guardian`) **PASS** — zero new user-data surface; deps cleared at native level; claims consistent; separation guard genuine. Carry: TC-022/TC-M-PRIV runtime check. |
| 2026-06-24 | **Phase 5 (Test) COMPLETE.** `/execute-tests` (`test-executor`) **`green`** — in-scope **92 passed / 0 failed / 0 flaky** (75 unit/widget + 14 wiring + 3 smoke, macOS + mock seams); whole-package regression **559/559**. Report `tests/_runner/reports/mini-window/20260624-152719/` (`verdict: green`) + `lcov.info`. Integration files run individually (macOS batch-relaunch limit). Deferred-manual legs documented (not failures). |
| 2026-06-24 | **Phase 6 (Ship) COMPLETE — ✅ SHIPPED (macOS-verified).** Green report `20260624-152719` machine-verified; all 18 ACs + 9 NFRs ticked (deferred-manual real-OS/Windows legs documented in acceptance-criteria.md verification-status block); spec `Status: shipped`; `planning/active/mini-window.md` → `planning/done/`. **Carried (clear before public/Windows release):** Medium #1 Windows tray-icon authoring + Windows runtime (NFR-9) · macOS manual checklist TC-M1/M2/M3/M4 · NFR-2 fps (TC-M-NF2) · privacy runtime (TC-022/TC-M-PRIV). |
| 2026-06-24 | **POST-SHIP real-OS fixes (TC-M3 on macOS, Kevin's run).** 3 defects the mock path couldn't catch, all fixed + verified on a real macOS run by `flutter-native-plugin-engineer`: (1) compact PiP had no restore control → added expand button (`AppShellCubit.showApp()`); (2) tray menu actions no-op'd (per-tick `setContextMenu` churned item IDs — distance moved to tooltip-only, menu rebuilds only on structure change; was review Low #2); (3) **P0** close button quit instead of hide-to-tray → `AppDelegate.applicationShouldTerminateAfterLastWindowClosed` `true`→`false` (merged-thread hypothesis disproved). analyze clean; **561 tests** (+2). TC-M3 now **VERIFIED** on macOS. Pre-existing out-of-scope: Cmd-Q bypasses the AC-16 flush (only tray Quit flushes) — separate decision. |

## Decisions made along the way
- **PiP content = compact Flame scene** (reuse shipped `journey-view`, sized down), not a bespoke widget.
- **Main / PiP = mutually exclusive, user-invoked (YouTube-style)** — overrode the initial "both visible" default.
- **Tray = always-present, static icon + quick actions** (Show app / Enter compact-PiP / Quit).
- **Close button = hide-to-tray, keep tracking; Quit = only full exit, flushes state.**
- **PiP = fixed compact size**, position-only persistence + off-screen clamp.
- **Launch-at-startup is OUT** — owned by shipped `local-stats`; reuse, don't duplicate.
- **Wiring → ADR-0003 Option A: single window, two modes.** One engine/Bloc/`JourneyGame` lifted to a shared `AppShell` owner; window transforms full ⇄ compact via `window_manager`. Multi-window/second-isolate rejected.
- **Spike-gate-first** (ADR-0003 macOS triad) before `/implement` — passed, no architectural surprises.
- **[blocked by: journey-view ✅, journey-engine ✅]** — both shipped; reuses the scene + journey Bloc.
