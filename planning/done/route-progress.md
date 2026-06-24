# Route Progress

**Promoted from backlog:** 2026-06-24
**Shipped:** 2026-06-24 (Wave 1 / v1)
**Target:** Wave 1 (v1) — alongside `journey-engine` + `journey-view` (shipped); `local-stats` remains
**Spec:** [specs/route-progress/](../../specs/route-progress/) — `Status: shipped (2026-06-24)`
**Green report shipped on:** [tests/_runner/reports/route-progress/20260624-113456/](../../tests/_runner/reports/route-progress/20260624-113456/summary.md) — `verdict: green`, 145/145 in-scope (308/308 full regression)

## Goal
Turn the engine's cumulative `distanceKm` into a *place*: model Vietnam as one ordered province chain
(Mũi Cà Mau ⇄ Hà Giang), let the user pick start + direction, resolve position (passed / next / distance-to-next / % of country) on a custom-painted map, and handle route completion (celebration + summary, no auto-advance).

## Plan
- [x] Copy spec template → `specs/route-progress/`
- [x] Draft spec (`spec.md`) — problem / scope / constraints / open questions
- [x] Domain framing — `product-domain-expert` proposed 22 ACs (18 functional + 4 NFR)
- [x] **Kevin reviewed & approved spec** (2026-06-24); resolved all 5 open questions
- [x] Test cases — `test-case-designer` wrote **24 cases** (TC-001..018 + TC-014b + TC-NF1..NF4); `test-plan.md` filled.
- [x] Implement (`/implement`) — chain model + position math (domain) · persistence (data) · custom-painted map + Cubit (presentation)
- [x] Review (`/review-code`) + `/privacy-audit` — approved (B-1 fixed); privacy **PASS**
- [x] Execute tests (`/execute-tests`) — **green** 145/145 in-scope (report `20260624-113456`)
- [x] Ship (`/ship`) — **SHIPPED 2026-06-24**; all 18 ACs + 4 NFRs ticked; spec `shipped`; moved to `planning/done/`

## Phase ledger
- [x] Phase 2 · Spec — spec **approved**; 22 ACs; 5 open questions resolved; 24 test cases; test-plan filled.
- [x] Phase 3 · Build — `/implement`: full slice built (domain/data/presentation) + `ActivityTicker.onDistance` scalar wiring (engine untouched); AC-8/AC-11 contradiction ratified; `/self-review` blockers fixed. 308 tests green, analyze + format clean.
- [x] Phase 4 · Review — `/review-code` **changes requested** (B-1 stale integration-test assertion; production source **approved as-is**) → **B-1 fixed**; `/privacy-audit` **PASS**.
- [x] Phase 5 · Test — `/execute-tests` **green** — 145 in-scope (142 unit/widget + 3 integration on macOS device) + 308/308 regression, 0 flakes; report `20260624-113456`.
- [x] Phase 6 · Ship — `/ship` **SHIPPED 2026-06-24**; all ACs ticked (Performance NFR ticked w/ on-device fps carry-over); spec `shipped`; moved here.

**Current phase:** DONE (shipped 2026-06-24). **Unblocks:** nothing pending in Wave 1 except `local-stats` (independent, `[blocked by: journey-engine]` — already satisfied). **v2 `map-geographic`** is `[blocked by: route-progress]` → now unblocked for Wave 2.

## What shipped
- **Province-chain domain model** — `vietnamProvinceChain` (`features/route/domain/province_chain.dart`): a curated
  **13-checkpoint** ordered chain Mũi Cà Mau → Hà Giang whose segments sum to **exactly 2000 km**
  (`totalChainKm`), constructor-validated (strictly ordered, all-positive segments, sum == total). Direction-aware
  helpers (`destinationOf`, `distanceFromStartTo`, `distanceToDestination`, `checkpointsAhead`, `isOffDirectionTip`).
- **Pure position resolver** (`route_progress_resolver.dart`) — `resolve({routeDistanceKm, selection, chain}) →
  RoutePosition{passed, next, distanceToNextKm, currentSegment, percentOfCountry, isCompleted, fractionAlongRoute}`.
  Framework-free, deterministic. Boundary rule "reached at exactly its distance = passed"; monotonic; NaN/±Inf and
  negative distance clamped; **completion freezes ALL outputs at the destination** (incl. a persisted-`completed`
  selection below its distance).
- **Per-route offset (engine untouched)** — position math runs on `routeDistanceKm = cumulative − routeStartOffset`.
  `RouteProgressCubit.startNewRoute` captures the offset; the shipped `JourneyEngine` got **no reset API and no
  change**; its cumulative `distanceKm` doubles as a free lifetime total.
