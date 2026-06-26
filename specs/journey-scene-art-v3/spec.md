# Journey scene art v3 — hi-res cohesive scenery re-source (incl. beach + animals)

**Status:** shipped (2026-06-25)
**Owner:** Kevin (Tuyen Vo)
**Last updated:** 2026-06-25

## Problem
The journey scene **functions** — winding road, parallax scenery, first-person cockpit, decoupled cosmetic
scroll all shipped through Wave 1 + Wave 2 (`journey-view` → `journey-scene-v2` → `journey-pov`). But it is
the product's **main emotional screen** ("I travel because I am focused"), it is meant to stay on-screen the
**whole work session** (full window **and** the always-on-top mini-window PiP), and Kevin's eye says it still
reads **placeholder-grade**: the art is "whatever CC0 asset happened to be available," assembled from a mix of
flat-vector scenery (Background Elements Redux) and pixel-art people/vehicles (Pixel Vehicle Pack), at modest
resolution. Two concrete consequences:

- **It looks cheap / inconsistent.** The current set was picked for availability, not craft — mixed resolution,
  mixed sub-styles, and a visible "asset-pack" feel rather than a designed, cohesive trip across Vietnam.
- **Two scenery categories are missing.** `journey-scene-v2` **AC-8 explicitly deferred beach/coast + side-view
  animals** because no license-clean *cohesive* asset existed in the then-current pack family (beach was
  approximated procedurally; animals were dropped). Those gaps are still open and still flagged
  "pre-public-release" on the roadmap.

This is the **Wave 1 slice of the `visual-polish` epic**. It is a **curation-heavy, code-light** re-source: a
**full cohesive re-source** of the scene to **one** higher-craft, **stylized-flat** pack family across
road/sky/vehicle/parallax + people/city, that **also covers beach/coast + animals**, replacing the current
mixed set wholesale. "More beautiful" means **higher-craft stylized-flat — photoreal stays declined**
(consistent with the `journey-pov` house-direction decision). The work flows through the **existing**
`journey_assets` manifest + `journey_sprites` graceful-degradation loader; it does **not** touch journey logic.

## User & outcome
- **The focused individual** (developer / student / remote worker) — primary, and the only persona. They keep
  the journey on-screen **all session** (full-screen and in the PiP) while they work in another app. They want
  the trip to look **beautiful and cohesive enough to leave up** — a single designed art direction, not an
  asset-pack patchwork — and they want the scene to finally show the **beach/coast and animals** that a trip
  across Vietnam implies.
- **The privacy-skeptical teammate** — must stay completely unaffected. This slice is **presentation only**: it
  swaps which image files the scene draws. It adds **no** OS signal, reads **no** user data, and changes **no**
  journey truth. `/privacy-audit` must still PASS.

**Observable success:** the scene (driven by a mock activity source) renders a **cohesive, higher-resolution
stylized-flat** set across road, sky, vehicles, parallax bands, people/city **and** the previously-missing
**beach/coast + animal** side-objects, which **appear in the spawn rotation** during a journey **without
breaking the even-spacing cadence (journey-scene-v2 AC-7)**; every asset the scene loads is **higher-res than
its predecessor (or net-new)**, is **CC0 / license-clean**, and has a **source + licence row in
`assets/CREDITS.md`**; the scene still loads **nothing** absent from the `JourneyAssets.all` manifest; it still
holds **≥30fps** on the reference machine on **both** surfaces; and the engine's `distanceKm` / progress is
**byte-for-byte unchanged**.

## Scope
### In
- **Art-direction spike (the gate — first task).** Before any asset is replaced, an **art-direction spike**
  (via `ui-asset-curator` / `/source-assets`) surveys CC0/permissive **stylized-flat** pack families and
  confirms **one** cohesive family that covers **all** scene categories — road/sky/vehicles/parallax/people/
  city **and** beach/coast **and** side-view animals — at higher craft + resolution than today. The spike
  produces a candidate set + per-asset licence + a side-by-side look comparison, and is a **human go/no-go
  sign-off** (cohesion cannot be auto-verified). **No asset lands before the spike is signed off.**
