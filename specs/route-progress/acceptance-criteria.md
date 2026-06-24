# Acceptance criteria

Each item is a checkable, observable statement. If it isn't testable, rewrite it.

> Driven by `specs/route-progress/spec.md`. This slice is a **pure consumer** of the shipped
> `journey-engine`'s cumulative scalar `distanceKm` (mirror of how `journey-view` consumes engine
> state). It owns the *geography* — the ordered province chain, the position math, and the completion
> rule — but adds **zero** activity logic and **zero** new privacy surface.
>
> **Worked-example fixture.** The position-resolution ACs below are written against a small, explicit
> test chain so they are observable and unit-testable. The chain runs Mũi Cà Mau → Hà Giang as an
> ordered list of checkpoints with inter-checkpoint distances (km):
>
> ```
> Mũi Cà Mau ─60→ Cần Thơ ─170→ Đà Lạt ─300→ Đà Nẵng ─310→ Hà Nội ─600→ Hà Giang
>      0          60         230        530        840        1440
> ```
> (cumulative km from the Mũi-Cà-Mau end shown under each node; **total chain length = 1440 km**.
> Segments `[60, 170, 300, 310, 600]` sum to 1440; this makes Đà Nẵng = 470 km and Hà Giang = 1380 km
> from Cần Thơ's start — the load-bearing numbers AC-1 and AC-11 assert. *(Fixture corrected 2026-06-24:
> the prior diagram showed a 300 km final segment + a stray cumulative value, which contradicted those
> asserted distances; segments now sum consistently to the 1440 total.)*)
> These names/distances/total are **illustrative fixtures for the ACs**, not the final tuned data —
> the real list, granularity, and total are open questions (see ⚠ notes). Tests should key off the
> fixture's structure (ordered nodes + segment distances + total), not the literal numbers, so they
> survive re-tuning. "% of country" below is computed **distance-based** = `distanceCovered ÷ totalChainKm`.

## Functional — position resolution (pure mapping of distanceKm → place)

