# Test cases: route-progress

Spec: [specs/route-progress/spec.md](../../specs/route-progress/spec.md)
Acceptance criteria: [specs/route-progress/acceptance-criteria.md](../../specs/route-progress/acceptance-criteria.md)
Upstream (shipped): [specs/journey-engine/spec.md](../../specs/journey-engine/spec.md) — supplies the single cumulative scalar `distanceKm` via the journey Bloc / engine seam.
Sibling consumer (shipped): [specs/journey-view/spec.md](../../specs/journey-view/spec.md) — the pure-consumer pattern these cases mirror.

## Scope of these cases

These cases verify the **route/progress model + its custom-painted map screen** as a **pure consumer**
of the engine's cumulative `distanceKm`. The model owns the *geography* — an ordered Vietnam province
chain (Mũi Cà Mau ⇄ Hà Giang) with inter-checkpoint distances, a deterministic position-resolution
function, and the terminal completion rule — and turns `distanceKm` into *place*: provinces passed,
the next province ahead, distance-to-next, the current segment, and % of country. They verify the
**per-route offset** model (`routeDistanceKm = engine.distanceKm − routeStartOffset`; engine never
reset), **direction** handling, **persistence** of start/direction/completed-state across restart,
**route completion** (celebration + summary, % capped at 100%, no rollback, no auto-advance), the
**chain-tip off-direction block in the picker**, and the **purity / privacy invariant** (reads only
`distanceKm`, no OS/activity surface, no network/tiles).

They deliberately do NOT re-exercise: active/idle judgment, grace/threshold model, distance accrual,
sleep/wake, midnight rollover, the `kmPerActiveHour` accrual itself (all `journey-engine`, tested
there — this slice only *injects* the rate config and *reads* the resulting `distanceKm`); real OS
idle/lock acquisition (`activity-detection`); the POV road scene (`journey-view`); stats / streaks /
badges (`local-stats`); per-mode speeds / energy (v2 `journey-energy-model`); live map tiles / real
GIS coordinates (v2 `map-geographic`).

## The five locked decisions these cases encode (Kevin, 2026-06-24 — do not re-open)

1. **Per-route offset; engine never reset.** Position math operates on
   `routeDistanceKm = engine.distanceKm − routeStartOffset`. The shipped engine's cumulative
   `distanceKm` is a lifetime total and is never reset; a new start captures a new offset so the new
   route restarts at `routeDistanceKm = 0` while cumulative keeps climbing. (AC-14)
2. **`totalChainKm ≈ 2000`, rate `250` injected.** route-progress owns the chain total; the engine
   takes `kmPerActiveHour` as injected config (default `250 == 2000 ÷ ~8h`). (Chain-data NFR)
3. **% of country = distance-based, full-chain denominator** = `routeDistanceKm ÷ totalChainKm`,
   capped at 100%. (AC-1 / AC-8)
4. **Chain-tip off-direction = blocked in the picker** — the off-chain direction is disabled for a tip
   province; the model never starts already-finished. (AC-15)
5. **Curated chain of ~10–15 major checkpoints** along Mũi Cà Mau → Hà Giang. (Smooth-paint NFR)

## Conventions used by these cases

