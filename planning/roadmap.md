# Roadmap

The **single** roadmap + "what do I run next" tracker. (This file absorbed the old
`execution-roadmap.md`.) Per-slice history lives in [done/](done/); active state lives in
[active/](active/) (each slug's Phase ledger).

> **Start every new session with `/status`** — it reads the on-disk artifacts and prints the exact
> next command for each active slug. This file is the human-facing summary of the same state.

---

## Where I am right now

_Last updated: 2026-07-15_

- 🚧 **NEW WAVE — `refine-app-ui-ux` (started 2026-07-15).** Opening slice **`journey-reset` ✅ SHIPPED
  2026-07-15** (dev build, macOS-verified) — in [done/](done/journey-reset.md). Settings factory-reset (full
  wipe → first-run) + launch Resume/Start-over prompt (Start-over keeps lifetime stats, reusing ADR-0005).
  `/review-code` approved (0 Blocking) · `/privacy-audit` PASS · `/execute-tests` **green 1235/1235**;
  AC-1..12 + NFR-2 `[x]`. **`active/` is now empty.** Carried follow-ups (see the done ledger): reset-seam
  ADR (`/add-adr`), drift-guard + NFR static tests, launch-at-startup-OS-state question, product-copy TODOs,
  and the on-device/Windows release legs.

### 👉 Immediate next action (2026-07-15)
**`refine-app-ui-ux` wave is open; its first slice `journey-reset` shipped. `active/` is empty — pick the next move:**
- **Continue the wave:** define the next UI/UX-refinement slice(s) and `/capture-idea <slug>` → `/new-feature`.
- **Or harden `journey-reset` follow-ups:** write the reset-seam ADR (`/add-adr`), add the drift-guard/NFR
  static tests, and resolve the launch-at-startup + copy questions.
- **Or release-readiness:** burn down the carried on-device / Windows legs across shipped slices.
  _(Further UI/UX-refinement slices for this wave: TBD — capture with `/capture-idea`.)_

- ✅ **`visual-polish` epic COMPLETE (2026-06-26)** — Wave 1 `journey-scene-art-v3` · Wave 2
  `journey-dynamic-curve` + `journey-cockpit-lean` · Wave 3 **`vehicle-picker`** (production mode selector,
  ADR-0007). The debug-only `dev-mode-switcher` was a lean-lane stepping stone, now removed (superseded).
  **`active/` is empty** — next is release-readiness (carried pre-public/Windows legs) or a new epic.

- ✅ **Wave 1 (v1 MVP) COMPLETE (2026-06-24)** — all 5 slices shipped, in [done/](done/):
  `activity-detection` · `journey-engine` · `journey-view` · `route-progress` · `local-stats`.
- ✅ **Wave 2 (v2) feature wave COMPLETE (2026-06-25)** — shipped: **`mini-window`** · **`idle-accounting`** ·
  **`journey-scene-v2`** (all 2026-06-24) · **`map-experience`** · **`route-planner-v2`** ·
  **`journey-pov`** (all 2026-06-25), all in [done/](done/). The #2 first-person cockpit POV reframing
  (`journey-pov`) shipped as the final Wave-2 extra. **`active/` is now empty.**
- **`mini-window` SHIPPED 2026-06-24 (macOS-verified)** — single-window
  two-mode (ADR-0003); `/review-code` approved · `/privacy-audit` PASS · `/execute-tests` green
  (92 in-scope + 559/559; report `tests/_runner/reports/mini-window/20260624-152719/`); in [done/](done/).

### 👉 Immediate next action
**`vehicle-picker` ✅ SHIPPED 2026-06-26 — CLOSES `visual-polish` Wave 3 AND the whole epic. `active/` is now empty.**
In [done/](done/vehicle-picker.md). Production icon-based vehicle selector: cosmetic skin override
(`vehiclePreference ?? engineMode` via a shared `composeDisplayedMode`/`VehiclePreferenceListener` seam wired
into BOTH the `AppShell` shared-game driver and standalone `JourneyScreen`); persisted via `shared_preferences`;
two entry points (Settings row + journey affordance · skippable pre-seeded route-start) sharing one `SettingsCubit`;
6 CC BY 3.0 game-icons. Engine firewall (AC-10) + byte-for-byte accrual intact. `/review-code` **approved**
(after fixing 4 Blocking across the gates) · `/privacy-audit` **PASS** · `/execute-tests` **green** (final ship
re-run after removing the debug `dev-mode-switcher`: **1161 pass**, `tests/_runner/reports/vehicle-picker/20260626-135858/`).
AC-1..15 + NFR-1/2/3 all `[x]`. The throwaway **`dev-mode-switcher`** was removed this session (superseded).

**🎉 `visual-polish` epic COMPLETE** — Wave 1 (`journey-scene-art-v3`), Wave 2 (`journey-dynamic-curve` +
`journey-cockpit-lean`), Wave 3 (`vehicle-picker`) all shipped. **`active/` is empty — pick the next initiative:**
- **Release-readiness (recommended):** burn down the carried **pre-public / Windows legs** across shipped slices —
  on-device ≥30fps (TC-M-NF1), real-OS frameless-PiP visuals (TC-M-PIP), motion-comfort feel (TC-M-FEEL),
  icon-cohesion/a11y (TC-M-ART / TC-M-A11Y), and the **Windows runtime** pass (all shipped work is macOS-verified only).
- **Or promote the captured idea:** **`journey-reset`** (factory reset + resume/start-over launch prompt,
  Size M) — `/new-feature journey-reset`. Other deferred options: `journey-energy-model` (per-mode speeds —
  note ADR-0007's firewall) or `signed-distribution`. Start fuzzy ones with `/capture-idea`.

**(history) `vehicle-picker` — Phase 2 (Spec) — `visual-polish` Wave 3 (the production mode selector).**
Active in [active/vehicle-picker.md](active/vehicle-picker.md); spec [specs/vehicle-picker/spec.md](../specs/vehicle-picker/spec.md).
**[ADR-0007 accepted](../docs/architecture/decisions/0007-vehicle-picker-cosmetic-override-precedence.md)** (cosmetic skin-override precedence) → promoted via `/new-feature`; spec drafted + **15 ACs (AC-1..15) + 3 NFRs proposed by `product-domain-expert`** (pick swaps display ≤1 frame · precedence `vehiclePreference ?? engineMode` · persists across restart · engine byte-for-byte unchanged · forward-compat firewall vs `journey-energy-model` · two entry points one source · route-start surfacing · fun per-mode icons · a11y).
**Phase 5 (Test) ✅ GREEN 2026-06-26 → Phase 6 (Ship) NEXT.** `/execute-tests` **green**: 84/84 in-scope + **1121/1121
regression** (stats/journey/route/mini_window), 0 flakes — report `tests/_runner/reports/vehicle-picker/20260626-132959/summary.md`.
AC-1..15 + NFR-1/2/3 all `[x]`. **👉 Next: `/ship vehicle-picker`** (final phase; NFR-2 privacy gate already PASS).
Carried manual legs: TC-M-ART (icon cohesion), TC-M-A11Y (real keyboard/screen-reader), TC-M-NF1 (on-device fps).

**(prior) Phase 4 (Review) ✅ APPROVED 2026-06-26.** `/review-code` verdict **approved** (after fixes)
· **`/privacy-audit` PASS** (NFR-2 gate cleared, `[x]` in spec). Built: `AppSettings.vehiclePreference` +
`SettingsCubit.setVehicle`; cosmetic override `vehiclePreference ?? engineMode` via a shared
`composeDisplayedMode`/`VehiclePreferenceListener` seam wired into BOTH drivers (`AppShell` production shared-game
+ standalone `JourneyScreen`); icon-chip picker; two entry points (Settings row + journey affordance · skippable
pre-seeded route-start) sharing one cubit. **4 Blocking found across self-review + formal gate — all fixed**
(route-picker crash w/o cubit · scene-manifest guard vs new icons · **override missing on the production AppShell
driver** · the missing shell-path test). Firewall AC-10 + engine byte-for-byte intact. **Full suite 1162 green.**
**👉 Next: `/execute-tests vehicle-picker`** → `/ship`. Manual carries: TC-M-ART/A11Y/NF1; NFR-2 already PASS.

**(prior) `journey-cockpit-lean` ✅ SHIPPED 2026-06-26 — CLOSES `visual-polish` Wave 2. `active/` was empty before this.**
In [done/](done/journey-cockpit-lean.md). Bounded/eased/reduce-motion-gated **rotation of the `CockpitPainter`
output only** about a bottom-centre pivot, sampled from `lateralSlopeAt(worldAtCamera(scrollOffset))` (max ~3°,
smoothing 60px scroll-phase, signed into the turn). `/review-code` **`approved-with-suggestions`** (0 Blocking)
· **`/privacy-audit` PASS** · `/execute-tests` **green** (re-run after tweaks: 69/69 in-scope + 247 regression,
`tests/_runner/reports/journey-cockpit-lean/20260626-103704/summary.md`). AC-1..14 + NFR-1/2/3 all `[x]`.
Shipped **with two live-tuning tweaks**: car steering wheel sized to the dash band (whole wheel visible) +
minimap moved bottom-right → centre-right. Also shipped this session: **`dev-mode-switcher`** (debug-only
top-center mode dropdown, in [done/](done/dev-mode-switcher.md)).

**Pick the next initiative:**
- **👉 Wave 3 — `vehicle-picker`** (the PRODUCTION mode selector; supersedes the dev switcher). **Needs its
  precedence ADR first** (`/add-adr` — how a user choice interacts with any future auto-derived mode), then
  `/new-feature vehicle-picker`.
- **Or:** burn down the **carried pre-public / Windows release legs** across shipped slices (see below):
  on-device ≥30fps (TC-M-NF1), real-OS frameless-PiP visuals (TC-M-PIP), motion-comfort feel sign-off
  (TC-M-FEEL), Windows runtime.
- **Optional non-blocking polish (journey-cockpit-lean):** zero `_appliedLean` in `applyState` for
  non-cockpit/reduce-motion (latent only); `dart format` the 2 lean test files.

**(prior) `journey-cockpit-lean` — Phase 3 (Build) ✅ DONE 2026-06-25 — `visual-polish` Wave 2, slice 2 of 2.**
Active in [active/journey-cockpit-lean.md](active/journey-cockpit-lean.md); spec [specs/journey-cockpit-lean/spec.md](../specs/journey-cockpit-lean/spec.md) **`Status: approved`**.
Built (flame-game-developer): bounded/eased/reduce-motion-gated **rotation of `CockpitPainter` output only**
about a bottom-centre pivot, sampled from `lateralSlopeAt(worldAtCamera(scrollOffset))`. Pinned: max **~3°**
(0.0523599), gain 18, smoothing **60px scroll-phase** (deterministic, not dt), sign +1 into the turn. New
seams `appliedLeanAngle` + `rawLeanTargetAngle`. **Tests green:** 23 unit + 18 TC-501..518 (66 unit/widget/
golden/perf + 2 integration on `-d macos`). **Self-review (flutter-code-reviewer) caught 1 Blocking** —
AC-13 corner-coverage (flat 6% overdraw didn't cover the corner lifted by `(w/2)·sin θ`) + a loose TC-514
guard that couldn't see it — **both fixed & verified** (lever-arm-scaled overdraw; point-in-rotated-quad
guard with a non-vacuity proof). AC-7 reworded (procedural curve has no exact-zero-slope frame → exact 0.0
reserved for the reduce-motion / non-cockpit hard-zero gates).

**👉 Next: `/review-code journey-cockpit-lean`** (formal gate), then `/execute-tests` → `/privacy-audit`
(NFR-2 gating) → `/ship`. Carried manual legs: TC-M-FEEL (feel + physical into-the-turn direction),
TC-M-PIP (real-OS PiP visual), TC-M-NF1 (on-device fps), TC-M-PRIV; Windows runtime deferred.

**Then in this wave / after:**
- **Wave 3:** `vehicle-picker` — needs its precedence ADR first (`/add-adr`).
- **Or:** burn down the carried pre-public/Windows release legs below.

**(prior) `journey-scene-art-v3` ✅ SHIPPED 2026-06-25 (dev build, macOS-verified) — closes `visual-polish` Wave 1.** In
[done/](done/journey-scene-art-v3.md). Full cohesive art re-source (pure-view): hybrid AC-2 rungs 1+2 (Kenney
*Background Elements Remastered* CC0 scenery + original-flat vehicles/people/animals/beach band, signed off);
**closed the journey-scene-v2 AC-8 gaps** — beach/coast band + 4 side-view animals (buffalo/dog/chicken/bird)
now render, plus the long-missing **ship** skin and a non-procedural sky (sun/moon arc by cosmetic
`timeOfDayHours`, clouds by scroll phase). `JourneyAssets.all` 32→**46**; spawn-stride gcd fix; new
`bundled ⊆ manifest` guard. 17 ACs + 3 NFRs all `[x]`; `/review-code` **ready** · `/privacy-audit` **PASS** ·
`/execute-tests` **green 465/465** (`tests/_runner/reports/journey-scene-art-v3/20260625-160430/`). **`active/`
is now empty — no slice in flight.** ⚠️ Pre-public/Windows: NFR-1 on-device fps (TC-M-NF1), NFR-2 runtime-egress
(TC-M-PRIV).

**Pick the next initiative — `visual-polish` Wave 2** (the curve+lean pair) or the alternatives below:
- **👉 `/new-feature journey-dynamic-curve`** — F1-style sweeping/animated bends; highest risk-to-invariants
  slice (must preserve AC-7 even-spacing, arc-length-aware if needed, + ≥30fps). Then `journey-cockpit-lean`
  `[blocked by: journey-dynamic-curve]`. (Wave 3 `vehicle-picker` needs its precedence ADR first — `/add-adr`.)
- **Or:** `signed-distribution`, or burn down the carried pre-public release legs.

**Wave 2 feature wave (history): `journey-pov` ✅ SHIPPED 2026-06-25 (dev build) — closed it.** In
[done/](done/journey-pov.md). The #2 first-person cockpit POV (car = through-windshield, motorbike =
over-handlebars), **car + motorbike only**, built as a stylized-flat foreground overlay over the existing scene
(`cockpit_painter.dart`, framing 0.36). Green report machine-checked (verdict **green**, **948/948**;
`tests/_runner/reports/journey-pov/20260625-130932/`); `/review-code` **`approved`** · `/privacy-audit` **`pass`**.
AC-1..11/13/14/15/17 + NFR-2 ticked; AC-12 (real-OS PiP) · AC-16 (art-cohesion) · NFR-1 (on-device fps) ·
NFR-3 (silhouette visual) carried as pre-public-release legs. **`active/` is now empty — no slice in flight.**

**Pick the next initiative:**
- **Wave 3 (v3):** `signed-distribution` — start when ready (create child backlog items, then
  `/new-feature <slug>` each).
- **Harden for release:** burn down the per-slice "Carried before any public / Windows release" legs below
  (on-device fps / a11y / runtime-egress / Windows runtime — now including journey-pov's 4 carried legs).
- **Polish — `visual-polish` EPIC (framed 2026-06-25, Wave 1 ready):** 4 child slices from Kevin's beautify +
  dynamic-drive + vehicle-choice asks. Decisions taken: vehicle pick = **cosmetic-only**; F1-curve + lean =
  **two slices**. **👉 Start Wave 1: `/new-feature journey-scene-art-v3`** (hi-res scene + scenery art, closes
  the journey-scene-v2 AC-8 beach/animals gap). See [backlog/visual-polish.md](backlog/visual-polish.md).
  Plus journey-pov's 3 non-blocking review follow-ups (see [done/journey-pov.md](done/journey-pov.md)).

**⚠️ Carried before any public / Windows release of map-experience** (tracked in [done/](done/map-experience.md)):
AC-11 real OSM round-trip/offline (TC-M1/2), NFR-1 fps (TC-M-NF1), NFR-3 colour-blind + screen-reader
(TC-M3/4), NFR-2 runtime egress (TC-M-PRIV), Windows runtime never verified. Non-gating cleanup:
`route_map_painter.dart` now orphaned.
After map-experience ships: **`route-planner-v2`** `[blocked by: map-experience]`.

**⚠️ Carry into `map-experience`:** persist `idleSince` (idle-accounting S-3) + decide segment day-key (S-1).
**⚠️ Carry before any public release:** journey-scene-v2 AC-8 beach/animals (TC-M4 sign-off), on-device fps +
real per-OS occlusion legs (Windows occlusion is fallback-only).

Carry-forwards: idle-accounting S-3 (`idleSince` persistence) + S-1 (segment day-key) → handle in
`map-experience` (#7).

Then per slice: `/review-code <slug>` → `/execute-tests <slug>` → `/ship <slug>`.

_(Historical — Wave 2 is now complete; all of journey-pov · map-experience · route-planner-v2 shipped
2026-06-25. See "Where I am right now" above for current state.)_

---

## The per-slug loop (memorize this)

Each slug runs **5 phase commands**. A "wave" (v1/v2/v3) is just a batch of slugs pushed through them.

| # | Command | Phase | Gate before moving on |
|---|---------|-------|-----------------------|
| 1 | `/new-feature <slug>` | 2 Spec | review the spec → set `spec.md` `status: approved` (ACs live inline in the spec) |
| 2 | `/implement <slug>` | 3 Build | all ACs have code; unit tests pass; built-in self-review pass clean |
| 3 | `/review-code <slug>` | 4 Review | verdict `ready`; no open P0/P1 findings (auto-runs `/privacy-audit`) |
| 4 | `/execute-tests <slug>` | 5 Test | verdict `green`; P0 ACs ticked `[x]` |
| 5 | `/ship <slug>` | 6 Ship | machine-checks the green report; archives to `done/` |

**Small-change lane:** for a bug fix or tiny tweak, run **`/quick-change <slug>`** instead — one lean
spec stub → implement+test → review → test → ship, skipping `/capture-idea`, separate test-case design,
ADRs, and summaries. Use the full 5-command loop only for genuine features.

Helpers fire **automatically** inside these phases (don't call them directly):
- First-ever `/implement` triggers one-time **`/flutter-bootstrap`**.
- `/implement` also uses `/source-assets` (art) and runs a **self-review pass** before handing off.
- `/review-code` also runs **`/privacy-audit`** (the trust-promise gate).

---

## Now / Next / Later

### Now — `refine-app-ui-ux` wave, STARTED 2026-07-15
Theme: refine the app's UI/UX. Promote each slice with `/new-feature <slug>` in order.
- **journey-reset** — Settings factory-reset (full wipe → first-run) + launch Resume/Start-over prompt
  (Start-over reuses the ADR-0005 `abandoned` lifecycle, keeps lifetime stats). **✅ SHIPPED 2026-07-15**
  (dev build, macOS-verified) — review approved (0 Blocking), privacy PASS, tests **green 1235/1235**;
  in [done/](done/journey-reset.md).
- _More UI/UX-refinement slices: TBD — capture with `/capture-idea <slug>` as they're defined._

### Now (history) — Wave 2 (v2), STARTED 2026-06-24
- **mini-window** — ✅ SHIPPED 2026-06-24 (macOS-verified). ⚠️ Windows tray-icon authoring + Windows
  runtime, macOS manual legs, fps, runtime-privacy carried before public/Windows release (see
  [done/mini-window.md](done/mini-window.md)).
- **idle-accounting** — idle counts from when it shows Idle/Paused + record active/idle route segments
  · [blocked by: journey-engine ✅]. **✅ SHIPPED 2026-06-24** (Option B; 602/602; privacy PASS) — in
  [done/](done/idle-accounting.md). ⚠️ Carry to #7: persist `idleSince` (S-3); segment day-key (S-1).
- **journey-scene-v2** — winding road · 3× slower scroll · keep animating when visible-but-unfocused ·
  richer scenery · even spacing · [blocked by: journey-view ✅]. **✅ SHIPPED 2026-06-24 (dev build)** (642
  tests; macOS occlusion / Windows fallback) — in [done/](done/journey-scene-v2.md). ⚠️ Pre-public: AC-8
  beach/animals (TC-M4), on-device fps + occlusion legs. (POV #2 → `journey-pov`.)
- **journey-pov** — first-person cockpit foreground (car windshield / motorbike handlebars), stylized-flat,
  car+motorbike only (#2, carved out of journey-scene-v2) · [blocked by: journey-scene-v2 ✅]. **✅ SHIPPED
  2026-06-25 (dev build)** — 17 ACs + 3 NFRs; `cockpit_painter.dart` foreground (framing 0.36); 4 CC BY 3.0
  glyphs + 3 procedural shapes; **948/948 green**; review **approved** · privacy **pass** — in
  [done/](done/journey-pov.md). ⚠️ Pre-public/Windows: real-OS PiP (AC-12), art-cohesion (AC-16), fps
  (NFR-1), silhouette visual (NFR-3), Windows runtime.
- **map-experience** — map overlay on journey tab + tap→fullscreen, drop Map tab · idle drawn red ·
  real geography (absorbs `map-geographic` = `flutter_map` + OSM tiles) · [blocked by: route-progress ✅,
  idle-accounting ✅]. **✅ SHIPPED 2026-06-25 (dev build, macOS-verified)** — 12 ACs + 3 NFRs; ADR-0004;
  ~91 new tests; **730/730 green**; review ready · privacy PASS — in [done/](done/map-experience.md).
  ⚠️ Pre-public/Windows: real tiles (TC-M1/2), fps (TC-M-NF1), a11y (TC-M3/4), runtime egress (TC-M-PRIV),
  Windows runtime. **Provides the geography model `route-planner-v2` now consumes.**
- **route-planner-v2** — many start/end provinces · multi-stop + auto-insert + review-before-start ·
  stop & start a new journey · [blocked by: route-progress ✅, map-experience ✅]. **✅ SHIPPED 2026-06-25
  (dev build, macOS-verified)** — 12 ACs + 3 NFRs; ADR-0005 (sub-chain model); **877/877 green**; review
  ready · privacy PASS — in [done/](done/route-planner-v2.md). ⚠️ Pre-public/Windows: fps (TC-M-NF1),
  a11y screen-reader (TC-M-A11Y), runtime egress (TC-M-PRIV), Windows runtime.
- **journey-energy-model** — per-mode speeds + energy/fuel strategy · [blocked by: journey-engine ✅]. Not started (deferred, see Later).

> ✅ **Wave 2 feature wave shipped in this order:** idle-accounting ‖ journey-scene-v2 → mini-window →
> map-experience → route-planner-v2 → **journey-pov** (2026-06-25, the POV-reframing extra closed the wave).
> All Wave-2 slices are in [done/](done/); `active/` is empty.

### Next — `visual-polish` EPIC (framed 2026-06-25, Wave 1 ready to promote)
Beautify + dynamic-drive + vehicle-choice, from Kevin's expanded asks. Epic: [backlog/visual-polish.md](backlog/visual-polish.md).
Decisions taken at capture: vehicle pick = **cosmetic-only override**; F1-curve + lean = **two slices**.
- **Wave 1:** journey-scene-art-v3 — hi-res cohesive scene + scenery art, closed the journey-scene-v2 AC-8
  beach/animals gap. `[blocked by: journey-pov ✅]` **✅ SHIPPED 2026-06-25 (dev build, macOS-verified)** —
  green 465/465, in [done/](done/journey-scene-art-v3.md).
- **Wave 2:** journey-dynamic-curve — F1-style sweeping/animated bends. **✅ SHIPPED 2026-06-25 (dev build,
  macOS-verified)** — green 182/182, arc-length-aware cadence (ADR-0006), in [done/](done/journey-dynamic-curve.md).
  · then [journey-cockpit-lean](backlog/journey-cockpit-lean.md) — cockpit tilts into the curve,
  reduce-motion-gated, **now unblocked** `[blocked by: journey-dynamic-curve ✅]`.
- **Wave 3:** [vehicle-picker](backlog/vehicle-picker.md) — cosmetic vehicle chooser + persisted preference
  `[blocked by: precedence ADR]` (write with `/add-adr` first).

### Later
- **`journey-energy-model`** (per-mode speeds) — note the forward-dependency: `vehicle-picker`'s cosmetic-only
  contract must hold even after this lands (a user pick must never change accrual).
- **`signed-distribution`** (Apple signing/notarization + installer) — for any public release.

> **Scope guardrail (2026-07-15, Kevin):** local, single-user product only — no team, online, leaderboard,
> or AI-coach features. Any such idea is explicitly out of scope; do not add it to a wave.

---

## Carried before any public / Windows release (NOT blocking the dev build)
Tracked per slice in [done/](done/); clear before the respective public release:
- **activity-detection (L3):** Windows runtime never verified (no device / MSVC-blocked); manual checklist 0/6.
- **journey-view:** on-device fps (TC-015/016) unmeasured; polish P-1/P-2.
- **route-progress:** on-device fps (TC-NF2) unmeasured.
- **local-stats:** TC-022 runtime privacy socket-check; TC-NF5 real-OS launch/toast legs; MSIX identity TODO.
- **mini-window:** Windows tray-icon authoring + Windows runtime (NFR-9); macOS manual legs TC-M1..M4;
  NFR-2 fps; runtime privacy (TC-022 / TC-M-PRIV).
- **journey-scene-v2:** **AC-8 beach/coast + side-view animals omitted** (no license-clean cohesive asset)
  → TC-M4 human content sign-off; on-device real occlusion per OS (TC-M1/2/3) + **Windows occlusion is
  fallback-only** (pauses on minimized/hidden, not on cover-by-other-window); ≥30fps both surfaces (TC-M-NF1);
  TC-M-PRIV runtime privacy. Non-blocking test follow-ups: native `stop` contract (S2), reduce-motion loop-pause (S5).
- **map-experience:** AC-11 real OSM tile round-trip + real offline/airplane-mode (TC-M1/2); NFR-1 ≥30fps
  macOS+Windows incl. inline↔full-screen (TC-M-NF1); NFR-3 colour-blind perception (TC-M3) + real
  screen-reader (TC-M4); NFR-2 runtime egress packet-capture — only anonymous OSM tile GETs leave (TC-M-PRIV);
  **Windows runtime never verified** (`flutter_map` desktop tile render/cache/perf unconfirmed on Windows).
  Non-gating cleanup: `route_map_painter.dart` now production-orphaned.
- **route-planner-v2:** NFR-1 ≥30fps picker/review/auto-insert macOS+Windows (TC-M-NF1); NFR-3 real
  screen-reader + keyboard-only picker/review/abandon (TC-M-A11Y); NFR-2 runtime-egress capture confirming
  zero new outbound traffic (TC-M-PRIV); **Windows runtime never verified**. Non-gating: unbounded
  idle/active segment growth across abandon cycles → future `journey-engine` bounded-segment-store slug
  (ADR-0005 dec.6); `RoutePosition.percentOfCountry` dual-meaning rename when AC-7 freeze lifts (review L1).
- **journey-scene-art-v3:** NFR-1 on-device ≥30fps both surfaces with the higher-res set (TC-M-NF1; bounded-pool/
  no-alloc proxy green); NFR-2 runtime-egress capture (TC-M-PRIV; `/privacy-audit` static PASS — art-v3 added
  zero deps/capabilities). Non-gating P2 polish: AC-7 seam-vs-renderer curve-weighting code comment; a direct
  net-new (beach/animal) asset-degradation **injection** test (currently proven by analogy). Optional: craft-
  polish pass on the rung-2 original-flat vectors (read flatter than the Remastered scenery; Kevin accepted).
- **journey-pov:** AC-12 real-OS frameless/always-on-top PiP render + occlusion-pause confirmation (TC-M-PIP;
  two-surface logic automated green); AC-16 stylized-flat art-cohesion visual sign-off (TC-M4-ART); NFR-1
  on-device ≥30fps both surfaces (TC-M-NF1; no-alloc/no-new-geometry proxy green); NFR-3 distinct car-vs-
  motorbike silhouette visual leg (reduce-motion half automated). **Windows runtime never verified.**
  Non-blocking review follow-ups: NFR-1 `_drawImageFit` Rect/docstring; AC-13 injected-failure test; AC-5
  occlusion-proxy tightening.

---

## Principles
- **Privacy-first, always.** Read only aggregate idle time; never keystrokes/screen/files. The trust promise is the product.
- **Wave discipline.** Ship a wave before starting the next; each slice is independently shippable.
- **Enhancing a shipped slug = a NEW slug in a later wave** (tagged `[blocked by: …]`) — never re-`/implement` a shipped slug.
- **Validate the loop cheaply.** Local-only v1 before any backend/AI/signing investment.
- **Right-size the process.** Full 5-command loop for features; `/quick-change` for small fixes.