- **Full cohesive re-source.** Replace the current mixed-pack art **wholesale** with the chosen cohesive
  family: road surface/markings (as drawn assets where applicable), sky elements (sun/moon/clouds),
  **all six vehicle skins**, far-background parallax bands (mountains/hills), and all roadside scenery
  (forest/countryside/city/people). Each replacement is **higher-resolution** than its predecessor.
- **Close the journey-scene-v2 AC-8 gaps.** Add **beach/coast** scenery and **side-view animal** side-objects
  as first-class, cohesive members of the chosen family — the explicit reason this slice exists. New
  `SideObjectKind`s for them are **additive** and enter the **spawn rotation**.
- **Spawn-rotation integration.** New beach/coast + animal kinds (and any added scenery kinds) are wired into
  the existing pooled side-object spawner so they appear during a journey **without breaking the even-spacing
  cadence** that `journey-scene-v2` AC-7 guarantees (spacing variance ≤ ±20% along the curving road).
- **Manifest + CREDITS update.** Update `JourneyAssets` (paths, `all`, any per-kind lists) and add a
  `CREDITS.md` row for **every** asset (source pack, URL, author, licence, notes), following the
  `journey-pov` AC-17 pattern. The scene loads **only** manifest paths.
- **Golden re-baseline.** Because the look changes wholesale, render/golden tests are re-baselined as part of
  this slice (expected, not a regression) — but **only** the visual baselines move; behavioural assertions
  (spacing, pooling, reduce-motion, idle-park, perf guards) are preserved.

### Out
- **#2 F1-style dynamic curve** — owned by `journey-dynamic-curve` (epic Wave 2). Road *geometry/animation* is
  unchanged here; this slice only re-skins what the existing geometry draws.
- **#3 Cockpit lean** — owned by `journey-cockpit-lean` (epic Wave 2). The cockpit is not re-tilted here.
- **#4 Vehicle picker UI** — owned by `vehicle-picker` (epic Wave 3, behind its precedence ADR). This slice may
  *re-skin* the six existing vehicles but adds **no** UI to choose one and **no** new Bloc state.
- **Cockpit glyph re-source** — the `journey-pov` cockpit glyphs (steering wheel / gauges / handlebar) are
  out of scope unless the chosen family supplies a clearly-better cohesive cockpit set; default is to leave
  them as shipped.
- **Any journey-logic / motion / geometry / state change.** No change to engine truth, scroll rate, curve,
  visibility rule, modes, or accrual. Pure-view, pure-art.
- **Photoreal art.** Declined (carry-over from `journey-pov`). Higher-craft **stylized-flat** only.
- **Drawing original *scenery* art as the primary plan.** Original flat vectors are a **named fallback**
  (below), not the default; the default is a sourced cohesive CC0 family.

## Constraints & assumptions
- **Presentation-only; pure-view invariant preserved (load-bearing).** The scene owns no journey logic and is a
  faithful mirror of engine `state` / `mode` / `distanceKm`. This slice changes **only which image files are
  drawn** — never what the journey truth is. `journey_game.dart` + siblings keep importing only `dart:*`,
  `package:flame/*`, and `TravelMode`; state still enters via the single `applyState({moving, mode,
  reduceMotion, timeOfDayHours})` seam.
- **CC0 / license-clean only — cohesion is a human sign-off gate.** Every shipped asset is CC0 or clearly
  permissive (attribution recorded), sourced via `ui-asset-curator` (`/source-assets`), with a `CREDITS.md`
  row. Cohesion / "stylized-flat craft" is verified by **human sign-off**, not automation — it is a review
  gate for this slice (mirrors `journey-scene-v2` AC-8 / `journey-pov` AC-16).
- **Re-source scope = FULL (decided 2026-06-25).** Kevin chose a **full cohesive re-source** (one higher-craft
  pack family, replace scene + scenery + vehicles wholesale) over gap-fill — for maximum visual lift. The
  golden re-baseline cost is accepted.