- **Fixture chain (structure, not literals).** The position-resolution cases run against a small,
  explicit ordered chain — the ACs' worked example:

  ```
  Mũi Cà Mau ─60→ Cần Thơ ─170→ Đà Lạt ─300→ Đà Nẵng ─310→ Hà Nội ─600→ Hà Giang
       0          60         230        530        840        1440
  ```
  (cumulative km from the Mũi-Cà-Mau end under each node; total chain length = 1440 km in the fixture.
  Segments `[60, 170, 300, 310, 600]` sum to 1440, making Đà Nẵng = 470 km and Hà Giang = 1380 km from
  Cần Thơ's start — the numbers TC-001/TC-011 assert. *Fixture corrected 2026-06-24 (prior diagram's
  300 km final segment + stray cumulative contradicted those distances).* The AC-7/TC-007 north-mirror
  clause is illustrative — compute its expected passed/next from the segment structure, not the prose.)
  **Tests key off the fixture's *structure* — an ordered node list, positive inter-node segment
  distances, and the declared total — NOT the literal numbers.** They must survive re-tuning to the
  production curated ~10–15-checkpoint chain whose summed segments give `totalChainKm ≈ 2000`. Each
  case states its expected outputs *relative to the fixture* (e.g. "passed = origin + every checkpoint
  whose cumulative distance from start ≤ routeDistanceKm"), with the literal fixture values shown only
  as a worked illustration.

- **No real engine, no real timers, no wall-clock.** The engine / journey Bloc is replaced by a
  **deterministic, scriptable distance source** (a fake Bloc or in-memory stub exposing a settable
  cumulative `distanceKm`). The model reads `distanceKm`; cases set it directly and resolve position.
  Position resolution is a **pure function** of `(distanceKm, start, direction, chainData)` — no
  timers, no `DateTime.now()`, no Flutter, no I/O — mirroring the engine's framework-free discipline.

- **`routeDistanceKm` is the unit under test for position math.** Unless a case is explicitly about
  the offset (TC-014/TC-014b), it sets `routeStartOffset = 0` so `routeDistanceKm == engine.distanceKm`
  and the fixture's cumulative-from-start numbers apply directly. The offset cases prove that with a
  non-zero offset the *same* position outputs result from the *same* `routeDistanceKm`.

- **Test layer per `docs/architecture/overview.md`.** Executable tests live under `src/focus_journey/`:
  pure position-math + chain-integrity → **unit tests** (`src/test/`); the custom-painted map / picker
  → **widget / golden tests** (`src/test/`); full Bloc↔model↔map wiring and restart-persistence
  smokes → **integration tests** (`src/integration_test/`); the separation / privacy cases →
  **static inspection** (grep / source review / `/privacy-audit`). `tests/cases/` (this file) holds
  the human-readable scenarios only; no executable test is placed under the top-level `tests/` tree.

- **Persistence is mocked in-memory.** The `shared_preferences`/JSON repository seam is faked
  in-memory for restart cases; "restart" = construct a fresh model/Bloc that restores from the saved
  blob. No new persistence store is introduced (AC-9/AC-10).

- **Float tolerance.** Where a case asserts a distance-to-next or a % value, "equal" means within
  **±1e-6** (km, resp. percentage points) unless stated otherwise, to absorb division rounding.
  Percentage assertions also tolerate the documented rounding the readout uses (e.g. one decimal
  place); cases state the underlying ratio so the assertion survives display-format changes.

- **Boundary rule (fixed).** A checkpoint reached at **exactly** its cumulative distance counts as
  **passed/reached**, and `next` advances to the following checkpoint. The literal node distances follow
  the curated chain; the rule is invariant.

## Cases

### Case: Mid-chain position resolution reports passed / next / distance-to-next / segment / %
**ID:** TC-001
**Priority:** P0
**Type:** happy-path
**Covers:** AC-1

Given the fixture chain, start = `Cần Thơ`, direction = `north` (toward Hà Giang), `routeStartOffset = 0`, and the distance source reports `distanceKm = 400` (so `routeDistanceKm = 400`)
When the model resolves position
Then it reports **passed** = the origin plus every checkpoint whose cumulative distance from the start ≤ `routeDistanceKm` (fixture: [`Cần Thơ`, `Đà Lạt`]), **next ahead** = the first un-passed checkpoint (`Đà Nẵng`), **distance-to-next** = that checkpoint's cumulative-from-start minus `routeDistanceKm` (fixture: 470 − 400 = 70 km), **current segment** = last-passed → next (`Đà Lạt → Đà Nẵng`), and **% of country** = `routeDistanceKm ÷ totalChainKm` capped at 100% (fixture: 400 ÷ 1440 ≈ 27.8%)

**Notes:** Pure-function unit test (`src/test/`). Assert against the structural rule, asserting the fixture literals (70 km, 27.8%) as the worked illustration. The start node itself counts as already reached/passed; distance-to-next is always remaining km to the next un-passed checkpoint.

---

### Case: Distance = 0 at the start — origin only passed, in-progress, marker on start pin
**ID:** TC-002
**Priority:** P0
**Type:** boundary
**Covers:** AC-2

Given start = `Cần Thơ` heading `north`, `routeStartOffset = 0`, and `routeDistanceKm = 0`
When the model resolves position
Then **passed** = the origin only (fixture: [`Cần Thơ`]), **next ahead** = the immediately following checkpoint (`Đà Lạt`), **distance-to-next** = that first segment's length (170 km), **current segment** = origin → next (`Cần Thơ → Đà Lạt`), **% of country** = 0%, the route state is **in-progress** (not completed), and the current-position marker sits exactly on the start pin

**Notes:** Pure-function unit test (`src/test/`) for the model state; a companion **widget/golden** pins the marker-on-start-pin frame. Lower boundary of position math. Asserts the route never begins already-completed for a valid (non-tip-off-direction) start (pairs with AC-15 / TC-015).

---

### Case: Distance exactly on a checkpoint — reached counts as passed, next advances
**ID:** TC-003
**Priority:** P0
**Type:** boundary
**Covers:** AC-3

Given start = `Cần Thơ` heading `north`, `routeStartOffset = 0`, and `routeDistanceKm` equals exactly a checkpoint's cumulative-from-start distance (fixture: `170`, the Cần Thơ→Đà Lạt segment, landing on `Đà Lạt`)
When the model resolves position
Then that checkpoint (`Đà Lạt`) is reported as **passed/reached** (reached at exactly its distance counts as passed), **next ahead** advances to the following checkpoint (`Đà Nẵng`), **distance-to-next** = the next segment's full length (300 km), **current segment** = `Đà Lạt → Đà Nẵng`, and the classification is **deterministic** — the same input always yields the same result with no flicker between segments

**Notes:** Pure-function unit test (`src/test/`). Encodes the fixed boundary rule "reached at exactly its distance = passed; next advances". Resolve the same input twice and assert identical output (determinism at the boundary).

---

### Case: Just before a checkpoint — not yet passed, distance-to-next = the small remainder
**ID:** TC-004
**Priority:** P0
**Type:** boundary
**Covers:** AC-4, AC-3

Given start = `Cần Thơ` heading `north`, `routeStartOffset = 0`, and `routeDistanceKm` is one unit short of a checkpoint's cumulative-from-start distance (fixture: `169`, 1 km short of `Đà Lạt`)
When the model resolves position
Then that checkpoint (`Đà Lạt`) is **not yet** passed, **next ahead** = that checkpoint (`Đà Lạt`), **distance-to-next** = the remainder (1 km), **current segment** = origin → that checkpoint (`Cần Thơ → Đà Lạt`), and **% of country** = `routeDistanceKm ÷ totalChainKm` (fixture: 169 ÷ 1440 ≈ 11.7%)

**Notes:** Pure-function unit test (`src/test/`). The "before" leg of the 169/170/171 boundary triplet (TC-004 → TC-003 → TC-005).

---

### Case: Just after a checkpoint — passed, next is the following checkpoint
**ID:** TC-005
**Priority:** P0
**Type:** boundary
**Covers:** AC-5, AC-3

Given start = `Cần Thơ` heading `north`, `routeStartOffset = 0`, and `routeDistanceKm` is one unit past a checkpoint's cumulative-from-start distance (fixture: `171`, 1 km past `Đà Lạt`)
When the model resolves position
Then that checkpoint (`Đà Lạt`) **is** passed, **next ahead** = the following checkpoint (`Đà Nẵng`), **distance-to-next** = next-segment length minus the 1 km already into it (fixture: 299 km), **current segment** = `Đà Lạt → Đà Nẵng`

**Notes:** Pure-function unit test (`src/test/`). The "after" leg of the boundary triplet. TC-004/TC-003/TC-005 together demonstrate the boundary transition is monotonic and off-by-one-safe across 169 / 170 / 171.

---

### Case: Monotonic advance over a strictly increasing distance sequence
**ID:** TC-006
**Priority:** P0
**Type:** boundary
**Covers:** AC-6

Given a fixed start + direction (`routeStartOffset = 0`) and a strictly increasing sequence of `routeDistanceKm` values fed to the model
When the model resolves position at each value in turn
Then the count of provinces passed is **non-decreasing**, % of country is **non-decreasing**, and the current-position marker only ever moves toward the destination — it never moves backward for a forward distance change, and `next ahead` never regresses to an already-passed checkpoint

**Notes:** Pure-function unit test (`src/test/`) iterating a synthetic increasing sequence (e.g. 0, 60, 169, 170, 171, 400, 1000, 1440). Assert each resolved field is monotone in the forward direction. Pairs with the on-marker smooth-paint NFR (TC-019).

---

### Case: South is the mirror of north from the same start
**ID:** TC-007
**Priority:** P0
**Type:** direction
**Covers:** AC-7

Given the same start = `Đà Nẵng` and `routeDistanceKm = 300`, resolved once with direction = `south` (toward Mũi Cà Mau) and once (sibling run) with direction = `north`
When the model resolves each
Then `south` walks the chain in the **opposite** order — **passed** = origin + checkpoints reached going south (fixture: [`Đà Nẵng`, `Đà Lạt`]), **next ahead** = the next southward checkpoint (`Cần Thơ`), **distance-to-next** = 170 km, **current segment** = `Đà Lạt → Cần Thơ` — while `north` from the same start + same distance yields the mirror result (fixture: passed up to `Hà Nội`, next ahead = `Hà Giang`); the only difference between the two runs is traversal direction, the position math is otherwise identical

**Notes:** Pure-function unit test (`src/test/`) running both directions against the same start/distance and asserting the mirrored passed-list / next / segment. Guards against north-only assumptions baked into the walk.

---

### Case: Direction sets which tip is the destination; % uses full-chain denominator
**ID:** TC-008
**Priority:** P0
**Type:** direction
**Covers:** AC-8

Given start = `Đà Lạt`, resolved once direction = `north` and once direction = `south`
When the model identifies the completion target and computes % of country
Then direction = `north` makes the north tip (`Hà Giang`) the completion target with the south tip (`Mũi Cà Mau`) unreachable, direction = `south` makes the south tip (`Mũi Cà Mau`) the target with the north tip unreachable, and in **both** directions **% of country** is **distance-based against the full chain** = `routeDistanceKm ÷ totalChainKm` capped at 100% (fixture denominator 1440; production `totalChainKm ≈ 2000`) — NOT the chosen-direction span

**Notes:** Pure-function unit test (`src/test/`). Encodes locked decision 5 (full-chain denominator). Assert the % ratio uses `totalChainKm`, not the remaining-chain-in-direction length, for both directions. Distance-to-completion may use the direction's remaining chain, but the % denominator must be the full chain.

---

### Case: New start after completion captures the offset — route restarts at 0, cumulative unchanged
**ID:** TC-014
**Priority:** P0
**Type:** offset
**Covers:** AC-14

Given a completed route and the distance source's cumulative `distanceKm = D` (e.g. 1500, climbing unbroken from the engine's lifetime total)
When the user explicitly selects a new start + direction
Then the model captures the **current cumulative `distanceKm` as the new `routeStartOffset`** (= D), begins resolving the new route from `routeDistanceKm = engine.distanceKm − routeStartOffset = 0`, the new route reports the start-only / in-progress state (per TC-002) even though cumulative keeps climbing, and the engine's cumulative `distanceKm` is **never reset** — it is read, not written (asserted via the fake source recording zero writes)

