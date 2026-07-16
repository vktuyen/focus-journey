# ADR-0005: Custom multi-checkpoint routes via derived sub-chains + stop-and-restart lifecycle

- Status: accepted
- Date: 2026-06-25
- Deciders: Kevin (Tuyen Vo) / system-architect

## Context

> This ADR **supersedes two assumptions** baked into the shipped `route-progress` slice (which were
> recorded only in that spec, never as a standalone accepted ADR):
> 1. its **single fixed full-spine chain + (start province, binary N/S direction)** selection model, and
> 2. its **terminal-only completion lifecycle** — "completion is terminal until the user chooses"
>    (`route-progress` decision 1 + Scope) which **never contemplated abandoning a route mid-journey**.
>
> It does **not** supersede ADR-0002 (Flutter/Bloc/Flame stack), ADR-0003 (single-window two-mode), or
> ADR-0004 (OSM tiles + canonical-km `RoutePolylineProjector`). It **builds on** ADR-0004's single
> canonical-km axis and `route-progress` decision 1 (`routeStartOffset`; engine never reset), and reuses
> `route-progress` decision 3 (block invalid selection in the picker) and decision 5 (full-chain %).

The approved `route-planner-v2` spec (12 ACs + 3 NFRs) gives the user **authorship of the route**: pick any
start + any end on the curated ~10–15-checkpoint spine, mark optional stops the app auto-fills, review and
edit the resolved ordered route before committing, and abandon a route mid-journey to start a fresh one
without losing lifetime distance. This is the tail of Wave 2 and consumes — never re-derives — the static
province geography shipped by `map-experience`.

The gating forces:

- **AC-7 (hard / position-invariant preservation):** the **unchanged** `RouteProgressResolver` +
  `RoutePolylineProjector` must compute position over the **authored ordered checkpoint list**, preserving
  ADR-0004's single canonical-km axis — no second distance axis, no second geography definition.
- **AC-11 + AC-12 (no-bleed across an abandon, survives restart):** an abandoned route's idle/active
  segments must never paint on the new route's red trace, and an active custom route must survive a restart
  via the existing `shared_preferences`/JSON seam (no new store).
- **NFR-2 (CRITICAL / gating):** selection + auto-insert read **only** static reference geography — no
  device location, no GPS, no new network egress beyond ADR-0004's OSM tiles. `/privacy-audit` stays PASS.

Verification against the shipped code confirmed the recommended design is achievable without touching the
resolver/projector/mapper internals:

- `ProvinceChain`'s constructor accepts **any** ordered ≥2-node south→north subset with strictly-positive
  segments and derives `totalChainKm` from the segments (`province_chain.dart:30-89`).
- `ProvinceGeography` validates against *its* chain's nodes and exposes `coordinateOf` per province
  (`province_geography.dart:71-122`) — coordinates already exist for every spine node.
- `RouteProgressResolver.resolve` and `RoutePolylineProjector` derive everything structurally from the
  `(chain, geography, start, direction)` they are handed — neither hard-codes the full spine
  (`route_progress_resolver.dart`, `route_polyline_projector.dart`).
- `IdleTraceMapper.resolve` already re-bases by `routeStartOffsetKm` and **clips to `[0, routeLengthKm]`**,
  dropping out-of-window segments (`idle_trace_mapper.dart:82-104`).

## Decision

**Represent a user-authored route as a derived contiguous SUB-CHAIN of the curated spine, run the
unchanged resolver/projector/mapper over it, and model abandon as a distinct terminal state that stamps a
new `routeStartOffset` over the never-reset engine distance.**

### (1) Custom route = a derived sub-chain (the key decision) — RATIFIED.