- [x] AC-1 (mid-chain happy path): **Given** the fixture chain, start = `Cần Thơ`, direction = `north`
      (toward Hà Giang), and the engine reports `distanceKm = 400`, **When** the model resolves
      position, **Then** it reports: provinces **passed** = [`Cần Thơ`, `Đà Lạt`] (origin + every
      checkpoint whose cumulative distance from the start ≤ 400), **next province ahead** = `Đà Nẵng`,
      **distance-to-next** = `70 km` (Đà Nẵng is 470 km from Cần Thơ's start position; 470 − 400),
      **current segment** = `Đà Lạt → Đà Nẵng`, and **% of country** = `400 ÷ 1440 ≈ 27.8%`.
      *(The start node itself counts as already reached/passed; `distance-to-next` is always the
      remaining km to the next un-passed checkpoint.)*

- [x] AC-2 (distance = 0, at the start): **Given** start = `Cần Thơ` heading `north` and
      `distanceKm = 0`, **When** the model resolves position, **Then** provinces **passed** = [`Cần Thơ`]
      (the origin only), **next ahead** = `Đà Lạt`, **distance-to-next** = `170 km`, **current segment**
      = `Cần Thơ → Đà Lạt`, **% of country** = `0%`, and the route state is **in-progress** (not
      completed). The current-position marker sits exactly on the start pin.

- [x] AC-3 (distance lands exactly on a checkpoint): **Given** start = `Cần Thơ` heading `north` and
      `distanceKm = 170` (exactly the Cần Thơ→Đà Lạt segment), **When** the model resolves position,
      **Then** `Đà Lạt` is reported as **passed/reached** (a checkpoint reached at exactly its distance
      counts as passed), **next ahead** = `Đà Nẵng`, **distance-to-next** = `300 km`, **current
      segment** = `Đà Lạt → Đà Nẵng`. The model is deterministic at the boundary: the same input always
      yields the same classification (no flicker between segments). The boundary **rule** ("reached at
      exactly its distance = passed; `next` advances to the following checkpoint") is fixed; the literal
      node distances follow the curated ~10–15-checkpoint chain (granularity resolved 2026-06-24).

- [x] AC-4 (just before a checkpoint): **Given** start = `Cần Thơ` heading `north` and
      `distanceKm = 169` (1 km short of Đà Lạt), **When** the model resolves position, **Then** `Đà Lạt`
      is **not yet** passed, **next ahead** = `Đà Lạt`, **distance-to-next** = `1 km`, **current
      segment** = `Cần Thơ → Đà Lạt`, and **% of country** = `169 ÷ 1440 ≈ 11.7%`.

- [x] AC-5 (just after a checkpoint): **Given** start = `Cần Thơ` heading `north` and
      `distanceKm = 171` (1 km past Đà Lạt), **When** the model resolves position, **Then** `Đà Lạt`
      **is** passed, **next ahead** = `Đà Nẵng`, **distance-to-next** = `299 km`, **current segment** =
      `Đà Lạt → Đà Nẵng`. (AC-4 → AC-3 → AC-5 across 169 / 170 / 171 km demonstrate the boundary
      transition is monotonic and off-by-one-safe.)

- [x] AC-6 (monotonic advance with increasing distance): **Given** a fixed start + direction, **When**
      the model is fed a strictly increasing sequence of `distanceKm` values, **Then** the count of
      provinces passed is non-decreasing, % of country is non-decreasing, and the current-position
      marker only ever moves toward the destination — it never moves backward for a forward distance
      change.

## Functional — direction handling

- [x] AC-7 (south is the mirror of north from the same start): **Given** the same start = `Đà Nẵng`,
      **When** direction = `south` (toward Mũi Cà Mau) and `distanceKm = 300`, **Then** the model
      walks the chain in the **opposite** order: provinces **passed** = [`Đà Nẵng`, `Đà Lạt`] (Đà Lạt is
      300 km south of Đà Nẵng), **next ahead** = `Cần Thơ`, **distance-to-next** = `170 km`, **current
      segment** = `Đà Lạt → Cần Thơ`. The same start + same distance with direction = `north` instead
      yields the mirror result: passed = [`Đà Nẵng`, `Đà Nẵng→ +300 toward Hà Nội` … i.e. `Hà Nội`],
      next ahead = `Hà Giang`. The only difference between the two runs is the traversal direction;
      the position math is otherwise identical.

- [x] AC-8 (direction sets which tip is the destination): **Given** start = `Đà Lạt`, **Then**
      direction = `north` makes `Hà Giang` the completion target and `Mũi Cà Mau` unreachable; direction
      = `south` makes `Mũi Cà Mau` the completion target and `Hà Giang` unreachable. % of country and
      distance-to-completion are computed against the chosen direction's remaining chain, not the whole
      country span behind the start.
      ✅ **Resolved (Kevin, 2026-06-24):** % of country is **distance-based against the full chain** —
      `routeDistanceKm ÷ totalChainKm`, capped at 100% (NOT the chosen-direction span). The fixture uses
      full-chain `1440` here; production uses `totalChainKm ≈ 2000` (see chain-data NFR).

## Functional — selection persistence

- [x] AC-9 (start + direction persist across restart): **Given** the user has selected start = `Cần Thơ`
      and direction = `north`, **When** the app is closed and relaunched, **Then** the same start +
      direction are restored (read from the existing `shared_preferences`/JSON repository seam) and the
      map resolves the current `distanceKm` against that restored selection — the user is never silently
      reset to a default start/direction. No new persistence store is introduced.

- [x] AC-10 (route-completion state persists across restart): **Given** a route that has reached
      **completed** (AC-11) before the app closes, **When** the app relaunches, **Then** the route is
      still reported as completed (with its summary available) and does **not** revert to in-progress or
      auto-start a new route.

## Functional — route completion

- [x] AC-11 (reaching the chain end → completed + celebration + summary): **Given** start = `Cần Thơ`
      heading `north` (destination tip = `Hà Giang`, 1380 km from Cần Thơ's start position in the
      fixture), **When** the route's `routeDistanceKm` reaches or exceeds that distance-to-destination,
      **Then** the route enters a **completed** state, `Hà Giang` is reported as reached, and a
      **celebration + summary** is shown (e.g. provinces crossed and total distance/time for the route).
      ✅ **Resolved (Kevin, 2026-06-24): completion fires on ARRIVAL at the chosen destination tip — NOT
      on % = 100%.** Per decision 3, % of country is full-chain (`routeDistanceKm ÷ totalChainKm`,
      capped 100%), so a route that *started mid-chain* completes at **< 100%** (this fixture: 1380 ÷ 1440
      ≈ **95.8%**) — the honest fraction of Vietnam crossed. Only a full tip-to-tip route (e.g. Mũi Cà Mau →
      Hà Giang, AC covered by TC-011's tip leg) reaches **100%**. The celebration reads "You've reached
      Hà Giang", not "100%".

- [x] AC-12 (completion retains progress — no rollback): **Given** the route is completed, **Then**
      cumulative progress is **retained** (the model does not zero or roll back `distanceKm`, and a
      relaunch still shows the completed route — AC-10). Distance beyond the destination is clamped to
      the destination for display (position never overshoots the final pin), but the underlying
      cumulative `distanceKm` owned by the engine is untouched.

- [x] AC-13 (no auto-advance — waits for explicit user choice): **Given** the route is completed,
      **When** the engine continues to report increasing `distanceKm` (the user keeps focusing),
      **Then** the model makes **no further forward progress** on the chain and does **not** start a new
      route, pick a new start, or reverse direction on its own — it stays at the completed destination
      until the user makes an **explicit** choice to continue (e.g. choosing a new start/direction).
      Completion is terminal until that explicit action.

- [x] AC-14 (new start after completion is an explicit user action — per-route offset): **Given** a
      completed route, **When** the user explicitly selects a new start + direction, **Then** the model
      captures the engine's current cumulative `distanceKm` as the new `routeStartOffset` and begins
      resolving the new route from `routeDistanceKm = engine.distanceKm − routeStartOffset = 0` — i.e. the
      new route starts at distance 0 even though the engine's cumulative `distanceKm` keeps climbing
      unbroken. ✅ **Resolved (Kevin, 2026-06-24): per-route offset; the shipped engine is NEVER reset.**
      The engine's cumulative `distanceKm` is preserved as a free **lifetime total**. All position math in
      AC-1..AC-13 operates on `routeDistanceKm` (cumulative − offset), not raw cumulative. For the very
      first route the offset is the cumulative distance at first start (typically 0).

## Functional — chain-tip / off-direction selection

- [x] AC-15 (off-direction tip selection is blocked): **Given** the start picker, **When** the user
      selects a chain-tip province pointed off the chain (e.g. start = `Hà Giang` with direction =
      `north`, or start = `Mũi Cà Mau` with direction = `south`), **Then** that selection is **blocked**
      in the picker (the invalid direction is disabled/unavailable for that tip) so a route can never
      begin already-finished. The model never enters a state with zero reachable checkpoints ahead at
      `distanceKm = 0`.
      ✅ **Resolved (Kevin, 2026-06-24): block in the picker.** The off-chain direction for a tip province
      is disabled/unavailable in the start picker; the model never enters a zero-checkpoints-ahead state at
      `routeDistanceKm = 0`. (Instant-complete was rejected.)

## Functional — purity / privacy invariant

- [x] AC-16 (reads only `distanceKm` — separation invariant, code inspection): **Given** the
      route-progress source, **When** inspected, **Then** it reads **only** the engine's cumulative
      `distanceKm` (via the journey Bloc / engine seam) plus its own persisted start/direction selection
      — it makes **no** call to `ActivityPlugin`, `getSystemIdleSeconds()`, `isScreenLocked()`, no
      platform channel, no idle/lock/sleep/OS API, and contains **no** active-vs-idle decision logic and
      **no** distance-accrual logic. Verifiable by static inspection (no such imports/calls present in
      the slice's files). Mirrors `journey-view` AC-9.

- [x] AC-17 (accrues no distance / owns no engine state): **Given** the model is running, **Then** it
      never mutates or computes `distanceKm`, `activeTimeToday`, `rawActiveTime`, `idleTimeToday`, or the
      engine `state`; it only *consumes* `distanceKm` and maps it onto the chain. Verifiable by code
      inspection — no writes to engine/journey state originate in route-progress. Mirrors `journey-view`
      AC-10.

- [x] AC-18 (no new privacy surface): **Given** the slice, **When** audited, **Then** it introduces
      **no** dependency that reads input / screen / clipboard / files / network, and adds **no** OS
      surface beyond what `journey-engine` / `activity-detection` already audited. The custom-painted map
      uses **no** network or tile provider. Passes a `/privacy-audit` (`privacy-guardian`) review.

## Non-functional

- [x] Determinism: position resolution is a **pure function** of `(distanceKm, start, direction, chain
      data)` — no timers, no `DateTime.now()`, no Flutter, no I/O. The same inputs always produce the
      same passed/ahead/next/distance-to-next/segment/% outputs. Fully unit-testable with no real time
      passing (mirrors the engine's framework-free testability constraint).

- [x] Performance — smooth custom-painted map: the `CustomPainter`-based map (province-chain polyline,
      checkpoint pins, start pin, current-position marker, destination pin) renders smoothly on a
      typical desktop (macOS + Windows) — no sustained jank as the position marker advances; redraws are
      bounded (no per-frame allocation of the static chain geometry in the paint hot path).
      ✅ **Resolved (Kevin, 2026-06-24): curated subset (~10–15 major checkpoints)** along the
      Mũi Cà Mau → Hà Giang spine — not all 63 provinces — keeping pins/labels legible and paint cheap.
      ⏳ **Partially verified / carry-over (left unticked):** the *bounded-redraw* half is verified
      deterministically — `RouteMapGeometry` is value-equal and a `BlocSelector`/`buildWhen` gates the
      1 Hz distance ticks, so static chain geometry is not reallocated per frame (self-review fix; covered
      by `route_separation_static_test.dart` + the geometry equality test). The *on-device frame-rate*
      half (TC-NF2 — "no sustained jank / ≥ target fps as the marker advances") is **NOT instrumented**;
      the project's golden/perf infra is deferred (same posture as the shipped `journey-view` fps NFR).
      **Measure on macOS + Windows before any public release.** Owner: `test-executor` + `flutter-app-developer`.

- [x] No network / offline: the slice makes **no** network call and depends on **no** tile provider or
      external map service — the map is entirely local/offline (custom-painted). (`flutter_map` + OSM
      tiles is v2 `map-geographic`.)

- [x] Chain-data integrity: the province-chain fixture/asset is internally consistent — strictly ordered
      Mũi Cà Mau → Hà Giang, every adjacent pair has a positive inter-checkpoint distance, and the sum of
      segment distances equals the declared `totalChainKm`. The total chain length is the **source of
      truth** that confirms the engine's `kmPerActiveHour` (total ÷ ~8 active hours).
      ✅ **Resolved (Kevin, 2026-06-24): route-progress owns `totalChainKm ≈ 2000 km`**; the engine takes
      `kmPerActiveHour` as **injected config**, defaulting to `2000 ÷ ~8h = 250` (== the engine's shipped
      placeholder), so no engine retune is needed. The `1440` in the AC fixture is illustrative only; the
      production total is the curated subset's summed segments (≈ 2000). The literal stays tunable for
      playtest without changing code shape.

## Out of scope (reminder)

- **Distance accrual / activity logic** — owned by the shipped `journey-engine`; this slice only
  *reads* `distanceKm`. It never reads idle seconds, lock, or sleep, and never decides active vs idle.
- **Live map tiles / real geographic maps** — `flutter_map` + OSM tiles is v2 (`map-geographic`).
  v1 is custom-painted only; no tile provider, no network.
- **The POV road scene** — that is `journey-view` (shipped); this is the separate map/overview surface.
- **Stats / streaks / badges / settings / onboarding** — that is `local-stats`. Milestone *badges* for
  reaching provinces live there; this slice only exposes the position they would consume.
- **Per-mode speeds / energy** — v2 (`journey-energy-model`). v1 is speed-only; `mode` is cosmetic.
- **Multi-route / lifetime-aggregate journeys, real Vietnam GIS coordinates** — v1 chain is a stylized
  ordered list with flavour distances, not survey-accurate geography.
- **Resetting / owning the engine's cumulative `distanceKm`** — that is an engine seam (see AC-14's
  open question); route-progress does not unilaterally reset engine state.