**Notes:** Pure-function + fake-source unit test (`src/test/`). Encodes locked decision 1. Assert (a) offset == cumulative at the moment of the new start, (b) resolved `routeDistanceKm == 0` immediately after, (c) the fake distance source observed **no** write/reset call. For the very first route the offset is the cumulative at first start (typically 0).

---

### Case: All position math operates on routeDistanceKm — identical outputs under a non-zero offset
**ID:** TC-014b
**Priority:** P0
**Type:** offset
**Covers:** AC-14, AC-1

Given two runs with the same start + direction that produce the same `routeDistanceKm = R` (e.g. 400): run A with `routeStartOffset = 0` and cumulative `distanceKm = 400`; run B with `routeStartOffset = 1100` and cumulative `distanceKm = 1500`
When the model resolves position in each
Then both runs produce **identical** passed / next / distance-to-next / current-segment / % outputs (within ±1e-6) — confirming position math keys off `routeDistanceKm` (cumulative − offset), never raw cumulative

**Notes:** Pure-function unit test (`src/test/`). The structural complement to TC-014: it proves the offset is correctly subtracted everywhere, not just at start capture. Guards against any path that accidentally reads raw cumulative for the % or the walk.

---

### Case: Start + direction persist across an app restart
**ID:** TC-009
**Priority:** P0
**Type:** persistence
**Covers:** AC-9