A custom route is the inclusive `[start..end]` slice of the curated spine, materialised as a **smaller
`ProvinceChain`** (sub-list of nodes + the corresponding sub-list of `segmentsKm`) plus a derived
`ProvinceGeography` sub-view built from the existing coordinate lookup, plus a `(start = one tip,
direction = toward the other tip)` pair. Because both value objects already accept any ordered south→north
subset with strictly-positive segments, the existing `RouteProgressResolver`, `RoutePolylineProjector`, and
`IdleTraceMapper` then run **literally unchanged** over the sub-chain — directly satisfying AC-7 and
preserving ADR-0004's single canonical-km axis. The sub-chain's `totalChainKm` **is** the route's
`subPathKm` (AC-8) by construction (it is the sum of its own segments).

- **Rejected:** generalising the resolver to take an arbitrary checkpoint list (the sub-chain *is* the
  generalisation — it needs no resolver change, which is the whole point of AC-7's "unchanged").
- **Rejected:** parallel/branching chains — they would break the single position axis, and no branching
  geography exists (the spine is linear; Scope/Out).
- **Consequence (confirmed):** removing an interior stop on the review screen (AC-5) must **merge its two
  adjacent segments (sum their km)** when re-deriving the sub-chain, so total distance and the canonical
  axis are preserved and the polyline draws straight between the surviving neighbours. (The endpoints'
  coordinates are unchanged; only the dropped node's coordinate disappears, which is exactly the straight
  draw `RoutePolylineProjector.baseRoutePolyline` already produces from the surviving node list.)

### (2) Auto-insert = a pure, deterministic, Flutter-free domain function — RATIFIED.

A new domain function (e.g. `RoutePlanner.resolveSubChain`) with the signature
`(fullChain, fullGeography, startProvince, endProvince, markedStops) → (ProvinceChain subChain,
ProvinceGeography subGeography)`, living in `features/route/domain/` alongside `RouteProgressResolver`,
mirroring its purity (no Flutter, no timers, no I/O). It reads **only** the static `fullChain`/`fullGeography`
(NFR-2). Behaviour:

- intermediates are the spine checkpoints strictly between the extreme picks, in **spine order** (AC-3);
- a marked stop **outside** the `[start, end]` span **extends the span** to include it, the stop becoming
  the new extreme endpoint in its direction (AC-4 — confirmed);
- the result is always a single contiguous spine sub-path of ≥2 adjacent nodes (AC-1/AC-2);
- it never re-orders, forks, or re-derives geography (build-once-consume-many).

The review screen's edit/remove (AC-5) re-invokes this same function (or its segment-merge variant for
interior removal), so a re-resolve is a pure in-memory recompute (NFR-1: well within one frame).

### (3) route % vs country % (AC-8) — RATIFIED, with explicit layer ownership.

- **route %** = the resolver-over-sub-chain's existing `percentOfCountry` output, which over a sub-chain
  **naturally becomes** `effectiveDistance ÷ subPathKm` (its denominator is the sub-chain's own
  `totalChainKm`). No resolver change. The domain layer (resolver) owns route %.
- **country %** = `(canonicalOriginKm + effectiveDistance) ÷ fullChainTotalKm`, where `canonicalOriginKm`
  is the cumulative-from-south-tip km of the sub-chain's origin on the **full** chain. This is computed at
  the **presentation/cubit layer** (`RouteProgressCubit`/`MapCubit`), which is the layer that holds the
  full chain (it is constructed with `vietnamProvinceChain` — `main.dart:237`) alongside the active
  sub-chain. The resolver stays unaware of the full chain. Both percentages are shown (AC-8 "show both").

### (4) Persistence + model shape (AC-12) — RATIFIED, with a defined migration rule.

Introduce a new descriptor `RoutePlan` (data/domain value object) that serialises the authored route so a
restart rebuilds the **same** sub-chain deterministically:

```
RoutePlan {
  orderedNodeIds: List<String>   // the authored sub-chain node ids in travel order (start → end)
  routeStartOffsetKm: double     // route-progress decision 1
  lifecycle: enum { active, completed, abandoned }   // see (5)
}
```

- Persist the **ordered node-id list** (not a `start`+`direction` pair): the list is the authoritative
  authored route after edits/segment-merges, so rebuilding the sub-chain = look each id up in the full
  chain, slice the matching `segmentsKm`, and derive the geography sub-view. `start`/`direction` are
  *derivable* from the list (first node + whether the list ascends or descends the canonical index), so
  storing the list avoids a redundant, drift-prone second field.
