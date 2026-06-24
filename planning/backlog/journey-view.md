# Journey View

**Intake date:** 2026-06-23  **Requested by:** tuyenv@joblogic.com  **Size (rough):** L
**Part of epic:** [vietnam-focus-journey](vietnam-focus-journey.md) · Wave 1 (v1)

## Why
The main emotional screen: a stylized 2D first-person road scene (Flame) — trapezoid road with scrolling lanes, parallax side objects, day/night tint, and the vehicle **skin** sprite — driven entirely by the engine/Bloc state (active → moving; idle → parked). Uses only license-clean assets curated via `/source-assets`.

## Signals
Ready when: the scene scrolls/animates on active and stops on idle, reads state from the journey Bloc (owns no activity logic), runs smoothly on desktop, and consumes only assets recorded in `assets/CREDITS.md`. [blocked by: journey-engine]

## First step
Run `/new-feature journey-view` to promote this slice into a spec (after `journey-engine`).