Given the user has selected start = `Cần Thơ` and direction = `north` and the selection is saved via the (in-memory) `shared_preferences`/JSON repository seam
When the app is closed and relaunched (a fresh model/Bloc restores from the saved blob)
Then the same start + direction are restored, the map resolves the current `distanceKm` against that restored selection, the user is **never** silently reset to a default start/direction, and **no new persistence store** is introduced

**Notes:** Integration test (`src/integration_test/`) with a faked in-memory repository; the restore path is also unit-testable (`src/test/`). Assert the restored selection equals the saved one and that resolution after restore matches a same-selection resolution. Reuses the established seam — assert no new store/key namespace beyond the existing pattern.

---

### Case: Route-completion state persists across an app restart
**ID:** TC-010
**Priority:** P0
**Type:** persistence
**Covers:** AC-10, AC-11

Given a route that has reached **completed** (per TC-011) before the app closes, with its completion saved via the in-memory seam
When the app relaunches (fresh model/Bloc restores from the saved blob)
Then the route is **still** reported as completed with its summary available, and it does **not** revert to in-progress nor auto-start a new route

**Notes:** Integration test (`src/integration_test/`) with the faked repository. Assert post-restore `state == completed`, summary present, and that resolving the (still-climbing) `distanceKm` does not flip it back to in-progress or start a new route (pairs with TC-013). Restore path is also unit-testable.

