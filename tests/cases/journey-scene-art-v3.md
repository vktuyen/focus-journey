# Test cases: journey-scene-art-v3

Spec: [specs/journey-scene-art-v3/spec.md](../../specs/journey-scene-art-v3/spec.md) — **approved (2026-06-25)** — 17 ACs (AC-1..AC-17) + 3 NFRs (NFR-1..NFR-3). Wave 1 of the `visual-polish` epic; a **curation-heavy, code-light full cohesive art re-source**.
Carved from / closes: [specs/journey-scene-v2/spec.md](../../specs/journey-scene-v2/spec.md) — its **AC-8 deferred beach/coast + side-view animals** (no cohesive license-clean asset existed then); this slice **reverses** that deferral. The even-spacing guarantee (journey-scene-v2 AC-7), bounded pool / no-alloc guards, reduce-motion handling, idle/paused parks, the manifest-only loading rule, and the graceful-degradation placeholder pattern are **inherited** and regression-guarded here. Existing cases: [tests/cases/journey-scene-v2.md](journey-scene-v2.md).
Shares (shipped): [specs/journey-pov/spec.md](../../specs/journey-pov/spec.md) — same `JourneyGame` instance + the mini-window PiP (ADR-0003); the AC-16/AC-17 art-cohesion + CREDITS patterns and the separation invariant are reused. Existing cases: [tests/cases/journey-pov.md](journey-pov.md).
Resolved decisions driving these cases: spec `## Open questions` (all resolved 2026-06-25) — (1) **beach/coast = far parallax BAND, not a pooled side-object** (AC-7 does NOT apply to it; cohesive beach *props* are an optional pooled kind to which AC-7 *would* apply); (2) **beach cycles by scroll phase with no geographic logic** (geography owned by `map-experience`); (3) **"higher-resolution" = strict PNG-dimension check** with a signed-off equal-resolution deviation valve. Plus the scope decisions: **full cohesive re-source** (replace wholesale) and the **spike-miss fallback ladder** (switch family → original flat vectors → procedural/drop, each rung 2/3 a signed-off deviation).
Manual companion: [journey-scene-art-v3-manual-checklist.md](journey-scene-art-v3-manual-checklist.md) — the art-direction spike sign-off, fallback-ladder sign-off, stylized-flat cohesion judgement (incl. beach band look, animal side-view cohesion, PiP-size look), on-device fps, and `/privacy-audit` release gate that are **not** cheaply automatable.

## Coverage note (which layers cover which ACs; risky / under-covered areas; automatable vs manual)

This slice is unusual: the **emotional payload is the look**, which is a human judgement. The automatable surface is the **mechanical scaffolding around** the look — manifest membership, PNG dimensions, CREDITS completeness, spawn-rotation reachability, even-spacing, pooling/no-alloc, engine byte-for-byte, separation, graceful degradation, and the regression carries. The cohesion / craft itself is gated by human sign-off legs.

- **Deterministic widget / golden tests (`src/focus_journey/test/`)** cover the mechanical core: the wholesale family replacement reflected in the requested manifest paths (AC-3), beach/coast rendering as a far parallax **band** from real manifest assets cycling by scroll phase with no geographic input (AC-5 mechanical leg), the side-view **animal** `SideObjectKind` being reachable in the live pool with a real manifest asset (AC-6 mechanical leg), even-spacing variance ≤ ±20% along the curve with the new **pooled** kinds present (AC-7), the bounded pool + no-per-frame-allocation guard with the higher-res set loaded (AC-8), the replacement-PNG-strictly-greater-than-predecessor dimension check (AC-9), the scene-loads-only-`JourneyAssets.all`-paths seam (AC-10), the asset⇄CREDITS cross-check incl. net-new beach/animals (AC-11), the engine `distanceKm`/progress byte-for-byte equality vs the pre-re-source baseline (AC-12 runtime leg), the missing/faulting asset → placeholder via `failedAssetPaths`/`hasPlaceholderAssets` never crashing (AC-14), reduce-motion unchanged (AC-15), idle/paused parks unchanged incl. the new kinds (AC-16), and the golden re-baseline being visual-only with behavioural assertions preserved (AC-17). Companion **golden** tests re-baseline the active full scene, the beach-band-in-rotation frame, the animal-in-rotation frame, the reduce-motion frame, and the parked frame.
- **Static inspection** (grep / source review) covers the AC-13 separation invariant (scene + siblings import only `dart:*`, `package:flame/*`, `TravelMode`), the AC-12 dependency direction (engine holds no scroll/scene reference), the AC-10 "no asset loaded that is absent from the manifest", the AC-11 "no manifest path absent from CREDITS", and the NFR-1 no-per-frame-allocation hot-path guard.
- **Integration tests (`src/focus_journey/integration_test/`)** cover the shared-game **both-surfaces** wiring so the re-sourced art lands on the full window and the PiP at once with no surface-specific divergence (AC-4 wiring leg) and a headline mock-driven smoke that drives a long journey so the new beach band + animal kind enter the rotation on both surfaces (AC-3/AC-5/AC-6/AC-7).
- **Manual / on-device + review checklist** covers what is **NOT cheaply automatable** — flagged `[REVIEW]` / `[DEVICE]` / `[AUDIT]`. **This slice has several manual legs** (the art is the point): the **art-direction spike + cohesion sign-off** that gates every asset (AC-1), the **fallback-ladder sign-off** (AC-2), the **stylized-flat cohesion** human judgement including the **beach band look** (AC-5 look leg), the **side-view animal cohesion** (AC-6 look leg), the **PiP-size look** (AC-4 look leg), sustained **≥30fps on both surfaces** (NFR-1 device leg), and the `/privacy-audit` PASS release gate (NFR-2).

