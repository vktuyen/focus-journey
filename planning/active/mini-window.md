# Mini-Window (always-on-top PiP + tray/menu-bar)

**Promoted from backlog:** 2026-06-24 (first slice of **Wave 2 / v2**)
**Target:** v2 milestone
**Spec:** [specs/mini-window/](../../specs/mini-window/)

## Goal
A small, frameless, always-on-top mini-window (PiP) reusing the shipped Flame journey scene, plus a
tray/menu-bar presence (status + Show app / Show-Hide mini-window / Quit) and hide-to-tray close
behavior — so the journey stays glanceable while the user works in another app, with tracking
continuing in the background. Pure view; zero new privacy surface.

## Plan
- [x] Spec drafted + scoping decisions captured (PiP = compact Flame scene · tray = status+actions · close = hide-to-tray · behaviors = remember position + always-on-top toggle + draggable/frameless)
- [x] `product-domain-expert` proposed acceptance criteria (18 ACs + 9 NFRs)
- [x] Kevin reviewed + approved `spec.md` — all open questions resolved; ADR-0003 written
- [x] `test-case-designer` wrote `tests/cases/mini-window.md` (28 cases) + `mini-window-manual-checklist.md`
- [ ] `/implement` (**spike `window_manager` + `tray_manager` first** — ADR-0003 macOS triad)

## Phase ledger
Update after each phase so a fresh session (`/status`) can resume. "Next" = the command to run next.
- [x] Phase 2 · Spec — spec **approved** (2026-06-24); 18 ACs + 9 NFRs; 28 test cases + manual checklist; ADR-0003
- [ ] Phase 3 · Build — `/implement`  ← **NEXT** (spike-gate first)
- [ ] Phase 4 · Review — `/review-code`  (verdict: )
- [ ] Phase 5 · Test — `/execute-tests`  (verdict: )
- [ ] Phase 6 · Ship — `/ship`

**Current phase:** 3 (Build)   **Next command:** `/implement mini-window` (run the ADR-0003 macOS spike-gate before committing the build)

## Status log
| Date | Note |
|------|------|
| 2026-06-24 | Wave 2 started. `/new-feature mini-window`: copied template → `specs/mini-window/`. Kevin made 4 scoping decisions (compact Flame scene · tray status+actions · hide-to-tray close · remember-position + always-on-top toggle + draggable/frameless; launch-at-startup explicitly OUT — `local-stats` owns it). Spec problem/scope/constraints drafted; 6 open questions logged. `product-domain-expert` proposed 18 ACs + 9 NFRs + surfaced 6 more open questions. |
| 2026-06-24 | Kevin reviewed + clarified UX: **YouTube-style PiP** — PiP is **user-invoked** and **mutually exclusive** with the main window (enter PiP → main hides to dock; open main → PiP dismissed). Menu-bar icon is **always present** (wifi/battery-style), updates state even after main window closed. All other surfaced OQs → recommended defaults. Spec updated (Problem/Scope/Resolved-decisions); ACs realigned (AC-6 user-invoked+mutual-exclusion, AC-7 always-on-top→P2, AC-12/14 menu items, AC-18 PiP-not-auto-shown). Mutual exclusivity **simplifies wiring** → single-window two-mode. Delegated wiring confirmation to `system-architect`. |
| 2026-06-24 | `system-architect` confirmed **Option A — single window, two modes** (one engine/Bloc/scene; window transforms full ⇄ compact; lift `JourneyGame` to a shared owner). Option B (second window/isolate) rejected. Kevin: **PiP = fixed compact size** (persist position only) + **write ADR now**. `/add-adr` → **ADR-0003** created (`docs/architecture/decisions/0003-mini-window-single-window-two-mode.md`); `system-architect` updated `docs/architecture/overview.md` v2 window model. **All open questions resolved.** Spec → `Status: in-review` (ready to approve). |
| 2026-06-24 | **Phase 2 (Spec) COMPLETE.** Kevin approved → spec `Status: approved`. `test-case-designer` wrote `tests/cases/mini-window.md` (**28 cases**: ~11 happy / ~13 edge / 1 negative / ~6 regression) + `tests/cases/mini-window-manual-checklist.md` (6 real-OS legs incl. ADR-0003 macOS spike-gate triad + privacy ship-gate + Windows-deferred block). Full AC/NFR→TC traceability, no orphans; NFR-2 fps + NFR-9 Windows runtime deferred (documented). **Next: `/implement mini-window` — run the ADR-0003 macOS spike-gate FIRST.** |

## Decisions made along the way
- **PiP content = compact Flame scene** (reuse shipped `journey-view`, sized down), not a bespoke lightweight widget.
- **Tray = status + quick actions** (Show app / Show-Hide mini-window / Quit; icon/tooltip reflects state).
- **Close button = hide-to-tray, keep tracking** (Quit only via tray menu).
- **Window behaviors in v1:** remember position/size · always-on-top toggle · draggable/frameless.
- **Launch-at-startup is OUT** — owned by shipped `local-stats`; reuse, don't duplicate.
- **[blocked by: journey-view ✅, journey-engine ✅]** — both shipped; reuses the scene + journey Bloc.
- Native window/tray via `window_manager` + `tray_manager` (per `docs/architecture/overview.md`), following the v1 `activity-detection` plugin pattern (interface + macOS/Windows backends + mock). **Spike first.**
- **Wiring resolved by `system-architect` (2026-06-24) → Option A: single window, two modes.** One FlutterEngine / one Bloc / one Flame `JourneyGame`; the window transforms full ⇄ compact (resize + frameless + always-on-top) via `window_manager`. Full + compact are widget subtrees under the existing `MultiBlocProvider` consuming the same `JourneyCubit` (AC-9 holds structurally). **Refinement:** lift `JourneyGame` to a shared owner so both render the same game. Option B (second window/isolate) rejected. → **`ADR-0003`** to be written via `/add-adr` after Kevin agrees (extends ADR-0002); overview updated then.
- **Spike gate before `/implement`:** prove the macOS triad on one window with the real backend — (a) drag after frameless, (b) stays above a focused app (NSWindow level/Spaces), (c) close-intercept → hide + tray keeps updating; plus shared `JourneyGame` survives re-parenting.