---

### Case: Reaching the chain end → completed + celebration/summary; % is the honest full-chain value at arrival
**ID:** TC-011
**Priority:** P0
**Type:** completion
**Covers:** AC-11

> ✅ **Ratified (Kevin, 2026-06-24):** completion fires on **arrival at the chosen destination tip**, NOT on % = 100%. Per decision 3, % of country is full-chain (`routeDistanceKm ÷ totalChainKm`, capped 100%), so a route that **started mid-chain completes at < 100%** — the honest fraction of Vietnam crossed. Only a full **tip-to-tip** route reaches 100%. Both legs below are required.

Given start = `Cần Thơ` heading `north` (destination tip = `Hà Giang`; fixture distance-to-destination = 1380 km from Cần Thơ's start position), `routeStartOffset = 0`, and `routeDistanceKm` reaches or exceeds that distance-to-destination
When the model resolves position
Then the route enters a **completed** state, the destination tip (`Hà Giang`) is reported as reached, **% of country** = the honest full-chain arrival value `1380 ÷ 1440 ≈ 95.83%` (NOT 100% — this is a mid-chain start), the value is **frozen/terminal** for any larger `routeDistanceKm` (it does not drift toward 100%), and a **celebration + summary** is shown (e.g. provinces crossed and total distance/time for the route)
And (tip-to-tip leg) Given start = `Mũi Cà Mau` heading `north` (a full tip-to-tip route), When `routeDistanceKm ≥ totalChainKm`, Then **% of country** = exactly **100%** (capped — never > 100%)

**Notes:** Pure-function unit test for the completed/% state (`src/test/`) plus a **widget/golden** for the celebration + summary surface. Assert (a) the mid-chain arrival % is the honest < 100 value and is **frozen** for `routeDistanceKm` well beyond the destination (terminal, pairs with TC-013), and (b) a tip-to-tip route hits exactly 100%. Distance-to-destination is computed structurally (sum of remaining segments in the chosen direction), not hardcoded to 1380.

---

### Case: Completion retains progress, clamps display to destination, no rollback
**ID:** TC-012
**Priority:** P0
**Type:** completion
**Covers:** AC-12

Given a completed route and `routeDistanceKm` beyond the destination's distance
When the model resolves position and renders the marker
Then cumulative progress is **retained** — the model does not zero or roll back `distanceKm` (the engine's cumulative is untouched, asserted via zero writes to the fake source), the displayed position is **clamped to the destination pin** (the marker never overshoots the final pin), and a relaunch still shows the completed route (pairs with TC-010); position never reports a rollback for a forward distance change

**Notes:** Pure-function + widget test (`src/test/`). Assert (a) no write to the distance source, (b) displayed marker position == destination pin for any `routeDistanceKm ≥ distance-to-destination`, (c) % stays **frozen at the arrival value** (full-chain; 95.83% for the mid-chain fixture route, 100% only tip-to-tip — TC-011), (d) no negative/backward movement.

---

### Case: No auto-advance — continued distance makes no further progress, starts no new route
**ID:** TC-013
**Priority:** P0
**Type:** completion
**Covers:** AC-13

Given a completed route, with no explicit user choice made
When the distance source continues to report increasing `distanceKm` (the user keeps focusing)
Then the model makes **no further forward progress** on the chain and does **not** start a new route, pick a new start, or reverse direction on its own — it stays at the completed destination with **% frozen at its arrival value** (the honest full-chain value; not necessarily 100%) until the user makes an **explicit** choice to continue; completion is **terminal** until that explicit action

**Notes:** Pure-function unit test (`src/test/`) feeding several increasing `distanceKm` values after completion and asserting the resolved position/state never changes (no new route, no marker movement, no direction flip). Encodes "completion is terminal until user choice"; the explicit-new-start path is TC-014. Pairs with TC-010 (the persisted completed state likewise does not auto-advance on relaunch).

---

### Case: Chain-tip off-direction is blocked in the picker; model never starts already-finished
**ID:** TC-015
**Priority:** P0
**Type:** chain-tip
**Covers:** AC-15

Given the start picker and a chain-tip province pointed off the chain (e.g. start = `Hà Giang` direction = `north`, or start = `Mũi Cà Mau` direction = `south`)
When the user attempts that selection
Then the invalid direction is **disabled/unavailable** for that tip in the picker so the selection cannot be committed, and consequently the model **never** enters a state with zero reachable checkpoints ahead at `routeDistanceKm = 0` — a route can never begin already-finished

**Notes:** Widget test on the picker (`src/test/`) asserting the off-chain direction control is disabled for each tip; plus a **negative** model-level unit test asserting that if the invalid (tip, off-direction) pair were nonetheless passed to the model it does not produce a zero-checkpoints-ahead in-progress state (it must reject/guard, not silently start finished). Encodes locked decision 4 (block; instant-complete was rejected).

---

### Case: Model reads only distanceKm — no OS / activity APIs (separation invariant)
**ID:** TC-016
**Priority:** P0
**Type:** purity
**Covers:** AC-16

Given the route-progress source (the chain data, the position-resolution function, the Cubit/Bloc, the map widget/painter, and the picker)
When inspected statically
Then it reads **only** the engine's cumulative `distanceKm` (via the journey Bloc / engine seam) plus its own persisted start/direction/completion selection, and contains **none** of: `ActivityPlugin`, `getSystemIdleSeconds`, `isScreenLocked`, any platform channel / `MethodChannel`, any idle/lock/sleep/OS API, nor any active-vs-idle decision logic, nor any distance-accrual logic — no such imports or calls are present

**Notes:** Static-inspection case (grep / source review over the route-progress files). Mirrors `journey-view` TC-009. Allowed: a `DateTime`/injected value used purely for the summary's elapsed display is permitted but must be distinguished from any activity decision (there should be none here). Re-run on any change to the slice's files. Reinforced by TC-018 (`/privacy-audit`).

---

### Case: Model accrues no distance and owns no engine state (write-free consumer)
**ID:** TC-017
**Priority:** P0
**Type:** purity
**Covers:** AC-17

Given the running model and its source
When inspected statically (and exercised at runtime through any distance sequence)
Then the model never mutates or computes `distanceKm`, `activeTimeToday`, `rawActiveTime`, `idleTimeToday`, or the engine `state` — it only **consumes** `distanceKm` and maps it onto the chain; no write to engine/journey state originates in route-progress, and driving the model through any sequence leaves the source's exposed values untouched

**Notes:** Primarily static-inspection (no assignments / mutating calls to engine state in the slice's files). Runtime guard: a unit/widget test using a fake distance source that records any write attempt and asserts none occurred (reused by TC-014/TC-012 for the no-reset assertions). Mirrors `journey-view` TC-010.

---

### Case: Privacy audit — route-progress adds no new OS surface and no network/tiles
**ID:** TC-018
**Priority:** P0
**Type:** purity
**Covers:** AC-18

Given all route-progress source (chain data, position math, Cubit/Bloc, map painter/widget, picker, persistence wiring) and the dependencies it adds
When `privacy-guardian` runs `/privacy-audit`
Then it confirms the slice introduces **no** dependency or call that reads input / screen / clipboard / files / network, adds **no** OS surface beyond what `journey-engine` / `activity-detection` already audited, and that the custom-painted map uses **no** network or tile provider — and the audit **passes**

**Notes:** Manual audit case, NOT an automated assertion (mirrors `journey-view` TC-026). A fail here blocks ship regardless of other passes. Reinforces the static-inspection cases TC-016/TC-017. Re-run on any change to the slice's source or its dependency set.

---

### Case: Determinism — same (distance, start, direction, chain) always yields the same outputs
**ID:** TC-NF1
**Priority:** P0
**Type:** nfr
**Covers:** NF — Determinism

Given identical inputs `(routeDistanceKm, start, direction, chainData)`
When position resolution is invoked twice (and/or the test is re-executed at a different real-world wall-clock time, on a different machine)
Then every output field (passed, next ahead, distance-to-next, current segment, % of country, completed-state) is **identical** across invocations — the function reads no timer, no `DateTime.now()`, no Flutter, no I/O; output depends only on the inputs

**Notes:** Pure-function unit test (`src/test/`). Mirrors `journey-engine` TC-012. Run the same input twice in one test and assert field-by-field equality; sleeping/advancing the real clock between runs must not change any output. Underpins the whole position-math suite (TC-001..TC-008, TC-011..TC-014).

---

### Case: Smooth custom-painted map as the marker advances — bounded redraws, no per-frame static-geometry allocation
**ID:** TC-NF2
**Priority:** P1
**Type:** nfr
**Covers:** NF — Performance: smooth custom-paint

Given the `CustomPainter`-based map (province-chain polyline, checkpoint pins, start pin, current-position marker, destination pin) rendering the curated ~10–15-checkpoint chain on a typical desktop (macOS + Windows)
When the position marker advances across a sustained run (a sweep of increasing `routeDistanceKm`)
Then the map renders smoothly with no sustained jank as the marker advances, redraws are bounded, and the **static** chain geometry (polyline + pins) is **not** re-allocated per frame in the paint hot path — only the marker/progress overlay updates per frame; `shouldRepaint` returns false when nothing relevant changed

**Notes:** Mixed: (a) `integration_test` / on-device frame-timing sweep (macOS + Windows) capturing build/raster times and asserting no sustained long-frame spikes as the marker moves; (b) static inspection of the painter's `paint`/`shouldRepaint` for per-frame `new`/list allocation of the static geometry and a correct `shouldRepaint`. The curated ~10–15-checkpoint cap (locked decision 5) keeps pins/labels legible and paint cheap — note device + OS in the report. A companion **golden** pins one painted frame for visual-structure regression.

---

### Case: Offline / no network — the map and slice make no network call and use no tile provider
**ID:** TC-NF3
**Priority:** P0
**Type:** nfr
**Covers:** NF — No network / offline

Given the slice running with no network connectivity (and its source + dependency set inspected)
When the map screen renders and the model resolves position end to end
Then no network call is made, no tile provider or external map service is depended upon (no `flutter_map`/OSM in v1), and the entire map renders from local custom-painted geometry — the feature works fully offline

**Notes:** Mixed: static inspection of imports/dependencies for any tile/network package (overlaps TC-016/TC-018) plus an `integration_test` smoke run with networking disabled asserting the map still renders and resolves. Encodes the v1 "custom-painted only; tiles are v2 `map-geographic`" scope.

---

### Case: Chain-data integrity — strictly ordered, positive segments, segment sum == totalChainKm
**ID:** TC-NF4
**Priority:** P0
**Type:** nfr
**Covers:** NF — Chain-data integrity

Given the production province-chain data (and the fixture chain used by the position cases)
When the chain is validated
Then it is **strictly ordered** Mũi Cà Mau → Hà Giang (south tip to north tip), **every** adjacent pair has a **positive** inter-checkpoint distance (no zero or negative segments, no duplicate nodes), the **sum of all segment distances equals the declared `totalChainKm`** (within ±1e-6), and the curated chain holds ~10–15 checkpoints; for the fixture the sum equals 1440, for production it equals `totalChainKm ≈ 2000` (the source of truth that, ÷ ~8 active hours, confirms the engine's injected `kmPerActiveHour ≈ 250`)

**Notes:** Pure-data unit test (`src/test/`) run against both the production chain constant/asset and the test fixture. Assert ordering, all-positive segments, the sum==total invariant, and the ~10–15-node count (locked decisions 2 and 5). This is the data-contract guard that the position-math cases (which assume a well-formed chain) depend on.

---

## Coverage table (AC / non-functional item → covering case IDs)

| Item | Description | Covered by |
|---|---|---|
| AC-1 | mid-chain: passed / next / distance-to-next / segment / % | TC-001, TC-014b |
| AC-2 | distance = 0 at start → origin only, in-progress, marker on start pin | TC-002 |
| AC-3 | distance exactly on a checkpoint → reached = passed, next advances | TC-003, TC-004, TC-005 |
| AC-4 | just before a checkpoint → not yet passed, small distance-to-next | TC-004 |
| AC-5 | just after a checkpoint → passed, next is following checkpoint | TC-005 |
| AC-6 | monotonic advance over increasing distance | TC-006 |
| AC-7 | south is the mirror of north from the same start | TC-007 |
| AC-8 | direction sets destination tip; % = full-chain denominator | TC-008 |
| AC-9 | start + direction persist across restart | TC-009 |
| AC-10 | route-completion state persists across restart | TC-010, TC-013 |
| AC-11 | reaching chain end → completed + celebration/summary, % capped 100% | TC-011, TC-010 |
| AC-12 | completion retains progress, clamps to destination, no rollback | TC-012 |
| AC-13 | no auto-advance — no further progress / new route until user choice | TC-013 |
| AC-14 | new start = per-route offset; engine never reset; math uses routeDistanceKm | TC-014, TC-014b |
| AC-15 | chain-tip off-direction blocked in picker; never starts finished | TC-015 |
| AC-16 | reads only distanceKm — no OS/activity APIs (separation invariant) | TC-016, TC-018 |
| AC-17 | accrues no distance / owns no engine state (write-free consumer) | TC-017, TC-018 |
| AC-18 | no new privacy surface; map uses no tiles/network; passes /privacy-audit | TC-018, TC-016, TC-NF3 |
| NF — Determinism | pure function; same inputs → same outputs | TC-NF1 |
| NF — Performance: smooth custom-paint | smooth marker advance; bounded redraws; no hot-path alloc | TC-NF2 |
| NF — No network / offline | no network/tile provider; renders fully offline | TC-NF3 (reinforced by TC-016, TC-018) |
| NF — Chain-data integrity | ordered, positive segments, sum == totalChainKm, ~10–15 nodes | TC-NF4 |

Every AC (AC-1..AC-18) and every non-functional item maps to at least one case. No AC is orphaned.
