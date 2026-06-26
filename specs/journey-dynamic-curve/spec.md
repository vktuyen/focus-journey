# Journey dynamic curve — F1-style sweeping animated bends

**Status:** shipped (2026-06-25)
**Owner:** Kevin (Tuyen Vo)
**Last updated:** 2026-06-25

> **Test verdict (2026-06-25): `green`** — 182/182 passed (report
> `tests/_runner/reports/journey-dynamic-curve/20260625-173303/`). `/review-code` `ready` · `/privacy-audit`
> `pass`. AC-1..AC-11 + NFR-2 verified by the green run + privacy gate. **Carried as pre-public-release legs**
> (manual, consistent with prior slices): **NFR-1** on-device ≥30fps both surfaces (automated O(1)/no-alloc/
> bounded-pool proxies green; device fps = TC-M-NF1); **NFR-3** the "doesn't obscure / F1-like but calm"
> visual read (reduce-motion + on-screen-bound halves automated green via AC-10/AC-11; visual = TC-M-FEEL /
> TC-M-PIP). ADR-0006 records the arc-length-aware spawn-cadence model change.

## Problem
The journey scene shipped by `journey-scene-v2` already renders a **winding** road — a segmented
heading-offset centre-line (`RoadGeometry.lateralAt(worldDistance)` → `sin(integratedHeading)`) that the
road, lane markings, and roadside objects all sample so they follow the bend. But the bend is deliberately
**gentle**: `maxHeading = 0.0016`, `segmentLength = 900px`, and the painter swings the centre-line only
`_curveAmplitudeFrac = 0.16` of the viewport width. Kevin's eye reads this as **tame** — the road meanders
but never feels like a *drive*. He wants **F1-track-grade sweeping, animated bends** so cornering reads as a
real, dynamic drive.

The hard part is doing this **without breaking three load-bearing invariants** the shipped scene guarantees,
and **without breaking the "calm companion" tone** (this is an ambient background for a work session, not a
game the user pilots — a literal racetrack would pull focus). So the feature is a bounded *intensification*
of the existing parameterised curve, not a new road model — with an explicit "sweeping but smooth" ceiling.

This enhances the **shipped** `journey-scene-v2` road geometry, so per wave discipline it is a **new slug**,
not a re-`/implement`. It is Wave 2 of the `visual-polish` epic and is the **highest risk-to-invariants
slice** (it directly stresses AC-7 even-spacing), which is why it gets its own golden-review cycle and is
sequenced after `journey-scene-art-v3` to reduce golden churn.

## User & outcome
- **The focused individual** (developer / student / remote worker) — primary. Success = the road now reads
  as a genuine sweeping drive: peak curvature is **visibly sharper** than the journey-scene-v2 baseline and
  the bend **sweeps over time** as the scene scrolls, yet the scene still feels calm enough to leave on-screen
  all session (no abrupt chicanes, no nausea-grade swings). Observable: peak |lateral curvature| exceeds the
  baseline maximum by a clear margin; the centre-line at the camera changes smoothly frame-to-frame while
  scrolling; reduce-motion freezes the sweep entirely.
- **The privacy-skeptical teammate** — unaffected. This is a **cosmetic, pure-view** change to road geometry
  only: the scene still reads no OS signal, owns no journey logic, accrues no distance. `/privacy-audit`
  stays PASS by construction (no new dependency — `RoadGeometry` imports only `dart:math`).

## Scope
### In
- **Sharper bends** — intensify the existing parameterised curve so peak curvature clearly exceeds the
  journey-scene-v2 baseline (some combination of higher `maxHeading`, shorter `segmentLength`, and/or a
  larger painter curve amplitude `_curveAmplitudeFrac`), bounded by a tuned "sweeping but smooth" ceiling.
- **Animated sweep folded into the existing scroll phase** — the bend must *sweep over time* as a function
  of the **same single scroll-phase / world-distance input** the whole scene already shares (the curve
  already flows toward the camera via `_worldAt(scrollOffset, t)`). Time-variation comes from scroll phase,
  **NOT a wall-clock** — so goldens stay deterministic and the curve freezes when the scene is stopped.
- **Preserve even arc-length spacing (AC-7)** — side objects today spawn on a fixed *longitudinal*
  world-distance cadence (`_spawnEveryWorldPx`). A sharper bend raises *arc-length* variance (true arc-length
  = ∫√(1 + (dlat/ds)²) ds grows where the road leans), which can push the ±20% spacing bound. Re-derive the
  spawn cadence to be **arc-length-aware** if (and only if) a parameter tune alone fails AC-7.
