# Route planner v2

**Intake date:** 2026-06-25
**Requested by:** Kevin (Tuyen Vo)
**Size (rough):** L
**Part of epic:** [wave2-feature-requests](wave2-feature-requests.md) · Wave 2 (slice S3)

## Why
**Problem.** Today the route is rigid: shipped `route-progress` models Vietnam as **one fixed ordered
province chain** (Mũi Cà Mau ⇄ Hà Giang) and the user only picks a **start province + a single
direction** (toward one of the two chain tips). They cannot say "I want to go from HCMC to Hà Nội," pick
several stops, or run a route that isn't the full N↔S spine. And once a journey is underway there is **no
way to abandon it and start a fresh one** — `route-progress` completion is terminal-until-user-choice, but
mid-route the only path forward is to keep going. This makes the journey feel like a fixed treadmill
rather than a trip the user authored.

**Who it's for, and why now.** The **focused individual** (developer / student / remote worker) gets
agency over *where* their focus walks them — choosing real endpoints, dropping the cities they care
about, and getting a sane, scenic auto-completed route (e.g. HCMC→Hà Nội auto-adds Đà Lạt, Nha Trang,
Huế) they can review before committing. The **privacy-skeptical teammate** stays the gating reviewer: the
"real map" auto-insert must consume only the **static province-geography reference data** shipped by
`map-experience` — never device location, never GPS. Why now: this is Wave 2's tail, and both hard
prerequisites just shipped — `route-progress` (2026-06-24, the chain + position math) and `map-experience`
(2026-06-25, the real lat/long + adjacency model #9's auto-insert must *consume*, build-once-consume-many).
Framing this last unblocks closing Wave 2.

## Raw requests (verbatim, from Wave 2 batch)
- **#8** — Let the user choose **many start provinces, many end provinces** — not just a N/S direction.
- **#9** — Let the user choose **many stops**; the app **auto-inserts intermediate provinces from the real map**
  (e.g. HCMC→Hà Nội auto-adds Đà Lạt, Nha Trang, Huế…), with a **review screen before starting**.
- **#10** — Let the user **stop the current journey and start a new one**.

## Domain notes
**Personas touched.**
- **The focused individual** — primary; gains authorship of the route (endpoints, stops, scenic
  auto-fill, review, and the ability to scrap a route and restart).
- **The privacy-skeptical teammate** — gating reviewer; the #9 "real map" auto-insert is the most
  location-suggestive *interaction* yet (the user types in real places), so it must demonstrably consume
  only **static province-geography reference data** (lat/long + adjacency) shipped by `map-experience`,
  with **no device location / GPS** and no new outbound signal beyond the OSM tiles `map-experience`
  already introduced.

**Grounding from shipped specs (what "route", "chain", "position", "segment" already mean).**
- **The route / chain** is defined by shipped `route-progress`: a single curated **ordered province
  chain** (~10–15 checkpoints, Mũi Cà Mau ⇄ Hà Giang, `totalChainKm ≈ 2000`), with **start + direction**
  selection, and position resolved as a **pure function of `routeDistanceKm`** (= `engine.distanceKm −
  routeStartOffset`). The engine is never reset; a new route is a new `routeStartOffset`.
- **Province geography** is defined by shipped `map-experience`: the **single** static lat/long +
  adjacency model. #9's auto-insert must **consume** it (build-once-consume-many) — this slice does **not**
  re-derive or fork geography.
- **Route segment / idle trace** is defined by shipped `idle-accounting` + `map-experience`: contiguous,
  gap-free, distance-keyed `{start, end, classification, cause}` records, **per-route** via
  `routeStartOffset`, day-split, persisted, rendered as the red trace for the *current route*.

**Key edge cases to surface now.**
- **Many-start + many-end vs the single ordered chain (#8 — the central tension).** `route-progress` is
  *one* fixed ordered chain with a single start + a binary direction. "Many start provinces, many end
  provinces" does not obviously map onto it: is the result (a) a **chosen contiguous sub-path** of the
  existing spine between two endpoints (cheapest; reuses chain order + position math verbatim); (b) **one
  composed path** that visits a set of provinces in a derived order (needs an ordering rule + adjacency
  from `map-experience`); or (c) genuinely **multiple parallel chains**? Pick one; (a)/(b) preserve the
  "position = pure function of `routeDistanceKm`" invariant, (c) likely breaks it. Also: what does
  "**many** start provinces" even mean for a single traveller at distance 0 — a pick-list to choose *one*
  from, or several origins fanning in? Needs disambiguation at `/new-feature`.
- **Auto-insert selection & ordering (#9).** Which intermediate provinces are added between the chosen
  endpoints/stops, and in what order — by `map-experience` **adjacency walk**, by geographic **proximity
  along the line**, or by following the existing **spine order**? Are auto-inserted provinces
  **user-editable** (remove / reorder / add more) on the review screen, or fixed once computed? What if two
  chosen stops are non-adjacent or off the curated ~10–15 chain (the curated subset may not contain a
  requested city)? Define the fallback (snap to nearest checkpoint / reject / expand the chain).
- **Review-before-start gate (#9).** The review screen must show the resolved ordered route + total
  distance/ETA **before** any `routeStartOffset` is stamped — i.e. reviewing must have **zero** side effect
  on the engine, recorded segments, or position until the user confirms "start." Define cancel/back
  behaviour (returns to picker, nothing recorded).
- **Stop-and-restart lifecycle (#10).** This is new: today completion is *terminal-until-user-choice* with
  no mid-route abandon. Starting a new route mid-journey must define what happens to: (1) **in-progress
  `routeDistanceKm`** — discarded for the new route but the engine's cumulative `distanceKm` (the lifetime
  total) is **never reset**, so a new `routeStartOffset` is simply stamped at the abandon instant; (2)
  **recorded idle/active segments** of the abandoned route — kept as history (per-route via the old offset)
  or pruned? `map-experience`'s red trace shows "current route only," so the old segments must not bleed
  into the new route's trace; (3) **celebration / completion state** — an abandoned route should **not**
  fire the arrival celebration (it wasn't completed); define the distinction between "completed" and
  "abandoned." Also: is there a **confirm** step before discarding in-progress progress (loss-of-progress
  guard)?

**Conflicts with existing domain rules / specs.**
- `docs/domain/{business-rules,glossary,personas}.md` are still **empty templates** — there is **no
  codified business rule to conflict with yet**. The personas and the privacy promise cited here live in
  the shipped feature specs, not in `docs/domain/`, which is itself a gap worth flagging (see candidates).
- **Tension with `route-progress` (shipped), to reconcile — not silently override:** `route-progress`
  explicitly scopes out "**multi-route … journeys**" and assumes a **single fixed chain + start +
  direction**. #8/#9 generalize that selection model and #10 adds a **mid-route abandon** lifecycle that
  `route-progress`'s "completion is terminal until user choice; no auto-advance" decision did not
  contemplate (it only covered *completing* a route, never *abandoning* one). This is the intended v2
  evolution, but it **supersedes** route-progress's selection + lifecycle assumptions and must be flagged
  for an explicit decision at `/new-feature`, not assumed.
- **Privacy promise (no contradiction, but a guardrail):** every shipped spec asserts "aggregate-only, no
  new OS signal, static reference geography, no device location." #9 must preserve this by **consuming**
  `map-experience`'s static province geography and adding **no** location read; `/privacy-audit` must stay
  PASS by construction.

## Candidate domain updates
> Flags only — promote into `docs/domain/` at `/new-feature` time if this feature ships.

**Glossary terms**
- [ ] candidate glossary term: **Custom route** — a user-authored route defined by chosen start/end
      province(s) and optional stops, superseding the fixed single-chain start+direction model from
      `route-progress`.
- [ ] candidate glossary term: **Waypoint / stop** — a province the user explicitly chooses to pass
      through (#9), distinct from auto-inserted intermediate provinces.
- [ ] candidate glossary term: **Auto-inserted intermediate province** — a province the app adds between
      chosen endpoints/stops, derived from `map-experience`'s static adjacency/geography (not user-picked).
- [ ] candidate glossary term: **Route review (review-before-start)** — the confirmation screen showing the
      resolved ordered route + distance/ETA before any `routeStartOffset` is stamped; reviewing has zero
      side effect.
- [ ] candidate glossary term: **Route abandon (stop-and-restart)** — ending the current route mid-journey
      without completion, to start a new one (#10); distinct from **route completion**.
- [ ] candidate glossary term: **Active route vs lifetime total** — formalize that a route is scoped by
      `routeStartOffset` over the engine's never-reset cumulative `distanceKm` (the lifetime total), so a
      new/abandoned route never resets the engine.

**Business rules**
- [ ] candidate business rule: a custom route resolves to an **ordered list of provinces**, and traveller
      position stays a **pure function of `routeDistanceKm`** — #8/#9 must not introduce a second position
      axis or a parallel-chains model that breaks the shipped position math.
- [ ] candidate business rule: auto-inserted intermediate provinces (#9) are derived **only** from
      `map-experience`'s single static province-geography model (lat/long + adjacency) —
      build-once-consume-many; this slice never re-derives or forks geography.
- [ ] candidate business rule: **reviewing a route has zero side effect** — no `routeStartOffset` is
      stamped and no segment/position changes until the user explicitly confirms "start" (#9 gate).
- [ ] candidate business rule: starting a new route (whether after completion **or** mid-route abandon)
      stamps a **new `routeStartOffset`** and **never resets** the engine's cumulative `distanceKm`
      (lifetime total preserved) (#10).
- [ ] candidate business rule: an **abandoned** route does **not** fire the arrival celebration (only
      genuine completion does); "completed" and "abandoned" are distinct terminal states (#10).
- [ ] candidate business rule: the current route's red idle trace shows **only the current route's**
      segments (per `routeStartOffset`); abandoned-route segments never bleed into the new route's trace
      (preserves `map-experience` "current route only").
- [ ] candidate business rule (**privacy invariant — keep intact**): route planning + auto-insert use
      **only static province reference geography**; **no device location, no GPS**, and no new outbound
      signal beyond the OSM tiles `map-experience` already introduced — `/privacy-audit` stays PASS.

**Process / docs gap**
- [ ] candidate flag: `docs/domain/{business-rules,glossary,personas}.md` are still empty templates while
      personas and the privacy promise are de-facto defined in shipped specs — worth backfilling so the
      domain layer becomes the single source of truth (carried from `map-experience`'s framing).

## Feasibility (high-level)

**Fit with the current architecture — good, and almost entirely additive on the domain + presentation layers.**
The two hard prerequisites already shipped exactly the seams this slice needs, so most of the work is a
generalization of an existing pure-domain model plus two new presentation surfaces (a picker and a review
screen). Crucially, **no new runtime dependency and no new OS signal / network egress is introduced** — the
privacy posture stays intact by construction (expanded under Risks).

**#8 multi-start/end + composed route vs the single-chain + `routeStartOffset` design.**
The pivotal question is which of the three shapes the Domain notes raise (sub-path / composed path /
parallel chains) the route model takes. The architecturally cheapest and lowest-risk shapes — **(a) a chosen
contiguous sub-path of the existing spine** and **(b) one composed path that visits a chosen set of provinces
in a derived order** — both **preserve the "position = pure function of `routeDistanceKm`" invariant**, because
in both the resolved route is still *a single ordered list of checkpoints with per-leg km*, exactly the shape
`route-progress`'s `ProvinceChain`/resolver and ADR-0004's `RoutePolylineProjector` already consume. Under (a)/(b)
the only generalization is: instead of one hard-coded full-spine chain + binary direction, the route becomes a
**user-authored ordered checkpoint list** built once at "start," and `RouteProgressResolver` /
`RoutePolylineProjector` run over *that* list unchanged. The engine is never touched; `distanceKm` stays the
lifetime total; a custom route is still just a `routeStartOffset` stamped over it. Shape **(c) parallel chains**
is the one to avoid — it would introduce a second position axis and break the single-canonical-km axis ADR-0004
locked. The recommendation to carry into `/new-feature` is (a) or (b); (c) is out. ("Many start provinces" almost
certainly means *a pick-list to choose one origin from*, not several simultaneous origins for one traveller —
disambiguate at spec time, but neither reading changes the layering.)

**#9 auto-insert as a pure domain function over the existing geography model (build-once-consume-many).**
This is the genuinely new algorithmic piece, but it fits cleanly: auto-insert can be a **new pure, deterministic,
Flutter-free domain function** (mirroring `RouteProgressResolver` / `RoutePolylineProjector`) that takes the
user's chosen endpoints + stops and returns an ordered checkpoint list, computed **only** from the static
province-geography model (lat/long + adjacency) that `map-experience` + ADR-0004 already shipped as the *single*
geography model. **No new infrastructure, no new dataset** — this slice *consumes* that model, it does not fork or
re-derive it. The ordering rule (adjacency walk vs proximity-along-the-line vs spine order) and the
off-chain-stop fallback (the curated ~10–15 chain may not contain a requested city: snap-to-nearest / reject /
expand) are real algorithmic decisions to settle, but they are decisions *inside one domain function*, not
architectural surface. Output of auto-insert feeds straight into the same resolver/projector, so the position
and red-trace math stay consistent for free.

**#10 stop-and-restart lifecycle — impact on engine / Bloc / persistence.**
This is the only lifecycle *change* (the rest is additive), but it lands lightly because `route-progress`
decision 1 already established the right primitive: **a route is just a `routeStartOffset` over the engine's
never-reset cumulative `distanceKm`.** Abandon-and-restart is therefore *stamp a new `routeStartOffset` at the
abandon instant* — the engine and ticker are untouched, and `rawActiveTime`/lifetime total are preserved.
The work is in **Bloc state + persistence**: (1) persist the new active-route descriptor (the authored ordered
checkpoint list + offset) alongside the existing start/direction state via the same `shared_preferences`/JSON
seam — no new store; (2) ensure the red idle trace keys off the *new* offset so abandoned-route segments
(per `idle-accounting`, distance-keyed per route) do not bleed into the new route's "current route only" trace —
this is a query/scoping concern, not a data migration, since segments are already per-route by offset; (3)
distinguish **abandoned** from **completed** so an abandon does **not** fire the arrival celebration — a new
terminal state on the route lifecycle, not an engine change. A loss-of-progress confirm step is pure presentation.

**Rough effort — L (confirms the batch pre-classification).** Three mostly-independent but each-non-trivial
workstreams: (1) generalizing the route model from fixed-chain+direction to a user-authored ordered checkpoint
list while *provably* preserving the `routeDistanceKm` position invariant and the ADR-0004 single-km-axis
projector — the model change with the most blast radius across shipped code; (2) the new pure auto-insert
selection/ordering function over the existing geography model, with a defined off-chain fallback (the novel
algorithmic piece); (3) two new presentation surfaces — a multi-select start/end/stops picker and a
zero-side-effect review screen — plus the #10 abandon/restart lifecycle (new terminal state + Bloc/persistence
wiring + confirm gate). Not **M**, because it *supersedes* two shipped behavioural assumptions (single-chain
selection and terminal-only completion) and touches the heart of the position model rather than adding a leaf
feature. Not **XL**, because the engine/ticker/`ActivityPlugin` are completely untouched, no new dependency /
network / native surface is added, the geography model and segment contract already exist (consume-only), the
chain is small and curated (~10–15 points, not nationwide routing), and the position/projection math is reused
rather than reinvented.

**Key risks.**
- **Position-invariant preservation (gating).** The whole slice rests on keeping "position = pure function of
  `routeDistanceKm`" and ADR-0004's single canonical-km axis true after generalizing the chain. Choosing model
  shape (c) parallel-chains would break it; even (a)/(b) need the resolver + projector to be proven to run over
  an arbitrary authored ordered list (not just the hard-coded spine) with the same determinism and unit-test
  rigor. This must be settled and unit-pinned before build.
- **Auto-insert correctness & off-chain fallback (#9).** With only ~10–15 curated checkpoints, a requested city
  may be off-chain; the selection/ordering rule and the fallback (snap / reject / expand) must be defined and
  deterministic, or the auto-completed route will surprise users. Algorithmic, not infrastructural — but novel.
- **Lifecycle ambiguity (#10).** "Abandoned" vs "completed" must be a clean, testable distinction so abandon
  never fires the celebration and the red trace shows only the new route; segment scoping by the new offset must
  be verified so old-route segments do not bleed through.
- **Review-gate side-effect leak (#9).** The review screen must stamp **no** `routeStartOffset` and record **no**
  segment/position change until "start" is confirmed — easy to get subtly wrong if the picker eagerly mutates
  Bloc/persisted state. Treat zero-side-effect-until-confirm as an explicit, tested invariant.
- **Documentation/decision drift.** This supersedes `route-progress`'s single-chain selection + terminal-only
  completion assumptions; shipping without recording the supersession (candidate ADRs below) leaves the
  overview and the `route-progress` spec stale.
- **Privacy posture (expected: intact, but assert it).** No device location, no GPS, no new outbound signal
  beyond the OSM tiles ADR-0004 already introduced — the user typing real place names is the most
  location-*suggestive* interaction yet, so `/privacy-audit` must be shown to stay PASS by construction
  (auto-insert reads only static reference geography).

## Candidate ADRs
> Flags only — to be written by `system-architect` at `/new-feature` time **if** this is promoted. No ADR is written now.

- [ ] **Custom route model generalization — superseding `route-progress`'s single-chain + start+direction selection.** Generalize the fixed full-spine `ProvinceChain` + binary-direction model into a **user-authored ordered checkpoint list** (chosen sub-path or composed path), while **provably preserving** the "position = pure function of `routeDistanceKm`" invariant. Must explicitly choose model shape (a) sub-path / (b) composed path and **reject** (c) parallel chains (it would break the single position axis). Coordinate with **ADR-0004(b)** — confirm `RouteProgressResolver` + `RoutePolylineProjector` run unchanged over an arbitrary authored list on the **same single canonical-km axis**. Supersedes the `route-progress` spec's single-chain assumption; relates to **ADR-0002** stack only insofar as the work stays pure-domain + Bloc (no new dependency).
- [ ] **Auto-insert selection & ordering algorithm (#9).** Define the pure, deterministic, Flutter-free domain function that derives intermediate provinces between chosen endpoints/stops — ordering rule (adjacency walk vs proximity-along-line vs spine order), user-editability of the result, and the **off-chain fallback** (snap-to-nearest checkpoint / reject / expand the curated ~10–15 chain). Must **consume only** the single static province-geography model shipped under **ADR-0004** (build-once-consume-many; no fork, no re-derive).
- [ ] **Stop-and-restart lifecycle + `routeStartOffset` semantics (#10).** Formalize mid-route **abandon** as *stamp a new `routeStartOffset` at the abandon instant*, engine + cumulative `distanceKm` (lifetime total) **never reset** — extending `route-progress` decision 1 from "new start after *completion*" to "new start after completion **or** abandon." Define **abandoned vs completed** as distinct terminal states (abandon never fires the arrival celebration) and the loss-of-progress confirm gate. Supersedes `route-progress`'s "completion is terminal until user choice; no auto-advance" lifecycle, which never contemplated abandonment.
- [ ] **Abandoned-route segment scoping (red-trace isolation).** Confirm the current route's red idle trace shows **only** the new offset's segments so abandoned-route segments (per `idle-accounting`, distance-keyed per route) never bleed into the new route's trace — preserving `map-experience` / ADR-0004's "current route only." A query/scoping decision, not a data migration. (May fold into the #10 lifecycle ADR.)
- [ ] **Review-gate-has-zero-side-effects invariant (#9).** Establish as an explicit, testable architectural invariant that the review-before-start screen stamps **no** `routeStartOffset` and mutates **no** segment / position / persisted state until the user confirms "start"; cancel/back returns to the picker with nothing recorded.
- [ ] **Privacy boundary for user-entered place selection — `/privacy-audit` stays PASS.** Confirm that letting the user pick/type real provinces + auto-insert reads **only static reference geography** (lat/long + adjacency) and adds **no device location / GPS** and **no new outbound signal** beyond the OSM tiles **ADR-0004** already introduced; **no** new dependency or OS signal vs **ADR-0002 / ADR-0003**. (May fold into the route-model ADR rather than stand alone.)

## Headline success signals
- **Custom endpoints honored beyond the fixed N/S spine (#8).** Given the user picks a start province
  and an end province other than the two chain tips (e.g. HCMC → Hà Nội), when the route is built and
  started, then the resolved route runs between exactly those chosen endpoints in chain-consistent order
  (not the full Mũi Cà Mau ⇄ Hà Giang spine), and the traveller's position stays a pure function of
  `routeDistanceKm` over that authored route.
- **Auto-insert + gated review with zero side effect (#9).** Given chosen endpoints and stops, when the
  user opens the review screen, then intermediate provinces are auto-inserted from the shipped
  `map-experience` province-geography model in a sensible order and the resolved ordered route + total
  distance/ETA are shown; and while only reviewing (no "start" confirmed), **no `routeStartOffset` is
  stamped and no segment/position/persisted state changes** — starting the journey is gated until the
  user confirms, and cancel/back returns to the picker with nothing recorded.
- **Stop-and-restart abandons cleanly without resetting lifetime or celebrating (#10).** Given a route is
  in progress, when the user abandons it and starts a new route, then a **new `routeStartOffset`** is
  stamped at the abandon instant while the engine's cumulative lifetime `distanceKm` is **never reset**,
  the **arrival celebration does not fire** (abandon is distinct from completion), and the new route's red
  idle trace shows **only the new route's** segments (abandoned-route segments do not bleed through).
- **Zero new tracking surface — privacy invariant.** Given the user picks/types real provinces and
  auto-insert runs, when the feature operates, then route planning reads **only static province reference
  geography** (lat/long + adjacency from `map-experience`), with **no device location / GPS** and no new
  outbound signal beyond the OSM tiles `map-experience` already introduced, and `/privacy-audit` stays
  **PASS**.

## Signals
Ready to promote when its framing is settled and the open questions below are answered.
**Dependencies:** `[blocked by: route-progress ✅ (shipped 2026-06-24), map-experience ✅ (shipped 2026-06-25)]`.
**Consumes:** the province-geography model (lat/long + adjacency) that `map-experience` shipped — #9
waypoint auto-insert reads from it (build-once-consume-many; do not re-derive geography here).

**Open questions to settle at `/new-feature` time (carried from Wave 2 batch):**
- **#9 granularity:** does auto-insert use `map-experience`'s real lat/long, or a curated province-adjacency
  list? How are intermediate provinces chosen / ordered? Are they user-editable after auto-insert?
- **#8 model shape:** how do "many start + many end provinces" reconcile with `route-progress`'s single
  ordered province chain (Mũi Cà Mau ⇄ Hà Giang) — multiple chains, a chosen sub-path, or a new model?
- **#10 stop-and-restart:** what happens to in-progress route distance, recorded idle segments, and the
  celebration state when the user abandons a route mid-journey to start a new one?

## First step
Run `/new-feature route-planner-v2` to promote this into a spec bundle.
