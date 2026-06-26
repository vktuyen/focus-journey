# Journey POV (first-person cockpit frame — car + motorbike)

**Promoted from backlog:** 2026-06-25
**Target:** Wave 2 (v2) — optional extra (the #2 POV reframing)
**Spec:** [specs/journey-pov/](../../specs/journey-pov/)

## Goal
The journey reads as a true first-person cockpit POV for car (through-windshield: dash + wheel) and
motorbike (over-handlebars: gauges + grips), composited over the existing road scene in a stylized flat
look, flowing to the mini-window PiP — cosmetic, pure-view, license-clean.

## Phase ledger
The **single** status tracker — one row per phase, updated in place after each phase command.

| ✓ | Phase | Command | Date | Verdict / note |
|---|-------|---------|------|----------------|
| [~] | 0 · Spike | art-direction spike (`ui-asset-curator`) | 2026-06-25 | **DONE.** Photoreal has no license-clean source; Kevin approved **stylized-flat** direction from a visual mock. Candidates staged in `scratchpad/pov-spike/`. |
| [x] | 2 · Spec | `/new-feature` → review & approve `spec.md` | 2026-06-25 | **APPROVED by Kevin 2026-06-25.** Forks resolved (foreground overlay · car+motorbike only · stylized-flat license-clean · hands omitted). 17 ACs + 3 NFRs; `spec.md` `Status: approved`. |
| [x] | 3 · Build | `/implement` (includes self-review pass) | 2026-06-25 | **DONE.** Cockpit foreground (car+motorbike) composited over the scene — new `cockpit_painter.dart` + `JourneyGame` wiring & seams (`isCockpitActive`, `cockpitAssetPaths`, `failedCockpitAssetPaths`, `cockpitViewportFraction`); framing pinned at **0.36** of viewport. 7 cockpit asset paths added; `/source-assets` sourced **4 CC BY 3.0 glyphs** (Delapouite/game-icons.net) + **3 procedural** shapes, all attributed in CREDITS (AC-17). Tests: **270** journey unit (was 231) + integration two-surface, **all green**; `analyze` clean. **Self-review verdict: `ready`** (no Blocking; applied the AC-9 canonical-sweep coverage fix; 4 suggestions + 2 nits carried to `/review-code`). |
| [x] | 4 · Review | `/review-code` | 2026-06-25 | verdict: **`approved`** (flutter-code-reviewer) — no Blocking; every functional AC has a non-vacuous test, separation/cosmetic invariants airtight. 3 suggestions (NFR-1 `_drawImageFit` Rect alloc / docstring; decouple AC-13 JourneyGame test from incidental unsourced-dashboard state; tighten AC-5 occlusion proxy) + 3 nits — none block ship. **`/privacy-audit`: `pass`** (privacy-guardian) — no new native/dep/egress; pure-view, static assets only; onboarding claims still hold. |
| [x] | 5 · Test | `/execute-tests` | 2026-06-25 | verdict: **`green`** — **948/948** passed, 0 failed/flaky/skipped (full package + integration two-surface). Report `tests/_runner/reports/journey-pov/20260625-130932/`. Ticked AC-1..11, 13, 14, 15, 17 + NFR-2 in `spec.md`. Carried as pre-public-release legs: AC-12 (real-OS PiP), AC-16 (art-cohesion review), NFR-1 (on-device fps; proxy green), NFR-3 (silhouette visual leg). |
| [x] | 6 · Ship | `/ship` | 2026-06-25 | **SHIPPED (dev build) 2026-06-25.** Kevin confirmed shipping with the 4 manual/visual legs carried (AC-12 real-OS PiP · AC-16 art-cohesion · NFR-1 on-device fps · NFR-3 silhouette visual). Gates: `green` **948/948** · `/review-code` `approved` · `/privacy-audit` `pass`. Green report: `tests/_runner/reports/journey-pov/20260625-130932/`. `spec.md` `Status: shipped`. |

**Current phase:** ✅ SHIPPED (2026-06-25) — slice complete; moved to [done/](../done/journey-pov.md).

### Review follow-ups (non-blocking — optional before ship; reviewer-suggested)
- **NFR-1 `_drawImageFit` (`cockpit_painter.dart:402-417`)** — src-rect cache churns on mixed glyph sizes within a car frame (≤~2 bounded `Rect` allocs/frame). Either key the cache per image identity / construct unconditionally, or soften the "no per-frame allocation" docstring to "no unbounded per-frame allocation." → `flutter-app-developer`.
- **AC-13 (`cockpit_seams_test.dart:167-183`)** — the JourneyGame-level degradation assertion rides the incidental unsourced `dashboard.png`; add an injected-failure test forcing a *sourced* glyph to fault so it decouples from on-disk sourcing state. (Painter-level null-glyph fallback is already covered.) → `unit-test-writer`.
- **AC-5 (`cockpit_render_behaviour_test.dart:303-339`)** — the 0.6 below-dash-line majority threshold is loose; consider asserting no added cockpit draw's `minY` rises above `cockpitTop - dashH` except the allowed A-pillars. → `test-script-author`.

## Decisions made along the way
- **Art-direction spike (Phase 0):** no license-clean photoreal cockpit exists; Kevin approved **stylized
  flat** (CC BY 3.0 glyphs — Delapouite/game-icons.net — + original flat shapes; CC0 Wikimedia wheel
  fallback). Photoreal/paid declined (possible future slug).
- **POV approach:** first-person cockpit **foreground overlay** over the existing receding road + horizon
  tuning — NOT a ground-up 3D camera rewrite.
- **Mode coverage:** car + motorbike only; other 4 modes keep the side-view sprite.
- **Hands omitted v1** (no license-clean source). Cosmetic, single-speed, pure-view; flows to the PiP.
- Broader low-res/beautify work parked in [backlog/visual-polish.md](../backlog/visual-polish.md)
  `[blocked by: journey-pov]`.

## What shipped
A first-person cockpit **foreground overlay** (car = through-windshield dash + steering wheel + decorative
speedometer/fuel gauges + A-pillar framing; motorbike = handlebar + grips + gauge pod + fuel tank),
composited over the existing receding-road Flame scene and **gated to `car`/`motorbike` only** (the other 4
modes keep their side-view sprite). New `cockpit_painter.dart` + `JourneyGame` wiring & read-only seams
(`isCockpitActive`, `cockpitAssetPaths`, `failedCockpitAssetPaths`, `cockpitViewportFraction`); cockpit
occupies the lower **0.36** of the viewport, leaving the road readable above. **Pure-view & cosmetic** — keys
only off the existing `mode`/`moving` values, touches no journey state, reads no OS signal (separation
invariant held). Renders on **both surfaces** (full window + always-on-top PiP) via the shared game
(ADR-0003). Art is **stylized-flat, license-clean**: `/source-assets` sourced **4 CC BY 3.0 glyphs**
(Delapouite/game-icons.net, recoloured to palette) + **3 procedural** flat shapes, all attributed in
`assets/CREDITS.md` (AC-17). Asset failure degrades to a placeholder, never crashes (AC-13).
- **Gates:** test `green` **948/948** (report `tests/_runner/reports/journey-pov/20260625-130932/`) ·
  `/review-code` **`approved`** · `/privacy-audit` **`pass`**.
- **Carried to pre-public-release** (manual/visual legs, automated proxies green): AC-12 real-OS frameless
  PiP confirmation · AC-16 art-cohesion visual review · NFR-1 on-device ≥30fps · NFR-3 silhouette visual leg.
- **Open follow-ups (non-blocking, see Review follow-ups above):** NFR-1 `_drawImageFit` Rect/docstring ·
  AC-13 injected-failure test · AC-5 occlusion-proxy tightening.

## What we'd do differently
- **Sequence asset sourcing before pinning count guards.** `/source-assets` bundling 4 real glyphs *after*
  the implementer set hardcoded "absent-asset count" guards broke 4 pre-existing tests mid-flow. Fix landed
  (assert the documented-absent **set**, not a magic count) and is now more robust — but sourcing the assets
  (or stubbing them) before the implementer pins manifest-count assertions would have avoided the churn.
- **Decouple degradation tests from on-disk sourcing state from the start** (the AC-13 follow-up): assert via
  an injected fault rather than "whichever glyph happens to be unsourced today."
