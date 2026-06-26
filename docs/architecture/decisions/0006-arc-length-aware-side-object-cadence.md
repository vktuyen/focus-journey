# ADR-0006: Arc-length-aware side-object spawn cadence for the dynamic (F1-style) curve

- Status: accepted
- Date: 2026-06-25
- Deciders: Kevin (Tuyen Vo) / system-architect

## Context

> This ADR records a model change **already implemented and shipped** in the `journey-dynamic-curve` slice.
> Its spec flagged it ahead of time: `journey-dynamic-curve` Resolved-decision 4 said the arc-length-aware
> spawn-cadence rework "may need an ADR", and Open-question 2 (resolved in build, 2026-06-25) confirmed the
> M-path was taken. This is that ADR.
>
> It does **not** supersede any prior ADR. It **builds on** ADR-0002 (the Flame scene is the presentation
> surface that owns this geometry) and ADR-0003 (full window + always-on-top mini-window PiP render the
> **same** `JourneyGame` instance, so the new cadence flows to the PiP for free — no second wiring).

The journey scene's roadside scenery (parallax side objects) must stay **evenly spaced along the curving
road** — measured as the **arc-length** gap between consecutive objects within **±20% of the mean**
(journey-scene-v2 AC-7 / journey-dynamic-curve AC-5).

Originally (`journey-scene-v2`) the side-object pool spawned on a fixed *longitudinal* world-distance cadence
(`_spawnEveryWorldPx = 220`). The comment claimed arc-length spacing was "even by construction" — but that
held **only while the road's bend was gentle** (`maxHeading = 0.0016`). True arc-length is
`∫√(1 + (dlateralPx/dworld)²) dworld`, which grows wherever the road leans, so equal *longitudinal* steps
yield **unequal** arc-length gaps once the bend sharpens.

`journey-dynamic-curve` intensified the curve for an F1-style sweeping read within Kevin's approved 2–3×
peak-slope bracket: `maxHeading 0.0016→0.0036` and painter `curveAmplitudeFrac 0.16→0.20`. Measurement at
the sharper curvature confirmed the fixed longitudinal cadence **breaks the ±20% arc-length bound at wider
viewports** — ~22% variance @1280px, ~41% @1920px (the gentle baseline stayed ≤13% at all widths). AC-5 is
non-negotiable (`journey-dynamic-curve` Resolved-decision 4), so a tune-only path was insufficient and the
cadence had to change.

The gating forces:

- **AC-5 (binding):** arc-length gap between consecutive objects within ±20% of the mean at the sharper
  curvature, at all representative viewport widths.
- **AC-8 (pure-view invariant, load-bearing):** the pool must keep importing **only** `dart:*`,
  `package:flame/*`, and the pure-Dart domain `TravelMode` — no Bloc / `JourneyEngine` / `ActivityPlugin` /
  platform channel / OS read.
- **AC-3 / AC-4 (determinism):** the cadence stays a pure function of the shared scroll phase — no clock, no
  `Random` — so goldens remain stable.
- **NFR-1 (performance):** the conversion stays **O(1)** and **allocation-free** on the hot path, however
  sharp the bend or however long the session has scrolled.

## Decision

**Spawn side objects on equal ARC-LENGTH increments rather than equal longitudinal world-distance, using a
closed-form analytic slope so the conversion stays O(1) and allocation-free.**

### (1) Arc-length-aware cadence — RATIFIED.

The pool now spawns on equal **arc-length** increments (`spawnEveryArcPx`) instead of equal longitudinal
world-distance. Each frame it converts the scroll delta to an arc-length delta with the closed-form

```
ds = √(1 + (ampPx · lateralSlopeAt(world))²) · dworld
```

where `ampPx` is the live near-camera curve amplitude (`RoadPainter.curveAmplitudeFrac · viewportWidth`)
threaded into the pool. This makes the gap *along the road* uniform regardless of how sharply the road leans,
so AC-5 holds at the sharper curvature.

### (2) Closed-form `RoadGeometry.lateralSlopeAt(worldDistance)` — RATIFIED.

A new `RoadGeometry.lateralSlopeAt(worldDistance)` returns the closed-form derivative of the centre-line
(`cos(integral) · heading(segment) · maxHeading`), so the arc-length conversion stays a **true O(1) closed
form** — one `sqrt` plus one closed-form slope per frame, no per-frame accumulating integral loop and no
per-frame allocation (NFR-1 preserved). The painter and the pool now share **one** `RoadGeometry` instance,
so the rendered bend and the spawn cadence agree by construction (no drift between what is drawn and where
objects are placed).

## Consequences

- **Easier / outcomes met:** AC-5 arc-length variance drops to **<0.7% at every viewport width 420–2560px**
  (was up to 41%); journey-scene-v2 AC-7 even-spacing is preserved at the sharper curvature. The
  pure-view invariant is intact (AC-8) — the pool's only new dependency is `dart:math` plus the pure
  sibling `road_geometry.dart`; no Flutter / Bloc / engine / OS. Determinism is preserved (AC-3/AC-4): the
  cadence is still a pure function of the shared scroll phase, with no clock/`Random`, so goldens stay
  stable. NFR-1 O(1)/alloc-free is maintained (one `sqrt` + one closed-form slope per frame; slot reuse; no
  growing loop). Per ADR-0003 the new cadence reaches the mini-window PiP for free (one shared `JourneyGame`).
- **Trade-off accepted:** the pool now depends on the **live near-camera amplitude** (which is
  viewport-width-dependent), introducing a deliberate coupling between the pool and the painter's
  `curveAmplitudeFrac` · width. This is the accepted cost — it is exactly what makes the spacing track the
  *rendered* bend rather than an abstract one.
- **Forward note:** a future per-mode-speed model (`journey-energy-model`) that changes scroll *velocity*
  does **not** affect this decision — the cadence is expressed in world/arc space and is speed-independent.

## Alternatives considered

### Keep the fixed longitudinal cadence (`spawnEveryWorldPx`)
Rejected: it fails AC-5's ±20% arc-length bound at wide viewports (~22% @1280px, ~41% @1920px) once the bend
is sharpened, because equal longitudinal steps give unequal arc-length gaps where the road leans.

### Cap curvature low enough that the longitudinal cadence stays within ±20%
Rejected: it would defeat the F1-style "clearly sharper than baseline" goal (AC-1, within Kevin's approved
2–3× bracket) — the curvature would have to stay near the gentle baseline that AC-1 explicitly exceeds.

### A numerical arc-length accumulator loop
Rejected: summing `ds` over many sub-steps per frame is not O(1) and would violate NFR-1's
no-per-frame-accumulating-loop / allocation-free constraint. The closed-form `lateralSlopeAt` conversion
achieves the same arc-length accuracy in O(1).

## References

- Spec: `specs/journey-dynamic-curve/spec.md` — AC-5/AC-6/AC-7, NFR-1, Resolved-decision 4, Open-question 2.
- ADR-0002 — Flutter/Bloc/Flame stack (the Flame scene owns this geometry).
- ADR-0003 — single-window two-mode / shared `JourneyGame` (the cadence flows to the PiP for free).
