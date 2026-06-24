# Activity Detection

**Promoted from backlog:** 2026-06-23
**Target:** Wave 1 (v1 MVP) — first slice
**Spec:** [specs/activity-detection/](../../specs/activity-detection/)

## Goal
Ship a privacy-clean `ActivityPlugin` (Dart interface + macOS/Windows native backends + mock source) that reports aggregate system idle-seconds and screen-lock state — the trustworthy signal the rest of the app is gated on.

## Plan
- [x] Phase 2 — scaffold spec, draft problem framing, confirm scope/open questions
- [x] Phase 2 — acceptance criteria (`product-domain-expert`) + test cases (`test-case-designer`)
- [x] Phase 2 — review & approve spec (`status: approved`)
- [x] Phase 3 — idle **spike** (custom plugin chosen) + `/implement` (auto `/flutter-bootstrap`)
- [ ] Phase 4 — `/review-code` (+ `/privacy-audit`)
- [ ] Phase 5 — `/execute-tests`
- [ ] Phase 6 — `/ship`

## Phase ledger
Update after each phase so a fresh session (`/status`) can resume. "Next" = the command to run next.
- [x] Phase 2 · Spec — spec **approved**; 11 ACs; 20 test cases (TC-001..020); test-plan written
- [x] Phase 3 · Build — `/implement` DONE — bootstrap + ActivityPlugin (interface/native/mock) + 30 unit tests + integration/manual harness; self-review B1 fixed; analyze clean
- [x] Phase 4 · Review — `/review-code` (verdict: **changes requested** — no blockers; privacy **pass**) — fix or document m1 (Windows cold-start lock parity vs AC-5) + m3 (negative idle coercion)
- [x] Phase 5 · Test — `/execute-tests` (verdict: **green** — 36/36 pass, macOS device) — report `tests/_runner/reports/activity-detection/20260623-170514/summary.md`
- [x] Phase 6 · Ship — `/ship` (2026-06-23) — **SHIPPED (macOS-verified)**; Windows runtime verification deferred (L3)

**Current phase:** 6 — **SHIPPED 2026-06-23** (macOS-verified). Green report: `tests/_runner/reports/activity-detection/20260623-170514/summary.md`.   **Next:** Wave-1 sibling `journey-engine` (`/new-feature journey-engine`); **before any Windows release**, clear L3 (build+run on Windows, execute the manual checklist on both OSes, then check AC-2/AC-3/AC-5/AC-9 + parity).

