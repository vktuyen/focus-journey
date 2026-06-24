# Acceptance criteria

Each item is a checkable, observable statement. If it isn't testable, rewrite it.

> Driven by `specs/journey-view/spec.md`. The scene is a **pure view** of the journey Bloc, which
> reflects `JourneyEngine` (`state` ∈ {active, idle, paused}, cosmetic `mode`, `distanceKm`).
> Where an open question affects an AC, the AC is written against the spec's recommended default and
> the dependency is noted.

## Functional — state drives motion

- [x] AC-1 (active → motion): **Given** the app is driven by a mock activity source and the journey
      Bloc emits `state = active`, **When** the journey scene is on screen, **Then** the road trapezoid
      and lane markings scroll toward the near camera, parallax roadside objects (v1: trees, houses,
      street lights, road signs) stream from horizon to camera (growing as they approach), and the
      vehicle plays its running/engine animation — all observable as continuous motion in the running
      app. *(Narrowed H-2, 2026-06-24: distant background layers — mountains/rice-fields/clouds —
      deferred to a later polish wave; not required for v1.)*

- [x] AC-2 (idle → stop + park + message): **Given** the Bloc emits `state = idle`, **Then** the road,
      lane markings and all side objects stop, the vehicle shows its parked pose, and a quiet
      "Paused — idle" overlay is shown over the scene.

- [x] AC-3 (paused → stop + park + message): **Given** the Bloc emits `state = paused`, **Then** the
      scene behaves identically to AC-2 (everything stopped, vehicle parked, "Paused — idle" overlay
      shown). v1 treats `idle` and `paused` as the same "stopped" visual — the scene draws no visual
      distinction between them. (Resolved: identical visual in v1; generic "Paused — idle" copy with no
      configured-threshold value, avoiding coupling to `local-stats`.)

- [x] AC-4 (single source of truth — never moves when stopped): **Given** the Bloc's last-emitted
      `state` is `idle` or `paused`, **When** the scene is left running on screen, **Then** no road,
      lane, side-object or vehicle-travel motion ever occurs — the scene cannot move unless the Bloc
      says `active`. (A short transition ease per AC-6 is the only motion permitted, and only while
      settling to rest immediately after the state change.)

- [x] AC-5 (resume → motion within one tick): **Given** the scene is stopped (`idle`/`paused`),
      **When** the Bloc emits `state = active`, **Then** scrolling resumes within one render
      tick/frame of receiving the state, with no perceptible lag between "Bloc says active" and "road
      moves."

- [x] AC-6 (transition latency / no jank): **Given** an active↔idle (or active↔paused) state change,
      **When** the scene reacts, **Then** the start/stop happens within one tick and reads
      unmistakably as "moving" vs "stopped" — any easing is a short bounded ramp (≤ ~0.5 s) that still
      leaves the stopped state visually unambiguous within that tick, and the transition produces no
      visible jump/jank or dropped frames. (Resolved: short ease — a bounded ≤ ~0.5 s ramp.)

- [x] AC-7 (binary speed — no proportionality): **Given** `state = active`, **When** the scene
      scrolls, **Then** it scrolls at a single constant scroll speed regardless of `distanceKm`,
      elapsed time, or any other value; when stopped, scroll speed is zero. The scene never speeds up
      or slows down based on engine numbers. (Resolved: binary moving/stopped, single scroll speed.)

## Functional — skin, separation, assets

- [x] AC-8 (vehicle skin reflects `mode`): **Given** the Bloc emits a specific cosmetic `mode`
      (e.g. walk / bike / car), **When** the scene renders, **Then** the displayed vehicle sprite is
      the skin for that `mode`; changing `mode` swaps the sprite. All skins move at the **same** scene
      speed (cosmetic-only, v1) — only the sprite differs.