- **Spike-miss fallback = SWITCH PACK FAMILY (decided 2026-06-25).** If the art-direction spike cannot find
  beach/coast + animals cohesively within a candidate family, **prefer a different CC0/permissive pack family
  that DOES cover them cohesively**, even at the cost of re-skinning more of the scene to match — rather than
  approximating procedurally or dropping the category again. Drawing **original flat vectors** matched to the
  chosen style is the *secondary* fallback if no single covering family exists; procedural-approximation /
  drop-the-category is the **last resort** and would be recorded as an explicit, signed-off deviation.
- **Higher-resolution-than-predecessor.** Each replaced asset must be greater resolution than the file it
  replaces (net-new assets exempt) — keep `FilterQuality.low` + a bounded object pool + no per-frame
  allocation so the resolution lift does not cost frame rate.
- **Even-spacing (AC-7) and pooling preserved.** Adding beach/animal kinds must not break the
  `journey-scene-v2` even-spacing guarantee (≤ ±20% variance along the curve) or the bounded-pool / no-alloc
  perf guards. New kinds slot into the existing spawn cadence.
- **One scene, two surfaces.** The full screen and the PiP render the **same** `JourneyGame` instance
  (ADR-0003); the re-source lands on both at once.
- **Regressions honoured (unchanged carries).** Reduce-motion still degrades to static/minimal motion;
  `idle`/`paused` still stops + parks + shows "Paused — idle"; both must read identically after the re-source
  (only the pixels change).
- **Privacy unchanged.** No new OS signal, no user-data read — swapping art files cannot affect privacy.
  `/privacy-audit` must still return **PASS**.
- **No ADR expected.** The change is additive through the existing manifest/loader; the epic feasibility note
  marks art-v3 as "No ADR." (If the chosen family forces a structural loader/manifest change, raise a
  candidate ADR during `/implement`.)
- **Stack per `docs/architecture/overview.md`:** Flutter desktop, Bloc, Clean Architecture, **Flame**
  (ADR-0002 / ADR-0003). Scene is presentation; depends inward via the Bloc.

## Acceptance criteria
Each item is a checkable, observable statement and the ship gate. These ACs ARE the contract —
`tests/cases/journey-scene-art-v3.md` references them by ID; there is no separate acceptance-criteria file.

> **Verified GREEN 2026-06-25** — `/execute-tests` 465/465 (report
> `tests/_runner/reports/journey-scene-art-v3/20260625-160430/`). All functional ACs covered by automated
> tests; AC-1/AC-2 human cohesion + fallback legs signed off by Kevin 2026-06-25; NFR-1 on-device fps
> (TC-M-NF1) and NFR-2 runtime-egress (TC-M-PRIV) carried before public release.

> _(Functional `[ ] AC-N: Given/When/Then` covering: art-direction spike sign-off as a hard gate before any
> asset lands; full cohesive re-source landed on both surfaces; beach/coast + animals reachable in the spawn
> rotation during a journey; even-spacing (journey-scene-v2 AC-7) preserved with the new kinds;
> higher-res-than-predecessor; manifest-only loading + CREDITS completeness; CC0/license-clean; reduce-motion +
> idle-park regressions unchanged; engine counters byte-for-byte unchanged. Plus Non-functional: ≥30fps both
> surfaces, /privacy-audit PASS, stylized-flat cohesion human sign-off.)_

**Art-direction spike — the hard gate**
- [x] AC-1 (spike sign-off gates every asset): Given the slice starts with an art-direction spike (via
      `ui-asset-curator` / `/source-assets`) that surveys CC0/permissive **stylized-flat** pack families,
      When the spike completes, Then it produces (a) **one** candidate family that covers **all** scene
      categories — road/sky/vehicles/parallax/people/city **and** beach/coast **and** side-view animals — at
      higher craft + resolution than today, (b) a per-asset licence list, and (c) a side-by-side look
      comparison vs the shipped set; **and no asset is replaced in `JourneyAssets` until a human signs off the
      candidate family.** _(Cohesion/craft cannot be auto-verified — the sign-off is a **manual review gate**,
      mirroring journey-scene-v2 AC-8 / journey-pov AC-16; the existence of the spike artifact + sign-off
      record is the checkable part, the look judgement is the human leg.)_