**Automatable vs manual split (call-out):**
- **Automatable (mechanical core):** AC-3, AC-6 (rotation-reachability leg), AC-7, AC-8, AC-9, AC-10, AC-11, AC-12, AC-13, AC-14, AC-15, AC-16, AC-17, AC-4 (two-surface *wiring* leg), AC-5 (band-renders-from-real-assets + cycles-by-scroll-phase + no-geographic-input leg), NFR-1 (pool/no-alloc proxy), NFR-3.
- **Manual / sign-off (human judgement — cannot be auto-verified):** AC-1 (spike artifact existence is checkable; cohesion/craft sign-off is human), AC-2 (recorded fallback rung is checkable; the deviation sign-off is human), AC-5 **beach band look**, AC-6 **animal side-view cohesion**, AC-4 **PiP-size look**, NFR-1 **on-device ≥30fps**, NFR-2 **/privacy-audit PASS** (gating ship-blocker).

**Risky / under-covered areas (flagged):**

- **AC-1 / AC-2 are PROCESS gates, not runtime asserts.** The hard gate is "no asset lands in `JourneyAssets` before a human signs off the spike". Automation can only check the **artifact exists** (a spike record + a sign-off record + a per-asset licence list + a side-by-side comparison are committed) and — as a backstop — that the manifest was not changed *without* a recorded sign-off (a process check, e.g. a commit/checklist gate). The cohesion/craft judgement and the fallback-rung-2/3 deviation sign-off are inherently human. Captured as `[REVIEW]` TC-M-SPIKE / TC-M-FALLBACK with the journey-scene-v2 AC-8 / journey-pov AC-16 deferral precedent.
- **AC-5 conflation risk (explicitly avoided here).** Beach/coast is a **backdrop band**, NOT a pooled side-object — so AC-7 even-spacing does **not** apply to it (it is exempt like the mountains/hills bands). TC-305 asserts the band renders from real manifest assets, cycles by scroll phase, and reads **no** geographic signal; TC-307 (AC-7) measures spacing on **pooled** kinds only (animals + any optional beach props). Do not assert band spacing under AC-7. The *optional* cohesive beach **props** (umbrella/boat/hut) are nice-to-have; if shipped as a pooled `SideObjectKind` they DO fall under AC-7 (covered by TC-307's parameterisation) — if not shipped, that leg is N/A, not a fail.
- **AC-9 higher-resolution — predecessor mapping is the soft spot.** The strict "replacement width×height > predecessor width×height" check is mechanical **only if** the replaced↔predecessor mapping is recorded (the spec puts it in `CREDITS.md` notes). Net-new assets (beach/coast, animals) are **exempt**. An equal-resolution replacement from a genuinely higher-craft family is a **signed-off deviation** (recorded in CREDITS notes), not a hard fail — so TC-309 must read the recorded mapping + deviation list, not assume every manifest entry has a predecessor.
- **AC-3 wholesale-replacement is proven by manifest membership, not by the look.** Automation proves the requested paths are the new family's paths and no prior mixed-pack path survives in `JourneyAssets.all` (except a prior asset that already belongs to the chosen family). "Reads as one cohesive designed trip" is the review gate TC-M-SPIKE.
- **AC-12 engine byte-for-byte — compares against a PINNED pre-re-source baseline.** Like journey-scene-v2 TC-002, the comparison is **exact equality** of engine `distanceKm`/progress/elapsed for identical mock input + injected elapsed, run against the pre-re-source baseline. Re-pin the baseline only if the engine genuinely changes (it must not in this slice).
- **NFR-1 (≥30fps both surfaces) is on-device only.** The deterministic proxy is the bounded-pool / no-per-frame-allocation guard re-run with the **higher-resolution** set loaded (TC-308); sustained frame rate under the resolution lift is the device leg TC-M-NF1.
- **NFR-2 (privacy) is an AUDIT ship-blocker.** Swapping image files adds no OS/user signal; `/privacy-audit` PASS (TC-M-PRIV) gates ship, reinforced by the AC-13 separation + AC-12 dependency-direction static cases. A fail blocks ship regardless of every other pass.

## Conventions used by these cases

- **No real OS, no real timers, no wall-clock waits.** As in `journey-view` / `journey-scene-v2` / `journey-pov`, the scene is driven exclusively through the public `applyState({moving, mode, reduceMotion, timeOfDayHours})` contract with plain values; frame advancement is explicit (`game.update(dt)` / `pump(duration)`), never by awaiting real time. The scene reads **no** Bloc/engine/OS.
- **"Requested manifest paths."** The set of image paths the scene declares/loads is enumerated from `JourneyAssets.all` and the per-kind / per-mode lists (vehicle skins, scenery kinds via `JourneySprites._kindPath` / `imageForKind`, backdrop band paths, cockpit lists). The scene loads **nothing** absent from this manifest (inherited rule — journey-view TC-011 / journey-scene-v2 TC-009 / journey-pov AC-17 seam).
- **"Net-new vs replacement" (AC-9).** A manifest path is a **replacement** if it maps to a previously-shipped file (mapping recorded in `CREDITS.md` notes), and **net-new** if it has no predecessor (e.g. beach/coast band, animal kind). Only replacements are subject to the strict-greater-dimension check; net-new are exempt; an equal-resolution replacement is permitted **only** if recorded as a signed-off deviation in CREDITS notes.
- **"Pooled kind" vs "backdrop band" (AC-5 / AC-7).** A **pooled side-object** is spawned/recycled by the bounded `SideObjectPool` and is subject to AC-7 even-spacing (measured by arc-length along the segmented road centre-line). A **backdrop band** (mountains/hills/**beach-coast**) is a scrolling parallax silhouette layer behind the road, cycled by **scroll phase**, NOT pooled, and **exempt** from AC-7. Tests must place each new asset on the correct side of this line.
- **"Beach cycles by scroll phase, no geographic logic" (AC-5).** The coast band appears in the backdrop theme rotation as a function of the scroll phase only; the scene exposes / reads **no** route/geography/coordinate input that could gate it. Asserted structurally (no geographic input on the scene) + behaviourally (driving wildly different mock activity / mode / time inputs does not change *whether* the band can appear — only scroll phase does).
- **"Animal is a first-class side-view kind" (AC-6).** A new additive `SideObjectKind` (e.g. `animal*`) is in the spawn-rotation source set and is reachable in the live pool (`liveSideObjectKinds` seam) over a full spawn cycle, drawn from a **real** side-view full-body manifest asset (not a badge-style face, not a placeholder) — reversing the journey-scene-v2 "animals dropped" deviation.
- **"Engine counters byte-for-byte unchanged" (AC-12).** For a fixed injected elapsed time and identical mock activity input, the engine's exposed `distanceKm` / progress / elapsed are **exactly identical** to the pre-re-source baseline — compared with **exact equality**, not ±epsilon (engine truth, not rendered floats). The re-source changes only which image files are drawn.
- **"Graceful degradation" (AC-14).** `JourneySprites.loadAll` never throws; a missing/faulting path becomes a neutral placeholder, is surfaced via `failedAssetPaths` + `hasPlaceholderAssets == true`, and the scene never crashes or blanks (the shipped `journey_game.dart` seams).
- **"Visual-only re-baseline" (AC-17).** When goldens are re-baselined, **only** the committed images move; every behavioural assertion in the same suite (spacing, pooling/no-alloc, reduce-motion, idle-park, engine counters) is **preserved and still asserted** — the golden churn is expected, not a regression.
- **Float tolerance.** Rendered positions / scroll offsets compare within **±1e-6** logical px; spacing variance uses the **≤ ±20% of mean** band; engine counters use **exact** equality.
- **Test layer per `docs/architecture/overview.md`.** Executable tests live under `src/focus_journey/`: manifest membership / dimensions / spacing / pooling / reduce-motion / parks / placeholder / band-rotation behaviour + goldens → **widget/golden** (`test/`); both-surfaces wiring + long-journey rotation smoke → **integration** (`integration_test/`); the separation invariant, dependency direction, asset⇄CREDITS, and NFR-1 hot-path guard → **static inspection**; the spike sign-off, fallback sign-off, art cohesion (incl. beach/animal/PiP look), on-device fps, and `/privacy-audit` legs → manual. `tests/cases/` (this file) holds human-readable scenarios.

## Cases

### Case: Art-direction spike artifact exists and gates the manifest — no asset landed before sign-off
**ID:** TC-301
**Priority:** P0
**Type:** happy-path
**Covers:** AC-1

Given the slice is expected to start with an art-direction spike (via `ui-asset-curator` / `/source-assets`)
When the spike's committed artifacts and the manifest history are inspected
Then there exists (a) a recorded **candidate family** that claims to cover **all** scene categories — road/sky/vehicles/parallax/people/city **and** beach/coast **and** side-view animals — at higher craft + resolution, (b) a **per-asset licence list**, and (c) a **side-by-side look comparison** vs the shipped set; **and** a recorded **human sign-off** exists before any `JourneyAssets` path was replaced (the gate: no asset lands pre-sign-off)

**Notes:** Process / static-inspection case — the **checkable** part of AC-1 is the *existence* of the spike record + licence list + comparison + a dated human sign-off, and that the manifest replacement post-dates the sign-off. The **cohesion / craft judgement** ("reads as one designed family, higher-craft stylized-flat") is the human review gate **[REVIEW] TC-M-SPIKE** — it cannot be auto-verified (mirrors journey-scene-v2 AC-8 / journey-pov AC-16). This case fails if the manifest changed without a recorded sign-off.

---

### Case: Covering-family fallback ladder honoured and any rung-2/3 use is a signed-off deviation
**ID:** TC-302
**Priority:** P1
**Type:** edge
**Covers:** AC-2

Given the spike could not find beach/coast + animals cohesively within its first candidate family
When the chosen fallback is inspected against the decided ladder
Then the recorded outcome follows the ladder in order — **(1)** switch to a different CC0/permissive family that DOES cover them cohesively (even at the cost of re-skinning more to match); else **(2)** original flat vectors matched to the chosen style; **(3)** procedural-approximation / drop-the-category only as last resort — **and** any use of rung 2 or 3 is recorded as an **explicit human-signed-off deviation** (no silent category drop)

**Notes:** Process / static-inspection case — the **checkable** artifact is the recorded fallback rung + (for rung 2/3) a dated deviation sign-off. The judgement that the chosen rung was the *right* call is the human gate **[REVIEW] TC-M-FALLBACK**. If the first candidate family covered everything (rung-0, no fallback needed), this case asserts no deviation was silently taken. Guards against the journey-scene-v2 "beach approximated / animals dropped" outcome recurring without sign-off.

---

### Case: Wholesale re-source — requested manifest paths are the new family; no prior mixed-pack path survives
**ID:** TC-303
**Priority:** P0
**Type:** happy-path
**Covers:** AC-3

Given the signed-off family and the scene rendering driven by a mock activity source
When the set of manifest paths the scene requests is captured across road surface/markings, sky (sun/moon/clouds), **all six vehicle skins**, far-background parallax bands (mountains/hills), and all roadside scenery (forest/countryside/city/people)
Then the prior mixed-pack art is replaced **wholesale** — no surviving asset from the prior mixed set remains in `JourneyAssets.all` **except** where a prior asset already belongs to the chosen family — observable via the requested manifest paths matching the new family's set

**Notes:** Widget / manifest test enumerating `JourneyAssets.all` + the per-kind / per-mode requested paths and asserting they are the chosen family's paths (and that the recorded "carried-over because already in-family" exceptions are exactly the documented set). "Reads as one cohesive designed trip" is the review gate **[REVIEW] TC-M-SPIKE**. Pairs with TC-309 (each replacement is higher-res) and TC-311 (every path credited).

---

### Case: Re-sourced art lands on BOTH surfaces (full window + PiP) via the shared JourneyGame, no divergence
**ID:** TC-304
**Priority:** P0
**Type:** happy-path
**Covers:** AC-4

Given the full window and the always-on-top mini-window PiP render the **same** `JourneyGame` instance (ADR-0003), the re-sourced family loaded
When each surface renders
Then the new cohesive art appears on **both** surfaces with **no surface-specific asset divergence** — both request the identical re-sourced manifest path set (they share one game instance, so the re-source lands on both by construction)

**Notes:** Integration test (`src/focus_journey/integration_test/`) against the shared-game per-surface wiring; assert the requested manifest path set is identical for the full size and the sized-down PiP size (no per-surface asset swap). The **PiP-size look** ("the art still reads well shrunk down") is the human review gate **[REVIEW] TC-M-SPIKE** (PiP-look leg). Pairs with journey-pov TC-209 / mini-window single-shared-instance.

---

### Case: Beach/coast renders as a far parallax BAND from real assets, cycling by scroll phase, no geographic logic
**ID:** TC-305
**Priority:** P0
**Type:** happy-path
**Covers:** AC-5

Given the re-sourced family and a journey run long enough to cycle the backdrop themes, `state = active`, visible, reduce-motion OFF
When the backdrop band rotation is exercised across a long scroll and the band's requested manifest path(s) are captured
Then **beach/coast** renders as a **far parallax band** (sea/sand horizon) drawn from **real manifest assets** — **not** the journey-scene-v2 procedural-tint approximation — appearing as one backdrop theme alongside mountains/hills, driven by **scroll phase** with **no geographic logic** (driving wildly different mock activity / mode / `timeOfDayHours` inputs does not gate whether the band can appear — only scroll phase does; the scene exposes/reads no route/coordinate input)

**Notes:** Widget + structural test. (a) Assert a real beach/coast band manifest path is requested and the theme appears in the backdrop rotation over a long scroll (not a placeholder, not a procedural tint). (b) Structural: the scene has **no** geographic/route/coordinate input; vary mock activity/mode/time and assert the band's eligibility is unchanged (only scroll phase drives it). The **beach band look** ("reads as a real coastline, cohesive with the family") is the human review gate **[REVIEW] TC-M-SPIKE** (beach leg). **Critical:** the band is a backdrop — even-spacing AC-7 does **NOT** apply to it (see TC-307). Companion golden TC-313 pins the beach-band-in-rotation frame.

---

### Case: Side-view animals are a first-class pooled kind, reachable in the rotation, from a real side-view asset
**ID:** TC-306
**Priority:** P0
**Type:** happy-path
**Covers:** AC-6

Given the re-sourced family and a journey run long enough to exercise a full spawn cycle, `state = active`, visible
When the spawn rotation is exercised and the live pool kinds (`liveSideObjectKinds` seam) + requested manifest paths are captured
Then a **side-view animal** `SideObjectKind` exists as an **additive** kind present in the spawn-rotation source set and **reachable in the live pool** during the journey, drawn from a **real cohesive side-view full-body manifest asset** (reversing the journey-scene-v2 "animals dropped" deviation — **not** a badge-style face, **not** a placeholder)

**Notes:** Widget test driving a full spawn cycle and asserting (a) the animal kind is in the rotation source set, (b) it appears in `liveSideObjectKinds` over the cycle, (c) its manifest path is requested and not in `failedAssetPaths` (a real asset, not the placeholder). The **side-view cohesion** of the chosen animals ("reads as a side-profile creature in-family, not a floating icon") is the human review gate **[REVIEW] TC-M-SPIKE** (animal leg). Companion golden TC-314 pins the animal-in-rotation frame.

---

### Case: Even spacing ≤ ±20% preserved with the new POOLED kinds (animals + optional beach props), band exempt
**ID:** TC-307
**Priority:** P0
**Type:** edge
**Covers:** AC-7

Given the new **pooled** kinds — side-view animals (AC-6) and any optional beach props (AC-5) — plus any added scenery kinds are in the spawn rotation, a full scroll cycle, `state = active`, the re-sourced scenery loaded
When the arc-length gaps (measured **along the segmented road centre-line**, not screen-space) between consecutive **pooled side-objects** are collected over the cycle
Then the gap stays within the journey-scene-v2 perceptual bound — **spacing variance ≤ ±20% of the mean gap** — with no clumping (gap → 0) and no empty stretch introduced by the new kinds; the beach/coast **band** (AC-5) is a backdrop and is **exempt** (like mountains/hills bands) and is **not** included in this measurement

**Notes:** Widget test extending journey-scene-v2 TC-008 with the new pooled kinds enabled; compute inter-object arc-length gaps along the road centre-line and assert `max |gap − mean| ≤ 0.20 × mean`. **Must exclude the backdrop bands** from the measured set (they are not pooled). Parameterise to include the optional beach props **only if shipped** as a pooled kind (else that leg is N/A). The human "looks evenly spaced" read is **[REVIEW] TC-M-SPIKE**. Guards that adding animals/props does not break the spacing cadence.

---

### Case: Bounded pool + no per-frame allocation preserved with the higher-resolution set + new kinds
**ID:** TC-308
**Priority:** P0
**Type:** regression
**Covers:** AC-8, NFR-1

Given the new kinds are wired into the existing pooled side-object spawner and the **higher-resolution** re-sourced set is loaded, `state = active`
When the scene is advanced across many `update(dt)` pumps and the hot path is inspected
Then the **bounded object pool** still holds (live count plateaus at a fixed capacity; new kinds reuse pooled instances, never re-`new`ed) and the **no-per-frame-allocation** guard still holds (the higher-resolution set introduces no per-frame heap allocation; geometry stays O(1) per object) — the resolution lift does not cost the perf invariants

**Notes:** Widget guard (live-count plateau) + static inspection of the `advance`/render hot path, re-run with the re-sourced higher-res set loaded — inherits journey-view TC-017/TC-018 + journey-scene-v2 pool/alloc guards + the `SideObjectPool` fixed-capacity contract. Deterministic proxy for NFR-1; sustained on-device ≥30fps under the resolution lift is the device leg **[DEVICE] TC-M-NF1**.

---

### Case: Each replaced asset is strictly higher-resolution than its predecessor; net-new exempt; equal-res = signed-off deviation
**ID:** TC-309
**Priority:** P0
**Type:** edge
**Covers:** AC-9

Given each asset in `JourneyAssets.all` that **replaces** a previously-shipped file, with the replaced↔predecessor mapping recorded in `CREDITS.md` notes
When each replacement PNG's dimensions (width × height) are compared to the file it replaces
Then the replacement is **strictly greater resolution** than its predecessor; **net-new** assets (beach/coast band, animals, any new kind) are **exempt** from the comparison; an **equal-resolution** replacement is accepted **only** when recorded as an explicit signed-off deviation in CREDITS notes (not a hard fail), and any replacement smaller than its predecessor with no deviation record is a **fail**

**Notes:** Mechanical widget/test reading the recorded mapping from `CREDITS.md` notes, decoding both PNGs, asserting strict-greater dimensions for replacements (or a recorded equal-res deviation), and skipping net-new. **Soft spot:** depends on the mapping being recorded — if a replacement has no recorded predecessor and is not flagged net-new, that is a coverage gap to escalate, not a silent pass. Re-run whenever an asset is added/replaced.

---

### Case: Scene loads ONLY manifest paths — nothing absent from JourneyAssets.all is requested
**ID:** TC-310
**Priority:** P0
**Type:** regression
**Covers:** AC-10

Given the re-sourced scene runs (across all six modes + a long scroll exercising bands + the new kinds)
When the set of image paths the scene requests is captured via the requested-paths seam
Then **every** requested path is present in `JourneyAssets.all` and the scene loads **nothing** absent from that manifest — including the net-new beach/coast + animal assets, which must be declared in the manifest before they are requested

**Notes:** Widget / manifest test mirroring journey-pov AC-17 / journey-view TC-011 / journey-scene-v2 TC-009: enumerate requested paths and assert each ∈ `JourneyAssets.all`. The seam this depends on (the scene loading only declared paths) is the load-bearing inherited invariant. Re-run whenever the manifest or a renderer path changes.

---

### Case: Every manifest path has a CC0/permissive CREDITS row, including net-new beach + animals
**ID:** TC-311
**Priority:** P0
**Type:** regression
**Covers:** AC-11

Given the updated `JourneyAssets.all` and `assets/CREDITS.md`
When every manifest path is cross-checked against CREDITS
Then **every** path — including the net-new beach/coast + animal assets — has a matching row recording **source pack, URL, author, licence, and notes**, every such licence is **CC0 or clearly permissive** (attribution recorded where the licence requires it, e.g. CC BY), and the scene loads **no** asset absent from CREDITS

**Notes:** Static-inspection / manifest test mirroring journey-pov TC-219 / journey-scene-v2 TC-009: parse `JourneyAssets.all`, parse CREDITS, assert a 1:1 row for each path with a CC0/permissive licence + (for attribution-required licences) the attribution present. The "actually license-clean / cohesive single family" provenance judgement is reinforced by **[AUDIT] TC-M-PRIV** + the spike sign-off TC-M-SPIKE. Re-run whenever an asset is added.

---

### Case: Engine distanceKm / progress / elapsed are byte-for-byte unchanged vs the pre-re-source baseline
**ID:** TC-312
**Priority:** P0
**Type:** edge
**Covers:** AC-12, AC-13

Given identical mock activity input and a fixed injected elapsed time, run once against the pre-re-source baseline and once with the re-sourced art loaded
When the engine's exposed `distanceKm` / progress / elapsed counters are read at the same elapsed points in both runs
Then the engine counters are **exactly identical** between the two runs — the re-source changes **only which image files are drawn**, never journey truth, scroll rate, curve geometry, visibility rule, modes, or accrual

**Notes:** Widget/integration test asserting **exact equality** (not ±epsilon) of engine counters across the baseline vs re-sourced runs for the same injected elapsed (mirrors journey-scene-v2 TC-002 / journey-pov TC-215). The static half (engine holds no scene/scroll reference) is folded into TC-315's dependency-direction inspection. Drives state via `applyState`; advances frames via the harness.

---

### Case: Golden re-baseline — active full scene with the new family is visually stable AND behavioural asserts preserved
**ID:** TC-313
**Priority:** P1
**Type:** regression
**Covers:** AC-17, AC-3, AC-5, AC-7

Given a fixed `mode`, fixed injected day-time clock, fixed scroll phase chosen to include the **beach/coast band** in the backdrop rotation, `state = active`, visible, reduce-motion OFF, the re-sourced family loaded
When the scene renders one frame
Then it matches the **re-baselined** "v3 cohesive scene + beach band" golden image — **and** in the same suite the behavioural assertions (even spacing, pooling/no-alloc, engine counters) are **still asserted and pass** — the golden churn is expected (visual-only re-baseline), not a regression

**Notes:** Golden test (`src/focus_journey/test/`) re-baselined for the new look; determinism via fixed clock/mode/phase (as journey-scene-v2 TC-012 / journey-pov TC-211). **AC-17's contract:** only the committed images move; the suite's behavioural assertions are preserved. Does **not** prove "reads as cohesive stylized-flat" — that is **[REVIEW] TC-M-SPIKE**. Pin a phase that exercises the beach band so the band is visually regression-guarded.

---

### Case: Golden re-baseline — animal side-object in rotation frame is visually stable
**ID:** TC-314
**Priority:** P1
**Type:** regression
**Covers:** AC-17, AC-6

Given a fixed `mode`, fixed clock, a fixed scroll phase chosen so the **animal** kind is present in the live pool, `state = active`, visible, reduce-motion OFF
When the scene renders one frame
Then it matches the **re-baselined** "v3 scene with side-view animal in rotation" golden — the animal reads as a real side-view full-body creature drawn from its manifest asset (not a placeholder, not a badge face)

**Notes:** Golden test pinning the net-new animal kind visually so it cannot silently revert to a placeholder/face. Determinism via a fixed phase that forces the animal into the pool. The side-view cohesion judgement is **[REVIEW] TC-M-SPIKE** (animal leg). Pairs with TC-306's seam-level reachability assertion.

---

### Case: Separation invariant — scene + siblings import only dart:*, package:flame/*, TravelMode
**ID:** TC-315
**Priority:** P0
**Type:** regression
**Covers:** AC-13

Given the re-source touches the Flame scene (`journey_game.dart` + presentation/game siblings, including the manifest, sprites loader, side-object pool, and any new band/kind source)
When the scene's source and its siblings are inspected statically (imports + references)
Then they import **only** `dart:*`, `package:flame/*`, and the pure-Dart domain `TravelMode` — **no** `flutter_bloc`, `JourneyEngine`, `ActivityPlugin`, `MethodChannel` / platform channel, or any OS idle/lock/screen/location read — and state still enters via the single `applyState({moving, mode, reduceMotion, timeOfDayHours})` seam

**Notes:** Static-inspection case (grep / import scan / dependency-direction) over `lib/features/journey/presentation/game/*.dart`, mirroring journey-scene-v2 TC-003 / journey-pov TC-214 + the file's own SEPARATION INVARIANT docstring. Re-run on any new source file added by the re-source. Reinforces NFR-2. Includes the engine-holds-no-scene/scroll-reference dependency-direction half referenced by TC-312.

---

### Case: Asset failure stays non-fatal — placeholder drawn, failed path surfaced, no crash (incl. net-new)
**ID:** TC-316
**Priority:** P0
**Type:** negative
**Covers:** AC-14

Given any re-sourced or net-new asset (e.g. a vehicle skin, the beach band, or the animal asset) is absent from the bundle or faults while decoding
When the scene loads via the existing `JourneySprites.loadAll` never-throws pattern and renders
Then a neutral **placeholder** is drawn in that element's place, the failed path is surfaced through `failedAssetPaths` and `hasPlaceholderAssets == true`, and the scene **never crashes or blanks** (the rest of the scene still renders) — unchanged from the shipped loader

**Notes:** Widget test injecting a missing/faulting path for a re-sourced and a net-new asset (mirror journey-view/journey-scene-v2 TC-014 / journey-pov TC-216). Assert `failedAssetPaths` contains the path, `hasPlaceholderAssets` true, no exception, frame still renders. Explicitly cover the **net-new** beach band + animal paths so an un-shipped net-new asset degrades gracefully rather than crashing.

---

### Case: Reduce-motion regression unchanged across the re-sourced art
**ID:** TC-317
**Priority:** P0
**Type:** regression
**Covers:** AC-15, NFR-3

Given the OS/app "reduce motion" preference is ON (`applyState(..., reduceMotion: true)`, `reduceMotion == true`), the re-sourced family loaded
When the scene is `active` and advanced across several `update(dt)` pumps
Then it renders the **same** static/minimal-motion presentation as before the re-source (state still conveyed active-vs-stopped) — the higher-craft visuals and the new beach band + animal kinds introduce **no** new motion that bypasses reduce-motion; only the pixels changed

**Notes:** Widget test with reduce-motion true + the re-sourced set, inheriting journey-scene-v2 TC-010 / journey-pov TC-217. Assert (a) full scrolling suppressed, (b) the new band/kinds add no motion under reduce-motion, (c) active-vs-stopped still observable. Companion golden re-baselines the reduce-motion frame (AC-17, visual-only).

---

### Case: Idle / paused-park regression unchanged — road + objects + bands + new kinds stop, vehicle parks, overlay shows
**ID:** TC-318
**Priority:** P0
**Type:** regression
**Covers:** AC-16, NFR-3

Given the engine is `idle` (and, in a sibling run, `paused`) — `moving == false` — the re-sourced family loaded, visible
When the scene settles and is advanced across several `update(dt)` pumps
Then the road, lane markings, all (re-sourced) pooled scenery **including the new animal kind**, and the **backdrop bands including beach/coast** all **stop** (offsets unchanged across pumps), the vehicle shows its parked pose, and the "Paused — idle" overlay shows — **identical** to before the re-source (only pixels change)

**Notes:** Widget test asserting stopped quantities + the overlay for both `idle` and `paused`, explicitly including the new beach band + animal kind in the "everything parks" check, inheriting journey-scene-v2 TC-011 / journey-pov TC-218. Companion golden re-baselines the parked frame (AC-17, visual-only). Guards that the new kinds park honestly (NFR-3).

---

### Case: End-to-end smoke — mock-driven long journey lands the new family + beach band + animals on both surfaces
**ID:** TC-319
**Priority:** P1
**Type:** regression
**Covers:** AC-3, AC-4, AC-5, AC-6, AC-7

Given the app launched with the mock activity + mock window/visibility path, the shared `JourneyGame` rendering on both surfaces, `state = active`
When the mock drives a journey long enough to cycle the backdrop themes (beach band appears) and exercise a full spawn cycle (animal kind enters the pool) across both the full window and the sized-down PiP
Then across the flow the re-sourced family renders on **both** surfaces (no divergence), the beach/coast **band** appears in the backdrop rotation, the **animal** kind appears in the live pool, and the pooled-object even-spacing cadence holds — confirming the full wiring of the re-source + new kinds on the shared game

**Notes:** `integration_test` (`src/focus_journey/integration_test/`) on the real widget tree with the **mock** activity + window/visibility path (deterministic, no real OS). The mock-path twin of the manual look legs. Drives a long enough journey to reach the band rotation + a full spawn cycle; per-surface detail is TC-304, spacing detail is TC-307. The qualitative look is **[REVIEW] TC-M-SPIKE**; on-device fps is **[DEVICE] TC-M-NF1**.

---

## Manual / on-device + review legs (see the companion checklist)

These verify what is **NOT cheaply automatable** — and for this art-re-source slice they carry the **emotional payload** (the look). They live in
[journey-scene-art-v3-manual-checklist.md](journey-scene-art-v3-manual-checklist.md) and are flagged here.

- **TC-M-SPIKE** `[REVIEW]` — **stylized-flat cohesion + craft sign-off** (the hard gate of AC-1, and the look legs of AC-3/AC-4/AC-5/AC-6): the chosen family reads as **one designed, higher-craft stylized-flat trip across Vietnam** — not an asset-pack patchwork, **not** photoreal; the **beach/coast band** reads as a real cohesive coastline (AC-5 look); the **side-view animals** read as in-family side-profile creatures, not floating badge-faces (AC-6 look); the art still reads well at the **sized-down PiP** (AC-4 look); the wholesale re-source reads cohesive (AC-3 look). **No asset lands before this sign-off** (AC-1 gate). Automated mechanical legs: TC-301/TC-303/TC-304/TC-305/TC-306/TC-313/TC-314.
- **TC-M-FALLBACK** `[REVIEW]` — **fallback-ladder sign-off** (AC-2): if the first candidate family could not cover beach/coast + animals cohesively, the recorded fallback rung (switch family → original flat vectors → procedural/drop) was the right call, and any rung-2/3 use is a **dated, explicit, signed-off deviation** — no silent category drop. Automated mechanical leg: TC-302.
- **TC-M-NF1** `[DEVICE]` — sustained **≥30fps on both surfaces** (full window + sized-down PiP) with the **higher-resolution** cohesive set + the net-new beach/animal kinds loaded while `active` (NFR-1). Automated proxy: TC-308 + inherited bounded-pool / no-alloc guards.
- **TC-M-PRIV** `[AUDIT]` — `/privacy-audit` PASS: the re-source adds **no** new OS signal about the user, reads **no** user/input/screen/location data, and changes no journey truth — it swaps only static image assets (NFR-2). **Gating ship-blocker.** Reinforced by TC-315 (separation) + TC-312 (cosmetic-only engine counters).

---

## Coverage table (AC / NFR → covering case IDs)

| Item | Description | Covered by |
|---|---|---|
| AC-1 | art-direction spike + cohesion sign-off gates every asset | TC-301; **[REVIEW]** TC-M-SPIKE |
| AC-2 | covering-family fallback ladder honoured; rung-2/3 = signed-off deviation | TC-302; **[REVIEW]** TC-M-FALLBACK |
| AC-3 | wholesale re-source landed (manifest paths = new family) | TC-303, TC-313, TC-319; **[REVIEW]** TC-M-SPIKE |
| AC-4 | re-source on both surfaces, no divergence | TC-304, TC-319; **[REVIEW]** TC-M-SPIKE (PiP-look) |
| AC-5 | beach/coast = far band from real assets, cycles by scroll phase, no geography | TC-305, TC-313, TC-319; **[REVIEW]** TC-M-SPIKE (beach-look) |
| AC-6 | side-view animals = first-class pooled kind reachable in rotation | TC-306, TC-314, TC-319; **[REVIEW]** TC-M-SPIKE (animal-look) |
| AC-7 | even spacing ≤ ±20% preserved with new pooled kinds (band exempt) | TC-307, TC-313, TC-319; **[REVIEW]** TC-M-SPIKE |
| AC-8 | bounded pool + no per-frame alloc preserved with higher-res set | TC-308; **[DEVICE]** TC-M-NF1 |
| AC-9 | each replaced asset strictly higher-res; net-new exempt; equal-res = signed-off deviation | TC-309 |
| AC-10 | scene loads only `JourneyAssets.all` paths | TC-310 |
| AC-11 | every manifest path has a CC0/permissive CREDITS row (incl. net-new) | TC-311; reinforced by **[AUDIT]** TC-M-PRIV |
| AC-12 | engine counters byte-for-byte unchanged vs baseline | TC-312 (+ static via TC-315) |
| AC-13 | separation invariant — only dart:*, flame/*, TravelMode | TC-315, TC-312 |
| AC-14 | asset failure non-fatal — placeholder, surfaced, no crash (incl. net-new) | TC-316 |
| AC-15 | reduce-motion regression unchanged across re-sourced art | TC-317 |
| AC-16 | idle/paused-park regression unchanged (incl. new kinds + bands) | TC-318 |
| AC-17 | golden re-baseline visual-only; behavioural asserts preserved | TC-313, TC-314 (+ re-baselined reduce-motion/parked frames in TC-317/TC-318) |
| NFR-1 | ≥30fps both surfaces; bounded pool + no per-frame alloc under resolution lift | TC-308; **[DEVICE]** TC-M-NF1 |
| NFR-2 | pure-view; no new OS signal; /privacy-audit PASS | **[AUDIT]** TC-M-PRIV (reinforced by TC-315, TC-312) |
| NFR-3 | reduce-motion honoured + new kinds park honestly across re-sourced art | TC-317, TC-318 |

Every AC (AC-1..AC-17) and every NFR (NFR-1..NFR-3) maps to at least one case. No AC/NFR is orphaned.

### Automation coverage (where each automatable case lives)

Authored 2026-06-25 by `test-script-author`. Executable tests live under `src/focus_journey/` (per
`docs/architecture/overview.md` — the chassis `tests/integration|e2e` dirs are NOT used for Flutter
executables). One-to-one with the cases; each test name carries its TC-ID + AC-ID.

| Case(s) | File |
|---|---|
| TC-301, TC-302 (AC-1/AC-2 process/artifact gates) | `src/focus_journey/test/features/journey/presentation/game/journey_scene_art_v3_spike_artifact_test.dart` |
| TC-303, TC-305, TC-306, TC-307, TC-308, TC-310, TC-313, TC-314, TC-316, TC-317, TC-318 | `src/focus_journey/test/features/journey/presentation/game/journey_scene_art_v3_test.dart` |
| TC-309 (AC-9 dims), TC-311 (AC-11 CREDITS) | `src/focus_journey/test/features/journey/presentation/game/journey_scene_art_v3_credits_test.dart` |
| TC-312 (AC-12 engine byte-for-byte), TC-315 (AC-13 separation) | `src/focus_journey/test/features/journey/presentation/game/journey_scene_art_v3_separation_test.dart` |
| TC-304 (AC-4 both surfaces), TC-319 (e2e long-journey smoke) | `src/focus_journey/integration_test/journey_scene_art_v3_smoke_test.dart` |
| Part-A churn repairs (manifest count 31→32; ship now ships; placeholder set) | `src/focus_journey/test/features/journey/presentation/game/journey_assets_test.dart`, `.../journey_sprites_no_orphan_test.dart` |

**MANUAL (not automatable — human judgement / device / audit):** TC-M-SPIKE (AC-1 cohesion + AC-3/4/5/6 look
legs), TC-M-FALLBACK (AC-2 rightness), TC-M-NF1 (NFR-1 on-device ≥30fps), TC-M-PRIV (NFR-2 `/privacy-audit`,
gating) — all in [journey-scene-art-v3-manual-checklist.md](journey-scene-art-v3-manual-checklist.md).
TC-301/TC-302 automate only the **artifact-existence + process** half of AC-1/AC-2; the cohesion/fallback
judgement stays manual. The "golden" cases TC-313/TC-314 are automated as **deterministic frame-structure**
assertions (the repo ships no committed golden PNG baselines — predecessor-slice precedent), not
`matchesGoldenFile` images.

### Coverage notes / flagged gaps

- **AC-1 / AC-2 are process + judgement gates.** Automation checks the **artifact existence** (spike record + licence list + comparison + dated human sign-off; recorded fallback rung + deviation sign-off) and the **process guard** that the manifest did not change before sign-off (TC-301/TC-302). The cohesion/craft + fallback-rightness judgements are the human gates TC-M-SPIKE / TC-M-FALLBACK — they cannot be auto-verified (journey-scene-v2 AC-8 / journey-pov AC-16 precedent).
- **AC-5 / AC-7 deliberately NOT conflated.** Beach/coast is a backdrop **band** (TC-305) and is **exempt** from AC-7; AC-7 (TC-307) measures **pooled** kinds only (animals + any optional beach props). Do not assert band spacing under AC-7.
- **AC-9 depends on a recorded predecessor mapping.** Mechanical strict-greater-dimension check (TC-309) needs the replaced↔predecessor mapping in CREDITS notes; net-new are exempt; equal-res is a signed-off deviation. A replacement with no recorded mapping and no net-new flag is a gap to escalate, not a silent pass.
- **AC-3 / AC-4 wholesale + both-surfaces proven by manifest membership + shared-instance wiring**, not by the look; "reads cohesive" + "reads well at PiP size" is TC-M-SPIKE.
- **AC-17 golden churn is expected.** The re-baseline moves only images; the behavioural assertions in the same suites (spacing, pooling/no-alloc, reduce-motion, idle-park, engine counters) are preserved and still asserted (TC-313/TC-314/TC-317/TC-318 + the AC-7/AC-8/AC-12 cases they sit beside).
- **NFR-1 (≥30fps both surfaces) — DEVICE only.** TC-308 + inherited bounded-pool / no-alloc guards re-run with the **higher-resolution** set are the deterministic proxy; sustained frame rate under the resolution lift is on-device TC-M-NF1.
- **NFR-2 (privacy) — AUDIT gate.** Swapping image files adds no OS/user signal; `/privacy-audit` PASS (TC-M-PRIV) is the gating ship-blocker, reinforced by the AC-13 separation (TC-315) + the AC-12 cosmetic-only counters (TC-312). A fail blocks ship regardless of every other pass.
- No AC was left without a **meaningful** case — every functional AC has at least one deterministic or process-checkable case; the clauses without a fully automated case (spike/fallback cohesion sign-off, beach/animal/PiP look, on-device fps, privacy audit) are explicitly captured in the manual checklist with the journey-scene-v2 / journey-pov deferral precedent, not silently dropped.