- [x] AC-9 (no OS/activity signals read by the scene — separation invariant, code inspection):
      **Given** the journey-view source, **When** inspected, **Then** the scene reads **only** the
      journey Bloc's `state`, `mode`, and `distanceKm` — it makes no call to `ActivityPlugin`,
      `getSystemIdleSeconds()`, `isScreenLocked()`, no platform channel, no idle/lock/OS API, no
      `DateTime.now()` for activity decisions, and contains no active-vs-idle/distance-accrual logic.
      Verifiable by static inspection (no such imports/calls present in the scene's files).

- [x] AC-10 (scene accrues no distance / owns no journey state): **Given** the scene is running,
      **Then** it never mutates or computes `distanceKm`, `activeTimeToday`, `rawActiveTime`,
      `idleTimeToday`, or `state`; it only consumes them. Verifiable by code inspection — no writes to
      journey state originate in journey-view.

- [x] AC-11 (assets are CREDITS-recorded only): **Given** every visual asset the scene loads
      (road, lane markings, side objects, vehicle skins, background/day-night layers, fonts),
      **When** cross-checked against `assets/CREDITS.md`, **Then** each loaded asset has a matching
      entry with a licence + attribution, and the scene loads **no** asset absent from
      `assets/CREDITS.md`. No hand-authored/original art is shipped.

- [x] AC-12 (day/night tint, cosmetic): **Given** an injected/clock-based notion of time-of-day,
      **When** the scene renders, **Then** a cosmetic day/night tint layer is applied over the scene;
      the tint is purely ambient and never gates or alters motion (motion is governed only by `state`).
      (Resolved: injected clock — deterministic and testable; full weather is out of scope.)

- [x] AC-13 (first-frame / pre-state default): **Given** the scene is mounted but the Bloc has not yet
      emitted a real `state` (or emits an unrecognised/loading/error state), **When** the scene renders,
      **Then** it shows the parked/stopped look with no motion — it never auto-scrolls before a real
      `active` state arrives.

- [x] AC-14 (missing-asset graceful degradation): **Given** a curated asset fails to load at runtime,
      **When** the scene renders, **Then** it shows a neutral placeholder (or the parked vehicle) and
      keeps running — a missing sprite never crashes the scene or blanks the screen.

## Non-functional

- [ ] Performance — frame rate: the scene sustains ~60 fps on a typical desktop (macOS + Windows)
      while `active`, with a worst-case floor of ≥ 30 fps under load; no sustained jank.
      **⚠️ DEFERRED carry-over (shipped 2026-06-24):** on-device fps was never measured (TC-015/016 are
      opt-in `--dart-define=run-perf=true`; no perf-timing session in the green run). A live macOS run
      (2026-06-24) showed smooth motion with no visible jank, but the ~60 fps / ≥30 fps floor is
      **unverified by instrumentation** — run TC-015/016 on macOS + Windows hardware before a public
      release. Owner: `test-executor` + `flame-game-developer`.

- [x] Performance — no jank on toggle: an active↔idle/paused state toggle introduces no visible
      stutter or dropped-frame spike at the transition (supports AC-6). *(Verified deterministically:
      TC-006/TC-024 ease curve — bounded, monotonic, no spike; confirmed visually in the live run. The
      on-device frame-timing half, TC-016, shares the frame-rate deferral above.)*

- [x] Performance — bounded object pool: side objects are recycled from a bounded pool (off-screen
      objects are reused, not endlessly spawned); object count stays bounded over a long active
      session, and there are no per-frame heap allocations in the hot render/update path. *(TC-017.)*

- [x] Performance — suspended when not visible: when the journey scene is not the visible/foreground
      view, its animation and update loop are **paused** (not merely hidden), consuming no per-frame
      work. *(TC-018.)*

- [x] Privacy / Separation: the scene adds **no** new OS surface and introduces no dependency that
      reads input/screen/clipboard/files/network; it is a pure consumer of Bloc `state`/`mode`/
      `distanceKm` (reinforces AC-9, AC-10). Passes a `/privacy-audit` (`privacy-guardian`) review.
      *(TC-026 — `/privacy-audit` PASS, Phase 4.)*

- [x] Accessibility — reduced motion: when an OS/app "reduce motion" preference is on, the scrolling
      scene honours it — motion is reduced or replaced with a static/minimal-motion presentation while
      still conveying active vs stopped (e.g. a non-scrolling indicator), so the screen is usable by
      motion-sensitive users. (Resolved: v1 honours the preference and still conveys state; the exact
      static/minimal-motion visual is an implementation detail.) *(TC-019.)*

- [x] Accessibility — message readability: the "Paused — idle" overlay is legible against the scene
      (sufficient contrast, readable size) and exposed to the accessibility tree / screen readers as
      text, not baked into a sprite. *(TC-020/TC-027.)*

## Out of scope (reminder)

- **Route / map / geography** — province chain, start province, direction, "% of country",
  checkpoints. The scene shows generic forward travel only (`route-progress`).
- **Stats, streaks, badges, settings, onboarding/privacy screens** (`local-stats`).
- **Per-mode speeds / energy / fuel** — v1 skins are cosmetic, one shared speed
  (`journey-energy-model`, v2).
- **Rive character polish, real weather system, true 3D** — Flame-only 2D for v1.
- **Mini-window / always-on-top PiP / tray rendering** (`mini-window`, v2).
- **Drawing original art** — all visuals come from curated free, license-clean assets.
- **Any activity/idle decision, distance accrual, or persistence** — owned by `journey-engine` and
  the activity ticker; the scene only reads state.
- **The live distance counter widget** — resolved: the counter is a plain Flutter widget layered over
  the Flame scene, not rendered by the scene itself.