- **Custom-painted map** (`route_map_painter.dart` / `route_map_screen.dart`) — offline `CustomPainter` polyline +
  km-weighted checkpoint pins + start/current/destination markers + "next: <province> in N km" / "% of Vietnam"
  readout + completion celebration. Value-equal geometry + `BlocSelector`/`buildWhen` so 1 Hz distance ticks don't
  reallocate static geometry. **No network, no tiles.**
- **Start picker** (`start_picker.dart`) — blocks off-chain tip/direction combos in the UI; `RouteSelection.create`
  defensively rejects an off-direction tip pair.
- **Persistence** (`shared_preferences_route_repository.dart`) — single key `route_selection_v1`, JSON
  `{startId, direction, routeStartOffsetKm, completed}`, corrupt-blob-safe `load() → null`.
- **Wiring** — `main.dart` async composition root feeds the cubit a bare `double` via `ActivityTicker.onDistance`;
  `kmPerActiveHour` injected = `2000/8 = 250` (== engine's shipped placeholder, no retune).
- **Tests** — 145 in-scope (142 unit/widget + 3 integration on macOS device) across resolver/chain/selection/repo/
  cubit/picker/map + persistence & wiring smokes. `/review-code` **approved** (after B-1), `/privacy-audit` **PASS**,
  `/execute-tests` **green 145/145** (308/308 full regression).

### Resolved decisions (Kevin, 2026-06-24 at approval)
1. **`kmPerActiveHour` ↔ chain-total seam** → route owns `totalChainKm ≈ 2000`; engine takes injected rate = 250 (no retune). *Closes journey-engine's carried follow-up.*
2. **New-start basis** → **per-route offset**; engine never reset; cumulative = lifetime total.
3. **% of country** → distance-based, full-chain (`routeDistanceKm ÷ totalChainKm`, capped 100%).
4. **Chain-tip off-direction** → block in the picker.
5. **Province granularity** → curated ~10–15 checkpoints.
6. **(Ratified mid-build)** completion fires on **arrival at the destination tip**, NOT at % = 100% — a mid-chain route honestly completes at < 100% (only tip-to-tip = 100%).

## What we'd do differently
- **Catch spec self-contradictions at spec time, not mid-build.** The AC-8 (% full-chain) vs AC-11 ("100% at completion")
  conflict was only surfaced by two test agents *during build*. A spec-review pass that traces each numeric AC against
  the locked decisions would have caught "mid-chain start can't hit 100% under a full-chain denominator" before any code.
- **Keep worked-example fixtures arithmetically self-checked.** The AC/TC fixture diagram shipped internally inconsistent
  (last segment 300 + a stray cumulative ⇒ total ≠ stated 1440), forcing a mid-build correction. A one-line "segments sum
  to total" assertion *in the doc fixture* (as the chain constant itself has) would have caught it.
- **Run the integration tier on-device every phase, not just at the test gate.** "308 green" (Build) was the headless
  unit/widget tier only; the stale-assertion blocker (B-1) lived in an `integration_test/` file that needs `-d macos`
  and so went unrun until `/review-code` flagged it. Running `integration_test/ -d macos` in Build would have caught
  B-1 a phase earlier.
- **Self-review earns its keep.** It caught a real masked bug (celebration hardcoded "100%" with a test asserting the
  wrong value) plus a latent tiny-canvas crash — neither would have been caught by the green unit suite alone.

## Open follow-ups (non-blocking; carried forward)
- **TC-NF2 — on-device frame-rate not instrumented** → `test-executor` + `flutter-app-developer`. The Performance NFR's
  bounded-redraw half is verified deterministically (value-equal geometry + `buildWhen`), but "no sustained jank / ≥ target
  fps as the marker advances" was never measured (project golden/perf infra deferred, same as `journey-view`'s fps NFR).
  **Measure on macOS + Windows before any public release.**
- **Review Lows/Nit (no change required):** L-1 fire-and-forget completion `save()` (`route_progress_cubit.dart:127`);
  L-2 `startNewRoute` mutates `_cumulativeDistanceKm` from its override; N-1 `destinationOf` ignores its `start` param.
- **`map-geographic` (v2)** now unblocked — will reuse this chain model + position math behind real `flutter_map` tiles.

## Status log
| Date | Note |
|------|------|
| 2026-06-24 | Promoted from backlog via `/new-feature route-progress` (dependency `journey-engine` shipped 2026-06-23). Copied template; drafted `spec.md` (pure consumer of engine `distanceKm`; province chain + custom-painted map + completion). `product-domain-expert` proposed 22 ACs (5 flagged on open questions). Created active entry. |
| 2026-06-24 | **Kevin reviewed & APPROVED the spec** + resolved all 5 open questions: (1) per-route offset — engine never reset; (2) route owns `totalChainKm ≈ 2000`, engine takes injected `kmPerActiveHour` = 250 (no retune); (3) % = distance-based full-chain; (4) block off-direction tips in picker; (5) curated ~10–15 checkpoints. Folded decisions into spec + resolved the ⚠ flags in ACs. Spec `Status: approved`. |
| 2026-06-24 | **Phase 2 COMPLETE.** `test-case-designer` wrote **24 cases** (TC-001..018 + TC-014b + TC-NF1..NF4) — all 18 ACs + 4 NFRs covered, the 5 locked decisions encoded; filled `test-plan.md` (coverage matrix + risks). → ready for `/implement`. |
| 2026-06-24 | **Phase 3 BUILD COMPLETE.** `flutter-app-developer` built the slice under `src/focus_journey/lib/features/route/` (domain resolver + 13-node/2000 km chain + off-direction-tip guard · `shared_preferences` repo · custom-painted map/painter/picker/cubit). Wiring: `main.dart` async composition root + `ActivityTicker.onDistance` scalar seam (route cubit holds NO engine ref → AC-16/17 by construction; `kmPerActiveHour` injected = 250, engine untouched). `unit-test-writer` (+5) & `test-script-author` (+6) added tests. **Mid-build both test agents surfaced an AC-8 vs AC-11 contradiction; Kevin ratified arrival=complete + full-chain honest %** — resolver hardened to freeze all outputs at the destination (fixed %-drift + persisted-completed bugs); AC-11/TC-011 + fixture diagram corrected (segments `[60,170,300,310,600]`=1440). `/self-review`: **changes-requested** — 1 blocker (celebration hardcoded "100%") + masking test + suggestions → **all fixed** (also a latent tiny-canvas `ArgumentError`). **308 tests green, analyze + format clean.** |
| 2026-06-24 | **Phase 4 REVIEW — verdict `changes requested` (1 blocker); `/privacy-audit` PASS.** `flutter-code-reviewer`: **production source approved as-is**, all 5 decisions + 18 ACs faithfully implemented, self-review fixes verified, Clean-Arch/Bloc/null-safety clean. **B-1:** `route_persistence_test.dart:138` asserted ≈100% for the mid-chain route (honest 95.833%) — **stale test, not a code defect**. **M-1:** integration tier needed on-device validation. Lows/Nit no-change. **`privacy-guardian` PASS** — `features/route/**` imports only `equatable`/`flutter_bloc`/`material`/`shared_preferences`/`dart:convert`/`dart:math` + domain; no platform-channel/OS/network/tile/file/clipboard; persistence aggregate-only; `onDistance` forwards a bare `double`. **Zero new privacy surface.** |
| 2026-06-24 | **Phase 5 TEST — verdict `green`.** B-1 fixed (structural `dest ÷ chain.totalChainKm × 100` ≈ 95.83, frozen across +1000 km). `test-executor` (Flutter 3.38.10 / Dart 3.10.9): unit/widget **142/142** (route) + **308/308** full-regression w/ coverage; integration on **macOS device** — `route_persistence_test.dart` 2/2 + `route_wiring_smoke_test.dart` 1/1 (per-file). **145 in-scope, 0 failed, 0 flaky.** M-1 closed. Report `20260624-113456` (`verdict: green`) + `lcov.info`. Ticked 18/18 functional ACs + 3/4 NFRs; Performance NFR's fps half carried (TC-NF2). |
| 2026-06-24 | **`/ship` COMPLETE — SHIPPED.** Gates verified: all ACs checked (Performance NFR ticked with the on-device fps measurement carried as a post-ship note, matching the `journey-view` precedent), no P0/P1 case unimplemented, green report `20260624-113456` (`verdict: green`, 145/145) present and **not stale** (no `src/` file newer than the report). Set spec `Status: shipped (2026-06-24)`; moved `planning/active/route-progress.md` → `planning/done/`. Carry-overs: TC-NF2 on-device fps (macOS+Windows), review Lows/Nit (no change). **Wave 1 now 4/5 shipped — only `local-stats` remains.** |

## Decisions made along the way
- Route-progress is a **pure consumer** of the engine's `distanceKm` (mirrors `journey-view`'s pure-consumer pattern) — zero activity logic, zero new privacy surface (verified by `/privacy-audit`).
- v1 map is **custom-painted** (polyline + pins), no live tiles/network — `flutter_map` + OSM is v2 (`map-geographic`).
- Completion is **terminal until explicit user choice** — no auto-advance; progress retained; arrival (not % = 100) triggers it.
- **Per-route offset** means the shipped `journey-engine` needed **no change**; the **injected-rate seam** (route owns total, engine takes rate) closed journey-engine's carried `kmPerActiveHour` follow-up.
