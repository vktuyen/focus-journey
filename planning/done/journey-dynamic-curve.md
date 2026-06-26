# Journey dynamic curve — F1-style sweeping animated bends

**Promoted from backlog:** 2026-06-25
**Target:** visual-polish Wave 2
**Shipped:** 2026-06-25 (dev build, macOS-verified)
**Spec:** [specs/journey-dynamic-curve/](../../specs/journey-dynamic-curve/)
**Green report:** [tests/_runner/reports/journey-dynamic-curve/20260625-173303/](../../tests/_runner/reports/journey-dynamic-curve/20260625-173303/) (verdict `green`, 182/182)

## Goal
The road reads as a genuine F1-style sweeping, animated drive — peak curvature clearly sharper than the
journey-scene-v2 baseline and bending over time via the shared scroll phase — while preserving AC-7
arc-length even-spacing (±20%), ≥30fps (O(1) curve), reduce-motion freeze, and the pure-view/cosmetic
invariants, all within a "sweeping but smooth" calm-tone ceiling.

## Phase ledger
The **single** status tracker — one row per phase, updated in place after each phase command.

| ✓ | Phase | Command | Date | Verdict / note |
|---|-------|---------|------|----------------|
| [x] | 2 · Spec | `/new-feature` → review & approve `spec.md` | 2026-06-25 | **APPROVED** (Kevin). AC-1..11 + NFR-1..3; calm-tone ceiling = ~2–3× bracket. Test cases authored: `tests/cases/journey-dynamic-curve.md` (TC-401..415) + manual checklist (TC-M-FEEL/PIP/NF1/PRIV). |
| [x] | 3 · Build | `/implement` (includes self-review pass) | 2026-06-25 | **DONE.** Arc-length-aware fork (M-path): `maxHeading 0.0016→0.0036`, `curveAmplitudeFrac 0.16→0.20`, new `lateralSlopeAt` + arc-length spawn cadence. AC-1 2.25×, AC-5 var <0.7% all widths. **ADR-0006** written. Tests **green: 1012 unit/widget + integration (macOS)**, analyze clean. **Self-review verdict `ready`** (no Blocking; nits + TC-405 traceability + ADR folded in). AC-11 bound corrected (literal was unsatisfiable even at baseline). |
| [x] | 4 · Review | `/review-code` | 2026-06-25 | verdict: **`ready`** (flutter-code-reviewer; no P0/P1 — math/cadence independently re-derived, pure-view + cosmetic-only confirmed, ADR-0006 matches code, AC-11 correction sound). **`/privacy-audit` PASS** (NFR-2 gate; no new dep/OS read; only `dart:math`). 4 non-blocking P2 polish items carried (see below). |
| [x] | 5 · Test | `/execute-tests` | 2026-06-25 | verdict: **`green`** — 182/182 (181 unit/widget game-dir + 1 integration smoke `-d macos`), 0 failures, no flake patched. Report `tests/_runner/reports/journey-dynamic-curve/20260625-173303/`. AC-1..11 + NFR-2 ticked `[x]`; NFR-1 (on-device fps TC-M-NF1) + NFR-3 (visual TC-M-FEEL/PIP) carried; 4 manual legs. |
| [x] | 6 · Ship | `/ship` | 2026-06-25 | **SHIPPED** (dev build, macOS-verified). Green report machine-checked (verdict `green`, 182/182). Spec `Status: shipped`. AC-1..11 + NFR-2 ticked; NFR-1/NFR-3 carried as pre-public-release legs. |

**Current phase:** SHIPPED (Wave 2 of visual-polish). `active/` slot cleared.