- **Preserve performance (NFR-1)** — the curve integral stays **O(1)** (no per-frame accumulating loop, no
  per-frame allocation) however sharp the bend or however long the session has scrolled.
- **Reduce-motion freezes the sweep** — when reduce-motion is on, `scrollDelta == 0` so the curve is already
  frozen; this must remain true (the sharper curve introduces no new independent motion source).
- **One scene, two surfaces** — the sharper curve flows automatically to the **mini-window PiP** (both
  surfaces render the same `JourneyGame` instance, ADR-0003) and must read correctly at the sized-down PiP
  without the road bending off-screen.

### Out
- **A new road model / spline / ground-up 3D camera** — we tune and (if needed) make the *spawn cadence*
  arc-length-aware on the **existing** segmented heading-offset model; we do not replace `RoadGeometry` with
  a spline or rebuild the trapezoid into a true 3D projection.
- **Wall-clock-driven animation** — no `DateTime.now` / real-time sweep. All time-variation rides the
  shared scroll phase (keeps goldens deterministic; freezes when stopped).
- **Cockpit lean / tilt-into-the-curve** — that is the sibling slice `journey-cockpit-lean`
  (`[blocked by: journey-dynamic-curve]`). This slice only changes road geometry; the cockpit stays level.
  (The lean will be tuned against the *final* curve shipped here.)
- **Per-mode speeds / different curve per vehicle** — the curve is single, cosmetic, mode-independent
  (per-mode behaviour is the deferred `journey-energy-model`).
- **Any change to journey logic** — engine, distance accrual, idle/active decisions, route/map, stats.

## Constraints & assumptions
- **Pure-view invariant (hard, load-bearing).** `RoadGeometry` and its painter/pool siblings import **only**
  `dart:*`, `package:flame/*`, and the pure-Dart domain `TravelMode`. The curve is driven solely by the
  shared scroll offset (world distance) — **no** Bloc, `JourneyEngine`, `ActivityPlugin`, `MethodChannel`,
  or OS read. It decides no active-vs-idle and accrues no distance.
- **Frame-deterministic.** The centre-line is a pure function of world distance (no `Random`, no clock), so
  unit tests and goldens are stable. The animated sweep must preserve this (scroll-phase only).
- **O(1) curve integral (NFR-1).** `_integratedHeading` is a true closed form today (cyclic heading table +
  precomputed prefix sums). Any intensification must keep it O(1) and allocation-free on the hot path.
- **AC-7 is the binding risk.** Even-spacing is measured **along the curving road (arc-length, ±20% of mean
  gap)**. The fixed *longitudinal* spawn cadence only satisfies this while the bend is gentle. The implementer
  must measure arc-length variance at the chosen curvature and switch to arc-length-aware spawn cadence if the
  tune alone would fail it.
- **Calm-tone ceiling.** "Sweeping but smooth" — a max-curvature / max-rate-of-change bound so the scene
  reads as a dynamic drive but does not pull focus or induce motion discomfort. (Sibling lean slice has its
  own motion-sickness clamp; this slice bounds the road itself.)
- **One scene, two surfaces.** Full window + always-on-top mini-window PiP render the same `JourneyGame`
  (ADR-0003); the curve must read correctly and stay on-screen at both sizes.
- **Desktop targets:** macOS + Windows. Stack per `docs/architecture/overview.md`; scene is Flame
  presentation (ADR-0002).

## Resolved decisions (from Phase-0 capture, Kevin 2026-06-25)
1. **Enhance the existing parameterised curve** (raise intensity + animate via scroll phase) — **not** a new
   road model, spline, or 3D camera.
2. **Animate via the existing scroll-phase input**, never a wall-clock — goldens stay deterministic, curve
   freezes when stopped/reduce-motion.
3. **"Sweeping but smooth" ceiling** — sharper than baseline but bounded so it never becomes a literal
   racetrack chicane (calm-companion tone protected).
