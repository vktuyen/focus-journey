# Test cases: journey-scene-v2

Spec: [specs/journey-scene-v2/spec.md](../../specs/journey-scene-v2/spec.md) — **approved (2026-06-24)**
Upstream (shipped, reworked here): [specs/journey-view/spec.md](../../specs/journey-view/spec.md) — the Flame scene; the pure-view invariant, reduced-motion handling, and idle/paused parks are inherited and regression-guarded here. Existing cases: [tests/cases/journey-view.md](journey-view.md).
Related (shipped): [specs/mini-window/spec.md](../../specs/mini-window/spec.md) — the PiP reuses the **same** `JourneyGame` instance (ADR-0003); this slice **relaxes** mini-window NFR-1 (pause-when-not-visible, animate-when-visible-but-unfocused). Existing cases: [tests/cases/mini-window.md](mini-window.md).
Decisions driving these cases: spec `## Decisions` — (a) #5 animate-when-visible / pause-when-hidden, per-OS occlusion signal; (c) ~0.33× scroll with reduce-motion OVERRIDING the rate; (d) segmented heading-offset winding road.
Manual companion: [journey-scene-v2-manual-checklist.md](journey-scene-v2-manual-checklist.md) — the real-OS occlusion, fps, "looks even/curved", and privacy-audit legs that are not cheaply automatable.

## Coverage note (which layers cover which ACs; risky / under-covered areas)

- **Deterministic unit / widget tests (`src/focus_journey/test/`)** cover the bulk: the scroll-rate
  decoupling math (AC-1), the one-way dependency-direction inspection (AC-2), the per-surface
  animate/pause logic against an **injected visibility signal** (AC-3/AC-4/AC-5 — *logic only*, not real
  OS occlusion), the winding-road geometry being non-straight and curve-following (AC-6), the
  even-spacing variance bound measured along the segmented curve (AC-7), the asset⇄CREDITS manifest
  cross-check (AC-8), reduce-motion overriding the slower scroll (AC-9), and idle/paused parks (AC-10).
  Companion **golden** tests pin the winding road, the richer-scenery active frame, the reduced-motion
  frame, and the parked frame.
- **Integration tests (`src/focus_journey/integration_test/`)** cover the shared-game per-surface wiring
  (AC-5 against the mock window/visibility path) and a headline mock-driven smoke (AC-1/AC-3/AC-4 across
  both surfaces).
- **Static inspection** (grep / source review) covers the AC-2 dependency direction (engine has no
  reference to scroll state), the AC-8 "no asset loaded that is absent from CREDITS", and reinforces the
  NFR-2 privacy separation.
- **Manual / on-device checklist** covers what is **NOT cheaply automatable** and is flagged `[REAL-OS]`
  / `[DEVICE]` / `[AUDIT]` here: true per-OS window **occlusion** (macOS `NSWindow.occlusionState`,
  Windows visibility/minimize) animating-when-unfocused / pausing-when-hidden on a real window
  (AC-3/AC-4/AC-5 real leg), **≥30fps on both surfaces** under the full scene (NFR-1), the human "reads as
  a real winding road / evenly spaced / cohesive, content-appropriate scenery" judgement (AC-6/AC-7/AC-8
  qualitative leg), and the `/privacy-audit` release gate (NFR-2).

**Risky / under-covered areas (flagged):**

- **AC-3/AC-4/AC-5 visibility — automation proves only the *logic*, not the *OS signal*.** Headless tests
  drive an **injected** visibility flag per surface and assert animate/pause; they cannot prove that the
  macOS/Windows occlusion API actually fires for a real frameless always-on-top PiP behind another app.
  That truth lives in the manual `[REAL-OS]` legs (TC-M1/TC-M2/TC-M3) and is the spike obligation of
  spec Decision (b). If the per-OS spike finds **no reliable signal**, the agreed fallback is
  pause-when-hidden only on that OS (flag it) — TC-M5 records that fallback verdict.
