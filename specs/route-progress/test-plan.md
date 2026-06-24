# Test plan

## Coverage strategy
Most of route-progress is **pure-Dart position math** (a deterministic function of `routeDistanceKm`,
start, direction, and chain data), so the bulk of coverage is fast **unit** tests with a scriptable
fake distance source. The custom-painted map + completion surfaces add **widget/golden** coverage; a
thin slice of **integration/e2e** + **manual** covers persistence-across-restart, offline behaviour,
on-device paint smoothness, and the privacy promise. Executable tests live under
`src/focus_journey/test/` (unit/widget) and `src/focus_journey/integration_test/` (e2e), per the
architecture test-layout decision — not the top-level `tests/` tree.

| AC | Unit | Integration | E2E | Manual | Cases |
|----|------|-------------|-----|--------|-------|
| AC-1 position happy path | x | | | | TC-001 |
| AC-2 distance = 0 at start | x | | (golden) | | TC-002 |
| AC-3 exactly on checkpoint | x | | | | TC-003 |
| AC-4/5 just before/after (169/170/171) | x | | | | TC-004, TC-005 |
| AC-6 monotonic advance | x | | | | TC-006 |
| AC-7 south mirrors north | x | | | | TC-007 |
| AC-8 destination tip + full-chain % | x | | | | TC-008 |
| AC-9 start+direction persist | | x | | | TC-009 |
| AC-10 completed-state persists | | x | | | TC-010 |
| AC-11 reach end / %cap / celebration | x | | (golden) | | TC-011 |
| AC-12 retain / clamp / no-rollback | x | | | | TC-012 |
| AC-13 no auto-advance | x | | | | TC-013 |
| AC-14 per-route offset / engine never reset | x | | | | TC-014, TC-014b |
| AC-15 chain-tip off-direction blocked | x (model) | x (picker) | | | TC-015 |
| AC-16 reads only distanceKm | x | | | (grep) | TC-016 |
| AC-17 write-free (no engine-state writes) | x | | | | TC-017 |
| AC-18 no new privacy/network surface | | | | x (`/privacy-audit`) | TC-018 |
| NFR determinism | x | | | | TC-NF1 |
| NFR smooth custom-paint | | | x | x (device) | TC-NF2 |
| NFR offline / no-network | | x | | x | TC-NF3 |
| NFR chain-data integrity | x | | | | TC-NF4 |

## Scenarios
Full list of cases lives in [tests/cases/route-progress.md](../../tests/cases/route-progress.md) —
**24 cases (TC-001..TC-018 + TC-014b + TC-NF1..TC-NF4)**. Summary:

- Happy path: 1 (TC-001)
- Edge / boundary: 5 (TC-002, TC-003, TC-004, TC-005, TC-006)
- Direction: 2 (TC-007, TC-008)
- Per-route offset: 2 (TC-014, TC-014b)
- Persistence: 2 (TC-009, TC-010)
- Completion: 3 (TC-011, TC-012, TC-013)
- Chain-tip / negative: 1 (TC-015, incl. an invalid-selection negative leg)
- Purity / privacy: 3 (TC-016, TC-017, TC-018)
- Non-functional: 4 (TC-NF1..TC-NF4)

## Risks
- **Central test double — scriptable distance source.** Most cases need a settable-`distanceKm` stub
  for the engine/journey Bloc that **also records write attempts**, since TC-012/TC-014/TC-017 assert
  the shipped engine is never reset and route-progress never writes engine state. Build this first.
- **Golden images** (TC-002 marker-on-start-pin, TC-011 celebration/summary, TC-NF2 painted-map frame)
  need determinism discipline (fixed chain + fixed marker phase) and per-OS tolerance, like journey-view.
- **On-device paint smoothness (TC-NF2)** and **network-disabled behaviour (TC-NF3)** are
  integration/device runs, not deterministic units — expect macOS+Windows manual spot-checks where
  automated frame-timing is impractical (mirrors journey-view's deferred fps NFR).
- **TC-018 is a manual `/privacy-audit`** (ship-blocker, not automatable); TC-016/TC-017 lean partly on
  grep/static inspection rather than runtime assertions.
- **TC-015 negative leg** assumes the model exposes a reject/guard path for an invalid (tip,
  off-direction) pair even though the picker blocks it. If the implementation guards only at the picker,
  relax that sub-assertion to "picker-only" — confirm with the implementer at `/implement`.
- **TC-NF4 ordering convention** assumes the chain constant is stored Mũi Cà Mau → Hà Giang; if the
  production data stores the reverse, invert the integrity check's direction (structure still holds).
- **Fixture vs production data:** cases key off the fixture chain's *structure* (ordered nodes + segment
  distances + total), not literals, so they survive re-tuning the illustrative 1440 km to the production
  ~2000 km curated chain.