- **Reuse the existing seam:** persist via the shipped `RouteRepository` / `SharedPreferencesRouteRepository`
  JSON pattern — **no new store**. `RoutePlan` is a **new descriptor type** rather than an extension of
  `RouteSelection`, because `RouteSelection` encodes the now-superseded `start+direction` model and a binary
  `completed` flag (insufficient for the 3-state lifecycle). `RouteSelection` is retained internally as the
  per-sub-chain input the *unchanged* resolver/projector still take (they are constructed from the rebuilt
  sub-chain + its first node + derived direction), so AC-7's "unchanged" holds.
- **Backward-compatibility / migration rule (DEFINED — the wholesale-topology case is AMENDED BY ADR-0009):**
  The reconstruct-the-same-sub-path rule below still applies to an ordinary legacy blob on the *same*
  geography. But when the underlying province topology + total km change **wholesale** (the 2026 34-unit
  rebuild in `province-chain-2026`), ADR-0009 **overrides** this clause with **migrate-by-reset**: a legacy /
  retired-id plan becomes a fresh full-spine active plan stamped at the current engine cumulative distance
  (never an id-remap), because a remap onto a changed topology would misplace the traveller. Lifetime distance
  (BR-8) is preserved either way. The original rule text: the existing corrupt-safe `load()` returns `null`
  on unreadable data. An **old `RouteSelection` blob** (start id + direction + offset + completed) written by
  the shipped build is **migrated forward**, not discarded: on load, if the blob has no `orderedNodeIds` but
  has a legacy `startId`+`direction`, reconstruct the route as the **full sub-path from that start to the
  direction's tip** (exactly the shipped semantics) and synthesise `orderedNodeIds` from it, mapping legacy
  `completed:true → lifecycle:completed`, else `active`. This preserves an in-flight v1 route across the
  upgrade. A blob that is neither a valid new `RoutePlan` nor a valid legacy `RouteSelection` is treated as
  **"no saved route"** (`null`), per the established `FormatException → null` contract.

### (5) Lifecycle states + abandon (AC-9/AC-10) — RATIFIED, with the abandon path reconciled to the build.

> **Reconciled 2026-06-26 to match the as-built implementation (formal review H1).** The first-issued form
> of this decision said abandon "marks the abandoned plan `abandoned`." As built, the runtime abandon path
> (`abandonAndStartNew` → `confirmRoute`, `route_progress_cubit.dart:159-167`) **overwrites the single
> active-plan slot** and **discards** the outgoing plan — it does **not** mark or persist it as
> `abandoned`. The ADR is corrected below so the doc matches the code; AC-10 still holds, by a different
> (observable) mechanism. **Option (b) — the abandoned plan is intentionally discarded — is the accepted
> resolution.**

`RoutePlan` carries a 3-state `RouteLifecycle` enum (`active` / `completed` / `abandoned`). At **runtime**,
only `active` and `completed` are ever **produced and persisted**:

- there is a **single active-plan slot**; this slice has **no abandoned-history surface** (no list of past
  routes, no "resume an abandoned route") — consistent with the S3 dead-code removal;
- on abandon, the confirm guard is shown when there is progress to lose (`routeDistanceKm > 0`, not
  completed) (AC-9); cancelling it is fully inert (AC-9);
- on confirm, a **new `routeStartOffsetKm`** = engine cumulative `distanceKm` at that instant is stamped
  (reusing `route-progress` decision 1), the engine's cumulative `distanceKm` is **never** reset (no engine
  reset API — AC-10), and the **outgoing `RoutePlan` descriptor is discarded** (the new active plan simply
  overwrites the slot — it is never written back as `abandoned`);
- **AC-10 (abandoned ≠ completed; no celebration) holds observably and structurally**, not via a persisted
  `abandoned` flag: the new active plan never carries a `completed` lifecycle, and the discarded plan never
  had completion latched, so **the arrival celebration cannot fire on the abandon path** — the lifecycle
  *distinction* (a completed route fires the celebration; an abandoned one is just replaced) is what makes
  AC-10 observable, exactly as required.