- **The "v1 baseline" for AC-1 is a pinned constant, not a live v1 build.** The ~0.33× assertion compares
  the new rendered rate against a **recorded v1 scroll-rate baseline** (captured value, see Conventions).
  If v1's constant is refactored, the baseline must be re-pinned or this case silently drifts. The
  byte-for-byte engine-counter half does compare against the *actual* engine output for the same elapsed
  time.
- **AC-7 even spacing — the perceptual bound is a proxy.** The automated variance bound (≤ ±20% of the
  mean gap, measured along the curve arc-length) is a numeric stand-in for "looks evenly spaced"; the
  human read is the manual leg. Clumping that is numerically within bound but reads badly is only caught
  manually.
- **AC-6 winding read & AC-8 content-appropriateness are review/judgement gates**, not pass/fail asserts.
  Automation proves "the road centre-offset is non-constant and objects follow it" and "every asset is in
  CREDITS"; "reads as a calm real trip" and "respectful, on-brand depiction of Vietnam, no
  realistic/identifiable people" are the content-appropriateness **review gate** (TC-M4) the spec calls
  for.
- **NFR-1 (≥30fps both surfaces)** is on-device only — no deterministic unit proxy beyond the v1
  bounded-pool / no-per-frame-allocation guards (regression-inherited as TC-018).

## Conventions used by these cases

- **No real OS, no real timers, no wall-clock waits.** As in `journey-view` / `mini-window`, the journey
  Bloc is a **deterministic, scriptable state source** (fake Bloc / mocked stream emitting
  `state`/`mode`/`distanceKm`); frame advancement is driven explicitly (`game.update(dt)` /
  `pump(duration)`), never by awaiting real time. The **per-surface visibility signal** is likewise
  **injected** (an interface backed by `NSWindow.occlusionState` / Windows visibility in production, by a
  scriptable fake in tests) so "visible-but-unfocused" vs "hidden/minimized/tray" is set deterministically
  without a real window.
- **"v1 scroll-rate baseline."** AC-1's "~0.33× of v1" compares the new rendered scroll-offset delta per
  injected second against a **pinned v1 baseline constant** recorded in the test (the v1 constant scroll
  speed from `journey-view`). The factor target is **0.33×** with tolerance **±10% of the target factor**
  (i.e. accept 0.30×..0.36×) unless re-agreed; reduce-motion runs assert **no** rate (AC-9 supersedes).
- **"Engine counters byte-for-byte unchanged."** For a fixed injected elapsed time and identical mock
  activity input, the engine's exposed `distanceKm` / progress / elapsed values are **identical** whether
  the scene renders at the v1 rate or the v2 rate — the scroll rate change must not perturb any engine
  number (compared with **exact equality**, not ±epsilon, since these are engine truth, not rendered
  floats).
- **"Animating" / "paused" (per-surface).** A surface is *animating* when its scroll offset advances
  monotonically across consecutive `update(dt)` pumps while `state == active`; a surface is *paused* when,
  across consecutive pumps, its scroll offset is frozen (±1e-6) **and** no per-frame update work runs for
  that surface (e.g. a no-tick spy / `paused`-flag, mirroring `mini-window` TC-020). "Per-surface" means
  the same shared `JourneyGame` advances the visible surface's render while not advancing the hidden one.
