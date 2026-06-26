---
verdict: green
total: 70
passed: 70
failed: 0
flaky: 0
skipped: 0
run_at: 2026-06-26T09:45:19Z
feature: journey-cockpit-lean
---

# Test Run Summary — journey-cockpit-lean

Runner (per `docs/architecture/overview.md`): Flutter via **fvm** (Flutter 3.38.10 / Dart 3.10.9),
run from `src/focus_journey`. Unit/widget/golden/static/perf via `fvm flutter test`; integration via
`fvm flutter test integration_test/<file> -d macos`, **each integration file in its own invocation**
to avoid the documented macOS debug-connection chaining flake.

In-scope automated coverage: TC-501..TC-518 (the 14 ACs + NFR-1 deterministic proxies). All passed.

## Totals
- **In-scope total: 70 passed / 0 failed / 0 flaky / 0 skipped.**
  - Unit/widget/golden/static/perf (one invocation, 5 files): **67 passed** (counter 0..66).
  - Integration two-surface (`journey_cockpit_lean_two_surface_test.dart`, own invocation): **2 passed**.
  - Integration smoke (`journey_cockpit_lean_smoke_test.dart`, own invocation): **1 passed**.
- **Regression check** — broader journey-game suite (`test/features/journey/presentation/game/`):
  **248 passed / 0 failed** (counter 0..247). The lean slice did not break any sibling scene test
  (journey-pov, journey-dynamic-curve, cockpit, mini-window scene tests, etc.).

## Exact commands run (from `src/focus_journey`)
1. `fvm flutter test test/features/journey/presentation/game/journey_cockpit_lean_*` -> `unit.txt`
2. `fvm flutter test integration_test/journey_cockpit_lean_two_surface_test.dart -d macos` -> `integration-two-surface.txt`
3. `fvm flutter test integration_test/journey_cockpit_lean_smoke_test.dart -d macos` -> `integration-smoke.txt`
4. `fvm flutter test test/features/journey/presentation/game/` (regression) -> `regression.txt`

## Per-test -> case mapping
Each TC group is traceable by its TC-id tag in the test description strings.

Unit/widget — `journey_cockpit_lean_behaviour_test.dart` + `journey_cockpit_lean_test.dart`:
- TC-501 lean exists + signed INTO the turn -> AC-1, AC-10 (pass)
- TC-502 sign-flip caught (negative / fault-injection) -> AC-1 (pass)
- TC-503 monotonic |angle| vs |curve| below saturation -> AC-2 (pass)
- TC-504 bounded max roll — clamp ceiling exercised -> AC-3 (pass)
- TC-505 eased/low-pass per-frame delta cap, no snap incl. sharp curve jumps -> AC-4 (pass)
- TC-506 deterministic replay — byte-identical angle sequence -> AC-5 (pass)
- TC-507 reduce-motion HARD ZERO from first frame -> AC-6, NFR-3 (pass)
- TC-508 straight-road settled near-level (re-pinned: |angle| <= 1e-4, exact 0.0 only via hard-zero gates) -> AC-7 (pass)
- TC-509 (seam leg) mode-gating: non-zero only when isCockpitActive -> AC-8 (pass)
- TC-513 cosmetic-only — engine counters byte-for-byte unchanged -> AC-12 (pass)
- TC-515 faulted cockpit asset rotates as placeholder, no crash -> AC-14 (pass)

Golden — `journey_cockpit_lean_golden_test.dart`:
- TC-509 (golden leg) non-cockpit modes (walk/run/bicycle/ship) render byte-for-byte vs no-lean baseline -> AC-8 (pass)
- TC-510 only the cockpit rotates; scene renderer identical to baseline -> AC-9 (pass)
- TC-516 leaning car/motorbike cockpit golden anchor -> AC-1, AC-3, AC-4, AC-9 (pass)
  (structural goldens; repo ships no PNG baselines)

Static — `journey_cockpit_lean_separation_static_test.dart`:
- TC-511 lean signal sourced solely from in-scene curve sample -> AC-10 (pass)
- TC-512 separation invariant — only dart:*, flame/*, TravelMode -> AC-11 (pass)
- TC-517 (static no-alloc / no-loop source leg) -> NFR-1 (pass)

Perf — `journey_cockpit_lean_perf_test.dart`:
- TC-517 (runtime constant-cost / bounded-draw proxy: angle update bounded at tiny & huge scroll
  offsets; draw count stable + pool bounded over long leaning run) -> NFR-1 (pass)

Integration (`-d macos`) — `journey_cockpit_lean_two_surface_test.dart`:
- TC-514 lean on both surfaces; rotated frame covers the cockpit band at PiP (+ guard: the OLD
  flat-6%-overdraw base correctly FAILS the corner-containment check) -> AC-13, NFR-3 (pass)

Integration (`-d macos`) — `journey_cockpit_lean_smoke_test.dart`:
- TC-518 end-to-end smoke: bend -> lean -> reduce-motion hard-zero -> straight settled level ->
  walk no-lean -> car lean restored, both surfaces -> AC-1, AC-6, AC-7, AC-8, AC-13 (pass)

## Manual carries (NOT automated — deferred to the manual checklist, not run here)
Per `tests/cases/journey-cockpit-lean.md` and `journey-cockpit-lean-manual-checklist.md`:
- TC-M-FEEL `[VISUAL]` — feel / motion-comfort / accessibility sign-off (AC-3/AC-4 feel gate, AC-9 perceptual, NFR-3). DEFERRED.
- TC-M-PIP `[REAL-OS]` — real frameless always-on-top PiP visual, band coverage at peak lean (AC-13 real leg). DEFERRED.
- TC-M-NF1 `[DEVICE]` — sustained >=30fps on both surfaces, macOS + Windows, lean active (NFR-1 device leg). DEFERRED.
- TC-M-PRIV `[AUDIT]` — `/privacy-audit` PASS release gate (NFR-2, ship-blocker). Spec records privacy-guardian PASS (2026-06-26); the audit itself is a manual/command gate, not an automated test in this run. DEFERRED.

## AC / NFR automated-coverage roll-up (all green)
AC-1 AC-2 AC-3 AC-4 AC-5 AC-6 AC-7 AC-8 AC-9 AC-10 AC-11 AC-12 AC-13 AC-14 all pass.
NFR-1 pass (deterministic proxies; >=30fps device leg = TC-M-NF1 manual)
NFR-2 = TC-M-PRIV manual audit gate (reinforced by TC-511/TC-512, both green)
NFR-3 pass (TC-507/TC-510/TC-514; feel leg = TC-M-FEEL manual)

## Notes
- No flakes encountered. Both integration files were run in separate invocations per the
  authors' documented macOS chaining-flake guidance; no retries were needed and no scripts were patched.
- No production code or test scripts were modified.
- TC-508's "straight road -> exactly 0.0" was already re-pinned in build/spec (AC-7 resolution) to
  "settles to |angle| <= 1e-4 at the flattest reachable frame" because the shipped dynamic-curve
  geometry has no reachable scroll offset with `lateralSlopeAt == 0.0` exactly; exact 0.0 is reserved
  for the reduce-motion (TC-507) and non-cockpit (TC-509) hard-zero gates. This is the as-shipped
  contract, not a failure.
- Raw runner output saved alongside this summary: `unit.txt`, `integration-two-surface.txt`,
  `integration-smoke.txt`, `regression.txt`.

verdict: green
