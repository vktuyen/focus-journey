# Route Planner v2 (flexible route selection + planning)

**Promoted from backlog:** 2026-06-25
**Target:** Wave 2 (v2) — **closed the wave**
**Shipped:** 2026-06-25 (dev build, macOS-verified)
**Spec:** [specs/route-planner-v2/](../../specs/route-planner-v2/)
**Green report:** [tests/_runner/reports/route-planner-v2/20260625-110204/](../../tests/_runner/reports/route-planner-v2/20260625-110204/) (verdict green, 877/877)

## Goal
The user can pick any start + any end province (+ optional stops with auto-inserted intermediates,
reviewed/edited before start) and can abandon a route mid-journey to start a new one — without ever
resetting the lifetime distance or firing a false arrival celebration.

## Phase ledger
| ✓ | Phase | Command | Date | Verdict / note |
|---|-------|---------|------|----------------|
| [x] | 2 · Spec | `/new-feature` → review & approve `spec.md` | 2026-06-25 | **APPROVED by Kevin.** 12 ACs + 3 NFRs; #8/#9/#10 forks resolved (sub-path model · editable review · confirm-before-abandon); by-proposal AC-2/4/8 confirmed. Test cases authored by test-case-designer. |
| [x] | 3 · Build | `/implement` (includes self-review pass) | 2026-06-25 | **Built against ADR-0005** (sub-chain model). New: `RoutePlan` + `RoutePlanner` (auto-insert) + picker/review/abandon flow; cubit owns country %; AC-7 cores (resolver/projector/mapper) unchanged. Unit+widget **870 pass** · integration flow 7/7 · analyze+format clean. Self-review: 1 Blocking (B1 in-span marked-stop protection) **fixed + regression test**; S1 (prune-on-abandon) reconciled in ADR-0005 decision 6; S3 dead abandoned-plan path removed. |
| [x] | 4 · Review | `/review-code` | 2026-06-25 | verdict: **ready** (no Blocking; no correctness/privacy blocker). **`/privacy-audit` PASS.** H1 + M1 closed: ADR-0005 dec.5/6 amended (abandoned `RoutePlan` intentionally discarded — single active slot, no abandoned-history; `RouteLifecycle.abandoned` reserved/latent; engine-segments vs RoutePlan disambiguated) + stale "pruned" comments fixed (no-bleed by construction) + L3 branch collapsed. Re-verified analyze clean · 371 route tests pass. Non-gating carries: **M2** (AC-6 integration snapshot could also assert the segment record) · **L1** (`percentOfCountry` route%-vs-country% rename — deferred till AC-7 freeze lifts) · L2/L4. |
| [x] | 5 · Test | `/execute-tests` | 2026-06-25 | verdict: **green** — 877/877 (870 unit/widget + 7 E2E flow on -d macos); no flakes. Report `tests/_runner/reports/route-planner-v2/20260625-110204/`. AC-1..12 + NFR-2 ticked `[x]`; NFR-1/NFR-3 on-device legs carried (TC-M-NF1/TC-M-A11Y) + TC-M-PRIV runtime egress. |
| [x] | 6 · Ship | `/ship` | 2026-06-25 | **SHIPPED (dev build, macOS-verified).** Kevin confirmed dev-build ship carrying the two on-device NFR legs. Green report machine-checked (verdict green, 877/877; run_at 2026-06-25T11:02:04Z). AC-1..12 + NFR-2 ticked; NFR-1/NFR-3 carried. **Closes Wave 2.** |

**Current phase:** 6 · Ship — **DONE.**