- [x] AC-2 (covering-family fallback ladder honoured): Given the spike cannot find beach/coast + animals
      cohesively within its first candidate family, When the fallback is chosen, Then it follows the decided
      ladder — **(1) switch to a different CC0/permissive family that DOES cover them cohesively** (even at the
      cost of re-skinning more of the scene to match); **(2)** else draw **original flat vectors** matched to
      the chosen style; **(3)** procedural-approximation / drop-the-category only as last resort — and any use
      of rung 2 or 3 is recorded as an **explicit, human-signed-off deviation** (no silent category drop).
      _(Manual review gate — the recorded fallback rung + sign-off is the checkable artifact.)_

**Full cohesive re-source — both surfaces**
- [x] AC-3 (wholesale re-source landed): Given the signed-off family, When the scene renders driven by a mock
      activity source, Then the current mixed-pack art is replaced **wholesale** by that one family across
      road surface/markings, sky elements (sun/moon/clouds), **all six vehicle skins**, far-background parallax
      bands (mountains/hills), and all roadside scenery (forest/countryside/city/people) — no surviving asset
      from the prior mixed set remains in `JourneyAssets.all` except where a prior asset already belongs to the
      chosen family. Observable via the manifest paths the scene requests.
- [x] AC-4 (re-source on both surfaces at once): Given the full window and the always-on-top mini-window PiP
      render the **same** `JourneyGame` instance (ADR-0003), When the re-sourced scene runs, Then the new
      cohesive art appears on **both** surfaces with no surface-specific asset divergence (the re-source lands
      on both by construction, since they share one game instance). _(Two-surface wiring automatable; the
      PiP-size look is part of the AC-1 visual sign-off.)_

**Close the journey-scene-v2 AC-8 gap — beach/coast + animals in rotation**
- [x] AC-5 (beach/coast renders as a backdrop band, from real assets): Given the re-sourced family, When a
      journey runs long enough to cycle the backdrop themes, Then **beach/coast** renders as a **far parallax
      band** (sea/sand horizon) drawn from **real manifest assets** — *not* the journey-scene-v2 procedural-tint
      approximation — cycling as one backdrop theme alongside mountains/hills, driven by **scroll phase with no
      geographic logic** (geography is out of scope, owned by `map-experience`). Observable via the band's
      manifest path(s) being requested and the theme appearing in the backdrop rotation. _(Decision: beach is a
      **band**, not a pooled side-object — a coastline reads as a backdrop; even-spacing AC-7 does **not** apply
      to it.)_ **Optional:** if the chosen family supplies cohesive beach **props** (umbrella / boat / hut),
      they may be added as a pooled `SideObjectKind` (then AC-7 applies to them) — nice-to-have, not gating.
