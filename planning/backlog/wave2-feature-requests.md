# Wave 2 — feature requests (Kevin, 2026-06-24)

> Captured raw, then classified into slugs that **batch related work** (one asset pass, one scene
> rework, one route-model change) to save time. NOT yet promoted — promote each with `/capture-idea
> <slug>` → `/new-feature <slug>` when its turn comes. Wave discipline: these are all v2; they enhance
> shipped v1 slices, so each is a **new slug** (never a re-`/implement` of a shipped one).

## Raw requests (verbatim, numbered — nothing dropped)
1. Make winding road / curve road.
2. Adjust the main character to act like a motorbike / car POV (steering-wheel view) — make the objects look nicer and more real.
3. Make the scroll animation slower ×3 — the **speed stays the same**, only the visual scroll is slower.
4. Map overlay on the journey tab; pressing the map opens it full-screen — **no separate Map tab**.
5. When the app loses focus the road scroll stops — I want it to **keep running**.
6. Idle time isn't captured correctly — when it shows Idle/Paused, idle time should count **from that moment**.
7. Draw idle time on the map too (e.g. **red** on the road where idle).
8. Let the user choose **many start provinces, many end provinces** — not just a N/S direction.
9. Let the user choose **many stops**; the app **auto-inserts intermediate provinces from the real map** (e.g. HCMC→Hà Nội auto-adds Đà Lạt, Nha Trang, Huế…), with a **review screen before starting**.
10. Let the user **stop the current journey and start a new one**.
11. Enrich the scenery — more mountains, beach, people, city, animals, characters, forest…
12. Object spacing while scrolling should look **more even / "linear"** (perceptually) — current spacing isn't beautiful.

## Classification → proposed slugs

| Req | Slug | Why grouped |
|----|------|-------------|
| 1, 2, 3, 5, 11, 12 | **`journey-scene-v2`** | All live in the Flame scene (`features/journey/presentation/game/`) + need one `/source-assets` pass. Reworking road geometry / POV / scenery / spacing together avoids touching the scene repeatedly. |
| 6 | **`idle-accounting`** | Pure engine-domain correctness (`journey-engine`). Small, and it **unblocks #7**. |
| 8, 9, 10 | **`route-planner-v2`** | All touch route selection + the province-chain model + start picker (`features/route/`). #9 needs a geographic adjacency/ordering model. |
| 4, 7 | **`map-experience`** (merges the existing **`map-geographic`**) | Map placement (#4) + idle overlay (#7) + real geography (existing map-geographic) all touch the map presentation. #9's "auto-insert from the real map" wants the same geography model — build it once here. |

### S1 · split 2026-06-24 into S1a + S1b (Kevin) — POV carved out per architect recommendation
**S1a · `journey-scene-v2`** — Flame scene fidelity & motion  `[blocked by: journey-view ✅]` · **captured, size L, ready to promote**
- **In:** winding/curve road (#1) · scroll animation ×3 slower, same underlying speed (#3) · keep animating when the app loses focus *but visible* (#5) · richer scenery — mountains/beach/city/people/animals/characters/forest (#11) · better object-spacing distribution so it reads as even (#12).
- **Owners:** `flame-game-developer` + `ui-asset-curator`.
- **Bonus:** the mini-window PiP reuses this same scene, so all improvements flow to the PiP for free.
- **Subsumes** carried journey-view polish P-1 (scroll speed) = #3.
- **Flag:** #5 relaxes mini-window NFR-1 (animate when visible-but-unfocused; pause when hidden) — needs a per-OS occlusion-signal spike. #11 "characters" → curator sources **tasteful, license-clean (CC0)** assets only.

**S1b · `journey-pov`** — first-person vehicle frame  `[blocked by: journey-scene-v2]` · **captured, size L, parked behind S1a**
- **In:** POV / steering-wheel/handlebar view + more realistic vehicle + nicer objects (#2). Subsumes carried polish P-2 (motorbike size/blur).
- **Flag:** the **biggest, riskiest** item — may need an art-direction spike (full redirection vs nicer sprite). Cosmetic, single-speed only (per-mode speed = `journey-energy-model`).

### S2 · `idle-accounting` — engine idle-time correctness  `[blocked by: journey-engine ✅]`
- **In:** idle time counts from the moment the state becomes Idle/Paused (#6); **record active-vs-idle segments** along the route so they can be visualised (feeds #7).
- **Owners:** `code-generator` (pure Dart) + `unit-test-writer`.
- **Do first:** small, high-felt correctness fix; **prerequisite for #7 (idle-on-map)**. Needs a repro of current behaviour to define "correct".

### S3 · `route-planner-v2` — flexible route selection & planning  `[blocked by: route-progress ✅, map-experience geography model]`
- **In:** choose many start + many end provinces, not just a direction (#8) · multi-stop with **auto-inserted intermediate provinces from real geography** + a **review-before-start** screen (#9) · **stop current journey & start a new one** (#10).
- **Owners:** `product-domain-expert` (geography/adjacency + route rules) + `flutter-app-developer`.
- **Dep:** the auto-insert (#9) consumes the province-position/adjacency model built in `map-experience`.

### S4 · `map-experience` — map placement + real geography + idle viz  (merge target for `map-geographic`)
- **In:** map overlay on the journey tab + tap → full-screen, **drop the Map tab** (#4) · idle segments drawn **red** on the map road (#7) · **real geography** (province lat/long + adjacency, `flutter_map` + OSM tiles — the existing `map-geographic` scope) that #9 also needs.
- **Owners:** `flutter-app-developer` + map.
- **Deps:** #7 `[blocked by: idle-accounting ✅ (S2)]`; **provides** the geography model `route-planner-v2` (S3) consumes.

## Recommended sequence (dependency-ordered, with parallel tracks)
1. **`idle-accounting` (S2)** — small, pure-Dart, immediate correctness win; unblocks the idle overlay.  ‖  **`journey-scene-v2` (S1)** — independent subsystem, biggest visible payoff, also upgrades the PiP. (S1 ∥ S2 — different code, run in parallel.)
2. **`map-experience` (S4)** — builds the geography foundation (province positions/adjacency) + map placement + idle overlay (needs S2). Absorbs the old `map-geographic`.
3. **`route-planner-v2` (S3)** — last; consumes S4's geography model for waypoint auto-insert.
4. (Existing v2 candidates `journey-energy-model` and `team-leaderboard` slot in independently when wanted.)

## Open questions / decisions to settle at `/capture-idea` time
- **#5 vs battery (mini-window NFR-1):** define "lose focus." Likely: keep animating when the window is **visible but unfocused**; still **pause when hidden-to-tray / minimized** (nothing on screen). Confirm — this deliberately relaxes the NFR-1 we just hardened for the PiP.
- **#2 scope:** nicer vehicle sprite + slight POV, or a full windshield/handlebar POV redirection (→ its own `journey-pov` slug)?
- **#6:** capture a repro of the current idle accounting before defining "correct from that moment."
- **#9 granularity:** does auto-insert use real lat/long (map-geographic) or a curated province-adjacency list? How are intermediate provinces chosen/ordered? Editable by the user?
- **#11 content:** curator sources CC0/permissive, tasteful, broadly-appropriate scenery/characters only.