## What shipped
- **Flexible endpoints (#8)** — pick any one start + any one end checkpoint on the curated Mũi Cà Mau ⇄ Hà
  Giang spine; the route is the **contiguous sub-path** between them (direction implied). Replaced the
  shipped fixed-start + binary-N/S-direction picker.
- **Optional stops + auto-insert + editable review (#9)** — mark provinces you care about; the app
  auto-inserts the intermediate spine checkpoints (e.g. Huế → Đà Lạt adds Đà Nẵng, Nha Trang…) and shows a
  **review-before-start** screen with the ordered route + total distance that you can edit (remove/skip
  intermediates; marked stops stay protected). **Zero side effect until you confirm "start."**
- **Stop & start a new journey (#10)** — abandon the current route mid-journey (confirm guard when there's
  progress to lose) and start a fresh one. Lifetime distance is **never reset**; an abandoned route is
  distinct from a completed one (**no false arrival celebration**); the new route's red idle trace shows
  only its own segments (no bleed).
- **Architecture (ADR-0005):** a custom route is a **derived sub-chain** of the spine, so the shipped
  `RouteProgressResolver` / `RoutePolylineProjector` / `IdleTraceMapper` run **unchanged** (AC-7) — position
  stays a pure function of `routeDistanceKm` on the single canonical-km axis. New pure domain pieces
  (`RoutePlanner` auto-insert, `RoutePlan` descriptor with legacy→RoutePlan migration); country % owned by
  the cubit. **No new dependency, no native code, no device location/GPS, no new network** — `/privacy-audit`
  PASS by construction.
- **Tests:** 877/877 green (115+ new across domain/data unit, widget/cubit, and a macOS E2E flow). Every
  AC-1..12 + NFR-2 verified by automation.

## What we'd do differently / carry forward
- **⚠️ Carried before any public / Windows release** (on-device legs — NOT blocking the dev build; tracked
  in the manual checklist `tests/cases/route-planner-v2-manual-checklist.md`):
  - **NFR-1** no-jank ≥30fps on macOS + Windows for the picker/review/auto-insert (TC-M-NF1).
  - **NFR-3** real screen-reader pass + keyboard-only operation of picker / review (incl. remove controls) /
    abandon dialog (TC-M-A11Y) — deterministic semantics + activation were automation-verified.
  - **NFR-2** runtime-egress packet capture confirming zero new outbound traffic (TC-M-PRIV) — the static +
    `/privacy-audit` portions PASS; this is the runtime confirmation leg only.
  - **Windows runtime** never exercised (no device); the flow is pure-Dart + Bloc with no native code, so
    risk is low, but the Windows leg is unverified.
- **Unbounded segment growth (non-gating, ADR-0005 decision 6):** abandoning routes never prunes the
  engine's idle/active segment record (the engine must never be reset; AC-11 no-bleed holds by construction
  via the mapper's re-base+clip). Across many start/abandon cycles the persisted segment blob grows
  unbounded. Tracked as a future **`journey-engine`-enhancement** slug (bounded/prune-able segment store) —
  needs an additive engine API that AC-7's "unchanged cores" put out of scope here.
- **`RoutePosition.percentOfCountry` is now dual-meaning** (route % when resolved over a sub-chain, vs the
  cubit-computed full-chain country %). Reviewer flag **L1**: rename to a clearer field when the AC-7 freeze
  on the shipped cores lifts. Load-bearing only via comments today.
- **Review-screen marked-stop bug (B1) was caught only in self-review, not design** — the picker's marked
  stops were dropped before the review screen, so an in-span marked stop was wrongly removable. Fixed + a
  regression test added. Lesson: thread user-intent state end-to-end through multi-screen flows and test the
  *in-span* case, not just the boundary case (the original TC-309 only exercised an out-of-span stop).

## Decisions made along the way
- **#8 route model:** contiguous sub-path of the curated spine; rejected parallel/branching chains.
- **#9 review screen:** editable intermediates; zero side effect until "start."
- **#10 abandon:** confirm guard when there's progress; lifetime distance never reset; abandoned ≠ completed.
- **ADR-0005** ([decisions/0005-custom-routes-via-derived-subchains.md](../../docs/architecture/decisions/0005-custom-routes-via-derived-subchains.md)):
  sub-chain model; `RoutePlan` + legacy migration; country % in cubit; lifecycle active/completed/abandoned
  (abandoned reserved/latent — discarded at runtime, dec.5/6 reconciled 2026-06-25).
- See [backlog framing](../backlog/route-planner-v2.md) for the original candidate-ADR list.