**`RouteLifecycle.abandoned` is reserved for forward-compatibility, not dead.** It remains a valid
value-object state and a valid JSON round-trip value (`route_plan.dart:41`, `_lifecycleByName`), so a future
slice that *does* add an abandoned-history surface can persist and reload it without a schema change. It is
intentionally **latent** in this slice (constructible/serialisable, just not written by the runtime abandon
path) — not dead code to be removed.

### (6) Abandoned-route segment storage — DECIDED: **no-bleed by construction; physical pruning deferred.**

> **Reconciled 2026-06-26 to match the as-built implementation.** The first-issued form of this decision
> ("prune segments on abandon — reset the segment record to empty for the new offset window") was **not**
> implemented as written, and an accepted ADR must not silently contradict the code. The architectural
> outcome it sought (AC-11 no-bleed) is fully met by a *different, simpler* mechanism that does not require
> any engine change; only its storage-growth rationale is left as an explicit follow-up. The text below is
> the reconciled, authoritative decision.

> **Two different things, do not conflate (clarified with decision 5).** This decision is about the
> **engine's distance-keyed idle/active *segment record***, which is **kept** (never pruned) — that is the
> basis of the no-bleed-by-construction argument below. It is **not** about the abandoned route's
> **`RoutePlan` *descriptor***, which (per decision 5) is **discarded**. Phrasing here that says segments are
> "kept" refers only to the engine's segment record; the abandoned `RoutePlan` descriptor is not retained.

**No-bleed (AC-11) is guaranteed by construction by `IdleTraceMapper`'s re-base + clip — no physical prune
is performed.** Mechanism (verified against the shipped code):

- The engine owns the idle/active segment record, keyed by **absolute cumulative km**, and per
  `route-progress` decision 1 / AC-10 the engine's cumulative `distanceKm` is **strictly monotonic and
  never reset** (there is no engine reset *or* segment-prune API).
- On abandon, the new route's `routeStartOffsetKm` is stamped at the **abandon-instant cumulative km**.
  Because cumulative km only ever increases, **every** segment recorded before the abandon has
  `toKm <= newOffset`. `IdleTraceMapper.resolve` re-bases each segment by `newOffset` (so a stale segment
  re-bases to `toRoute <= 0`) and clips to the current route window `[0, routeLengthKm]`
  (`idle_trace_mapper.dart:88-97`) — a re-based-to-`<= 0` span is dropped. A stale segment therefore can
  **never** fall inside the new route's window. AC-11 holds for **all** inputs, by construction.
- This is **why no prune is needed for correctness**: the original "reset to empty" framing assumed pruning
  was load-bearing for AC-11; it is not. The mapper's existing window-clip already isolates the current
  route, so AC-11 + AC-12 are satisfied with the resolver/projector/mapper left **unchanged** (AC-7).

**Physical pruning is deferred (out of scope for this slice).** Actually discarding stale segments would
require an **additive engine API** (a bounded / prune-able segment store, or a "drop segments below km X"
call). Adding that touches the engine and the `idle-accounting` segment record, which the **AC-7-unchanged
constraint puts out of scope** for `route-planner-v2` (this slice must run the resolver/projector/mapper
verbatim and add no engine reset/prune API — Scope/Out + AC-10). So the implementer correctly did **not**
prune.

**Known follow-up (storage growth) — captured, not silently dropped.** The only unmet part of the original
rationale is its storage concern: the engine's persisted segment blob keeps **accumulating** across repeated
start/abandon cycles within a long session, growing **unbounded** in a `shared_preferences` JSON store sized
for "tiny data" (overview Persistence). This is a real but **non-gating** concern (it affects neither
correctness nor any shipped AC; AC-11/AC-12 pass). It is recorded as a **future `journey-engine`-enhancement
slug** — e.g. `journey-engine-bounded-segment-store` — to add a bounded / prune-able segment store (the
additive engine API above) in a later wave, tagged `[blocked by: journey-engine]`. Until then the growth is
bounded in practice by the daily segment reset and the modest size of each segment record.