- **"Along the curving road" (AC-7 spacing).** Object spacing is measured as **arc-length distance along
  the segmented road centre-line** between consecutive scenery objects, not screen-space pixel distance —
  so the curve (#1) and spacing (#12) are checked together.
- **Float tolerance.** Rendered scroll offsets / positions compare within **±1e-6** logical px unless
  stated; the AC-1 rate factor uses the ±10%-of-target band above; engine counters use **exact** equality.
- **Test layer per `docs/architecture/overview.md`.** Executable tests live under `src/focus_journey/`:
  scroll-rate / geometry / spacing / reduce-motion / parks behaviour + goldens → **widget/golden**
  (`test/`); per-surface visibility wiring + headline smoke → **integration** (`integration_test/`); the
  dependency-direction, asset-credit, and privacy cases → **static inspection** + the manual
  `/privacy-audit`. `tests/cases/` (this file) holds human-readable scenarios only.

## Cases

### Case: Rendered scroll rate is ~0.33× of the v1 baseline while active
**ID:** TC-001
**Priority:** P0
**Type:** happy-path
**Covers:** AC-1

Given the scene is mounted and visible, the fake Bloc has emitted `state = active`, and reduce-motion is OFF
When the scene is advanced by a fixed injected-time sequence (a known total injected elapsed) and the rendered scroll-offset delta is divided by that elapsed
Then the rendered scroll-offset delta per injected second is **~0.33×** of the pinned v1 baseline rate — within the agreed band (target 0.33×, tolerance ±10% of target ⇒ 0.30×..0.36×) — i.e. the visual scroll is ~3× slower than v1

**Notes:** Widget test (`src/focus_journey/test/`) measuring scroll delta over a known injected dt total and asserting the factor band against the recorded v1 baseline constant. Pure deterministic playback math; no device. Pairs with TC-002 (engine counters unchanged for the same elapsed). The tolerance band is the agreed value per spec Decision (c); re-pin the baseline if v1's constant is refactored.

---

### Case: Engine distanceKm / progress / elapsed are byte-for-byte unchanged from v1 for the same elapsed time
**ID:** TC-002
**Priority:** P0
**Type:** edge
**Covers:** AC-1, AC-2

Given identical mock activity input and a fixed injected elapsed time, run once with the scene rendering at the v1 rate and once at the new v2 ~0.33× rate
When the engine's exposed `distanceKm` / progress / elapsed counters are read at the same elapsed points in both runs
Then the engine counters are **exactly identical** between the two runs — changing the rendered scroll rate perturbs **no** engine number (the slower scroll is a one-way render concern only)

**Notes:** Widget/integration test asserting **exact equality** (not ±epsilon) of engine `distanceKm`/progress/elapsed across the v1-rate vs v2-rate runs for the same injected elapsed. This is the "byte-for-byte unchanged" half of AC-1 and the runtime side of AC-2. Drives state via the mock; advances frames via the harness.

---

### Case: No code path reads the rendered scroll offset/rate as an input to engine progress (dependency direction)
**ID:** TC-003
**Priority:** P0
**Type:** regression
**Covers:** AC-2

Given the engine / journey-Bloc source and the scene/scroll-rate source
When inspected statically (dependency direction)
Then the engine and its distance/progress/elapsed computation hold **no** reference to the scene's scroll offset / scroll rate / playback rate — no engine code path reads a rendered-scroll value as an input; the dependency is one-way (scene → reads engine; engine ⇏ scene), and the scroll-rate constant lives in the presentation layer only

**Notes:** Static-inspection case (grep / source review / dependency-direction): assert the engine module imports/references nothing from the scene's scroll state and that `distanceKm`/progress/elapsed are computed without any scroll-offset/rate term. Reinforces `journey-view`'s separation invariant (TC-009/TC-010 there) for the new playback-rate concern. Re-run on any change to either module. Runtime backstop is TC-002.

---

### Case: Visible-but-unfocused surface keeps animating while active
**ID:** TC-004
**Priority:** P0
**Type:** happy-path
**Covers:** AC-3

Given a surface (full or PiP) whose injected visibility signal is "visible" while another application is modelled as holding keyboard focus (focus ≠ visibility), and the fake Bloc emits `state = active`
When the scene is advanced by several `update(dt)` pumps
Then the surface **keeps animating** — its scroll offset advances monotonically frame-over-frame — because the animation trigger is **occlusion/visibility, not focus**

**Notes:** Widget/integration test driving the injected per-surface visibility = visible + a modelled "not focused" condition; assert scroll advances across pumps. This is the *logic* leg; the real-OS "PiP actually scrolls while you type in another app" leg is the manual `[REAL-OS]` TC-M2. Run for both the full surface and the PiP surface.

---

### Case: Hidden / minimized / hidden-to-tray surface pauses (offset frozen, no per-frame work)
**ID:** TC-005
**Priority:** P0
**Type:** happy-path
**Covers:** AC-4

Given a surface whose injected visibility signal is "not visible" (hidden / minimized / hidden-to-tray) while the fake Bloc emits `state = active`
When the scene is advanced by several `update(dt)` pumps
Then the surface **pauses** — its scroll offset is frozen (unchanged ±1e-6 across pumps) and **no per-frame animation work runs** for that surface (no-tick spy / paused flag) — preserving the mini-window battery guarantee (pause-when-hidden still holds even though pause-when-merely-unfocused is now relaxed)

**Notes:** Widget/integration test driving injected visibility = not-visible while `active`; assert frozen offset **and** suspended per-frame work (mirrors `mini-window` TC-020's no-tick assertion). Cover all three not-visible variants (hidden / minimized / tray). Guards against the #5 relaxation silently reverting the battery promise. Real-OS leg: TC-M3.

---

### Case: Per-surface evaluation — one surface visible, the other hidden, on the shared JourneyGame
**ID:** TC-006
**Priority:** P0
**Type:** edge
**Covers:** AC-5

Given the full and PiP surfaces share **one** `JourneyGame` instance (ADR-0003), `state = active`, with one surface's injected visibility = visible and the other's = not-visible (and, in a sibling run, the reverse)
When the scene is advanced by several `update(dt)` pumps
Then visibility is evaluated **per-surface**: the visible surface animates (scroll advances) while the hidden surface does **not** (offset frozen, no per-frame work) — the single shared game does not force both surfaces on or both off

**Notes:** Integration test (`src/focus_journey/integration_test/`) against the shared-game wiring + the injected per-surface visibility path; assert the visible surface's render advances while the hidden one's does not, then swap which is visible. Pairs with `mini-window` TC-009 (single shared instance). The real-OS "PiP visible while main minimized, and vice versa" leg is TC-M3.

---

### Case: The road visibly curves (left/right over distance) and lanes/objects follow the curve
**ID:** TC-007
**Priority:** P0
**Type:** happy-path
**Covers:** AC-6

Given the scene is mounted, visible, `state = active`, reduce-motion OFF, the richer scenery loaded
When the road is rendered across a scroll cycle and its centre-line offset is sampled along the trapezoid (near → horizon)
Then the road **curves**: the centre-line horizontal offset is **non-constant** over distance (not a dead-straight vertical), it bends both left and right across a cycle, **lane markings and roadside objects track the same curve** (their cross-road offsets follow the centre-line), and the near→horizon trapezoid (perspective narrowing) is **preserved**

**Notes:** Widget test sampling the computed road centre-line offset at several depth steps and asserting (a) variance/non-constancy (rejects dead-straight), (b) lane-marking + object lateral offsets equal centre-line + their lane offset (they follow the curve), (c) trapezoid width still narrows toward the horizon. Companion **golden** pins the winding active frame. The qualitative "reads as a real winding road" judgement is the manual TC-M4. Geometry per spec Decision (d): segmented heading-offset.

---

### Case: Consecutive scenery objects are evenly spaced along the curving road (variance bound)
**ID:** TC-008
**Priority:** P0
**Type:** edge
**Covers:** AC-7, AC-6

Given a full scroll cycle with the richer scenery loaded, `state = active`, on the curving road
When the arc-length gaps (measured **along the segmented road centre-line**, not screen-space) between consecutive scenery objects are collected over the cycle
Then the gap stays within the agreed perceptual bound — **spacing variance ≤ ±20% of the mean gap** — with **no** gap collapsing toward zero (clumping) and **no** stretch far exceeding the mean (empty stretch); spacing is computed along the curve so #1 and #12 interact correctly

**Notes:** Widget test computing inter-object arc-length gaps along the road centre-line over a cycle and asserting `max |gap − mean| ≤ 0.20 × mean` (the agreed bound). Must measure along the curve (per Conventions), not screen-space, so a curve does not look like clumping. The human "looks evenly spaced" read is the manual TC-M4. Pairs with TC-007 (curve) and TC-009 (asset set present).

---

### Case: Richer scenery set is present and every loaded asset is CREDITS-recorded (CC0/permissive)
**ID:** TC-009
**Priority:** P0
**Type:** regression
**Covers:** AC-8

Given the scene renders with the expanded scenery set, and `assets/CREDITS.md`
When the set of asset paths the scene declares/loads is enumerated and cross-checked against `assets/CREDITS.md`
Then the scene includes the expanded cohesive set (mountains / beach / city / forest / people / characters / animals — beyond the v1 four kinds), **every** loaded asset has a matching CREDITS entry with a **CC0/permissive** licence + attribution, and the scene loads **no** asset that is **absent** from CREDITS

**Notes:** Static-inspection case (enumerate scene/`pubspec.yaml` asset paths, parse `assets/CREDITS.md`, assert each loaded path has a CC0/permissive entry and no uncredited path is loaded) — partly automatable as a `src/focus_journey/test/` manifest test that fails on any uncredited asset (mirrors `journey-view` TC-011). The "cohesive single-pack, no realistic/identifiable people, respectful depiction of Vietnam" content-appropriateness judgement is the **review gate** TC-M4. Re-run whenever an asset is added.

---

### Case: Reduce-motion preference OVERRIDES the slower scroll — static/minimal presentation still conveys active vs stopped
**ID:** TC-010
**Priority:** P0
**Type:** edge
**Covers:** AC-9, NFR-3

Given the OS/app "reduce motion" preference is ON (injected via the platform/accessibility flag), the surface is visible
When the fake Bloc emits `state = active` and then `state = idle`/`paused`
Then the scene renders a **static / minimal-motion** presentation (no full scroll — the ~0.33× rate assertion does **not** apply, AC-9 supersedes Decision (c)) while **still** clearly conveying active vs stopped, **and** the keep-animating-when-visible rule (#5) does **not** re-introduce scrolling — reduce-motion wins over both the slower scroll (#3) and the visibility rule (#5)

**Notes:** Widget test with `MediaQuery.disableAnimations` / reduce-motion true. Assert (a) full scrolling is suppressed when active+visible (no rate assertion runs), (b) active-vs-stopped is still observable (e.g. a non-scrolling indicator differs), (c) the "Paused — idle" overlay still shows when stopped. Companion **golden** for the reduced-motion active + stopped frames. Inherits + extends `journey-view` TC-019; the new clause is that reduce-motion overrides BOTH #3 and #5.

---

### Case: Idle / paused still parks (road + objects stop, vehicle parks, "Paused — idle" overlay) — regression
**ID:** TC-011
**Priority:** P0
**Type:** regression
**Covers:** AC-10

Given the surface is visible and the fake Bloc emits `state = idle` (and, in a sibling run, `state = paused`)
When the scene settles and is advanced by several `update(dt)` pumps
Then the road, lane markings, and all (richer) scenery objects **stop** (offsets unchanged across pumps), the vehicle shows its parked pose, and the "Paused — idle" overlay is shown — **unchanged from v1**, independent of the slower scroll (#3) and the visibility rule (#5): a visible-but-unfocused idle surface does **not** scroll

**Notes:** Widget test asserting stopped quantities + the overlay for both `idle` and `paused`, including the cross-check that #5 (animate-when-visible) applies only to `active` — a *visible* surface that is `idle` stays parked. Companion **golden** reuses the parked frame. Regression guard inherited from `journey-view` TC-002/TC-003/TC-004; extends them with the richer scenery + the visibility-rule independence.

---

### Case: Golden — winding road + richer scenery active frame is visually stable
**ID:** TC-012
**Priority:** P1
**Type:** regression
**Covers:** AC-6, AC-7, AC-8

Given a fixed `mode`, a fixed injected day-time clock, a fixed scroll phase, `state = active`, visible, reduce-motion OFF, the richer scenery loaded
When the scene renders one frame
Then it matches the committed "v2 winding road + richer evenly-spaced scenery" golden image

**Notes:** Golden test (`src/focus_journey/test/`). Determinism via fixed clock/mode/phase (as `journey-view` TC-022). Regression guard that the winding geometry, lane-following, and scenery layout do not silently change. Does **not** prove "looks even/curved/cohesive" as a qualitative judgement — that is TC-M4.

---

### Case: End-to-end smoke — mock-driven scene on both surfaces scrolls slower, keeps animating unfocused, pauses when hidden
**ID:** TC-013
**Priority:** P1
**Type:** regression
**Covers:** AC-1, AC-3, AC-4, AC-5, AC-10

Given the app launched with the mock activity + mock window/visibility path, the shared `JourneyGame` rendering on a surface
When the mock drives `active` (scene scrolls at the slower rate), the surface is modelled visible-but-unfocused (keeps scrolling), then not-visible (pauses), then `idle` (parks), then `active`+visible again (resumes at the slower rate)
Then across the flow the rendered scroll is visibly slower than v1, the surface keeps animating while visible-but-unfocused, pauses (frozen, no per-frame work) when not-visible, parks on `idle`, and resumes on return — confirming the full Bloc↔visibility↔scene wiring on the shared game

**Notes:** `integration_test` (`src/focus_journey/integration_test/`) on the real widget tree with the **mock** activity + window/visibility path (deterministic, no real OS occlusion). The mock-path twin of the manual `[REAL-OS]` triad. Frames via the harness, state + visibility via the mock. Per-surface independence detail is TC-006.

---

## Manual / on-device legs (see the companion checklist)

These verify what is **NOT cheaply automatable**. They live in
[journey-scene-v2-manual-checklist.md](journey-scene-v2-manual-checklist.md) and are flagged here.

- **TC-M1** `[REAL-OS]` — real per-OS occlusion signal exists & fires (macOS `NSWindow.occlusionState`,
  Windows visibility/minimize) for a frameless always-on-top PiP — the spike of spec Decision (b).
  Automated logic leg: TC-004/TC-005/TC-006 (injected visibility).
- **TC-M2** `[REAL-OS]` — a **visible-but-unfocused** real surface **keeps scrolling** while another app
  holds focus (AC-3 real leg). Automated logic leg: TC-004.
- **TC-M3** `[REAL-OS]` — a **hidden/minimized/tray** real surface **pauses** (AC-4) and per-surface
  independence holds with a real PiP + main (AC-5 real leg). Automated logic leg: TC-005/TC-006.
- **TC-M4** `[REVIEW]` — content-appropriateness + qualitative read: the scene **reads as a calm real
  winding trip across Vietnam**, scenery **looks evenly spaced and cohesive**, and depictions are
  respectful / on-brand with **no realistic/identifiable people** (AC-6/AC-7/AC-8 judgement gate).
- **TC-M-NF1** `[DEVICE]` — sustained **≥30fps on both surfaces** (full window + sized-down PiP) under the
  full winding road + richer scenery while `active` (NFR-1).
- **TC-M-PRIV** `[AUDIT]` — `/privacy-audit` PASS: the rework adds **no** new OS signal beyond the app's
  **own** window occlusion/visibility; reads no other-app or input data (NFR-2). **Ship-blocker.**

---

## Coverage table (AC / NFR → covering case IDs)

| Item | Description | Covered by |
|---|---|---|
| AC-1 | rendered scroll ~0.33× of v1 while active; engine counters byte-for-byte unchanged | TC-001, TC-002, TC-013 |
| AC-2 | scroll rate is one-way only — engine reads no rendered-scroll value (dependency direction) | TC-003, TC-002 |
| AC-3 | animate when visible-but-unfocused | TC-004, TC-013; **[REAL-OS]** TC-M2 |
| AC-4 | pause (frozen, no per-frame work) when hidden/minimized/tray | TC-005, TC-013; **[REAL-OS]** TC-M3 |
| AC-5 | per-surface evaluation on the shared JourneyGame | TC-006, TC-013; **[REAL-OS]** TC-M1, TC-M3 |
| AC-6 | winding road curves; lanes/objects follow; trapezoid preserved | TC-007, TC-012; **[REVIEW]** TC-M4 |
| AC-7 | even spacing along the curve (variance ≤ ±20% of mean) | TC-008, TC-012; **[REVIEW]** TC-M4 |
| AC-8 | richer scenery set; every asset CC0/permissive in CREDITS; none uncredited | TC-009, TC-012; **[REVIEW]** TC-M4 |
| AC-9 | reduce-motion overrides slower scroll + #5; static/minimal, still conveys state | TC-010 |
| AC-10 | idle/paused parks — unchanged from v1, independent of #3/#5 | TC-011, TC-013 |
| NFR-1 | ≥30fps on **both** surfaces under the full scene while active | **[DEVICE]** TC-M-NF1 (regression-inherited pool/alloc guards from journey-view TC-017/TC-018) |
| NFR-2 | no new OS signal beyond own-window occlusion; /privacy-audit PASS | **[AUDIT]** TC-M-PRIV (reinforced by TC-003) |
| NFR-3 | reduce-motion honoured across all new motion behaviour | TC-010 |

Every AC (AC-1..AC-10) and every NFR (NFR-1..NFR-3) maps to at least one case. No AC/NFR is orphaned.

### Coverage notes / flagged gaps

- **AC-3/AC-4/AC-5 — automation proves the logic against an *injected* visibility signal, not the real
  OS occlusion API.** The mechanical animate/pause/per-surface behaviour is fully covered headlessly
  (TC-004/TC-005/TC-006/TC-013). What is **NOT** mechanically assertable — that macOS
  `NSWindow.occlusionState` / Windows visibility actually fire for a real frameless always-on-top PiP
  behind another focused app — is the spike-gate manual triad TC-M1/TC-M2/TC-M3 (spec Decision (b)). If a
  given OS has no reliable signal, the agreed fallback is pause-when-hidden there, recorded at TC-M1.
- **AC-1 baseline risk.** The ~0.33× assertion is against a **pinned v1 baseline constant**; re-pin it if
  v1's scroll constant is refactored, or TC-001 drifts silently. The engine byte-for-byte half (TC-002)
  compares actual engine output and is not subject to this.
- **AC-6/AC-7/AC-8 — numeric proxies + a review gate.** Automation proves non-straight curve + lanes
  follow it (TC-007), arc-length spacing variance ≤ ±20% (TC-008), and every asset is CREDITS-recorded
  CC0/permissive (TC-009). The qualitative "reads as a real winding trip, evenly spaced, cohesive,
  content-appropriate, no realistic/identifiable people" is the **review gate** TC-M4, not a pass/fail
  assertion.
- **NFR-1 (≥30fps both surfaces) — DEVICE only.** Like `journey-view` / `mini-window`'s fps NFR, sustained
  frame rate is on-device frame-timing, not a deterministic unit; the v1 bounded-pool / no-per-frame-alloc
  guards (`journey-view` TC-017/TC-018) regression-protect the hot path and should be re-run with the
  richer scenery loaded. Recorded as TC-M-NF1.
- **NFR-2 (privacy) — AUDIT gate.** The only new OS read is the app's **own** window occlusion; the
  `/privacy-audit` PASS (TC-M-PRIV) is the ship-blocker, reinforced by the AC-2 dependency-direction
  inspection (TC-003) and the inherited `journey-view`/`mini-window` separation cases. A fail blocks ship
  regardless of every other pass.
- No AC was left without a **meaningful** case — every functional AC has at least one deterministic case;
  the only clauses without a fully automated case (real OS occlusion, qualitative look, on-device fps,
  privacy audit) are explicitly captured in the manual checklist with the
  `journey-view` / `mini-window` / `activity-detection` deferral precedent, not silently dropped.