## Status log
| Date | Note |
|------|------|
| 2026-06-23 | `/new-feature activity-detection` — spec folder scaffolded; problem framing drafted & confirmed (raw-signals-only scope; screen-lock on both OSes; no special sleep/wake code). ACs delegated to `product-domain-expert`. |
| 2026-06-23 | `product-domain-expert` drafted 11 ACs (`acceptance-criteria.md`): AC-1..8 P0 (idle/lock both OSes, mock, privacy ×2), AC-9..11 P1 (sleep/wake, graceful failure, impl-independent contract). Awaiting user review before test-case-designer. |
| 2026-06-23 | User approved ACs. Spec → `status: approved`. `test-case-designer` wrote 20 cases (TC-001..020; P0=12/P1=8) + `test-plan.md`. **Phase 2 complete.** Next: idle spike, then `/implement`. |
| 2026-06-23 | `/implement` — repo pinned to **fvm Flutter 3.38.10** (`.fvmrc`); `/flutter-bootstrap` scaffolded `src/focus_journey` (macOS+Windows, flutter_bloc/equatable/shared_preferences/window_manager/tray_manager/flame; dev: bloc_test/mocktail). Spike → **custom platform-channel plugin** (no clean pub.dev pkg gives idle+lock on both OSes without input-capture risk); spec open-questions resolved. `flutter-native-plugin-engineer` built `lib/features/activity/` (domain interface + typed `ActivityPluginException` + macOS Swift + Windows C++/Win32 + deterministic mock + `--dart-define=mock-activity` DI seam). macOS debug build passes; Windows build env-blocked (no MSVC on this Mac). |
| 2026-06-23 | `unit-test-writer` + `test-script-author`: 30 unit tests (`src/test/features/activity/`) for mock/typed-failure/coercion/contract (AC-6, AC-10, AC-11); `integration_test/` flag→DI + real-backend smoke (passed on macOS device); per-OS **manual checklist** `tests/cases/activity-detection-manual-checklist.md` for real-OS TC-001..011 + privacy-audit pointer. |
| 2026-06-23 | `/execute-tests` — `test-executor`, runner `fvm flutter test` (Flutter 3.38.10) on macOS desktop device. **Verdict: GREEN — 36/36 pass, 0 fail, 0 skip** (unit/widget 32 + integration/e2e 4). Real `MethodChannelActivityPlugin` channel confirmed live (harness logged idle 23s→47s, locked=false). Auto-mapped to TC-001/002/004/006/011..017; coverage `lcov.info` saved. Flake note: batched `integration_test/ -d macos` lost the debug-VM connection on 2nd/3rd app launch (runner launch race, **not** a test defect) — both files passed on isolated re-runs; **no .dart edited**. CI: run desktop integration files one-per-invocation. ACs green by automation: AC-6/10/11 (full), AC-1/2/4 macOS-smoke-only; manual-only: AC-1..5+9 per-OS (TC-001..011), AC-5 Windows (no device), AC-7/8 (privacy audit, done). **Review m1 + m3 NOT fixed this run.** Report: `tests/_runner/reports/activity-detection/20260623-170514/summary.md`. Next: resolve m1/m3 then `/ship`. |
| 2026-06-23 | `/review-code` — Reviewer `flutter-code-reviewer` + Review-phase skill `/privacy-audit` (`privacy-guardian`). **Code review verdict: changes requested — 0 Blocking, 1 Major (M1, traceability), 3 Minor (m1/m2/m3), 4 Nit.** analyze clean, 30/30 activity tests pass, format clean. Actionable: **m1** Windows cold-start "launched while locked" returns stale `false` until first transition (vs AC-5/TC-008; macOS reads live) → `flutter-native-plugin-engineer`; **m3** Dart `_coerceIdleSeconds` lets a negative `num` through as a silently-wrong reading (Swift guards `>=0`, Dart doesn't) → `flutter-app-developer` + `unit-test-writer`. M1 = macOS UNAVAILABLE branch unreachable in practice (note only). m2 mock allows negative idle; nits n1–n4 cosmetic (incl. n4 TC numbering drift in `tests/cases/activity-detection.md`). **Privacy audit verdict: PASS** — macOS `CGEventSource.secondsSinceLastEventType`/`CGSessionCopyCurrentDictionary`, Windows `GetLastInputInfo`+WTS lock; no event taps/hooks/screen/clipboard/file/window-title capture; deps clean (`screen_retriever` transitive via `window_manager` reads display geometry only — risk-cleared); Release entitlements minimal; spec/README/onboarding privacy claims substantiated. Next: address m1+m3 (or document as accepted limits), then `/execute-tests`. |
| 2026-06-23 | `/self-review` (adversarial) — 1 Blocking (B1: non-int/bool channel payload threw untyped `_TypeError`, bypassing AC-10) + suggestions. **Fixed:** B1 defensive coercion (num→toInt for idle, bool-only for lock, else `unavailable`; no TypeError escapes) + B2 tests; S1 Windows `std::atomic<bool>` lock state; S3/S4/N2 comments & `--dart-define` doc consistency. `fvm flutter analyze` clean; full suite **31 green** (30 activity + 1 boilerplate counter). **Phase 3 complete.** Next: `/review-code activity-detection`. |
| 2026-06-23 | `/ship` — user decision: **accept m1/m3 + the Windows-runtime gap as documented limitations** (L1/L2/L3 in `acceptance-criteria.md`) and **ship macOS-verified**. Ship-gate check: green report present (`20260623-170514`, verdict `green`, 36/36, not stale); no unimplemented P0/P1 cases. ACs checked = those backed by green automation (AC-6/10/11, NFR Testability/Portability/Performance), the privacy audit (AC-7/8, NFR Privacy), and macOS automated smoke (AC-1/4). **Left unchecked & deferred (L3):** AC-2/AC-5 (Windows — no device, MSVC-blocked), AC-3/AC-9 (manual checklist 0/6 not executed), NFR Cross-platform parity. spec → `status: shipped`; planning moved active→done. **SHIPPED.** |

## Decisions made along the way
- Scope boundary: plugin reports raw signals only; active/idle judgment lives in `journey-engine`.
- `isScreenLocked()` on both macOS + Windows.
- No dedicated sleep/wake signal — large idle on wake is sufficient.
- Stack/standards: ADR-0002 (Flutter+Bloc+Flame); Clean Architecture (interface = domain, native = data).

## What shipped
The privacy-clean `ActivityPlugin` foundation — the trustworthy signal the rest of the app gates on:
- **Domain contract** (`lib/features/activity/domain/`): `ActivityPlugin` interface with `getSystemIdleSeconds()` / `isScreenLocked()` + typed `ActivityPluginException` distinguishing `unavailable`/`denied` from a normal reading.
- **Native backends** (`data/`): macOS Swift (`CGEventSource.secondsSinceLastEventType` + `CGSessionCopyCurrentDictionary`) and Windows C++/Win32 (`GetLastInputInfo` + WTS session-lock notifications, atomic lock cache). Defensive payload coercion so a bad native return surfaces as a typed failure, never a crash or silently-wrong value.
- **Deterministic mock + DI seam**: `MockActivitySource` selectable via `--dart-define=mock-activity`, enabling fully deterministic downstream tests with no real OS/timers.
- **Verification**: 36/36 green automated tests on macOS (unit/widget + integration smoke on a real device); `/privacy-audit` **PASS** (reads only aggregate idle + lock; no event taps/hooks/screen/clipboard/file/window-title capture; deps clean; spec/README/onboarding privacy claims substantiated).
- **Green report:** [`tests/_runner/reports/activity-detection/20260623-170514/summary.md`](../../tests/_runner/reports/activity-detection/20260623-170514/summary.md) (`verdict: green`).
- **Shipped macOS-verified.** Accepted limitations: **L1** (Windows cold-start lock state), **L2** (negative idle coercion), **L3** (Windows runtime + manual checklist deferred) — all recorded in `specs/activity-detection/acceptance-criteria.md`.

## What we'd do differently
- **Secure a Windows dev/CI machine before starting a cross-platform slice.** The whole Windows half (AC-2/AC-5/parity) shipped unverified because the dev Mac had no MSVC toolchain and no Windows device — the single biggest gap in this slice. A Windows runner in CI would have closed it inside the wave.
- **Run the real-OS manual checklist as part of Phase 5, not as an afterthought.** It sat at 0/6; AC-3 (input reset) and AC-9 (sleep/wake) shipped unverified-by-manual-run as a result. Treat the manual checklist as a gating artifact with its own sign-off.
- **Fix the cheap review findings rather than carrying them.** L1 (Windows cold-start lock) and L2 (negative idle coercion) are small, well-scoped fixes; deferring them adds follow-up bookkeeping for the next wave. Borderline-trivial findings are often cheaper to fix in-phase than to document and re-track.
- **Stabilise desktop integration runs early.** The batched `integration_test/ -d macos` debug-VM disconnect on the 2nd/3rd launch needed per-file invocation as a workaround — worth baking into the CI test config from the start.
