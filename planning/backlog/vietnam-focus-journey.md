# Vietnam Focus Journey

**Intake date:** 2026-06-23
**Requested by:** tuyenv@joblogic.com (Kevin / Tuyen Vo)
**Size (rough):** XL (epic)

> Full product & technical plan (locked v1/v2/v3 decisions, agents/skills, workflow): [vietnam_focus_journey_plan.md](vietnam_focus_journey_plan.md) §0.
> This file is the **epic** framing produced by `/capture-idea` (Phase 0). Promote slices with `/new-feature <slug>` in wave order.

## Why
Developers, students, and remote workers struggle to stay motivated through long focus sessions, and existing "productivity tracker" tools feel like surveillance — killing trust before they help. Vietnam Focus Journey reframes focus as play: your active computer time becomes a virtual road trip up or down Vietnam's province chain (Mũi Cà Mau ⇄ Hà Giang), with ~8 active hours crossing the whole country. It is privacy-first by construction (system idle-time only — never keystrokes, screen, or files), giving it a unique local identity and a trust story that monitoring tools can't match. Now is the right moment because the team already has Flutter desktop experience and the core loop ("work → travel") can be validated cheaply with a local-only v1 before any backend or AI investment.

## Domain notes
**Personas touched** (all currently placeholder in `docs/domain/personas.md`):
- The focused individual (developer/student/remote worker) — wants motivation without being watched; success = sustained focus sessions and a sense of progress.
- The privacy-skeptical teammate — will only adopt if the trust claim is verifiable; success = onboarding privacy claims match actual API usage.

**Key edge cases to pin down at spec stage:**
- **Sleep/wake:** on wake, idle is large → read as idle; the sleep gap counts as neither journey nor active time. Elapsed computed from last-tick timestamp, not an assumed interval.
- **Screen lock:** locked = idle even if recent — overrides the grace window.
- **Mid-thought idle inside the grace:** up to ~threshold of true idle counts as travel; **raw active-input time tracked separately** so stats/streaks aren't inflated. (Most important honesty rule.)
- **Day-boundary reset:** daily counters reset at local midnight; cumulative position, streak, badges persist. Timezone/DST and "app closed across midnight" need a rule.
- **Streak qualification:** ≥25 active minutes/day — decide raw vs journey minutes (recommend raw).
- **Route completion:** celebration + summary; no auto-advance; progress kept; explicit user choice to continue.
- **Chain tips & direction:** starting at a tip in the off-chain direction — block or instant-complete (decide).
- **Pacing vs realism:** §11 km/h are flavour; v1 uses one shared `kmPerActiveHour`; modes are cosmetic skins.

**Conflict/overlap check:** `docs/domain/{glossary,business-rules,personas}.md` are all **empty placeholders** — no existing rules to conflict with. This idea seeds the domain docs from scratch; the only caution is internal consistency (journey-time vs raw-active-time; flavour speeds vs the single v1 speed).

### Candidate domain updates (flags only — not written to docs/domain/ yet)
Glossary terms:
- [ ] active time / idle time — active = input within threshold AND screen unlocked AND not sleeping; idle = otherwise.
- [ ] idle threshold — configurable inactivity duration (default 5 min) after which the journey pauses.
- [ ] idle grace window — up-to-threshold true inactivity that still counts as travel.
- [ ] journey time vs raw active time — journey time includes grace (drives distance); raw active time is true input (drives stats/streaks).
- [ ] virtual distance / `kmPerActiveHour` — scaled travel; v1 single shared rate (~8 active hrs = whole country).
- [ ] province chain — ordered Vietnam provinces, Mũi Cà Mau ⇄ Hà Giang; replaces fixed A→B routes.
- [ ] start province + direction — user-chosen origin + north/south heading.
- [ ] checkpoint — a province/city node passed along the chain.
- [ ] travel mode (skin) — v1 cosmetic vehicle sprite; same speed for all.
- [ ] focus-day — ~8 active hours = full length of Vietnam.
- [ ] streak — consecutive local-calendar days meeting the active-minutes threshold.
- [ ] milestone recognition / badge — local achievement (e.g. "100 km this week", "halfway").

