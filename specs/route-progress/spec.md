# Route Progress (Vietnam province chain + custom-painted map)

**Status:** shipped (2026-06-24)
**Owner:** Kevin (Tuyen Vo)
**Last updated:** 2026-06-24 (shipped — Wave 1 / v1; green report `20260624-113456`)

## Problem
The shipped `journey-engine` produces a single honest scalar: cumulative `distanceKm`. That number is
*motion*, but it carries no **place**. Vietnam Focus Journey's whole promise is "your focus walks you up
(or down) Vietnam" — so something has to turn `distanceKm` into *"you have left Cần Thơ, you're 18 km
short of Đà Nẵng, and you've covered 41% of the country."* Without that mapping, the user sees a number
climbing but never feels they are *somewhere*, and never gets the payoff of arriving.

This slice is the **route/progress model + its custom-painted map screen**. It models Vietnam as one
continuous, ordered **province chain** (Mũi Cà Mau ⇄ Hà Giang) with inter-province distances. The user
picks a **start province** and a **direction** (toward Hà Giang = "north", toward Mũi Cà Mau = "south").
Given the engine's cumulative `distanceKm`, the model resolves the traveller's position along the chain —
which provinces are **behind**, which are **ahead**, the **distance to the next** province, and the
**percentage of the country** covered — and renders it on a **custom-painted** map (a stylized
province-chain polyline with checkpoint pins; **no live map tiles in v1**, so no tile-provider/OSM
dependency). When the traveller reaches the far end of the chosen direction, the route **completes**:
a celebration + summary appears, progress is retained, and the journey **waits for an explicit user
choice** — there is no auto-advance onto a new route.

Crucially this slice is a **pure consumer of engine distance**, exactly as `journey-view` is a pure
consumer of engine motion. It owns the *geography* (chain data, position math, completion rule) but adds
**zero** activity logic and **zero** new privacy surface: it never reads idle seconds, never decides
active vs idle, never accrues distance itself. The single source of truth for "how far" stays in the
engine; this slice only answers "where does that distance put me on the map."

## User & outcome
- **The focused individual** (developer / student / remote worker) — the primary beneficiary. They get a
  *sense of place and progress*: a map showing where they started, how far they've come, the next
  province coming up, and how much of Vietnam remains. Success = at a glance they can see their position
  advance as they focus, and reaching the end of the chain feels like an *arrival* (celebration +
  summary), not just a counter ticking over.
