# Test cases: journey-view

Spec: [specs/journey-view/spec.md](../../specs/journey-view/spec.md)
Acceptance criteria: [specs/journey-view/acceptance-criteria.md](../../specs/journey-view/acceptance-criteria.md)
Upstream (shipped): [specs/journey-engine/spec.md](../../specs/journey-engine/spec.md) — supplies `state` ∈ {active, idle, paused}, cosmetic `mode`, `distanceKm` via the journey Bloc.

## Scope of these cases

These cases verify the **Flame POV road scene as a pure VIEW** of the journey Bloc. The scene must
honestly mirror Bloc state and nothing more: scroll while `active`, stop + park + show a
"Paused — idle" overlay while `idle`/`paused`, swap the vehicle sprite on `mode`, tint cosmetically
by an injected clock, and degrade gracefully on first-frame / unknown state / missing assets. The
scene owns no activity logic, accrues no journey state, reads no OS signals, and loads only
CREDITS-recorded assets.

They deliberately do NOT re-exercise: active/idle judgment, the grace/threshold model, distance
accrual, sleep/wake, midnight rollover (all `journey-engine`, tested there); real OS idle/lock
acquisition (`activity-detection`, tested there via the mock); province/map/"% of country"
(`route-progress`); stats/streaks/badges (`local-stats`); per-mode speeds / energy
(v2 `journey-energy-model`); the live distance counter widget (resolved: a plain Flutter widget
layered over the scene, not rendered by the scene).

## Conventions used by these cases