Business rules:
- [ ] reads only aggregate system idle time + screen-lock/sleep state — never keystrokes, text, screen, clipboard, files, browser. (Core trust invariant; testable via `privacy-guardian`.)
- [ ] journey is active only when input occurred within threshold AND screen unlocked AND not sleeping; else paused.
- [ ] journey pauses after the configured idle threshold (default 5 min; options 3/5/10/custom).
- [ ] each tick's elapsed time computed from last-tick timestamp, never a fixed interval.
- [ ] a sleep/wake gap counts as neither journey nor active time.
- [ ] distance accrues from journey time (incl. grace); stats/streaks use raw active time.
- [ ] v1: all travel modes share one virtual speed (`kmPerActiveHour`); modes differ only visually.
- [ ] virtual pacing tuned so ~8 active hours covers the full province chain.
- [ ] daily counters reset at local midnight; cumulative position, streak, badges persist.
- [ ] a day counts toward a streak when raw active time ≥ 25 minutes.
- [ ] on reaching the chosen end: celebration + summary; no auto-advance; retain progress; explicit choice to continue.
- [ ] starting at a chain tip in the off-chain direction is disallowed or instant-completes (decide).
- [ ] positioning: a personal/team productivity game, never employee-monitoring software.

## Feasibility (high-level)
**Fit:** Strong. `docs/architecture/overview.md` already locks the stack (Flutter desktop macOS+Windows, Bloc, Clean Architecture) and the Agent roster wires the Flutter implementers/reviewer/privacy/asset roles. No conflict — this idea is why that stack was chosen. The overview is still skeletal (Components/Data-flow/External-deps/Environments/Automation-testing are placeholders) so promotion requires filling them, not rewriting decisions.

**Effort:** XL. Five v1 child items; cost concentrates in the two high-uncertainty ones (native idle plugin, Flame POV scene). Pure-Dart engine + persistence are small and well-specified.

**Key risks:**
1. **Native idle detection (macOS Swift + Windows C++) — top risk; spike first.** Two OS APIs with different sleep/wake & lock behaviour; the whole product is gated on it. Preserve §22 step-0 spike + pub.dev search before custom-plugin work; no child starts native work before the spike lands.
2. **Map/tiles deferred.** v1 = custom-painted province-chain polyline + pins (no live tiles → no OSM policy risk). `flutter_map` + real tiles = v2; don't assume a tile provider as a v1 external dependency.
3. **Unsigned/un-notarized internal distribution.** v1 ships without an Apple Developer account (right-click→Open / SmartScreen). Distribution-UX caveat, not a functional blocker; signing → v3.
4. **Framework-free engine for testability.** `JourneyEngine` = pure Dart, injected clock + injected `ActivityPlugin`, timestamp-delta ticks, separate journey-time vs raw-active-time. The key seam — unit-testable with no timers/native/Flame, and localizes the speed-only→energy (v2) swap.
5. **Cross-platform native parity.** Tray/menu-bar, always-on-top, launch-at-startup diverge per OS; v1 keeps native to idle only (mini-window/tray → v2), but real-Windows parity testing is a recurring tax CI can't fully cover.

