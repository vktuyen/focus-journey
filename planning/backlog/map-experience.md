# Map experience

**Intake date:** 2026-06-24
**Requested by:** Kevin (Tuyen Vo)
**Size (rough):** L
**Part of epic:** [wave2-feature-requests](wave2-feature-requests.md) · Wave 2 (slice S4)

## Why
**Problem.** Today geography lives in two disconnected places: the shipped `route-progress` map is a
*separate tab* with a stylized, custom-painted province polyline (no real coordinates, "no live tiles
in v1"), while `idle-accounting` (shipped today) silently records ordered **active-vs-idle route
segments** keyed by distance-along-route — data nobody can yet *see*. The map feels like a side panel
rather than part of the journey, and the freshly-captured idle data has no visual home.

**The idea.** Fold the map into the journey itself: (1) request #4 — replace the standalone Map tab
with a **map overlay on the journey tab** that opens **full-screen on tap**, so place is always
glanceable from where the user already is; (2) request #7 — **paint idle time on the map road in red**,
turning the invisible idle segments from `idle-accounting` into a felt "where I drifted off" trace; (3)
back both with **real Vietnam geography** — province lat/long + adjacency (absorbs the retired
`map-geographic` candidate) — so the road follows the actual country, not a stylized line.

**Who it's for.** The **focused individual** (developer / student / remote worker) gets a map that is
part of the journey, not a detour, and sees their focus-vs-drift honestly traced along a real Vietnam
route. The **privacy-skeptical teammate** must stay reassured: the red overlay visualizes only
*aggregate idle duration mapped to route position* — never a location, a timestamp trail, or anything
trackable.

**Why now.** Its two hard prerequisites both **shipped today (2026-06-24)**: `route-progress` (the
province-chain + position model) and `idle-accounting` (the ordered active/idle segment record, whose
distance-keyed shape was explicitly designed as "the contract for `map-experience` #7"). This feature
is also the **provider** of the real-geography province model that `route-planner-v2` (#9 waypoint
auto-insert) will consume next, so framing the geography model correctly here unblocks Wave 2's tail.

## Raw requests (verbatim, from Wave 2 batch)
- **#4** — Map overlay on the journey tab; pressing the map opens it full-screen — **no separate Map tab**.
- **#7** — Draw idle time on the map too (e.g. **red** on the road where idle).
- (absorbs the old **`map-geographic`** candidate) — **real geography**: province lat/long + adjacency,
  `flutter_map` + OSM tiles. The same geography model `route-planner-v2` (#9 auto-insert) will consume.

## Domain notes
**Personas touched.**
- **The focused individual** — primary; map overlay + red idle trace is the felt payoff.
- **The privacy-skeptical teammate** — the gating reviewer; real lat/long + a red "where idle" trace is
  the *most location-suggestive* surface the product has shipped, so it must be shown to add **zero**
  tracking surface.

**Grounding from shipped specs (what "idle", "segment", and "the route" already mean).**
- **Idle / route segment** are already defined by shipped `idle-accounting`: an ordered, contiguous,
  gap-free record of `{start, end, classification, cause}` **keyed by distance-along-route**, with idle
  cause tagged **voluntary** (active→grace→idle ramp) vs **lock/sleep** (immediate). Grace stays
  travel. This feature is a **pure visualizer** of that data — it must not re-derive or re-classify
  idle, only render the existing segments.
- **The route / provinces** are defined by shipped `route-progress`: a curated **ordered province chain**
  (~10–15 checkpoints, Mũi Cà Mau ⇄ Hà Giang), `totalChainKm ≈ 2000`, position resolved as a pure
  function of `routeDistanceKm`. This feature adds **real lat/long + adjacency** to that chain; the
  existing position math and completion rule are reused, not replaced.

**Key edge cases to surface now.**
- **Segment→geometry mapping (#7).** Idle segments are *distance-keyed*; the map road is *geometry*.
  Mapping a 1-D distance span onto a 2-D polyline (especially across province boundaries / curves) needs
  a defined rule so a red stretch lands on the right road piece.
- **Voluntary vs lock/sleep colour treatment.** `idle-accounting` deliberately tags cause — the overlay
  should decide whether both render the same red or are distinguished.
- **Per-route offset & day-split.** Segments split at day rollover and are per-route
  (`routeStartOffset`); the overlay must show the *current route's* trace, not lifetime, and survive
  restart (carry-forward: persist `idleSince`; settle segment day-key).
- **Off-screen / completed route.** What the overlay shows at `routeDistanceKm = 0`, mid-route, and
  after route completion (celebration state) must be defined.
- **Tile sourcing.** Real geography via `flutter_map` + OSM introduces a **network tile fetch** — new
  for this product; OSM attribution + offline/no-network behaviour must be handled.

**Conflicts with existing domain rules / specs.**
- `docs/domain/business-rules.md`, `glossary.md`, and `personas.md` are still **empty templates** — so
  there is **no codified business rule to conflict with yet**. The personas and the privacy promise
  cited above live in the shipped feature specs, not in `docs/domain/`, which is itself a gap worth
  flagging (see candidates).
- **Tension with `route-progress` (shipped), not a hard conflict:** route-progress v1 explicitly chose
  **custom-painted, "no live tiles, no network, no OSM dependency."** Introducing `flutter_map` + OSM
  tiles reverses that v1 decision. This is the intended v2 evolution (`map-geographic` was always the
  planned successor), but it is a **deliberate supersession to flag at `/new-feature` time**, not a
  silent override — the system-architect should record it (candidate ADR).
- **Privacy promise (no contradiction, but a guardrail):** every shipped spec asserts "no new OS signal,
  aggregate-only." Real lat/long here is **static province reference data**, not the user's location, and
  the red overlay is aggregate idle *duration* placed by route distance — no GPS, no timestamps, no
  per-event trail. The feature must preserve this by construction (`/privacy-audit` must stay PASS).

## Candidate domain updates
> Flags only — promote into `docs/domain/` at `/new-feature` time if this feature ships.

**Glossary terms**
- [ ] candidate glossary term: **Province geography** — the real lat/long + adjacency reference data for
      the province chain (static, app-supplied; not the user's location).
- [ ] candidate glossary term: **Map overlay** — the in-journey-tab map surface that opens full-screen on
      tap (replaces the standalone Map tab).
- [ ] candidate glossary term: **Idle trace (red overlay)** — the visual rendering on the map road of
      `idle-accounting`'s idle segments for the current route.
- [ ] candidate glossary term: **Idle cause** (voluntary vs lock/sleep) — promote the already-shipped
      `idle-accounting` distinction into the shared glossary, since the overlay surfaces it.
- [ ] candidate glossary term: **Route segment** — formalize the shipped contiguous distance-keyed
      `{start, end, classification, cause}` record in the shared glossary.

**Business rules**
- [ ] candidate business rule: the idle red overlay visualizes **only aggregate idle duration mapped to
      route distance** — no GPS, no location, no timestamped event trail (privacy invariant; keeps
      `/privacy-audit` PASS).
- [ ] candidate business rule: province lat/long is **static reference data**, never the user's actual
      position; the map never reads device location.
- [ ] candidate business rule: `map-experience` is a **pure visualizer** of `idle-accounting` segments and
      `route-progress` position — it neither re-classifies idle nor accrues distance.
- [ ] candidate business rule: the overlay shows the **current route** trace (per `routeStartOffset`,
      day-split), not the lifetime total.
- [ ] candidate business rule: there is **one geography model**, owned here and consumed by
      `route-planner-v2` (#9) — provinces, lat/long, and adjacency are defined once.

**Process / docs gap**
- [ ] candidate flag: `docs/domain/{business-rules,glossary,personas}.md` are still empty templates while
      personas and the privacy promise are de-facto defined in shipped specs — worth backfilling so the
      domain layer is the single source of truth.

## Feasibility (high-level)

**Fit with the current architecture — good, and partly pre-planned.**
- The geography/tile dependency is **not a surprise reversal**: ADR-0002 already lists `flutter_map` +
  `latlong2` (and "geographic map") as explicitly **deferred to v2**, and the overview's "Deferred to v2"
  lines name `flutter_map` + OSM tiles. This feature *activates* that planned step rather than overturning
  an accepted decision. The "no live tiles / no network" stance is scoped as a **v1** choice in the
  `route-progress` spec and the overview narrative — there is **no standalone accepted ADR** asserting
  "no network ever," so this is a clean, in-scope evolution. It still warrants an explicit supersession
  record because the overview text and the `route-progress` spec assert the no-network posture.
- The data contract is **already in place**: shipped `idle-accounting` deliberately stores segments
  **keyed by distance-along-route** ("so `map-experience` #7 paints by position") — contiguous, gap-free,
  cause-tagged, day-split, persisted. This feature is a **pure visualizer**; it adds no new OS signal,
  no timer, no idle re-classification. That keeps the privacy posture intact by construction and means the
  hard domain/data work is done — the remaining effort is presentation + geography reference data.
- Layering is clean: a new **province-geography model** (static lat/long + adjacency reference data) sits in
  *domain*, reusing the existing `route-progress` position math (position stays a pure function of
  `routeDistanceKm`). The map overlay + full-screen surface is *presentation* (Flutter + a tile widget),
  driven by existing Bloc state. No change to `JourneyEngine`, the ticker, or `ActivityPlugin`.

**Rough effort — L.** Three non-trivial, mostly-independent workstreams:
1. **New runtime dependency + network surface** (`flutter_map` + `latlong2` + OSM tiles) on a product that
   has been **fully offline to date** — needs offline/no-network fallback, tile caching, OSM attribution,
   and desktop (macOS/Windows) tile-rendering validation. This is the single biggest source of new risk.
2. **Province-geography reference data** — curating real lat/long + adjacency for the existing ~10–15
   province chain, plus a defined **distance→polyline geometry mapping** so a distance-keyed idle span lands
   on the correct road segment across province boundaries/curves (the genuinely novel algorithmic piece).
3. **Interaction rework** — removing the standalone Map tab, embedding a map overlay on the journey tab, and
   a full-screen-on-tap transition; plus rendering the red idle trace over the polyline with defined
   states at distance 0 / mid-route / completed, and a voluntary-vs-lock/sleep colour decision.
Not XL: the engine/domain core is untouched, the segment contract and position math already exist, and the
chain is small (curated, ~10–15 points), not arbitrary nationwide routing.

**Key risks.**
- **OSM/network on an offline-first, privacy-first product.** Tile fetch is a new outbound network call;
  must degrade gracefully with no connectivity and must not weaken the "fully local/offline" + "no tracking"
  promise. `/privacy-audit` must stay PASS — confirm the tile request carries no user data and that lat/long
  is **static reference data, never device location**. This is the gating risk for the privacy-skeptical persona.
- **Desktop tile rendering** — `flutter_map` desktop (macOS/Windows) caching/perf and OSM tile-usage-policy
  compliance need a spike before commit.
- **Distance→geometry mapping correctness** — the red overlay is only trustworthy if a distance span maps to
  the right polyline stretch; the mapping rule is new and must be unit-testable (mirror the deterministic,
  Flutter-free style of the existing position math).
- **Documentation drift** — the overview and `route-progress` spec both assert "no network / custom-painted";
  shipping this leaves them stale unless the supersession is recorded (candidate ADR below).
- **Carry-forwards from `idle-accounting`** (persist `idleSince`; settle segment day-key) must be resolved so
  the trace survives restart and shows the *current route only* — settle at `/new-feature` time.

## Candidate ADRs
> Flags only — to be written by `system-architect` at `/new-feature` time **if** this is promoted. No ADR is written now.

- [ ] **`flutter_map` + OSM tile dependency — superseding the v1 "no live tiles / no network, custom-painted map" posture.** Activates the dependency ADR-0002 already deferred to v2; must explicitly note the supersession of the `route-progress` spec's no-network stance and update `docs/architecture/overview.md` (External dependencies + "Deferred to v2"). Mark relationship to ADR-0002 explicitly.
- [ ] **Offline / no-network behaviour + tile-cache strategy** — what the map shows with no connectivity, tile caching approach, and OSM tile-usage-policy + attribution compliance (preserving the offline-first promise).
- [ ] **Province-geography data model & source** — the static lat/long + adjacency reference dataset: shape, ownership, and source; established here as the **single geography model** that `route-planner-v2` (#9) will consume.
- [ ] **Distance-keyed idle segment → map polyline geometry mapping** — the rule for projecting `idle-accounting`'s 1-D distance-keyed segments onto 2-D polyline geometry across province boundaries/curves (deterministic, unit-testable).
- [ ] **Map-overlay → full-screen navigation pattern** — interaction/navigation model for the journey-tab overlay opening full-screen on tap, and retirement of the standalone Map tab (coordinate with the ADR-0003 single-window two-mode model so this is a same-window surface, not a new window).
- [ ] **Privacy boundary for real geography + idle trace** — confirm that introducing real lat/long and a tile fetch adds **zero** tracking surface (static reference data only, aggregate idle duration by route distance, no device location/GPS/timestamp trail); keeps `/privacy-audit` PASS. (May fold into the dependency ADR rather than stand alone.)

## Headline success signals
- **Overlay-only, full-screen on tap (#4).** Given the user is on the journey tab, when the app
  renders, then a map overlay is shown inline on that tab and **no separate "Map" tab exists** in the
  navigation; and when the user taps the overlay, then it opens full-screen and can be dismissed back
  to the inline overlay (same window, no new window).
- **Idle renders as a red trace on the right stretch (#7).** Given the current route has recorded idle
  segments from `idle-accounting`, when the map overlay renders, then each idle segment appears as a red
  trace positioned along the road at the polyline stretch that corresponds to its distance-along-route
  span (right-hand stretch), while active segments are not red; and given a route with zero idle
  segments, then no red trace is drawn.
- **Road follows real Vietnam geography.** Given the curated province chain, when the map road is drawn,
  then each province checkpoint is placed at its real lat/long and the road polyline connects them in
  chain order, tracing the actual country shape (Mũi Cà Mau ⇄ Hà Giang) rather than a stylized line.
- **Zero new tracking surface — privacy invariant.** Given the map overlay and red idle trace are
  active, when the feature runs, then it reads **no device location / GPS**, records **no timestamp
  trail or per-event location data** (only static province reference lat/long + aggregate idle duration
  mapped to route distance), and `/privacy-audit` stays **PASS**.

## Signals
Ready to promote when its framing is settled and the open questions below are answered.
**Dependencies:** `[blocked by: route-progress ✅, idle-accounting ✅]` (both shipped 2026-06-24).
**Provides:** the province geography model that `route-planner-v2` (#9 waypoint auto-insert) consumes.

**Carry-forwards inherited from `idle-accounting` (settle here):**
- Persist `idleSince` (idle-accounting S-3) — needed so idle segments survive across sessions for the map overlay.
- Decide the segment **day-key** (idle-accounting S-1) — how active/idle segments bucket per day.

**Open questions to settle at `/new-feature` time:**
- Real lat/long geography vs a curated province-adjacency list? (drives `flutter_map` + OSM tile dependency)
- How are idle segments mapped onto the map road geometry for the red overlay (#7)?
- Map overlay placement on the journey tab + the full-screen transition (#4) — interaction model.

## First step
Run `/new-feature map-experience` to promote this into a spec bundle.