## Consequences

- **Easier / preserved:** AC-7 is met *by reuse, not rewrite* — the resolver, projector, and idle-trace
  mapper run unchanged over the sub-chain, so ADR-0004's single canonical-km axis and the engine's lifetime
  `distanceKm` stay authoritative; one geography model still serves everything. Auto-insert/edit is a cheap
  pure recompute (NFR-1). Privacy is preserved by construction (NFR-2): selection + auto-insert read only
  static reference geography; no device location/GPS; no new outbound signal beyond ADR-0004's OSM tiles —
  `/privacy-audit` stays PASS.
- **Harder / new obligations:** a new `RoutePlan` descriptor + the legacy-`RouteSelection`→`RoutePlan`
  migration must be implemented and unit-tested (incl. the corrupt-blob → null and legacy-blob → migrated
  paths). Interior-stop removal must correctly **merge segments** so `subPathKm` and the canonical axis stay
  exact. The presentation layer takes on owning **country %** (it must hold both the full chain and the
  active sub-chain). The lifecycle enum defines three states, but the runtime produces/persists only
  `active` and `completed`; abandon **discards** the outgoing plan (single active-plan slot, no
  abandoned-history surface — decision 5), and `abandoned` is a **reserved, latent** JSON round-trip value
  for a future history surface, not written by this slice's abandon path.
- **Trade-off accepted:** abandoned-route segments are **not physically pruned** (the engine is never reset
  and exposes no prune API — AC-7/AC-10), so the persisted segment blob **grows unbounded** across repeated
  start/abandon cycles within a long session. This is accepted as non-gating (it breaks no AC; AC-11 no-bleed
  holds by construction via the mapper's re-base+clip) and is tracked as a future
  `journey-engine`-enhancement (bounded/prune-able segment store) — see decision (6).

## Alternatives considered

### Generalise `RouteProgressResolver` to take an arbitrary ordered checkpoint list
Rejected: it would *change* the resolver, directly violating AC-7's "unchanged" requirement and risking the
single-axis invariant. The sub-chain approach achieves the same expressiveness with zero resolver change,
because `ProvinceChain` already accepts any valid ordered subset.

### Parallel / branching chains for multi-waypoint routes
Rejected: branching would break "position = a single scalar on one km axis" (ADR-0004) and there is no
branching geography to route through — the curated spine is linear (spec Scope/Out).

### Extend `RouteSelection` (add a node list + 3-state enum) instead of a new `RoutePlan`
Rejected for the persisted descriptor: `RouteSelection` encodes the superseded `start+direction` selection
model and a binary `completed` flag; overloading it would conflate the now-internal resolver input with the
authored-route persistence shape and complicate the migration. `RouteSelection` is kept as the *internal*
per-sub-chain resolver/projector input (preserving AC-7); `RoutePlan` is the persisted authored-route shape.

### Physically prune segments on abandon now (add an engine reset/prune API in this slice)
Rejected for this slice (this was the first-issued form of decision (6), reconciled away — see its note):
physically discarding stale segments requires an **additive engine API** (a bounded / prune-able segment
store, or a "drop segments below km X" call), which touches the engine and the `idle-accounting` record. The
**AC-7-unchanged constraint** forbids that here (the resolver/projector/mapper must run verbatim and no engine
reset/prune API may be added — AC-10/Scope-Out). Since AC-11 no-bleed is already guaranteed **by
construction** (cumulative km is strictly monotonic → every stale segment re-bases to `<= 0` and clips out of
the new window), pruning buys **no correctness** — only bounded storage. The implementation therefore keeps
the segments (no prune), and the storage-growth concern is deferred to a future `journey-engine`-enhancement
slug. *(The mirror-image alternative — "keep abandoned segments as inert history" — is what was in fact built,
so it is the accepted approach, not a rejected one.)*