## What shipped
- **F1-style sweeping curve, within the calm ceiling.** `RoadGeometry.maxHeading 0.0016 → 0.0036` and
  `RoadPainter.curveAmplitudeFrac 0.16 → 0.20` (now public) — measured **peak slope 2.25× baseline** (AC-1,
  inside Kevin's 2–3× bracket), rendered near-camera excursion ~1.25× (AC-2), per-frame cruise delta ~0.12%
  viewport width (well under the ~2% calm cap, AC-7). The bend sweeps purely off the shared scroll phase
  (deterministic, freezes on stop/reduce-motion — AC-3/AC-4/AC-10).
- **Arc-length-aware spawn cadence (the model rework — [ADR-0006](../../docs/architecture/decisions/0006-arc-length-aware-side-object-cadence.md)).**
  The decisive AC-5 measurement showed the old fixed *longitudinal* cadence breaks ±20% arc-length spacing at
  the sharper curve at wide viewports (~22% @1280px, ~41% @1920px). New `RoadGeometry.lateralSlopeAt`
  (closed-form derivative) lets the pool spawn on equal **arc-length** increments
  (`ds = √(1+(ampPx·slope)²)·dworld`), O(1)/alloc-free, fed the live near-camera amplitude. Result: **arc-length
  variance <0.7% at every width 420–2560px** (AC-5/AC-6). Painter + pool now share one `RoadGeometry`.
- **Invariants held.** Pure-view (only `dart:*`/`package:flame/*`/`TravelMode` — AC-8), cosmetic-only (engine
  distance/progress/idle byte-for-byte unchanged — AC-9), reduce-motion freeze (AC-10), two-surface PiP
  centre-line on-screen bound (AC-11). `/privacy-audit` **PASS** (NFR-2, gating). **948→1012+ tests**;
  `/execute-tests` **green 182/182** in-scope; `/review-code` **ready**.

## What we'd do differently
- **Spec the PiP bound against the real renderer, not an idealized one.** AC-11's original literal bound
  (`|centreLineOffset| + nearHalf ≤ width/2`) was **unsatisfiable even at the shipped baseline** — the
  trapezoid road's near half-width (`_roadNearHalfFrac 0.46`) already fills ~92% of the viewport by design.
  Caught in build and corrected to the road **centre-line** staying on screen, but a quick check against the
  actual painter constants at spec time would have avoided authoring an impossible AC + case.
- **Predict the AC-7 fork at capture, don't just flag it.** Phase-0 correctly called the arc-length-vs-
  longitudinal risk "may need an ADR", but a 2-minute back-of-envelope (arc-length grows with the *square* of
  the lateral slope, which scales with viewport width) would have told us the rework was near-certain at any
  meaningfully sharper curve — so we could have sized it M from the start rather than "S if pure tune".
- **The `liveCentreLinePoints` seam was the hero.** Pre-adding that test seam in journey-scene-v2 "for the
  AC-7 review gap" is exactly why AC-5 was measurable here without scrambling — worth repeating: when a
  shipped slice leaves a known-fragile invariant, leave the seam that lets the next slice *prove* it.

## Non-blocking P2 review polish (carried — not gating)
- `side_object_pool.dart:308` — defensive cap on the arc-length catch-up `while` loop (not
  production-reachable; same loop shape journey-scene-v2 shipped). → `flutter-app-developer`.
- `journey_dynamic_curve_cosmetic_engine_test.dart:78-87` — TC-409's "sharper vs baseline" arms are
  byte-identical (both use the shared/sharper geometry); AC-9 still holds but the test is weaker than its
  docstring — reword or inject a real baseline geometry. → `unit-test-writer`.
- `journey_scene_v2_test.dart:149-157` — `renderedArcLengthGaps` uses chord distance vs the convention's
  integral; the bound still binds (fidelity polish). → `unit-test-writer`.
- `journey_dynamic_curve_behaviour_test.dart` — not `dart format`-clean (3 wrap spots); production clean.
  → `unit-test-writer`.

## Carried before any public / Windows release (NOT blocking the dev build)
- **NFR-1** on-device ≥30fps both surfaces with the sharper curve under `active` (TC-M-NF1; automated
  O(1)-integral / no-per-frame-alloc / bounded-pool proxies green).
- **NFR-3 / AC-7 / AC-1 feel** — the "reads as a genuine F1-like sweeping drive yet stays a calm companion,
  no nausea-grade swings, doesn't obscure the road/vehicle/'Paused — idle' overlay" qualitative sign-off
  (TC-M-FEEL).
- **AC-11 real-OS PiP visual** — sharper bend never swings the road off readably on a live frameless
  always-on-top PiP (TC-M-PIP; automated centre-line-on-screen bound green).
- **Windows runtime** never verified for this slice (pure-Dart geometry; no native, but unconfirmed on
  Windows desktop).

## Decisions made along the way
- Phase-0 capture (Kevin, 2026-06-25): enhance the existing parameterised curve (not a new model); animate
  via scroll phase only (no wall-clock); "sweeping but smooth" ceiling (~2–3× peak-slope bracket); AC-7
  non-negotiable; curve + cockpit-lean are two slices.
- **ADR-0006 (2026-06-25):** *arc-length-aware side-object spawn cadence* —
  [docs/architecture/decisions/0006-arc-length-aware-side-object-cadence.md](../../docs/architecture/decisions/0006-arc-length-aware-side-object-cadence.md);
  indexed in `docs/architecture/overview.md`.
- **AC-11 corrected (2026-06-25):** literal "road edge on-screen" bound was unsatisfiable even at baseline;
  AC-11 + TC-412 now assert the road **centre-line** stays on screen. Real-OS visual = manual TC-M-PIP.

## Unblocks
- **`journey-cockpit-lean`** (`[blocked by: journey-dynamic-curve]`) — the cockpit tilt is to be tuned against
  this final curve (use `RoadGeometry.lateralSlopeAt` / `centreLineOffsetAt(t≈1)` as the bend signal).
