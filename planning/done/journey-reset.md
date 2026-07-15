# Journey reset — factory reset + resume-or-start-over on launch

**Promoted from backlog:** 2026-07-15
**Shipped:** 2026-07-15 (dev build, macOS-verified)
**Spec:** [specs/journey-reset/](../../specs/journey-reset/)
**Wave:** refine-app-ui-ux (Wave 1 · opening slice)
**Green report:** [tests/_runner/reports/journey-reset/20260715-152627/](../../tests/_runner/reports/journey-reset/20260715-152627/summary.md) — verdict `green`, 1235/1235

## Goal
A user can wipe all local data (Settings "Factory reset" → first-run), and on every reopen choose Resume or
Start over — Start over re-authors a route while keeping lifetime stats (reusing the ADR-0005 abandoned
lifecycle), Factory reset clears everything.

## Phase ledger
| ✓ | Phase | Command | Date | Verdict / note |
|---|-------|---------|------|----------------|
| [x] | 2 · Spec | `/new-feature` → review & approve `spec.md` | 2026-07-15 | ✅ Spec **approved** by Kevin; 12 ACs + 3 NFRs. |
| [x] | 3 · Build | `/implement` (includes self-review pass) | 2026-07-15 | ✅ Built by `flutter-app-developer` (new `features/reset/`: `LocalDataResetService` fault-isolated wipe seam, pure `decideLaunch` gate, factory-reset dialog + launch prompt, generation-keyed runtime rebuild in `main.dart`). Unit (40) + widget/integration (30) tests. Self-review: 1 Blocking (mid-wipe throw → half-reset/wedged splash) + drift-guard coupling + dialog emphasis — **all fixed**. `analyze` clean. |
| [x] | 4 · Review | `/review-code` | 2026-07-15 | verdict: **approved-with-suggestions** (0 Blocking); self-review fixes verified holding · **`/privacy-audit` PASS** (NFR-2 cleared). |
| [x] | 5 · Test | `/execute-tests` | 2026-07-15 | verdict: **green** — **1235/1235** (full 1221 regression, 0 cross-feature breaks + 14 integration on `-d macos`), 0 flakes. Report `tests/_runner/reports/journey-reset/20260715-152627/summary.md`. |
| [x] | 6 · Ship | `/ship` | 2026-07-15 | ✅ Shipped (dev build, macOS-verified). AC-1..12 + NFR-2 `[x]`; NFR-1/NFR-3 on-device legs + Windows runtime carried. |

## What shipped
- **Settings "Factory reset"** — a destructive, clearly-labelled confirmation (safe Cancel is the prominent
  action) → a fault-isolated `LocalDataResetService` wipes all 7 repos' keys (incl. both `mini_window` keys
  and legacy `route_selection_v1`; aggregates failures so no store is skipped) → generation-keyed runtime
  rebuild returns the app to true first-run onboarding with no stale re-persist.
- **Launch Resume/Start-over prompt** — a pure `decideLaunch` gate shows it only when an `active` route
  exists; suppressed on fresh/completed/abandoned/post-reset. **Resume** restores exact position; **Start
  over** reuses the shipped ADR-0005 `abandoned` lifecycle (new offset over never-reset distance), keeping
  lifetime stats/streaks/badges while replacing only the route.
- **BR-8 carve-out** surfaced in-product (Start over keeps lifetime data; Factory reset wipes it).
- Verified: `/review-code` approved (0 Blocking), `/privacy-audit` PASS, `/execute-tests` green (1235/1235).

## What we'd do differently / follow-ups (carried)
- **Reset-seam ADR not yet written** — the `LocalDataResetService` (aggregating per-repo `clear()`) decision
  should be pinned via `/add-adr`. Start over needed no new ADR (ADR-0005 covers it).
- **Drift-guard blind spot** — TC-705 still compares against a hand-maintained `_canonicalKeys` literal;
  add the grep-over-`lib/`-keys static test (TC-724) so a new persisted key can't silently escape the wipe. → `unit-test-writer`.
- **NFR static-guard tests (TC-723/724)** — no regression guard that the slice adds no read/network/blocking-IO. → `unit-test-writer`.
- **Format nit** — `test/features/reset/presentation/launch_prompt_test.dart:186` exceeds line length. → `unit-test-writer`.
- **Open product-copy questions** — exact factory-reset wording + whether Start over gets its own confirm
  (`reset_copy.dart` `TODO(copy)`). → product/Kevin.
- **launch-at-startup OS state** — factory reset doesn't de-register the OS login item; product/privacy call. → Kevin.
- **Carried before public / Windows release:** NFR-1 on-device instant-feel (TC-M-NF1), NFR-3 real
  screen-reader (TC-M-A11Y), TC-M-BOOT real kill/reopen, runtime-egress monitoring (TC-M-PRIV), Windows runtime.

## Decisions made along the way
- **Locked at capture:** Start over keeps lifetime stats (reuses ADR-0005 `abandoned`); Factory reset is the full wipe.
- **BR-8 carve-out:** user-initiated Factory reset is an explicit exception to BR-8's "cumulative persists" guarantee.