4. **AC-7 even-spacing is non-negotiable** — re-derive spawn cadence as arc-length-aware **if** a parameter
   tune alone breaks the ±20% bound. **This may need an ADR** (the dynamic-curve model change + its effect on
   AC-7 / NFR-1 — flagged in the epic's candidate ADRs).
5. **Curve + cockpit lean ship as two slices** — lean (`journey-cockpit-lean`) is blocked by this slice and
   tuned against the final curve.

## Acceptance criteria
Each item is a checkable, observable statement and the ship gate. If it isn't testable, rewrite it.
These ACs ARE the contract — `tests/cases/journey-dynamic-curve.md` will reference them by ID; there
is no separate acceptance-criteria file. "Baseline" everywhere below means the **shipped
journey-scene-v2 curve** (`RoadGeometry(segmentLength = 900, maxHeading = 0.0016)` +
`RoadPainter._curveAmplitudeFrac = 0.16`); the AC-N references are to **this** spec, the AC-7/AC-6
references are to **journey-scene-v2**.

**Sharper-than-baseline curvature**
- [x] AC-1 (peak curvature clearly exceeds baseline): Given the shipped journey-scene-v2 geometry as the
      reference, When the dynamic-curve `RoadGeometry` is sampled across a full heading cycle, Then its
      **peak |per-distance lateral derivative|** `max_d |Δ lateralAt(d) / Δd|` exceeds the baseline's
      peak by a clear, asserted margin. Observable via the pure `RoadGeometry.lateralAt(worldDistance)`
      seam: sample both the baseline params and the shipped params over `d ∈ [0, N·segmentLength]` and
      assert `peakSlope(new) ≥ K · peakSlope(baseline)`. _proposed resolution to Open question
      "Calm-tone ceiling — how sharp is F1-like but smooth?": target **K ≈ 2.0×** (clearly sharper, read
      as a real drive) — **Kevin signed off on the ~2–3× bracket (2026-06-25)**; flame-game-developer pins
      the exact achieved multiple in build (via higher `maxHeading` and/or shorter `segmentLength` and/or
      larger `_curveAmplitudeFrac`), within the AC-7 ≤3× ceiling._
- [x] AC-2 (sharper on screen, not just in the model): Given the new geometry feeds
      `RoadPainter.centreLineOffset(size, scrollOffset, t)`, When the near-camera centre-line offset
      (`t → 1`) is measured across a scroll sweep at a fixed viewport size, Then its peak absolute
      excursion exceeds the baseline painter's peak excursion by a clear, asserted margin (the sharper
      model is actually rendered, the painter does not clamp it away). Observable via `centreLineOffset`
      with the baseline vs shipped `_curveAmplitudeFrac` / geometry.

**Animated sweep folded into the shared scroll phase**
- [x] AC-3 (bend sweeps with scroll, deterministically): Given the engine is `active` (scroll
      advancing), When `roadScrollOffset` advances over successive frames, Then the centre-line bend at
      the camera (`centreLineOffset(size, scrollOffset, t≈1)`) **changes smoothly frame-to-frame** (a
      non-constant, continuous function of `scrollOffset`), and is a **pure deterministic function of the
      scroll phase only** — sampling at the same `scrollOffset` twice yields identical output, and no
      `DateTime.now` / wall-clock / `Random` is read (goldens stay stable). Observable via repeated
      `centreLineOffset` calls at recorded `roadScrollOffset` values.
- [x] AC-4 (single shared phase — no second motion source): Given the rest of the scene (lane dashes,
      side objects, parallax bands, sky) already rides the single shared scroll phase
      (`JourneyGame.roadScrollOffset` → `_motion.offset`), When the dynamic curve animates, Then it
      derives its sweep from that **same single phase input** and introduces **no new independent clock,
      timer, or per-component phase**. Observable by inspection (the curve's only time input is
      `scrollOffset` / `worldDistance`, the same value the road body, dashes and pool already consume)
      and by AC-3 determinism.

**AC-7 arc-length even-spacing PRESERVED (the binding invariant)**
- [x] AC-5 (even arc-length spacing holds at the sharper curvature): Given the side-object pool runs a
      full scroll cycle with the sharper curve loaded, When consecutive live objects' spawn positions are
      projected onto the curving centre-line, Then the **arc-length** gap between consecutive objects
      (`∫√(1 + (dlat/ds)²) ds` between their `spawnWorldDistance` values, using the new geometry) stays
      within **±20% of the mean gap** — preserving journey-scene-v2 AC-7, with no clumping or empty
      stretches. Observable via the pool's `spawnWorldDistance` / `worldDistance` / `spawnEveryWorldPx`
      seams plus the pure `RoadGeometry` arc-length integral.
