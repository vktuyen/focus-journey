# Journey cockpit lean — POV tilts into the curve

**Intake date:** 2026-06-25  **Requested by:** Kevin (Tuyen Vo)  **Size (rough):** S–M
**Part of epic:** [visual-polish](visual-polish.md) · Wave 2

## Why
The car/motorbike first-person cockpit holds level through bends. Kevin wants it to **lean/tilt into the
curve** so cornering feels physical. Extends the shipped `journey-pov` cockpit overlay (new slug). The tilt is
sampled from the existing curve-at-camera — stays pure-view (no new OS/clock read).

## Signals
Ready when: cockpit tilt is non-zero on a bend, **signed to match curve direction**, monotonic in curve
magnitude up to a **clamped max**, eased/low-pass (motion-sickness safety), and **exactly zero when
reduce-motion is on** or curvature is zero; implemented as a rotation of the `CockpitPainter` output only
(keeps the separation invariant + deterministic goldens); car/motorbike only. The lean is most meaningful
against the dramatic curve and shares its bend signal. `[blocked by: journey-dynamic-curve]`

## First step
Run `/new-feature journey-cockpit-lean` to promote this slice into a spec.
