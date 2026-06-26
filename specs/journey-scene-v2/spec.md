# Journey scene v2 — Flame scene fidelity & motion

**Status:** shipped
**Owner:** Kevin (Tuyen Vo)
**Last updated:** 2026-06-24

## Problem
The shipped `journey-view` scene works — it honestly mirrors engine state — but it **feels flat and a
little wrong**, and it is the product's **main emotional screen** ("I travel because I am focused"), so
anything that reads as cheap or behaves oddly directly undercuts the product's one motivational job.
Three concrete defects:

- **The road is dead-straight.** A fake-3D trapezoid with no curve reads as a tech demo, not a real,
  relaxing trip across Vietnam.
- **Side objects are sparse and uneven.** The v1 four kinds (trees, houses, street lights, road signs)
  pop in at irregular gaps, with visible clumping and empty stretches.
- **The motion behaves oddly.** The scroll reads too fast to be calming, *and* it stalls the moment the
  user clicks away to their real work — exactly the moment the floating journey is supposed to keep them
  feeling momentum.

This slice reworks scene fidelity and motion for **both** surfaces at once — the full-screen scene and
the v2 mini-window PiP, which reuse the **same** `JourneyGame` instance (ADR-0003) — so one art/motion
pass lands everywhere instead of paying twice later. It also subsumes the carried `journey-view` polish
item **P-1 (scroll speed = #3)**.

## User & outcome
- **The focused individual** (developer / student / remote worker) — primary. They glance at the
  journey **full-screen and in the PiP** while they actually work in another app, and want the scene to
  read as a **real, calm trip across Vietnam**: a winding road, rich-but-evenly-paced scenery, a gentle
  scroll that *keeps moving while they work* and parks honestly when they step away.
- **The privacy-skeptical teammate** — must stay unaffected. The whole rework is **presentation only**:
  it adds **no** new OS signal about the user and reads **no** user data. Richer scenery, slower scroll,
  and "keep scrolling when visible-but-unfocused" all derive from journey Bloc state and the scene's own
  window visibility — never from watching other apps or the user's input. `/privacy-audit` must still
  PASS.

**Observable success:** driven by a mock activity source, the scene renders a **winding** road with
**richer, evenly-spaced** scenery scrolling at **~1/3 of the v1 visual rate** while `active`; it **keeps
animating** when its window is visible but another app holds focus, and **pauses** when hidden /
minimized / hidden-to-tray; the engine's reported `distanceKm` / progress is **byte-for-byte unchanged**
from v1; the full scene holds **≥30fps** on the reference machine on both surfaces.

## Scope
### In
- **#1 Winding road.** The fake-3D road curves (left/right over distance) rather than running
  dead-straight; lane markings and roadside objects follow the curve. Cosmetic geometry only — preserves
  the trapezoid near→horizon read and the pure-view invariant.
- **#3 Visual scroll ~3× slower (same journey speed).** The *rendered* scroll rate is reduced to ~0.33×
  of v1's constant while `active`, with the engine's journey speed / distance / progress **unchanged**.
  The visual scroll rate is a **cosmetic playback rate only** and must never be read as, or feed back
  into, engine distance/progress/elapsed. Subsumes carried polish P-1.
- **#5 Visibility-aware animation.** Keep animating while the surface is **visible even if another app
  holds focus** (the working-alongside use case); **pause** (offset frozen, no per-frame work) only when
  the surface is **not visible** — hidden / minimized / hidden-to-tray. Evaluated **per-surface** (the
  PiP can be visible while the main window is hidden, and vice versa). The trigger is **occlusion /
  visibility, not focus**.
- **#11 Richer scenery.** Expand beyond the v1 four kinds to a fuller, cohesive set (mountains, beach,
  city, forest, plus people / characters / animals), sourced license-clean via `ui-asset-curator` and
  recorded in `assets/CREDITS.md`.
- **#12 Even object spacing.** Consecutive scenery objects read as evenly / "linearly" spaced **along
  the curving road** — no visible clumping or empty stretches — interacting correctly with #1.

### Out
- **#2 POV / steering-wheel reframing** — carved out into its own slice
  **[journey-pov](../../planning/backlog/journey-pov.md)**, sequenced after this one. Includes the
  dash/handlebar foreground overlay, camera/horizon rework, mode-sprite POV handling, and the
  more-realistic POV asset set (and carried polish P-2). **Do not implement #2 here.**
- **Per-mode / per-state speed, energy, fuel** — owned by `journey-energy-model`. Skins stay cosmetic
  and single-speed; the slower visual scroll is one constant, not per-mode.
- **Geographic map / route overlay / "% of country" / province chain** — owned by `map-experience` /
  `route-progress`. The scene shows generic forward travel.
- **Activity/idle logic, distance accrual, persistence** — owned by `journey-engine` (consumed) and the
  app-layer ticker. The scene only *reads* state.
- **Drawing original art** — all visuals come from curated CC0/permissive assets.

