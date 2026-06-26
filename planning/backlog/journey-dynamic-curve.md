# Journey dynamic curve — F1-style sweeping animated bends

**Intake date:** 2026-06-25  **Requested by:** Kevin (Tuyen Vo)  **Size (rough):** M (S if pure param-tune)
**Part of epic:** [visual-polish](visual-polish.md) · Wave 2

## Why
Today's road is a gentle winding road. Kevin wants **F1-track-grade sweeping, animated bends** so cornering
reads as a real, dynamic drive — without breaking the calm-companion tone (needs a "sweeping but smooth"
ceiling, not literal chicanes). Enhances the shipped `journey-scene-v2` road geometry (new slug, not a
re-`/implement`).

## Signals
Ready when: peak curvature visibly exceeds the journey-scene-v2 baseline maximum and the bend sweeps over time
(time-variation folded into the existing **scroll-phase** input, NOT a wall-clock — goldens stay
deterministic); **side-object even-spacing (AC-7, ±20% arc-length) still holds** — re-derive as arc-length-aware
spawn cadence if a sharper bend would otherwise fail it; **≥30fps (NFR-1)** preserved (O(1) curve integral);
reduce-motion freezes the sweep. `[blocked by: none]` — sequence after `journey-scene-art-v3` to reduce golden
churn. **May need an ADR** if the change exceeds a parameter tune (arc-length spawn rework).

## First step
Run `/new-feature journey-dynamic-curve` to promote this slice into a spec.