- **No real OS, no real timers, no wall-clock waits.** The journey Bloc / engine is replaced by a
  **deterministic, scriptable state source** (a fake Bloc or mocked stream emitting
  `state`/`mode`/`distanceKm` on command). Time-of-day comes from an **injected clock**. Frame
  advancement is driven explicitly (Flame's `game.update(dt)` / widget-test `pump(duration)`), never
  by awaiting real time. This mirrors `journey-engine`'s injected-clock discipline.
- **"Within one tick / one render frame"** means: after the Bloc emits a new `state`, the scene's
  motion responds on the **next** `update(dt)` pump — assert by comparing scene scroll offset across
  one or two explicit pumps, not by measuring wall-clock latency.
- **"Stopped" assertion.** A scene is *stopped* when, across consecutive `update(dt)` pumps with no
  intervening state change, the road scroll offset, lane-marking positions, side-object positions,
  and vehicle travel offset are all unchanged (within ±epsilon for float). The vehicle's *idle/parked
  pose* may differ from its running animation but must show no forward travel.
- **"Moving" assertion.** A scene is *moving* when those same quantities advance monotonically across
  consecutive pumps while `state == active`.
- **Golden vs widget vs integration vs static-inspection.** Each case names its likely automation
  layer per `docs/architecture/overview.md`: widget/golden tests under `src/test/`, e2e under
  `src/integration_test/`, and **static inspection** (grep / source review / `/privacy-audit`) for
  the separation, asset-credit, and privacy cases. Golden tests pin *visual* states; widget tests
  pin *behaviour*; integration tests pin *Bloc↔scene wiring* and *frame timing*.
- **Determinism for goldens.** Golden tests inject a fixed time-of-day clock, a fixed `mode`, and a
  fixed (or zero) scroll phase so the rendered frame is reproducible across runs and machines.
- **Float tolerance.** Where a case compares scroll offsets / positions, "unchanged" / "equal" means
  within ±1e-6 logical px unless stated otherwise.

## Cases

### Case: Active state drives road, lanes, side objects, and vehicle animation
**ID:** TC-001
**Priority:** P0
**Type:** happy-path
**Covers:** AC-1

Given the scene is mounted on screen and the fake Bloc has emitted `state = active` (mock activity source; no real OS)
When the scene is advanced by several explicit `update(dt)` pumps
Then the road trapezoid + lane markings scroll toward the near camera, parallax side objects move from horizon toward the camera and scale up as they approach, and the vehicle plays its running/engine animation — all four motion quantities advance monotonically across the pumps

**Notes:** Widget test (`src/test/`) asserting scroll offset / lane positions / side-object positions / vehicle-animation frame advance across pumps. A companion **golden** pins the "active" frame visually. Continuous-motion-in-the-running-app is additionally confirmed by an `integration_test` smoke (TC-021).

---

### Case: Idle state stops everything, parks the vehicle, shows "Paused — idle" overlay
**ID:** TC-002
**Priority:** P0
**Type:** happy-path
**Covers:** AC-2

Given the scene is mounted and the fake Bloc emits `state = idle`
When the scene settles (post-ease) and is advanced by several `update(dt)` pumps
Then road, lane markings, and all side objects are stopped (offsets unchanged across pumps), the vehicle shows its parked pose, and a "Paused — idle" overlay is displayed over the scene

**Notes:** Widget test (`src/test/`) asserting stopped quantities + presence of the overlay text. Companion **golden** pins the "idle / parked + overlay" frame. Overlay must be real text in the semantics tree (asserted in TC-027), not baked into a sprite.

---

### Case: Paused state renders identically to idle
**ID:** TC-003
**Priority:** P0
**Type:** happy-path
**Covers:** AC-3

Given the scene is mounted
When the fake Bloc emits `state = paused` and (in a sibling run) `state = idle`, each settled and pumped the same way
Then both produce the same stopped + parked + "Paused — idle" overlay presentation — the scene draws no visual distinction between `idle` and `paused` in v1

**Notes:** Widget test comparing the two states' observable outputs (stopped quantities, overlay text), plus a **golden equality** check that the `paused` golden matches the `idle` golden byte-for-byte (or asserts the same golden file for both). Resolved: identical visual in v1, generic copy.

---

### Case: Scene never moves while last-emitted state is idle/paused (single source of truth)
**ID:** TC-004
**Priority:** P0
**Type:** edge
**Covers:** AC-4

Given the fake Bloc's last-emitted `state` is `idle` (and, in a sibling run, `paused`) and no further state is emitted
When the scene is left running across many `update(dt)` pumps (a long stopped stretch)
Then no road, lane, side-object, or vehicle-travel motion ever occurs — across all pumps every motion quantity is unchanged; the scene cannot move unless the Bloc says `active`

**Notes:** Widget test (`src/test/`) pumping a long synthetic dt sequence and asserting zero net motion (the only permitted motion is the brief settle ease of AC-6, which precedes this stretch). Guards against any internal self-driving timer/animation that ignores Bloc state.

---

### Case: Resume from stopped to active produces motion within one render tick
**ID:** TC-005
**Priority:** P0
**Type:** happy-path
**Covers:** AC-5

Given the scene is stopped because the fake Bloc's last `state` was `idle` (or `paused`)
When the Bloc emits `state = active` and the scene is advanced by a single `update(dt)` pump
Then scrolling has resumed on that next pump — the road scroll offset has advanced relative to its stopped value, with no extra frames of delay between "Bloc says active" and "road moves"

**Notes:** Widget/integration test asserting motion on the first pump after the `active` emission (snapshot offset at emit, pump once, assert offset increased). No wall-clock measurement; "within one tick" == next pump.

---

### Case: Active↔stopped transition is a short bounded ease, still reads as stopped within one tick, no jank
**ID:** TC-006
**Priority:** P0
**Type:** edge
**Covers:** AC-6

Given the scene is `active` and scrolling
When the Bloc emits `state = idle` (and, separately, `paused`), and the scene is pumped across the transition
Then any easing is a short bounded deceleration ramp (≤ ~0.5 s of injected dt) after which all motion is zero; the stopped state is visually unambiguous within one tick (the ramp never looks like sustained travel); and there is no instantaneous offset jump/jank — the offset changes continuously, not in a single large step

**Notes:** Widget test driving a known dt sequence across the toggle: assert (a) the ramp duration is bounded ≤ ~0.5 s of accumulated dt, (b) post-ramp motion is exactly zero, (c) per-frame offset deltas during the ramp are monotonically shrinking and bounded (no spike → no jank). Pairs with the no-jank-on-toggle non-functional check (TC-024). Also verify the symmetric stopped→active accelerate-from-rest ramp.

---

### Case: Scroll speed is binary (constant while active, zero while stopped) — never proportional to engine numbers
**ID:** TC-007
**Priority:** P0
**Type:** edge
**Covers:** AC-7

Given two `active` runs that differ only in `distanceKm` (e.g. 0.0 vs 9999.0) and a third where `distanceKm` changes mid-run while `state` stays `active`
When each is pumped by an identical dt sequence
Then the per-frame scroll advance is the **same constant** across all runs regardless of `distanceKm` (or elapsed time, or any engine value); and when `state` is stopped the advance is exactly zero — the scene never speeds up or slows down based on engine numbers

**Notes:** Widget test asserting equal scroll advance across differing `distanceKm` (within ±1e-6). Guards against accidentally wiring scroll speed to `distanceKm`/elapsed. Resolved: binary moving/stopped, single shared speed.

---

### Case: Vehicle sprite reflects mode; changing mode swaps the sprite; all skins same speed
**ID:** TC-008
**Priority:** P0
**Type:** happy-path
**Covers:** AC-8

Given the fake Bloc emits a specific cosmetic `mode` (walk, then bike, then car), state `active`
When the scene renders each mode and is pumped by an identical dt sequence
Then the displayed vehicle sprite is the skin for that `mode`, emitting a new `mode` swaps the sprite, and the per-frame scroll advance is identical across all three modes (cosmetic-only — only the sprite differs, never the speed)

**Notes:** Widget test asserting (a) the active vehicle sprite asset matches the `mode`, (b) re-emitting a different `mode` changes the rendered sprite, (c) scroll advance is equal across modes (±1e-6). Companion **goldens** pin one frame per skin. Guards against per-mode speed leaking in before v2.

---

### Case: Scene source reads only Bloc state/mode/distanceKm — no OS/activity APIs (separation invariant)
**ID:** TC-009
**Priority:** P0
**Type:** regression
**Covers:** AC-9

Given the journey-view source files (the Flame scene + its Flutter wrapper widget)
When inspected statically
Then the scene references **only** the journey Bloc's `state`, `mode`, and `distanceKm` and contains **none** of: `ActivityPlugin`, `getSystemIdleSeconds`, `isScreenLocked`, any platform channel / `MethodChannel`, any idle/lock/OS API, `DateTime.now()` used for an activity decision, nor any active-vs-idle or distance-accrual logic — no such imports or calls are present

**Notes:** Static-inspection case (grep / source review over the journey-view files). Allowed: `DateTime`/injected clock used purely for the cosmetic day/night tint (AC-12) — distinguish that from an activity decision. Reinforced by the `/privacy-audit` case (TC-026). Re-run on any change to the scene's files.

---

### Case: Scene mutates/computes no journey state (accrues no distance)
**ID:** TC-010
**Priority:** P0
**Type:** regression
**Covers:** AC-10

Given the running scene and its source
When inspected statically (and exercised at runtime)
Then the scene never writes or computes `distanceKm`, `activeTimeToday`, `rawActiveTime`, `idleTimeToday`, or `state` — it only reads them; no write to journey state originates in journey-view, and pumping the scene through any state sequence leaves the Bloc's exposed values untouched

**Notes:** Primarily static-inspection (no assignments / mutating calls to journey state in the scene's files). Optional runtime guard: a widget test using a fake Bloc that records any write attempt and asserts none occurred while the scene runs. Pairs with TC-009.

---

### Case: Every loaded asset has a licence + attribution entry in assets/CREDITS.md
**ID:** TC-011
**Priority:** P0
**Type:** regression
**Covers:** AC-11

Given every visual asset the scene declares/loads (road, lane markings, side objects, vehicle skins, background / day-night layers, fonts)
When the set of loaded asset paths is cross-checked against `assets/CREDITS.md`
Then each loaded asset has a matching CREDITS entry with a licence + attribution, the scene loads **no** asset absent from `assets/CREDITS.md`, and no hand-authored / original art is present

**Notes:** Static-inspection case: enumerate the assets referenced by the scene (and/or the `pubspec.yaml` `assets:` block the scene uses) and assert each appears in `assets/CREDITS.md`. Can be partially automated as a `src/test/` test that parses CREDITS and the asset manifest and fails on any uncredited path. Reviewed alongside `/source-assets` output. Re-run whenever an asset is added.

---

### Case: Day/night tint derives from injected clock and is purely cosmetic (never gates motion)
**ID:** TC-012
**Priority:** P1
**Type:** edge
**Covers:** AC-12

Given an injected/clock-based time-of-day set to a "day" value and (in a sibling run) a "night" value, with `state = active` in both
When the scene renders and is pumped by an identical dt sequence under each clock
Then a cosmetic day/night tint layer is applied and differs between the two clocks, while the motion is **identical** across both — the tint never gates, starts, or stops scrolling (motion is governed only by `state`)

**Notes:** Widget test asserting (a) tint differs by injected time-of-day, (b) scroll advance is equal across day vs night (±1e-6). Companion **goldens** pin a day frame and a night frame. Also assert tint does not appear/disappear with `state` changes (it is ambient, not state-bound). Resolved: injected clock, deterministic.

---

### Case: First-frame / pre-state and unrecognised/loading/error state default to parked + stopped
**ID:** TC-013
**Priority:** P0
**Type:** edge
**Covers:** AC-13

Given the scene is mounted but the Bloc has **not yet** emitted a real `state` (and, in sibling runs, emits an unrecognised / loading / error state)
When the scene renders and is pumped across several `update(dt)` frames
Then in every case it shows the parked/stopped look with no motion — it never auto-scrolls before a real `active` state arrives

**Notes:** Widget test covering (a) initial state before any emission, (b) an unknown/loading/error state value. Assert zero motion across pumps and parked pose. Companion **golden** may reuse the idle/parked golden. Guards against a default "always scrolling" scene.

---

### Case: Missing or failed asset at runtime degrades gracefully (placeholder/parked, no crash)
**ID:** TC-014
**Priority:** P0
**Type:** negative
**Covers:** AC-14

Given a curated asset is made to fail to load at runtime (asset bundle returns an error / missing file for, e.g., a side-object or the vehicle skin)
When the scene renders and is pumped
Then it shows a neutral placeholder (or the parked vehicle) for the missing asset and keeps running — the scene does not throw, crash, or blank the screen, and other elements continue to render

**Notes:** Widget test injecting a faulting asset loader / mock bundle for selected asset(s). Assert no exception escapes the scene and the rest of the frame still renders. Cover both a side-object asset failure and the vehicle-skin failure. Resolved: degrade gracefully, never crash.

---

### Case: Sustained frame rate while active (~60 fps target, ≥30 fps floor, no sustained jank)
**ID:** TC-015
**Priority:** P1
**Type:** edge
**Covers:** NF — Performance: frame rate

Given the scene is `active` and rendering road + lanes + a full set of parallax side objects on a typical desktop
When the scene runs over a sustained active window under representative load
Then it holds ~60 fps in the steady state with a worst-case floor of ≥30 fps, and shows no sustained jank (no repeated long frames)

**Notes:** `integration_test` / on-device performance run (macOS + Windows) using Flutter's frame-timing / `traceAction` instrumentation; not a plain deterministic unit test. Capture frame build/raster times and assert the floor. Manual spot-check acceptable where automated frame-timing is impractical; record device + OS in the report.

---

### Case: No jank or dropped-frame spike on an active↔idle/paused toggle
**ID:** TC-016
**Priority:** P1
**Type:** edge
**Covers:** NF — Performance: no jank on toggle; AC-6

Given the scene is rendering and instrumented for frame timing
When the Bloc toggles `active ↔ idle` (and `active ↔ paused`) repeatedly
Then no transition introduces a visible stutter or dropped-frame spike — frame times across each toggle stay within the normal band (no long-frame outlier at the transition)

**Notes:** `integration_test` / on-device frame-timing run; complements the unit-level ease check (TC-006). Assert no frame-time spike coincides with the state change. Supports the AC-6 "no jank" clause.

---

### Case: Side objects are recycled from a bounded pool with no per-frame heap allocations
**ID:** TC-017
**Priority:** P1
**Type:** edge
**Covers:** NF — Performance: bounded object pool

Given the scene is `active` and side objects continuously stream past for a long session
When the scene runs over many frames (and source is inspected for the hot update/render path)
Then the live side-object count stays bounded (off-screen objects are reused, not endlessly spawned) and there are **no** per-frame heap allocations in the hot path

**Notes:** Mixed: (a) widget/integration test pumping a long dt sequence and asserting the object count plateaus (does not grow unbounded); (b) static inspection of the `update`/`render` path for per-frame `new`/list allocations; optionally an allocation-profiling pass on-device. Recycle-not-spawn is the core assertion.

---

### Case: Animation and update loop are suspended (not just hidden) when the scene is not visible
**ID:** TC-018
**Priority:** P1
**Type:** edge
**Covers:** NF — Performance: suspended when not visible

Given the scene is running while it is the foreground/visible view
When the scene becomes not the visible/foreground view (navigated away / backgrounded)
Then its update loop is **paused** — it consumes no per-frame work and its motion quantities do not advance while hidden; and when it becomes visible again it resumes from the correct state

**Notes:** Widget/integration test toggling visibility (e.g. route off the screen, or a `pauseEngine`/lifecycle hook) and asserting (a) `update(dt)` no longer advances motion while hidden, (b) on return the scene resumes per current Bloc `state`. Guards against a scene that keeps ticking off-screen.

---

### Case: Reduce-motion preference is honoured and still conveys active vs stopped
**ID:** TC-019
**Priority:** P1
**Type:** edge
**Covers:** NF — Accessibility: reduced motion

Given the OS/app "reduce motion" preference is ON (injected via the platform/accessibility flag)
When the Bloc emits `state = active` and then `state = idle`/`paused`
Then the scene reduces or replaces the scrolling motion with a static/minimal-motion presentation (no full scroll) while **still** clearly conveying active vs stopped — a motion-sensitive user can still tell whether the journey is travelling or parked

**Notes:** Widget test with `MediaQuery.disableAnimations` / reduce-motion flag set true. Assert (a) full scrolling is suppressed when active, (b) the active vs stopped distinction is still observable (e.g. a non-scrolling indicator differs between states) and the "Paused — idle" overlay still shows when stopped. Companion **golden** for the reduced-motion active + stopped frames. Resolved: honour the preference, still convey state.

---

### Case: "Paused — idle" overlay is legible and exposed to the accessibility/semantics tree as text
**ID:** TC-020
**Priority:** P1
**Type:** edge
**Covers:** NF — Accessibility: message readability

Given the scene is in a stopped state (`idle`/`paused`) showing the overlay
When the rendered overlay is inspected for contrast/size and the semantics tree is queried
Then the overlay text is legible against the scene (sufficient contrast, readable size) and is present in the accessibility tree / discoverable by a screen reader as the text "Paused — idle" — it is **not** baked into a sprite/bitmap

**Notes:** Widget test querying the semantics tree for the overlay string (e.g. `find.bySemanticsLabel` / `find.text`), asserting it exists as text. Contrast/size confirmed via a golden + a manual legibility spot-check. Guards against rendering the message as part of an image.

---

### Case: End-to-end smoke — mock-driven active→idle→active visibly stops and resumes in the running app
**ID:** TC-021
**Priority:** P1
**Type:** regression
**Covers:** AC-1, AC-2, AC-5, AC-6

Given the app launched with `--mock-activity` so the journey Bloc is driven by deterministic mock state (no real OS), with the scene on the main journey screen
When the mock drives `active`, then `idle`, then back to `active`
Then the scene visibly scrolls while `active`, visibly stops + parks + shows "Paused — idle" on `idle` within one tick, and visibly resumes scrolling on the return to `active` within one tick — confirming the full Bloc↔scene wiring end to end

**Notes:** `integration_test` (`src/integration_test/`) on the real widget tree with the mock activity source. This is the spec's headline "observable success" check. Drives state via the mock, not real OS signals; advances frames via the harness, not wall-clock sleeps where avoidable.

---

### Case: Golden — active scene frame is visually stable
**ID:** TC-022
**Priority:** P1
**Type:** regression
**Covers:** AC-1

Given a fixed `mode`, a fixed injected day-time clock, and a fixed scroll phase, with `state = active`
When the scene renders one frame
Then it matches the committed "active" golden image

**Notes:** Golden test (`src/test/`). Determinism per the conventions (fixed clock/mode/phase). Regression guard that visual structure (road trapezoid, lanes, side objects, running vehicle) does not silently change.

---

### Case: Golden — stopped (idle/paused) scene frame with overlay is visually stable
**ID:** TC-023
**Priority:** P1
**Type:** regression
**Covers:** AC-2, AC-3

Given a fixed `mode`, a fixed injected day-time clock, with `state = idle` (and the same golden reused for `paused`)
When the scene renders one settled frame
Then it matches the committed "stopped + parked + 'Paused — idle' overlay" golden image, and the `paused` render matches the same golden (AC-3 identity)

**Notes:** Golden test (`src/test/`). Pins the parked/overlay presentation and the idle≡paused equivalence visually. Pairs with TC-002/TC-003.

---

### Case: No-jank ease curve produces continuous, bounded per-frame deltas on toggle
**ID:** TC-024
**Priority:** P1
**Type:** edge
**Covers:** AC-6, NF — Performance: no jank on toggle

Given the scene is `active` and scrolling at the constant speed
When the Bloc emits `idle` and the ease runs across a known dt sequence
Then the per-frame scroll-offset delta decreases smoothly to zero with no single-frame jump larger than the steady-state per-frame advance — the deceleration is continuous (no discontinuity), confirming the unit-level "no jank" property complementary to the on-device TC-016

**Notes:** Deterministic widget test (`src/test/`) — pure math on the ease curve via pumps, no device needed. Asserts max per-frame delta ≤ steady-state delta and monotonic decrease to zero. Unit-level counterpart to the on-device frame-timing check (TC-016).

---

### Case: Day and night golden frames differ only in tint, not in geometry/motion
**ID:** TC-025
**Priority:** P2
**Type:** regression
**Covers:** AC-12

Given two fixed renders identical except the injected clock (day vs night), `state = active`, same scroll phase
When each renders one frame
Then each matches its committed golden (day, night), and the two differ only in the tint layer — road/lane/side-object/vehicle geometry is identical between them

**Notes:** Golden tests (`src/test/`). Reinforces AC-12 "cosmetic, never gates motion" at the pixel level. Pairs with the behavioural TC-012.

---

### Case: Privacy audit — journey-view adds no new OS surface
**ID:** TC-026
**Priority:** P0
**Type:** regression
**Covers:** NF — Privacy / Separation; AC-9, AC-10

Given all journey-view source (the Flame scene, its Flutter wrapper, and any helpers it introduces) and the dependencies it adds
When `privacy-guardian` runs `/privacy-audit`
Then it confirms the scene introduces **no** dependency or call that reads input / screen / clipboard / files / network, and that the scene is a pure consumer of Bloc `state`/`mode`/`distanceKm` — and the audit **passes**

**Notes:** Manual audit case, NOT an automated assertion (mirrors `activity-detection` TC-018/TC-019). A fail here blocks ship regardless of other passes. Re-run on any change to the scene's source or its dependency set. Reinforces the static-inspection cases TC-009/TC-010.

---

### Case: Semantics convey active vs stopped state to assistive tech beyond the overlay text
**ID:** TC-027
**Priority:** P2
**Type:** edge
**Covers:** NF — Accessibility: message readability; AC-2

Given the scene transitions between `active` and stopped (`idle`/`paused`)
When the semantics tree is inspected in each state
Then the stopped state exposes the "Paused — idle" text node (per TC-020) and the active/stopped distinction is discoverable via semantics (not conveyed by motion alone), so an assistive-tech user can determine the journey state without seeing the animation

**Notes:** Widget test querying semantics in both states. Complements TC-019 (reduce-motion) and TC-020 (overlay text). Lower priority refinement of the readability AC; flag to `product-domain-expert` only if a specific semantic label for the active state is required beyond the overlay.

---

## Coverage table (AC / non-functional item → covering case IDs)

| Item | Description | Covered by |
|---|---|---|
| AC-1 | active → road/lanes/side-objects scroll + vehicle animates | TC-001, TC-021, TC-022 |
| AC-2 | idle → stop + park + "Paused — idle" overlay | TC-002, TC-021, TC-023, TC-027 |
| AC-3 | paused → identical to idle | TC-003, TC-023 |
| AC-4 | never moves while last state is idle/paused (single source of truth) | TC-004 |
| AC-5 | resume active → motion within one tick | TC-005, TC-021 |
| AC-6 | transition is short ≤0.5 s ease, stopped-within-one-tick, no jank | TC-006, TC-016, TC-021, TC-024 |
| AC-7 | binary scroll speed — never proportional to distanceKm/elapsed | TC-007 |
| AC-8 | vehicle sprite reflects mode; mode swaps sprite; all skins same speed | TC-008 |
| AC-9 | scene reads only Bloc state/mode/distanceKm — no OS/activity APIs | TC-009, TC-026 |
| AC-10 | scene accrues/mutates no journey state | TC-010, TC-026 |
| AC-11 | every loaded asset is CREDITS-recorded; no uncredited/hand-authored art | TC-011 |
| AC-12 | day/night cosmetic injected-clock tint, never gates motion | TC-012, TC-025 |
| AC-13 | first-frame/pre-state + unrecognised/loading/error → parked/stopped | TC-013 |
| AC-14 | missing/failed asset at runtime → placeholder/parked, no crash | TC-014 |
| NF — Performance: frame rate (~60 fps, ≥30 fps floor) | sustained fps while active | TC-015 |
| NF — Performance: no jank on toggle | no stutter/dropped-frame spike at transition | TC-016, TC-024 |
| NF — Performance: bounded object pool | recycled pool, no per-frame allocations | TC-017 |
| NF — Performance: suspended when not visible | update loop paused off-screen | TC-018 |
| NF — Privacy / Separation | no new OS surface; passes /privacy-audit | TC-026 (reinforced by TC-009, TC-010) |
| NF — Accessibility: reduced motion | honoured + still conveys state | TC-019 |
| NF — Accessibility: message readability | overlay legible + in semantics tree, not in a sprite | TC-020, TC-027 |

Every AC (AC-1..AC-14) and every non-functional item maps to at least one case. No AC is orphaned.