- [x] AC-6 (arc-length-aware cadence IFF the fixed cadence fails the bound): Given the sharper curvature
      is chosen, When the implementer measures arc-length variance at that curvature, Then **either** the
      existing fixed longitudinal cadence (`spawnEveryWorldPx`) still satisfies AC-5's ±20% bound (no
      cadence change), **or** the spawn cadence is made **arc-length-aware** (spawn on equal arc-length
      increments rather than equal longitudinal `worldDistance`) so AC-5 passes — and the change keeps
      the pool allocation-free and O(1) per spawn (NFR-1). _proposed resolution to Open question "does a
      parameter tune alone hold AC-7…": flame-game-developer measures and decides S (tune-only) vs M
      (arc-length-aware cadence + ADR); whichever is chosen, AC-5 is the binding pass/fail._

**Calm-tone ceiling**
- [x] AC-7 (sweeping but smooth — bounded curvature & rate-of-change): Given the chosen curvature, When
      the geometry and painter are measured, Then the bend is bounded below a tuned ceiling so the scene
      reads as a dynamic drive but never a nausea-grade chicane: the centre-line stays on screen
      (|`lateralAt`| ≤ 1 by construction) **and** the per-frame change of the near-camera centre-line at
      the expected cruise scroll rate stays below a smoothness cap. _Resolution to Open question
      "Calm-tone ceiling" (**Kevin signed off the ~2–3× bracket, 2026-06-25**): peak per-distance slope
      **≤ ~3×** baseline (the upper bound complementing AC-1's ~2× lower target — sharper, but bounded), and
      the **per-frame** near-camera `centreLineOffset` delta at cruise scroll velocity **≤ ~2% of viewport
      width per frame** (no abrupt snap); flame-game-developer pins the exact px/frame cap against the actual
      eased cruise `scrollDelta` in build. Observable via sampling `lateralAt` derivative and stepping
      `centreLineOffset` by one cruise-frame's `scrollDelta`._

**Pure-view & separation**
- [x] AC-8 (pure-view invariant preserved): Given the sharper curve is implemented, When
      `road_geometry.dart`, `road_painter.dart` and `side_object_pool.dart` are inspected, Then they still
      import **only** `dart:*`, `package:flame/*`, and the pure-Dart domain `TravelMode` — **no**
      `flutter_bloc`, `JourneyEngine`, `ActivityPlugin`, `MethodChannel`/platform channel, or OS
      idle/lock/screen/location read (mirrors journey-scene-v2's separation AC and journey-pov AC-9). The
      curve is driven solely by the shared scroll offset (world distance).
- [x] AC-9 (cosmetic-only — no journey state touched): Given the sharper curve renders, When the journey
      runs the same inputs as the no-curve-change baseline, Then the engine's `distanceKm` / progress /
      elapsed / idle-vs-active decisions are **byte-for-byte unchanged** from baseline — the curve reads no
      OS signal, decides no active-vs-idle, and accrues no distance (cosmetic, single-speed, pure-view;
      mirrors journey-pov AC-10).

**Reduce-motion**
- [x] AC-10 (reduce-motion freezes the sweep): Given reduce-motion is on (so `scrollDelta == 0` and the
      scroll phase is frozen), When the scene renders, Then the bend is **frozen** (the centre-line is
      constant frame-to-frame because it is a pure function of the frozen scroll phase) — the sharper
      curve introduces **no new independent motion source** that would animate under reduce-motion
      (mirrors journey-scene-v2 AC-9 / journey-pov AC-14). Observable: with the scroll phase held fixed,
      successive `centreLineOffset` samples are identical.

**One scene / two surfaces**
- [x] AC-11 (sharper curve reads correctly on both surfaces): Given the full window and the always-on-top
      mini-window PiP render the **same** `JourneyGame` instance (ADR-0003), When the sharper curve
      renders, Then it appears on **both** surfaces and, at the sized-down PiP, the road **stays readable**
      — the road **centre-line** never leaves the viewport and the sharper bend's near-camera excursion is
      bounded — and it still reads as a sweeping bend. _Resolution to Open question "PiP read at sharp
      curvature" (**corrected in build, 2026-06-25**): the originally-proposed bound `|centreLineOffset| +
      nearHalf ≤ width/2` is **unsatisfiable even at the shipped journey-scene-v2 baseline** — the trapezoid
      road's near half-width (`_roadNearHalfFrac = 0.46`) already fills ~92% of the viewport by design, so
      the curving road EDGE extends past the viewport edge at baseline too (0.46 + 0.16 > 0.5); this is the
      intended near-camera trapezoid read, not a regression. The satisfiable, meaningful bound the build/
      tests assert instead: the road **centre-line** stays on screen across a scroll sweep at representative
      PiP + full sizes — `|centreLineOffset(size, scrollOffset, 1.0)| ≤ size.width/2` (in practice ≤
      `curveAmplitudeFrac`·width = 0.20·width, comfortable margin) — and the bend reads as non-constant. The
      real frameless-PiP visual confirmation that the road never swings off readably is the manual
      `[VISUAL]` TC-M-PIP. Reviewer may adjust the PiP test size._

### Non-functional
- [ ] NFR-1 Performance: With the sharper curve loaded, the curve integral stays **O(1)** and
      **allocation-free** on the hot path (no per-frame accumulating loop and no per-frame geometry
      allocation, however sharp the bend or however long the session has scrolled), and the scene holds
      **≥30fps** on macOS + Windows at **both** surfaces (full window and the sized-down PiP) under
      `active`. _(Automated guards: `_integratedHeading` stays a closed form — assert constant call cost
      independent of `worldDistance` magnitude — plus no per-frame allocation in the painter/pool; if AC-6
      adds arc-length-aware cadence it must also be O(1)/alloc-free. On-device ≥30fps is a manual carry
      before public release — TC-M-NF1 — consistent with journey-scene-v2 / journey-pov NFR-1.)_
- [x] NFR-2 Security/Privacy (gating): The sharper curve is **pure-view** — it adds **no** new OS signal,
      input, screen, or location read; the curve is driven solely by the existing shared scroll phase and
      `dart:math`. `/privacy-audit` stays **PASS** by construction. **Gating** — ship blocks until
      `/privacy-audit` returns PASS.
- [ ] NFR-3 Accessibility: The OS/app "reduce motion" preference is honoured (per AC-10), and the sharper
      curve does **not** obscure essential journey readouts — the road read, the vehicle/cockpit, and any
      "Paused — idle" overlay stay visible and on-screen (per AC-7's on-screen bound and AC-11's PiP read).

## Open questions
- [x] **Calm-tone ceiling — how sharp is "F1-like but smooth"?** **RESOLVED (Kevin, 2026-06-25): ~2–3×
      bracket** — AC-1 lower target ~2× baseline peak slope, AC-7 ceiling ~3×, per-frame near-camera delta
      ≤ ~2% viewport width/frame. flame-game-developer pins the exact achieved values in build within that
      bracket; final feel sign-off at review.
- [x] **Does a parameter tune alone hold AC-7, or is arc-length-aware spawn cadence required?**
      **RESOLVED (build, 2026-06-25): arc-length-aware cadence required (M-path).** At the chosen curvature
      (`maxHeading 0.0016→0.0036`, `curveAmplitudeFrac 0.16→0.20`) the fixed *longitudinal* cadence broke
      the ±20% arc-length bound at wide viewports (~22% @1280px, ~41% @1920px). The pool now spawns on equal
      **arc-length** increments (closed-form `ds = √(1 + (ampPx·slope)²)·dworld`, O(1)/alloc-free) → variance
      <0.7% at all widths 420–2560px. **ADR warranted** (the spawn-cadence model change + its AC-7/NFR-1
      implications) — to be written with `/add-adr`.
- [x] **PiP read at sharp curvature** — **RESOLVED (build, 2026-06-25):** the literal "road edge on-screen"
      bound is unsatisfiable even at baseline (trapezoid by design); AC-11 corrected to the satisfiable
      "road **centre-line** stays on screen" bound (`|centreLineOffset(…,1.0)| ≤ width/2`, in practice ≤
      0.20·width). Real-OS PiP visual = manual TC-M-PIP. — owner: flame-game-developer

## Related
- Backlog framing: [planning/backlog/journey-dynamic-curve.md](../../planning/backlog/journey-dynamic-curve.md)
- Parent epic: [planning/backlog/visual-polish.md](../../planning/backlog/visual-polish.md) (Wave 2)
- Enhances: [specs/journey-scene-v2/spec.md](../journey-scene-v2/spec.md) (AC-6 winding road, AC-7 even spacing)
- Sibling (blocked by this): [planning/backlog/journey-cockpit-lean.md](../../planning/backlog/journey-cockpit-lean.md)
- Code: `road_geometry.dart` (curve model), `road_painter.dart` (`centreLineOffset` / amplitude),
  `side_object_pool.dart` (spawn cadence / AC-7), `journey_game.dart` (`applyState`, scroll phase)
- Architecture: [docs/architecture/](../../docs/architecture/) — ADR-0002 (Flutter/Bloc/Flame stack),
  ADR-0003 (single-window two-mode / shared `JourneyGame`)
- Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md)