## Constraints & assumptions
- **Presentation-only; pure-view invariant preserved (load-bearing).** The scene owns no journey logic
  and is a faithful mirror of engine `state` / `mode` / `distanceKm`. Every change alters *how the
  picture is drawn/paced*, never *what the journey truth is*. The slower visual scroll (#3) is a one-way
  render concern that must leave engine counters byte-for-byte identical.
- **Reduced-motion honoured (unchanged carry).** The OS/app "reduce motion" preference is still
  respected; the slower scroll (#3) and keep-animating-when-visible (#5) must both still degrade to a
  static/minimal presentation that still conveys active vs stopped.
- **Idle/paused still parks (unchanged carry).** All motion changes apply to the `active` state only;
  `idle`/`paused` still stop + park + show "Paused — idle".
- **One scene, two surfaces.** The full screen and the PiP render the **same** `JourneyGame` instance
  (ADR-0003); every change lands on both. The visibility/animation rule (#5) is evaluated per-surface.
- **Privacy unchanged.** No new user-data signal; the only new OS read is the app's **own** window
  occlusion/visibility state (not other-app observation). `/privacy-audit` must still PASS.
- **License-clean, content-appropriate assets.** People / characters / animals and all scenery are CC0 /
  permissive, sourced via `/source-assets` (`ui-asset-curator`) and recorded in `assets/CREDITS.md`,
  consistent with `journey-view`'s single-Kenney-pack cohesion rule (supplement only where it lacks an
  asset). No realistic/identifiable people, no culturally insensitive or off-brand depictions of
  Vietnam — a warm, respectful tour. Content-appropriateness is a review gate for this slice.
- **#5 relaxes mini-window NFR-1.** `mini-window` hardened "pause when not visible *or unfocused*"; this
  slice relaxes it to "pause only when **not visible**, keep animating when **visible even if
  unfocused**." This must not silently revert the battery guarantee — pause-when-hidden still holds.
- **Stack per `docs/architecture/overview.md`:** Flutter desktop, Bloc, Clean Architecture, **Flame**
  (ADR-0002 / ADR-0003). The scene is presentation; it depends inward via the Bloc. The per-OS
  visibility signal is native plumbing (macOS `NSWindow.occlusionState`; Windows visibility/minimize).

## Acceptance criteria
Each item is a checkable, observable statement and the ship gate. These ACs ARE the contract —
`tests/cases/journey-scene-v2.md` will reference them by ID.

- [x] AC-1 (#3 visual–progress decoupling): Given the engine is `active`, When the scene runs for a
      fixed elapsed time, Then the rendered scroll-offset delta per second is ~0.33× of v1's rate
      (within an agreed tolerance) **and** the engine's reported `distanceKm` / progress / elapsed
      counters are **byte-for-byte identical** to v1 for the same elapsed time.
- [x] AC-2 (#3 one-way only): Given the visual scroll rate is changed, When journey distance/progress is
      computed, Then no code path reads the rendered scroll offset/rate as an input to engine
      distance/progress/elapsed (verifiable by inspection / dependency direction; the engine has no
      reference to the scene's scroll state).
- [x] AC-3 (#5 animate when visible-but-unfocused): Given a surface (full or PiP) is on screen and
      another application holds keyboard focus, When the engine is `active`, Then the scene **keeps
      animating** (scroll offset advances frame-over-frame). _(Logic verified via MockWindowVisibilityController;
      real-OS occlusion confirmation = manual TC-M1/M2 pre-release.)_
- [x] AC-4 (#5 pause when not visible): Given a surface is hidden / minimized / hidden-to-tray (no
      pixels on screen), When the engine is `active`, Then the scene **pauses** (scroll offset frozen,
      no per-frame animation work) — preserving the mini-window battery guarantee. _(Logic verified; real-OS
      leg = manual TC-M3 pre-release.)_
- [x] AC-5 (#5 per-surface): Given the two surfaces share one `JourneyGame` instance, When one surface
      is visible and the other is hidden, Then visibility is evaluated **per-surface** and the visible
      surface animates while the hidden one does not.
- [x] AC-6 (#1 winding road): Given the engine is `active`, When the road renders, Then it visibly
      **curves** (left/right over distance) rather than running dead-straight, with lane markings and
      roadside objects following the curve while preserving the near→horizon trapezoid read.
- [x] AC-7 (#12 even spacing along the curve): Given a full scroll cycle with the richer scenery loaded,
      When consecutive scenery objects pass, Then the gap between them stays within an agreed perceptual
      bound (e.g. spacing variance ≤ ±20% of the mean gap) **measured along the curving road** — no
      visible clumping or empty stretches.
- [x] AC-8 (#11 richer scenery, license-clean): Given the scene renders, When scenery is shown, Then it
      includes the expanded cohesive set (mountains/beach/city/forest/people/characters/animals) and
      every asset used is present in `assets/CREDITS.md` with a CC0/permissive licence; the scene loads
      no asset absent from CREDITS. _(License-clean + no-uncredited-asset + expanded set: PASS. **DEVIATION:**
      beach/coast + side-view animals omitted — no license-clean cohesive asset exists; beach approximated
      procedurally. Needs **TC-M4 human content sign-off** before public release.)_
- [x] AC-9 (reduced-motion regression): Given the OS/app "reduce motion" preference is enabled, When the
      engine is `active`, Then the scene renders a static/minimal-motion presentation that still conveys
      active vs stopped — the slower scroll (#3) and keep-animating-when-visible (#5) both still honour
      the preference.
- [x] AC-10 (idle/paused parks — regression): Given the engine is `idle` or `paused`, When the scene
      renders, Then the road and objects stop, the vehicle parks, and the "Paused — idle" overlay shows
      — unchanged from v1, independent of the slower scroll and visibility changes.

### Non-functional
- [x] NFR-1 Performance: With the winding road and full scenery set
      (mountains/beach/city/forest/people/characters/animals) loaded, the scene holds **≥30fps** on the
      reference machine on **both** surfaces (full window and the sized-down PiP) under `active`
      (NFR-2 family / smooth-on-desktop). _(Automated guards PASS: object pooling/no-per-frame-alloc + O(1)
      winding-road geometry. **On-device ≥30fps not measured in this env** — deferred to manual TC-M-NF1,
      carried before public release, consistent with prior slices.)_
- [x] NFR-2 Privacy: The rework adds **no** new OS signal about the user beyond the app's **own** window
      occlusion/visibility state; it reads no other-app or input data. `/privacy-audit` still returns
      **PASS**. _(/privacy-audit PASS 2026-06-24.)_
- [x] NFR-3 Accessibility: The OS/app "reduce motion" preference is honoured across all new motion
      behaviour (slower scroll and visibility-aware animation), per AC-9.

## Decisions (resolved at approval, 2026-06-24)
> (a) and (b) confirmed by Kevin; (c) and (d) set to recommended defaults (neither blocks approval —
> both can be refined at `/implement`).

- [x] **(a) #5 visibility rule — CONFIRMED (Kevin: "yes").** Animate when **visible-but-unfocused**;
      pause only when **hidden/minimized/tray**. We **accept the relaxation** of mini-window NFR-1 — the
      battery cost while the surface is visible-but-unfocused is intended (that's the whole point of #5).
      The mini-window NFR-1 wording is superseded accordingly (animate-when-visible, pause-when-hidden).
- [x] **(b) Per-OS occlusion signal — APPROVED, spike is the first `/implement` task (Kevin: "yes").**
      `/implement` opens with a build spike proving a concrete, testable "is this surface visible" API
      per OS (macOS `NSWindow.occlusionState`; Windows visibility/minimize + occlusion), evaluated
      per-surface, working for the frameless always-on-top PiP, without regressing `/privacy-audit`
      (own-window occlusion only — no other-app/input data). If the spike finds no reliable signal on a
      given OS, fall back to the existing pause-when-hidden behaviour there and flag it.
- [x] **(c) #3 factor → ~0.33× (×3 slower) confirmed; reduced-motion OVERRIDES.** Target rendered scroll
      rate ≈ 0.33× of v1 (tolerance fixed in `tests/cases`); when "reduce motion" is on, the static/
      minimal presentation (AC-9) **supersedes** the rate entirely (no scroll-rate assertion applies).
- [x] **(d) Winding-road geometry → segmented heading-offset over the trapezoid (recommended default).**
      Cheaper and perf-friendlier than a spline and fits the existing fake-3D trapezoid; roadside
      placement + even spacing (#12) computed along the segmented curve. To be confirmed/recorded via a
      candidate ADR during `/implement` if the implementer finds a spline necessary for the look.

## Related
- Epic: [planning/backlog/wave2-feature-requests.md](../../planning/backlog/wave2-feature-requests.md) · Wave 2 (v2) · S1a
- Backlog slice (Phase-0 framing): [planning/backlog/journey-scene-v2.md](../../planning/backlog/journey-scene-v2.md)
- Upstream (shipped): [specs/journey-view/spec.md](../journey-view/spec.md) — the Flame scene reworked here · **[blocked by: journey-view ✅]**
- Related (shipped): [specs/mini-window/spec.md](../mini-window/spec.md) — reuses the same `JourneyGame` (ADR-0003); #5 relaxes its NFR-1
- Downstream: [planning/backlog/journey-pov.md](../../planning/backlog/journey-pov.md) — #2 POV reframing · **[blocked by: journey-scene-v2]**
- Out-of-scope siblings: `journey-energy-model` (per-mode speed) · `map-experience` (map overlay)
- Architecture: [docs/architecture/overview.md](../../docs/architecture/overview.md) — ADR-0002 (stack) · ADR-0003 (single-window two-mode PiP)
- Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md)
