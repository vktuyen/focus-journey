# Journey cockpit lean — first-person POV tilts into the curve

**Promoted from backlog:** 2026-06-25
**Target:** visual-polish epic · Wave 2 (slice 2 of 2)
**Spec:** [specs/journey-cockpit-lean/](../../specs/journey-cockpit-lean/spec.md)

## Goal
The first-person cockpit (car + motorbike) leans/tilts **into** the curve — bounded, eased, and
reduce-motion-gated — implemented as a rotation of the `CockpitPainter` output only, sampled from the
shipped `journey-dynamic-curve` curve, with the pure-view invariant and deterministic goldens intact.

## Phase ledger
The **single** status tracker — one row per phase, updated in place after each phase command.
Each row carries the date + a one-line note + verdict, so a fresh session (`/status`) can resume
from this table alone. Do not keep a separate status log; the ledger IS the log.

| ✓ | Phase | Command | Date | Verdict / note |
|---|-------|---------|------|----------------|
| [x] | 2 · Spec | `/new-feature` → review & approve `spec.md` | 2026-06-25 | **Approved by Kevin.** 14 ACs + 3 NFRs (product-domain-expert); test cases designed (`test-case-designer`): 18 automated TC-501..518 + 4 manual carries in `tests/cases/journey-cockpit-lean.md` (+ `-manual-checklist.md`) |
| [x] | 3 · Build | `/implement` (includes self-review pass) | 2026-06-25 | **Done (flame-game-developer).** Lean = bounded/eased/reduce-motion-gated rotation of `CockpitPainter` only; `appliedLeanAngle`+`rawLeanTargetAngle` seams; constants pinned (max ~3°/0.0523599, gain 18, smoothing 60px scroll-phase, sign +1, bottom-centre pivot). Tests: 23 unit (unit-test-writer) + 18 TC-501..518 (test-script-author), all green. **Self-review (flutter-code-reviewer): 1 Blocking (B1 AC-13 corner-coverage) + B2 (loose guard) — both FIXED & verified**; AC-7 reworded (procedural curve has no exact-zero-slope frame). |
| [x] | 4 · Review | `/review-code` | 2026-06-26 | verdict: **`approved-with-suggestions`** (flutter-code-reviewer) — **0 Blocking**; both self-review fixes (AC-13 overdraw + tightened TC-514) verified correct; every AC has real teeth or accepted manual carry. **`/privacy-audit` PASS** (privacy-guardian) → NFR-2 gate cleared. Non-blocking: 1 Suggestion (stale `_appliedLean` field — zero it in `applyState` for non-cockpit/reduce-motion; not reachable on-device since render always follows update) + 2 Nits (test-file `dart format`; golden uses path AABB). |
| [x] | 5 · Test | `/execute-tests` | 2026-06-26 | verdict: **`green`** — 70/70 in-scope (67 unit/widget/golden/static/perf + 2 two-surface + 1 smoke) + **248/248 regression** (journey-game suite), 0 flakes. Report `tests/_runner/reports/journey-cockpit-lean/20260626-094519/summary.md`. AC-1..14 + NFR-1/NFR-3 ticked (NFR-2 via privacy gate). |
| [x] | 6 · Ship | `/ship` | 2026-06-26 | **SHIPPED.** spec `Status: shipped`; AC-1..14 + NFR-1/2/3 all `[x]`. Folded in two live-tuning tweaks: car steering wheel sized to the dash band so the **whole wheel is visible** (`cockpit_painter.dart`), and the minimap moved **bottom-right → centre-right** (`map_surface.dart`). Re-run green: 69/69 in-scope + 247 regression (`tests/_runner/reports/journey-cockpit-lean/20260626-103704/summary.md`). |

**Current phase:** SHIPPED (2026-06-26) — closes `visual-polish` Wave 2.

### Review outcome (2026-06-26) — non-blocking follow-ups (optional, can fold into a later pass)
- **Suggestion (flame-game-developer):** in `journey_game.dart`, zero `_appliedLean` inside `applyState` when mode is non-cockpit or `reduceMotion` so the backing field never diverges from the gated `appliedLeanAngle` seam. Latent only (production `render` always runs after `update`; TC-509 dodges it by asserting `rawLeanTargetAngle`).
- **Nit (unit-test-writer / test-script-author):** `dart format` the two lean test files (`journey_cockpit_lean_test.dart`, `journey_cockpit_lean_behaviour_test.dart`) — production files already clean.

### Build outcome (2026-06-25)
- **Files changed (lib):** `cockpit_painter.dart` (optional `leanRadians` → save/rotate/restore about bottom-centre pivot; lever-arm-scaled corner overdraw `(w/2)·sin θ + 4px`, gated on `leaning`), `journey_game.dart` (lean state + `_advanceLean(scrollDelta)` + seams), `road_painter.dart` (`worldAtCamera`).
- **Tests:** `test/.../game/journey_cockpit_lean_{test,behaviour,golden,separation_static,perf}_test.dart` (66 green) + `integration_test/journey_cockpit_lean_{two_surface,smoke}_test.dart` (green individually on `-d macos`).
- **Self-review fixes:** B1 — overdraw was a flat 6% of band height but the lifted bottom corner needs `(w/2)·sin θ`; now lever-arm-scaled, corner coverage proven at PiP 360×220 + full 1280×800 at θ=max. B2 — TC-514 guard rewritten from loose device AABB → point-in-rotated-quad containment + a non-vacuity guard proving it goes red against the old painter.
- **Determinism:** smoothing keyed on `scrollDelta` (scroll-phase), not `dt` — replay-identical, goldens stable.
- **Carried (manual, consistent with prior slices):** TC-M-FEEL (motion-comfort/feel + physical "into-the-turn" direction), TC-M-PIP (real-OS frameless PiP visual), TC-M-NF1 (on-device ≥30fps), TC-M-PRIV (`/privacy-audit` gate, NFR-2). Windows runtime deferred.

### Build note for the implementer (flame-game-developer)
The test cases (AC-1..8 sign/magnitude suite) assume a new **read-only `appliedLeanAngle`-style seam** on
`JourneyGame` (deterministic, a pure function of the smoothed scroll-phase) — add it, mirroring how
`isCockpitActive` / `centreLineOffsetAt` / `liveCentreLinePoints` were exposed, so the sign convention
(AC-1) and the clamp/ease (AC-3/AC-4) can genuinely fail. The smoothing is stateful, so determinism
(AC-5) requires replay from the same initial smoothing state. Three build decisions to pin (with proposed
targets in the spec): max angle ~3°, smoothing ~0.2°/frame, signal = signed `lateralSlopeAt` at `t≈1`,
pivot = bottom-centre.

## Decisions made along the way
- Blocked-by `journey-dynamic-curve` ✅ shipped 2026-06-25 — lean is tuned against its final curve
  (`maxHeading 0.0036`, `curveAmplitudeFrac 0.20`, peak slope ~2.25× baseline).
- Lean is a rotation of `CockpitPainter` output only (not a scene/camera tilt) — preserves the cockpit↔scene
  separation invariant + deterministic goldens. See spec `## Resolved decisions`.
- Open questions for build/review: max lean angle + smoothing constant; slope vs centre-line-offset signal;
  rotation pivot point.