- [x] AC-6 (side-view animals are a first-class kind in rotation): Given the re-sourced family, When a journey
      runs long enough to exercise a full spawn cycle, Then **side-view animal** side-objects exist as an
      additive `SideObjectKind` present in the spawn rotation, reachable in the pool during a journey, drawn
      from real cohesive side-view full-body manifest assets (reversing the journey-scene-v2 AC-8 "animals
      dropped" deviation — not badge-style faces). Observable via the kind in the rotation set + its manifest
      path requested. _(Side-view cohesion of the chosen animals is part of the AC-1 visual sign-off.)_

**Even-spacing & pooling preserved (journey-scene-v2 AC-7 carry)**
- [x] AC-7 (even spacing ≤ ±20% preserved with new pooled kinds): Given the new **pooled** kinds — side-view
      animals (AC-6) and any optional beach props (AC-5) — plus any added scenery kinds are in the spawn
      rotation, When a full scroll cycle passes with the re-sourced scenery loaded, Then consecutive **pooled
      side-objects** stay within the journey-scene-v2 AC-7 perceptual bound (spacing variance **≤ ±20%** of the
      mean gap) **measured along the curving road** — no visible clumping or empty stretches introduced by the
      new kinds. _(Applies to pooled side-objects only; the beach/coast **band** (AC-5) is a backdrop and is
      exempt, like the mountains/hills bands.)_
- [x] AC-8 (bounded pool + no per-frame alloc preserved): Given the new kinds are wired into the existing
      pooled side-object spawner, When the scene animates, Then the bounded object pool and the
      no-per-frame-allocation guard from journey-scene-v2 still hold (new kinds reuse pooled instances; the
      higher-resolution set does not introduce per-frame allocation). _(Automatable via the existing pool /
      no-alloc guards.)_

**Higher-resolution-than-predecessor**
- [x] AC-9 (each replaced asset is higher-res): Given an asset in `JourneyAssets.all` that **replaces** a
      previously-shipped file, When its PNG dimensions are compared to the file it replaces, Then the
      replacement is **strictly greater resolution** (width × height) than its predecessor; **net-new** assets
      (e.g. beach/coast, animals) are **exempt** from the comparison. _(Mechanically verifiable by comparing
      PNG dimensions; the replaced↔predecessor mapping is recorded in `CREDITS.md` notes.)_

**Manifest-only loading + CREDITS completeness (journey-pov AC-17 pattern)**
- [x] AC-10 (scene loads only manifest paths): Given the re-sourced scene runs, When the set of image paths it
      requests is captured, Then every requested path is present in `JourneyAssets.all` and the scene loads
      **nothing** absent from that manifest (mirrors journey-pov AC-17 / journey-view TC-011). Observable via
      the requested-paths test seam.
- [x] AC-11 (every manifest path has a CREDITS row): Given the updated `JourneyAssets.all`, When
      `assets/CREDITS.md` is cross-checked, Then **every** manifest path — including the net-new beach/coast +
      animal assets — has a matching row recording source pack, URL, author, licence, and notes, and every
      such licence is **CC0 or clearly permissive** (attribution recorded where the licence requires it,
      e.g. CC BY). The scene loads no asset absent from CREDITS.

**Pure-view invariant & regressions (load-bearing carries)**
- [x] AC-12 (engine truth byte-for-byte unchanged): Given the re-sourced scene runs against the same mock
      inputs as the pre-re-source baseline, When the journey runs, Then the engine's `distanceKm` / progress /
      elapsed counters are **byte-for-byte identical** to the baseline — the re-source changes **only which
      image files are drawn**, never journey truth, scroll rate, curve geometry, visibility rule, modes, or
      accrual.
- [x] AC-13 (separation invariant preserved): Given the re-source, When `journey_game.dart` and its scene
      siblings are inspected, Then they still import **only** `dart:*`, `package:flame/*`, and the pure-Dart
      domain `TravelMode` — no `flutter_bloc`, `JourneyEngine`, `ActivityPlugin`, `MethodChannel`/platform
      channel, or OS read; state still enters via the single `applyState({moving, mode, reduceMotion,
      timeOfDayHours})` seam (mirrors journey-pov AC-9).
- [x] AC-14 (asset failure stays non-fatal): Given any re-sourced or net-new asset is absent from the bundle
      or faults while decoding, When the scene loads via the existing `JourneySprites.loadAll` never-throws
      pattern, Then a neutral **placeholder** is drawn, the failed path is surfaced via `failedAssetPaths` /
      `hasPlaceholderAssets`, and the scene never crashes or blanks (unchanged from the shipped loader).
- [x] AC-15 (reduce-motion regression unchanged): Given the OS/app "reduce motion" preference is enabled, When
      the re-sourced scene is `active`, Then it renders the same static/minimal-motion presentation as before
      (state still conveyed active-vs-stopped) — only the pixels changed, the reduce-motion behaviour is
      unchanged (journey-scene-v2 AC-9 carry).
- [x] AC-16 (idle/paused-park regression unchanged): Given the engine is `idle` or `paused`, When the
      re-sourced scene renders, Then the road and objects stop, the vehicle parks, and the "Paused — idle"
      overlay shows — identical to before the re-source (journey-scene-v2 AC-10 carry; only pixels change).
- [x] AC-17 (golden re-baseline is visual-only): Given the look changes wholesale, When render/golden tests are
      re-baselined as part of this slice, Then **only** the visual baselines move; the behavioural assertions
      (even spacing, pooling, reduce-motion, idle-park, perf guards, engine counters) are **preserved and still
      asserted** — the golden churn is expected, not a regression.

### Non-functional
- [x] NFR-1 Performance: With the higher-resolution cohesive set loaded (including the net-new beach/coast +
      animal kinds), the scene holds **≥30fps** on the reference machine on **both** surfaces (full window and
      the sized-down PiP) under `active`, with a **bounded object pool** and **no per-frame allocation** despite
      the resolution lift (keep `FilterQuality.low`). _(Automated guards — object pooling / no-per-frame-alloc /
      O(1) geometry — are the checkable proxy; **on-device ≥30fps is a manual carry before public release
      (TC-M-NF1)**, consistent with journey-scene-v2 NFR-1 and journey-pov NFR-1.)_
- [x] NFR-2 Privacy (gating): The re-source adds **no** new OS signal about the user, reads **no** user/input/
      screen/location data, and changes no journey truth — it swaps only static image assets. `/privacy-audit`
      still returns **PASS**. **Gating** — ship blocks until `/privacy-audit` returns PASS.
- [x] NFR-3 Accessibility: The OS/app "reduce motion" preference is honoured across the re-sourced art (per
      AC-15) — the higher-craft visuals introduce no new motion that bypasses reduce-motion, and the new
      beach/animal kinds park honestly under idle/paused (per AC-16).

## Open questions
_All three resolved at approval (Kevin, 2026-06-25). Recorded as decisions below._

- [x] **Beach/coast = parallax band, not a pooled side-object (RESOLVED).** A coastline reads as a backdrop, so
      beach/coast renders as a far parallax **band** (sea/sand horizon) cycling alongside the mountains/hills
      bands — even-spacing AC-7 does **not** apply to it. AC-5 reworded accordingly. Optional cohesive beach
      **props** (umbrella/boat/hut) may be added as a pooled `SideObjectKind` if the chosen family supplies
      them (then AC-7 applies to those props) — nice-to-have, not gating.
- [x] **Beach frequency = general rotation, no geographic gating (RESOLVED).** The coast band cycles as one
      backdrop theme among mountains/hills, driven by **scroll phase** with **no geographic logic** — a generic
      forward trip; geography stays out of scope (owned by `map-experience`). Preserves the pure-view boundary.
- [x] **"Higher-resolution" = strict PNG-dimension check, deviation valve allowed (RESOLVED).** AC-9's strictly
      greater PNG dimensions (crisper source even though downscaled at the fixed draw size) is the intended
      contract. An equal-resolution replacement from a genuinely higher-craft family counts as a **signed-off
      deviation** (recorded in `CREDITS.md` notes), not a hard fail.

## Related
- Epic: [planning/backlog/visual-polish.md](../../planning/backlog/visual-polish.md) · Wave 1
- Backlog slice (Phase-0 framing): [planning/backlog/journey-scene-art-v3.md](../../planning/backlog/journey-scene-art-v3.md)
- Upstream (shipped): [specs/journey-scene-v2/spec.md](../journey-scene-v2/spec.md) — re-skins this scene; **closes its AC-8 beach/animals gap** · **[blocked by: journey-pov ✅]**
- Related (shipped): [specs/journey-pov/spec.md](../journey-pov/spec.md) — shares the scene + AC-16/AC-17 art-cohesion + CREDITS patterns; [specs/mini-window/spec.md](../mini-window/spec.md) — same `JourneyGame` (ADR-0003)
- Downstream (epic): `journey-dynamic-curve` (#2 curve) · `journey-cockpit-lean` (#3 lean) · `vehicle-picker` (#4 picker)
- Asset infra: `lib/features/journey/presentation/game/journey_assets.dart` (manifest) · `journey_sprites.dart` (graceful loader) · [src/focus_journey/assets/CREDITS.md](../../src/focus_journey/assets/CREDITS.md)
- Architecture: [docs/architecture/overview.md](../../docs/architecture/overview.md) — ADR-0002 (stack) · ADR-0003 (single-window two-mode PiP)
- Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md)
