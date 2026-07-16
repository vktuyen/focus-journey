# Province chain 2026 — journey data model on all 34 current units

**Promoted from backlog:** 2026-07-15
**Target:** —
**Spec:** [specs/province-chain-2026/](../../specs/province-chain-2026/)
**Wave:** refine-app-ui-ux (slice 2 of the Vietnam-2026 pair; sibling `vietnam-map-fidelity` ✅ shipped)

## Goal
The journey traverses all 34 current provinces in one coast-hugging south→north spine (great-circle
distances), on real 2026 geography — no route segment crosses the sea — with in-progress journeys migrated,
not lost, and the engine accrual mechanism unchanged.

## Phase ledger
| ✓ | Phase | Command | Date | Verdict / note |
|---|-------|---------|------|----------------|
| [x] | 2 · Spec | `/new-feature` → review & approve `spec.md` | 2026-07-15 | **Approved by Kevin.** 11 ACs + 3 NFRs (`product-domain-expert`); architecture framed (`system-architect`); test cases designed (`test-case-designer` → `tests/cases/province-chain-2026.md`, PC-901..930). |
| [x] | 3 · Build | `/implement` (includes self-review pass) | 2026-07-15 | **Done, 1414 tests green, analyze clean, macOS build ✓.** 34-unit great-circle spine (`totalChainKm ≈ 3201.9 km`, `kmPerActiveHour ≈ 400.2`); new `haversine.dart` + `vietnam_units_2026.dart`; migration-by-reset (AC-9) reads real cumulative; ADR-0009 written. Self-review B1 (unratified ~25 km coord nudges) → Kevin ruled **minimize+ratify+golden test**: offsets capped ≤0.1° + golden coord table test; one residual (`quảng_trị→hà_tĩnh`, ~0.114°) **waived** (Hà Tĩnh exact, ≤3-sample bound). |
| [x] | 4 · Review | `/review-code` | 2026-07-16 | verdict: **approved** (`flutter-code-reviewer`) — no Blocking; every AC-1..11/NFR-1..3 has real non-vacuous coverage; 1 Suggestion (doc-note that migrate-by-reset keys off retired-id detection), 1 Nit (PC-908 substring guard → word-boundary regex). **`/privacy-audit`: PASS** (`privacy-guardian`) — no new location/egress/file read; engine firewall + zero-egress baseline intact; onboarding claims still truthful. |
| [x] | 5 · Test | `/execute-tests` | 2026-07-16 | verdict: **green** — 285/285 pass, **0 skipped** (`test-executor`). Flagship: the carried no-sea-crossing guard is **re-armed and green** on the 34-unit spine. Every AC-1..11 + NFR-1..3 has ≥1 green automated leg. Report: `tests/_runner/reports/province-chain-2026/20260716-092850/`. |
| [x] | 6 · Ship | `/ship` | 2026-07-16 | **Shipped.** All AC-1..11 + NFR-1..3 ✓; green report 285/285 (`20260716-092850`); also covered by route-real-road's later full-suite run (1481 green). Status→shipped; moved active→done. |

**Current phase:** SHIPPED (2026-07-16)   **Next command:** — (slice complete)

## What shipped
The journey province/route data model was rebuilt onto Vietnam's **current 34 administrative units (2026 reform)** from a single ordered source-of-record (`kVietnamUnits2026`), with **great-circle (haversine) distances**, a hand-curated **coast-hugging on-land S→N spine** (Cà Mau → Cao Bằng, ~3202 km), 7 relocated admin centres exact, and **migration-by-reset** for retired pre-2025 ids (re-bases lifetime distance, never an id-remap). Ratified the bounded ≤0.1° coast-alignment offset (ADR-0009) with a golden coordinate table + re-armed no-sea-crossing guard. 285/285 green.

## What we'd do differently
- One over-cap residual (`quảng_trị→hà_tĩnh`, ~0.114°) is documented/waived as a coastline-decimation artifact (Kevin: keep Hà Tĩnh exact) — a denser coastline sample could remove it.
- The spine's "traverse all 34" route was superseded almost immediately by **route-real-road** (real bundled highway). The DATA (units/coords/map/migration) is the lasting deliverable; the derived all-34 tour route was short-lived — worth having anticipated the real-road direction before building the spine-as-route.
- Report link: [tests/_runner/reports/province-chain-2026/20260716-092850/summary.md](../../tests/_runner/reports/province-chain-2026/20260716-092850/summary.md)
**Green report:** [tests/_runner/reports/province-chain-2026/20260716-092850/summary.md](../../tests/_runner/reports/province-chain-2026/20260716-092850/summary.md) (`verdict: green`, 285 pass)
**Manual legs:** TC-M-PRIV (privacy) already **PASS** at `/review-code`. TC-M-GEO (visual coast-hugging) / TC-M-NF1 / TC-M-A11Y = macOS confidence legs pending, Windows DEFERRED (precedent: `vietnam-map-fidelity`) — automated companions (PC-909/910/914/928/930) all green.

## Non-blocking review follow-ups (carry into a later polish pass — not ship gates)
- **Suggestion:** doc-note on `loadPlan` that migrate-by-reset triggers on retired-id *detection*, not a schema-version field (a legacy blob whose ids all coincidentally survive is reinterpreted, not reset — inherent, always valid/non-crashing). → `flutter-app-developer`.
- **Nit:** PC-908's retired-literal guard uses substring `contains('250')`/`'2000'`; a word-boundary regex is more future-proof. → `unit-test-writer`.

## Two flags from test-case design to carry into build
1. **AC-2 wording tension** — "strictly ordered south→north" conflicts with the resolved *coast-hugging* order
   (which threads inland units, so latitude is not strictly monotonic). Tests assert only endpoints + overall
   direction and defer ordering-correctness to the no-sea-crossing test (AC-5). Treat AC-2 as endpoint/direction
   + count/segment invariants, **not** per-index latitude monotonicity.
2. **AC-9 needs new code** — the shipped decoder silently returns `null` on a retired-id `ArgumentError` (drops
   the plan). AC-9 requires migrate-**by-reset** (fresh full-spine plan at current cumulative, lifetime
   preserved) — the implementer must add this path, not rely on the existing catch.

## Decisions settled at framing (→ ADR-0009 to write at build time)
- **One spine through all 34 units**, hand-curated south→north order, verified no-sea-crossing via
  `BaseMapGeometry.containsLandmass` sampling (ADR-0008). No synthetic waypoints.
- **Great-circle distances** (new `Haversine` pure helper); `totalChainKm` derived; `kmPerActiveHour = total/8`
  (already injected at `main.dart:597`); **engine accrual untouched** (BR-6).
- **Migration by reset** (fresh full-spine plan at current cumulative), never id-remap; lifetime distance in a
  separate store (untouched). Existing decoders already degrade retired ids safely.
- **Enum stability:** keep `JourneyDirection.towardHaGiang/towardMuiCaMau` + tip getters (persisted-by-name);
  doc/label updates only.
- **ADR-0009** (write via `/add-adr` at build): great-circle distances (amends ADR-0004(b)) · curated
  ordering + no-sea-crossing test · migration-by-reset (amends ADR-0005) · enum-name stability.

## Watch (top risk)
Shipped-test regression: several tests hardcode the old model (`totalChainKm == 2000`, 13 nodes,
`kmPerActiveHour: 250`, old ids). Budget for updating production-chain fixtures/tests.