- **The privacy-skeptical teammate** — benefits indirectly: this slice reads only the engine's
  `distanceKm` (and persists the user's start/direction choice). A glance at the code shows it touches no
  OS signal and no input data — it adds no privacy surface beyond what `journey-engine` already audited.

**Observable success:** given a chosen start province + direction and a sequence of increasing
`distanceKm` values from the engine, the model reports the correct **provinces passed**, **province
ahead**, **distance to next**, and **% of country**, and the custom-painted map reflects that position.
Feeding it enough distance to reach the chain end transitions the route to **completed**, shows the
celebration + summary, retains progress, and makes no further forward progress until the user chooses to
continue. Start/direction selection persists across an app restart.

## Scope
### In
- **Province-chain domain model** — Vietnam as one ordered list of province/city checkpoints from Mũi Cà
  Mau to Hà Giang, with the **inter-province distance (km)** between each adjacent pair. This data is the
  **source of truth for total chain length**, which (÷ ~8 active hours) confirms the engine's
  `kmPerActiveHour` (see the journey-engine open seam). Data lives as a static asset/constant in the
  *domain*/*data* layer; values are tunable.
- **Start-province + direction selection** — the user picks an origin province from the chain and a
  direction (toward Hà Giang / toward Mũi Cà Mau). Persisted locally (via the existing repository seam /
  `shared_preferences`) so it survives restart.
- **Position resolution (pure function of distance)** — map cumulative `distanceKm` + start + direction
  onto the chain to produce: **provinces behind** (passed), the **next province ahead**, **distance
  remaining to the next province**, the **current segment**, and **% of the full chain covered**. A pure,
  deterministic, unit-testable mapping — no timers, no Flutter.
- **Custom-painted map screen** — a stylized rendering of the province chain (polyline + checkpoint pins,
  start pin, current-position marker, destination pin) showing passed-vs-ahead state and a "next: <province>
  in N km" / "% of country" readout. `CustomPainter`-based; **no live tiles, no network**.
- **Route completion** — when distance reaches the chain end in the chosen direction: enter a
  **completed** state, show a **celebration + summary** (e.g. provinces crossed, total distance/time),
  **retain** cumulative progress, and **wait for an explicit user choice** to continue (no auto-advance,
  no automatic new route).
- **Chain-tip / off-direction handling** — choosing a start at a chain tip pointed off the chain (e.g.
  start = Hà Giang, direction = north) must be handled deterministically (block the invalid selection
  **or** instant-complete — decision in Open questions).

### Out
- **Distance accrual / activity logic** — owned by the shipped `journey-engine`; this slice only *reads*
  `distanceKm`. It never reads idle seconds or decides motion.
- **Live map tiles / real geographic maps** — `flutter_map` + OSM tiles is **v2 (`map-geographic`)**. v1
  is custom-painted only.
- **The POV road scene** — that is `journey-view` (shipped). This slice is the *map/overview* screen, a
  different surface from the first-person road.
- **Stats / streaks / badges / settings / onboarding** — that is `local-stats`. (Milestone *badges* for
  reaching provinces, if any, live there; this slice exposes the position they'd consume.)
- **Per-mode speeds / energy** — v2 (`journey-energy-model`). v1 is speed-only; mode is cosmetic.
- **Multi-route / lifetime-aggregate journeys, real Vietnam GIS coordinates** — v1 chain is a stylized
  ordered list with flavour distances, not survey-accurate geography.

## Constraints & assumptions
- **Pure consumer of engine state (hard constraint).** Reads `JourneyEngine.distanceKm`; adds no
  activity logic and no new privacy surface. Position resolution is a pure function of (distance, start,
  direction, chain data) — deterministic and unit-testable with no timers/Flutter.
- **No network in v1.** Custom-painted map only; no tile provider, no OSM policy risk.
- **Stack per `docs/architecture/overview.md`** — Flutter desktop, Bloc, Clean Architecture. Chain data +
  position math are *domain*; persistence of start/direction is *data*; the map screen + any Cubit/Bloc
  are *presentation*.
- **Persistence reuses the existing seam** — start province + direction (and route-completion state) save
  via the established `shared_preferences`/JSON repository pattern, not a new store.
- **Chain length is the rate's source of truth.** Total chain km ÷ ~8 active hours tunes/confirms the
  engine's `kmPerActiveHour` (shipped placeholder default 250). This slice owns the number; the seam must
  be agreed so engine and route agree (journey-engine carried this as an open follow-up).
- **Completion is terminal until user choice.** No auto-advance; cumulative progress is retained; a new
  start after completion is an explicit user action.

> **Superseded by ADR-0005 (2026-06-25):** the **single fixed full-spine chain + (start province, binary
> N/S direction) selection** model below, and the **terminal-only completion lifecycle** ("completion is
> terminal until the user chooses"; no mid-route abandon), are superseded by `route-planner-v2`. A route is
> now a user-authored **contiguous sub-chain** with a 3-state lifecycle (`active`/`completed`/`abandoned`).
> The `routeStartOffset`/engine-never-reset primitive (decision 1), the block-invalid-in-picker rule
> (decision 3), and the full-chain % denominator (decision 5) are **retained and reused** by ADR-0005.

## Resolved decisions (Kevin, 2026-06-24 — at spec approval)
1. **New start after completion ⇒ per-route offset; engine is never reset.** route-progress stores a
   `routeStartOffset` (the engine's cumulative `distanceKm` at the moment a route begins) and computes
   `routeDistanceKm = engine.distanceKm − routeStartOffset`. The shipped `journey-engine` is **not**
   modified — no reset API. The engine's cumulative `distanceKm` doubles as a free **lifetime total**.
   Position math keys off `routeDistanceKm`, not raw cumulative. *(Resolves the AC-14 / data-model seam —
   no shipped-engine change.)*
2. **`kmPerActiveHour` ↔ chain-total seam:** route-progress **owns `totalChainKm` (≈ 2000 km**, ≈ the real
   Vietnam N–S road span). Rate `= totalChainKm ÷ ~8 active hours = 250 km/active-hour`, which **equals the
   engine's shipped placeholder default**, so the engine needs **no retune** — it simply takes
   `kmPerActiveHour` as **injected config** (250 stays its fallback). The literal total stays a tunable
   constant; playtest may adjust it without changing code shape. *(Closes the journey-engine carried
   follow-up.)*
3. **Chain-tip off-direction ⇒ block in the picker.** A tip province's off-chain direction is
   disabled/unavailable, so a route can never begin already-finished; the model never enters a
   zero-checkpoints-ahead state at `distanceKm = 0`.
4. **Province granularity ⇒ curated subset (~10–15 major checkpoints)** along the Mũi Cà Mau → Hà Giang
   spine — legible on the painted map and cheap to render. Not all 63 administrative provinces in v1.
5. **% of country ⇒ distance-based against the full chain:** `routeDistanceKm` (covered) `÷ totalChainKm`,
   capped at 100%. (Distance-based for honesty with the engine; full-chain denominator, not the
   chosen-direction span.)

## Open questions
> All five open questions were **resolved by Kevin at spec approval (2026-06-24)** — see **Resolved
> decisions** above. No open items remain blocking implementation.
- [x] Chain-tip off-direction selection — **block in the picker** (decision 3).
- [x] New start after completion — **per-route offset; engine never reset** (decision 1).
- [x] v1 total chain length & `kmPerActiveHour` — **route owns `totalChainKm ≈ 2000`; rate 250 injected**
      (decision 2).
- [x] Province list granularity — **curated subset ~10–15 checkpoints** (decision 4).
- [x] % of country basis — **distance-based, full-chain denominator, capped 100%** (decision 5).

## Related
- Epic: [planning/backlog/vietnam-focus-journey.md](../../planning/backlog/vietnam-focus-journey.md) · Wave 1 (v1)
- Backlog slice: [planning/backlog/route-progress.md](../../planning/backlog/route-progress.md)
- Upstream (shipped): [specs/journey-engine/spec.md](../journey-engine/spec.md) — provides cumulative `distanceKm`
- Sibling consumer (shipped): [specs/journey-view/spec.md](../journey-view/spec.md) — the pure-consumer pattern this slice mirrors
- Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md)
- Architecture: [docs/architecture/overview.md](../../docs/architecture/overview.md) — "Route/progress model" in Components; ADR-0002 (stack)
