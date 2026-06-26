# Journey scene v2 — Flame scene fidelity & motion

**Intake date:** 2026-06-24
**Requested by:** Kevin
**Size (rough):** L
**Part of epic:** [Wave 2 feature requests](wave2-feature-requests.md) · S1a

> **Scope decision (2026-06-24, Kevin):** the riskiest item, **#2 POV reframing, was carved out into
> its own slice [journey-pov](journey-pov.md)** (sequenced *after* this one). This slice now covers the
> five bounded scene/motion items #1/#3/#5/#11/#12. The framing below still discusses #2 in places for
> context — that work now lives in `journey-pov`; do not implement #2 here.

## Raw idea (verbatim)
Rework the Flame journey scene (`features/journey/presentation/game/`) — bundled so the scene + one
asset pass are touched once, not repeatedly:
1. Winding / curve road (#1).
2. Scroll animation **×3 slower** — the underlying *speed stays the same*, only the visual scroll is slower (#3).
3. When the app **loses focus, keep the road scrolling** (currently it stops) (#5).
4. Richer scenery — mountains, beach, people, city, animals, characters, forest (#11).
5. Object spacing while scrolling should read **more even / "linear"** (perceptually) (#12).

_Carved out → [journey-pov](journey-pov.md):_ vehicle acts like a motorbike/car **POV** (steering-wheel /
handlebar view) with more-realistic objects (#2) — sequenced after this slice.

> Bonus: the mini-window PiP reuses this scene, so improvements flow to the PiP for free.
> Subsumes carried journey-view polish P-1 (scroll speed = #3); P-2 (motorbike size/blur ⊂ #2) moves to `journey-pov`.

## Why
**Problem.** The shipped `journey-view` scene works — it honestly mirrors engine state — but it
*feels flat and a little wrong*. The road is dead-straight, side objects are the sparse "v1 four
kinds" (trees, houses, street lights, road signs) that pop in unevenly, the scroll either reads too
fast to be calming or stalls the moment the user clicks away, and the vehicle is a flat cosmetic
sprite rather than a believable POV. The scene is the **main emotional screen** ("I travel because I
am focused"), so a scene that looks cheap or behaves oddly directly undercuts the product's one
motivational job.

**Who it's for.** The **focused individual** (developer / student / remote worker) who glances at the
journey — full-screen *and* in the v2 mini-window PiP — to feel momentum while they actually work.
They want the scene to read as a real, relaxing trip across Vietnam, not a tech demo.

**Why now.** Two upstream slices just shipped: `journey-view` (the scene) and `mini-window` (the PiP
that *reuses* that exact scene). Reworking scene fidelity now means one art/asset pass and one motion
rework flow to **both** surfaces at once, instead of paying twice later. It also subsumes the carried
`journey-view` polish items P-1 (scroll speed = #3) and P-2 (vehicle size/blur ⊂ #2), so they don't
linger as orphan tweaks.

## Domain notes
**Personas touched.**
- **The focused individual** — primary. Sees the scene full-screen and in the PiP; wants immersion and
  calm motion. Directly affected by #1/#2/#11/#12 (look) and #3/#5 (motion behaviour).
- **The privacy-skeptical teammate** — must stay unaffected. The whole rework is *presentation only*:
  it adds **no** new OS signal and reads **no** user data. Richer scenery, POV, and "keep scrolling
  when unfocused" must all derive from journey Bloc state + the scene's own visibility, never from
  watching other apps or the user's input. The `/privacy-audit` gate must still PASS.

**Pure-view invariant (unchanged, load-bearing).** Per `journey-view` and `mini-window`, the scene
**owns no journey logic** and is a faithful mirror of engine `state` / `mode` / `distanceKm`. Every
change below must preserve that: the scene may change *how* it draws/animates, never *what the journey
truth is*.

**CONFLICT / open question #5 — "keep scrolling when unfocused" vs mini-window NFR-1.**
`mini-window` deliberately hardened the rule "animation **paused (not just hidden)** while `idle`/
paused and/or while the PiP is not visible" (its battery/CPU constraint, the NFR-1 family) — the PiP
must not spin CPU when nothing is on screen. Request #5 ("keep the road scrolling when the app loses
focus") **directly tensions** that hardened rule, because "lose focus" is ambiguous between *visible
but not the foreground app* and *hidden to tray / minimized*. **Proposed precise definition (for the
spec to confirm with Kevin):**
- **Visible-but-unfocused** (the window — full or PiP — is on screen but another app has keyboard
  focus): **keep animating.** This is the actual #5 use case — the user is working in their IDE while
  the journey floats in view; freezing it there is the current "feels wrong" bug.
- **Hidden / minimized / hidden-to-tray** (nothing of the scene is on screen): **still pause**,
  exactly as NFR-1 requires. No pixels visible → no animation → no battery cost.
- Net effect: this **relaxes** the just-hardened "pause when not visible" into "pause when **not
  visible**, but keep animating when **visible even if unfocused**." Flag clearly so the rework does
  not silently revert mini-window's battery guarantee. The trigger must be **occlusion/visibility**,
  not **focus** — and the spec must pick a concrete, testable signal for "visible" on macOS + Windows
  (and confirm the per-OS API exists for the frameless always-on-top PiP).

**CONFLICT / open question #3 — "×3 slower scroll, same speed" decouples visual scroll from accounting.**
Today the scene scroll is a single binary constant tied to `active`. #3 asks for the *visual* scroll
to render ~1/3 as fast **without changing the journey**. Critical rule: the **visual scroll rate is a
cosmetic playback rate only** and must **NOT** be read as, or feed back into, the engine's
distance/progress (the engine truth). Slowing the scroll must leave `distanceKm` / progress / elapsed
counters byte-for-byte identical. Flag: nobody — code, tests, or future features — may infer "how far
have I travelled" from the rendered scroll offset; that remains the engine's job exclusively. This
preserves the pure-view invariant: the scene reinterprets *pace of the picture*, not *truth of the
trip*.

**Content & scope guardrail — #2 / #11 ("characters / people / animals").**
Richer scenery now includes **people, characters, and animals**. These must be sourced by the curator
(`ui-asset-curator` via `/source-assets`) as **tasteful, content-appropriate, license-clean (CC0 /
permissive) assets only**, recorded in `assets/CREDITS.md` — consistent with `journey-view`'s
"single Kenney pack primary, supplement only where it lacks an asset" cohesion rule and its "nothing
drawn from scratch, nothing with an unclear licence" constraint. No realistic/identifiable people, no
culturally insensitive or off-brand depictions of Vietnam — the journey should read as a warm,
respectful tour. Flag content-appropriateness as a review gate for this slice.

**Other edge cases to carry into the spec.**
- **POV reframing (#2):** a steering-wheel/handlebar POV implies a foreground overlay (dash/handlebars)
  and possibly which `mode` sprite shows — must still honour the *cosmetic, single-speed* v1 rule
  (per-mode speed/energy is `journey-energy-model`, out of scope here).
- **Winding road (#1) vs "even spacing" (#12):** curves change perceived object spacing; the two
  requests interact — spacing evenness must hold *along the curving road*, not just a straight one.
- **Reduced-motion accessibility:** `journey-view` already honours the OS "reduce motion" preference;
  the slower scroll (#3) and "keep scrolling unfocused" (#5) must both still respect it (static/minimal
  presentation that still conveys active vs stopped).
- **Idle/paused still parks:** all motion changes apply to the `active` state only; `idle`/`paused`
  must still stop + park + show "Paused — idle" (unchanged).
- **One scene, two surfaces:** because the PiP reuses the *same* `JourneyGame` instance (ADR-0003),
  every change lands in both — the visibility/animation rule above must be evaluated per-surface
  (the PiP can be visible while the main window is hidden, and vice versa).

## Candidate domain updates
> Flagged only — `docs/domain/` is **not** edited at Phase 0. Promote during `/new-feature`.

- [ ] **Glossary — "visual scroll rate"**: the cosmetic playback speed of the rendered road,
      distinct from journey speed/progress; explicitly **not** a measure of distance travelled (#3).
- [ ] **Glossary — "journey speed / progress (engine truth)"**: distance & progress owned solely by
      `JourneyEngine`; never derived from the rendered scroll (reinforce existing one-source-of-truth).
- [ ] **Business rule — animate-when-visible-unfocused vs pause-when-hidden**: the scene/PiP keeps
      animating while **visible** (even if another app holds focus) and pauses only when **not visible**
      (hidden-to-tray / minimized). Supersedes/relaxes the mini-window "pause when not visible (or
      unfocused)" wording; trigger is **occlusion/visibility, not focus** (#5; reconcile with NFR-1).
- [ ] **Business rule — visual scroll must not feed engine state**: rendered scroll rate/offset may
      never be read back as journey distance or progress; cosmetic only (#3).
- [ ] **Business rule — scene content appropriateness**: people/characters/animals and all scenery use
      tasteful, content-appropriate, CC0/permissive assets in `assets/CREDITS.md`; respectful depiction
      of Vietnam; nothing drawn from scratch or with an unclear licence (#2/#11).
- [ ] **Glossary — "POV vehicle frame"**: foreground steering-wheel/handlebar overlay framing the
      road; cosmetic, single-speed (does not introduce per-mode speed) (#2).

## Feasibility (high-level)
> Commitment-free Phase-0 assessment. `docs/architecture/` is untouched; ADRs are only *flagged* below.

**Architectural fit — good for most of it, one item is a bigger fish.** Five of the six requests
(#1 winding road, #3 slower visual scroll, #5 visibility-aware animation, #11 richer scenery, #12 even
spacing) fit the existing shape cleanly: the Flame scene lives at
`src/focus_journey/lib/features/journey/presentation/game/`, is driven by journey Bloc state, and the
single `JourneyGame` instance is already shared full ⇄ compact PiP (ADR-0003). Because the PiP reuses
the *same* scene instance, every change lands on both surfaces from one rework — the bundle's core
premise holds. The **pure-view invariant** is preserved throughout: each change alters *how the picture
is drawn/paced*, never the engine truth (`state` / `mode` / `distanceKm`). Assets continue to flow
through `ui-asset-curator` via `/source-assets` into `assets/CREDITS.md`, matching `journey-view`'s
single-Kenney-pack cohesion + license-clean rule.

**The #2 POV reframing is the biggest and riskiest item — architecturally distinct from the rest.**
A steering-wheel / handlebar first-person frame is not "a nicer vehicle sprite": it is a potential
**art redirection** of the whole scene (foreground dash/handlebar overlay, a re-thought camera/horizon
relationship, possibly which `mode` sprite is even shown, and a fresh curated asset set that must read
as one consistent POV). It carries the heaviest asset-curation and visual-design load, the most
review/redo risk, and the loosest spec today. The other five items are bounded scene/motion tweaks;
#2 alone could rival them combined. This is the dominant driver of the Size and of the split question
below.

**#5 visibility trigger needs a concrete, testable per-OS "is the scene visible" signal.** The domain
note already nails the *intent* (animate when visible-but-unfocused; pause when hidden/minimized/
hidden-to-tray), which **relaxes** mini-window NFR-1 from "pause when not visible *or unfocused*" to
"pause only when **not visible**". The feasibility risk is purely the mechanism: for a **frameless,
always-on-top PiP** the spec must pick and prove a real occlusion/visibility API per OS (macOS
`NSWindow` occlusion state / `occlusionState`; Windows visibility/minimize + occlusion) — focus is
explicitly *not* the trigger. This is a build-spike item (same flavour as ADR-0003's macOS triad spike)
and must be evaluated **per-surface** since the PiP can be visible while the main window is hidden and
vice-versa. It also must not regress the battery guarantee or the existing `/privacy-audit` PASS (no
new user-data signal — window occlusion is the app's own window state, not other-app observation).

**Perf budget is real but bounded (NFR-2 / smooth-on-desktop, ≥30fps).** Winding road geometry + POV
foreground + the full scenery set (mountains/beach/city/forest/people/animals) is materially more to
draw than v1's four roadside kinds, and it must hold frame rate on **both** the main window and the
sized-down PiP. The shipped scene already pools/recycles objects and avoids hot-path allocations, so
the lever exists; #1 (curved path layout math) and #12 (even spacing *along a curve*) interact and add
per-frame cost. Treat ≥30fps under the full scene as a hard acceptance gate (already a Headline success
signal).

**Cross-cutting carries that must not regress:** reduced-motion accessibility must still hold for the
slower scroll (#3) and the keep-animating-when-visible behaviour (#5); `idle`/`paused` must still park
+ show "Paused — idle"; #3's visual scroll rate must remain a cosmetic playback rate that never feeds
back into engine distance/progress.

**Rough effort.** Bundled as one slice: **L** (multiple distinct scene/motion changes + a full asset
pass on the product's most emotionally central screen, touching both surfaces). If #2 POV stays in
scope it tips toward **XL** — hence the split recommendation. Notable risks, ranked:
1. **#2 POV art redirection** — largest, loosest, highest redo risk (consider its own slice).
2. **#5 per-OS visibility signal** for the frameless always-on-top PiP — needs a build spike; relaxes NFR-1.
3. **Perf** of richer scenery + winding road at ≥30fps on both surfaces (NFR-2).
4. **Asset licensing + content-appropriateness** of people/characters/animals + respectful depiction of Vietnam (a review gate).

## Candidate ADRs
> Flagged only — no ADR is written and `docs/architecture/` is untouched at Phase 0. Promote/write via
> `/add-adr` during `/new-feature` if these survive scoping. All extend ADR-0002 (stack) / ADR-0003 (PiP).

- [ ] **Winding-road geometry model (#1, interacts with #12).** How the curving fake-3D road is
      represented and laid out (e.g. parametric curve / spline / segmented heading offset over the
      trapezoid), and how roadside object placement + perceived spacing is computed *along the curve*
      while preserving the pure-view invariant and the perf budget.
- [ ] **POV reframing approach — and whether #2 splits into its own `journey-pov` slug.** The dash/
      handlebar foreground overlay, camera/horizon relationship, and `mode`-sprite handling; explicitly
      records the scope decision (single slice vs separate `journey-pov` slice). Highest-risk decision —
      flagged as the likely trigger for splitting this backlog item into an epic (see recommendation).
- [ ] **Visibility-vs-focus animation trigger that relaxes mini-window NFR-1 (#5).** Adopt
      "animate when **visible** (even if unfocused); pause only when **not visible** / hidden-to-tray /
      minimized," superseding mini-window's "pause when not visible *or unfocused*" wording. Must name a
      concrete, testable per-OS occlusion/visibility signal for the frameless always-on-top PiP
      (macOS `NSWindow` occlusion; Windows visibility/minimize + occlusion), evaluated **per-surface**,
      with a build spike — trigger is **occlusion, not focus**, and must keep `/privacy-audit` PASS.
- [ ] **Visual scroll rate decoupled from journey progress (#3).** Establish "visual scroll rate" as a
      cosmetic playback rate (≈0.33× of v1) that is a one-way render concern only and may **never** be
      read back as / feed into engine distance/progress/elapsed (reinforces the single-source-of-truth
      rule; engine counters stay byte-for-byte identical).

## Headline success signals
- **Visual–progress decoupling:** for the same elapsed idle time, the rendered scroll rate is ~1/3 of v1 (≈0.33×, measurable via scene scroll-offset delta per second), while the engine's reported journey distance / progress is byte-for-byte unchanged from v1 (#3).
- **Focus-aware animation:** with the window visible-but-unfocused the scene keeps animating (scroll offset advances frame-over-frame); when hidden-to-tray or minimized it pauses (offset frozen) — battery rule preserved (#5).
- **Even spacing:** across a full scroll cycle the gap between consecutive scenery objects stays within a perceptual bound (e.g. spacing variance ≤ ±20% of the mean gap) — no visible clumping or empty stretches (#12).
- **Performance under richer scene:** with the winding road and full scenery set (mountains/beach/city/forest/people/animals) loaded, frame rate holds ≥30fps on the reference machine, in both the main window and the reused mini-window PiP (#1, #11). _(POV vehicle perf belongs to [journey-pov](journey-pov.md).)_

## Signals
**Ready to promote now** — its only upstream dep is shipped (`[blocked by: journey-view ✅]`); runs in
parallel with `idle-accounting` (different subsystem). Two things to settle at `/new-feature` intake
(they don't block promotion but the spec can't be approved without them):
1. **#5 visibility trigger** — confirm the "animate when visible-but-unfocused; pause when hidden/
   minimized/tray" rule (it deliberately **relaxes** mini-window NFR-1) and run a small per-OS occlusion-
   signal spike (macOS `NSWindow.occlusionState`; Windows visibility/minimize) before `/implement`.
2. **#3 decoupling** — the spec must assert the visual scroll rate never feeds engine distance/progress.

**Scoped out:** #2 POV reframing now lives in [journey-pov](journey-pov.md) `[blocked by: journey-scene-v2]`.
**Downstream:** none hard-block on this; `journey-pov` builds on it.

## First step
Run `/new-feature journey-scene-v2` to promote this into a spec bundle.