### Candidate ADRs (flags only — write via /add-adr if promoted)
- [ ] Flutter desktop (macOS + Windows) as the application stack
- [ ] Bloc (`flutter_bloc`) for state management
- [ ] Clean Architecture layering (presentation/domain/data) + SOLID + DI as the coding-standards baseline
- [ ] Native `ActivityPlugin` interface over platform channels (idle/lock/sleep), with a mock for UI/tests
- [ ] Framework-free `JourneyEngine` (injected clock + ActivityPlugin, timestamp-delta ticks, journey-vs-raw accounting)
- [ ] Local persistence via `shared_preferences`/JSON for v1 (`drift`/SQLite → v2)
- [ ] Custom-painted province-chain map for v1, no live tiles (`flutter_map` → v2)
- [ ] Speed-only distance model, single shared `kmPerActiveHour`; modes are cosmetic skins in v1 (per-mode speeds + energy → v2)
- [ ] Free/CC0 asset-licensing policy + attribution in `assets/CREDITS.md`
- [ ] Privacy-by-design release gate via `privacy-guardian` / `/privacy-audit`
- [ ] Internal unsigned/un-notarized distribution for v1; signing + notarization → v3
- [ ] Flutter test stack: `flutter test` (unit + widget/golden) + `integration_test` (e2e) — fills the overview Automation-testing section before `/execute-tests`

## Headline success signals (epic-level)
- **Idle pauses the journey at the threshold.** At 5-min system idle (no input, or locked/sleeping) the journey pauses, the vehicle visibly stops, a "Paused — idle" indicator shows, and today's distance stops increasing.
- **Activity resumes forward travel.** On new input, within one tick the state returns to active, the road scrolls, and distance resumes.
- **Distance & position survive an app restart** within the same local day (persisted locally).
- **Province-chain position advances and is visible on the map** (passed vs ahead, distance to next, % of country).
- **Privacy promise is verifiable by audit** (`privacy-guardian` confirms only aggregate idle/lock/sleep is read — no keystroke/screen/clipboard/file/browser access).
- **Stats reflect honest active time** — raw active-input time reported separately from (and lower than) journey time.

## Breakdown
Delivered as independently-shippable slices (wave discipline). Promote each with `/new-feature <slug>` in wave order. **Don't start a wave until the previous wave ships.** Wave-2/3 child files are created when their wave starts.

| Wave | Slice (slug) | Scope (one line) | Depends on |
|------|--------------|------------------|------------|
| 1 · v1 | [activity-detection](activity-detection.md) | Native idle/lock/sleep plugin + Dart `ActivityPlugin` + mock source (⚠️ spike first) | — |
| 1 · v1 | [journey-engine](journey-engine.md) | Pure-Dart core loop: active/idle→distance (speed-only), journey vs raw time, persistence | — |
| 1 · v1 | [journey-view](journey-view.md) | Flame POV road scene driven by engine state | [blocked by: journey-engine] |
| 1 · v1 | [route-progress](route-progress.md) | Province-chain + start/direction/position model + custom-painted map screen | [blocked by: journey-engine] |
| 1 · v1 | [local-stats](local-stats.md) | Daily/weekly stats + settings + onboarding/privacy screen + milestone badges | [blocked by: journey-engine] |
| 2 · v2 | mini-window | Always-on-top PiP + tray/menu-bar | [blocked by: journey-view] |
| 2 · v2 | journey-energy-model | Per-mode speeds + energy/fuel strategy | [blocked by: journey-engine] |
| 2 · v2 | map-geographic | `flutter_map` + real tiles | [blocked by: route-progress] |
| 3 · v3 | signed-distribution | Apple notarization + installers | — |

## Open questions (resolve at spec stage, not blocking Phase 0)
- Streak threshold measured in raw active minutes (recommended) vs journey minutes?
- Chain-tip off-direction: block, or instant-complete?
- Day-boundary while app closed: does a missed midnight reset daily counters on next launch using stored date?
- New start province after completion: reset cumulative distance, or keep a lifetime total alongside per-journey distance?
- Exact v1 `kmPerActiveHour` and total chain length (km) — playtest tuning; spec names the source of truth (province data).

## First step
Before any feature: consider `/init-architecture` to fill the overview (Components, Data flow, **Automation testing** runner) and `/add-adr` for the decisions above. Then **promote Wave 1**, starting with the spike-bearing foundation: `/new-feature activity-detection` (and `/new-feature journey-engine` can proceed in parallel — no dependency).
