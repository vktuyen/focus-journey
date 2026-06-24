# Test plan — activity-detection

Scope: verify the **`ActivityPlugin` contract only** (`getSystemIdleSeconds()`, `isScreenLocked()`,
the deterministic mock source, the typed-failure contract, the privacy promise). Active/idle
judgment, the 5-min threshold/grace, pause/resume, distance, and UI are out of scope — they live in
`journey-engine`.

Human-readable scenarios: [tests/cases/activity-detection.md](../../tests/cases/activity-detection.md).

## Layer mapping reality (read before reading the matrix)

Per `docs/architecture/overview.md`, on this project **executable** Flutter tests live INSIDE the
package — unit/widget under `src/test/`, e2e under `src/integration_test/`. The cases below are the
human-readable specs; `test-script-author` writes the executables under `src/` later. The columns
mean:

- **Unit** — deterministic Dart test under `src/test/`, no real timers / no real idle waits / no real
  OS. Only the **mock source** and **contract-shape / typed-failure** behaviours qualify.
- **Integration** — platform-specific test (e.g. `src/integration_test/`) or flag→DI wiring test that
  needs a real desktop platform but can be scripted.
- **E2E** — full on-device run through the real backend (`integration_test`), per-OS.
- **Manual** — requires a human to drive real OS input / lock / sleep that cannot be reliably
  automated, OR is the `privacy-guardian` audit. Run **per-OS** (macOS, then Windows).

Important honesty note: AC-1..AC-5 and AC-9 depend on **real OS input/idle/lock across two
platforms**. They are largely **Manual** (with optional per-OS integration/e2e harnessing); they are
NOT plain unit tests. Privacy (AC-7/AC-8) is an **audit**, not an automated assertion. The matrix
marks the *primary* verification layer; a secondary layer in parentheses is a nice-to-have.

## Coverage matrix (AC × layer)

| AC | Unit | Integration | E2E | Manual | Cases |
|----|:----:|:-----------:|:---:|:------:|-------|
| AC-1  (idle climbs — macOS)        |     | (x) | (x) | **x** | TC-001 |
| AC-2  (idle climbs — Windows)      |     | (x) | (x) | **x** | TC-002 |
| AC-3  (idle resets on input)       |     |     | (x) | **x** | TC-003, TC-004, TC-005 |
| AC-4  (lock state — macOS)         |     |     | (x) | **x** | TC-006, TC-008, TC-009 |
| AC-5  (lock state — Windows)       |     |     | (x) | **x** | TC-007, TC-008, TC-009 |
| AC-6  (mock injectable + deterministic) | **x** | x |  |    | TC-012, TC-013, TC-014, TC-015 |
| AC-7  (privacy — reads only idle+lock)  |   |     |     | **x** (audit) | TC-018, TC-020 |
| AC-8  (privacy — no bad dependency)     |   |     |     | **x** (audit) | TC-019, TC-020 |
| AC-9  (large idle after sleep/wake)|     |     | (x) | **x** | TC-010 |
| AC-10 (typed failure on unavailable/denied) | **x** |  |  |   | TC-016, TC-017 |
| AC-11 (contract is implementation-independent) | (x) |  | (x) | **x** | TC-011, TC-014 |

Every AC (AC-1..AC-11) has at least one case. No gaps.

Non-functional coverage:
- **Privacy (headline)** → TC-018, TC-019, TC-020 (audit).
- **Cross-platform parity** → both `getSystemIdleSeconds` and `isScreenLocked` covered on macOS
  (TC-001, TC-003, TC-006) and Windows (TC-002, TC-004, TC-007); parity re-affirmed by TC-011.
- **Performance (cheap / non-blocking)** → not yet a dedicated case; see Risks.
- **Testability (injectable mock, no real timers)** → TC-012..TC-015.
- **Portability of contract** → TC-011, TC-014.

## Scenario summary

20 cases total.

By priority:
- **P0 (12):** TC-001, TC-002, TC-003, TC-004, TC-006, TC-007, TC-012, TC-013, TC-014, TC-018, TC-019, TC-020.
- **P1 (8):** TC-005, TC-008, TC-009, TC-010, TC-011, TC-015, TC-016, TC-017.
- **P2 (0):** none.

By type:
- **happy-path (10):** TC-001, TC-002, TC-003, TC-004, TC-006, TC-007, TC-012, TC-013, TC-014, TC-015.
- **edge (4):** TC-005, TC-008, TC-009, TC-010.
- **negative (2):** TC-016, TC-017.
- **regression (4):** TC-011, TC-018, TC-019, TC-020.

## Risks

- **Real-OS cases are Manual and per-platform (TC-001..TC-011).** They depend on a human not
  touching input, on lock/unlock re-auth flows, and on real sleep/wake timing. They are slow,
  non-deterministic at the second level (hence the **±2s** tolerance band), and easy to skip under
  time pressure. Mitigation: a small logging dev-harness that records readings on a timer so the
  tester can drive the OS state without occupying the foreground app, plus a per-OS run checklist.
- **macOS has no "denied" path for idle/lock (TC-017).** The permission-denied branch of AC-10 is
  untestable on macOS; only the "unavailable / channel-error" branch is. This is acceptable per the
  resolved decisions but means AC-10's "denied" half is exercised only on Windows (if Windows
  surfaces a denied condition at all). Flag during script authoring.
- **Privacy ACs (AC-7/AC-8) are an audit, not an automated test.** TC-018/TC-019/TC-020 rely on
  `privacy-guardian` judgment. They have no green/red CI signal of their own; the gate is the audit
  verdict. Risk: a dependency bump silently broadens capability between audits — mitigated by TC-020
  wiring the re-audit into `/review-code` on every dependency/native-API change.
- **`isScreenLocked()` semantics ambiguity is resolved but fragile (TC-009).** The "asleep but
  unlocked → false" case requires "require password after sleep" to be OFF to set up; if a tester's
  machine auto-locks on sleep, the precondition silently can't hold and the case may be mis-recorded
  as pass. Note this in the run checklist.
- **Performance non-functional (cheap / non-blocking call) has no dedicated case.** Currently only
  implied by the contract. If polling cadence in `journey-engine` proves sensitive, consider adding a
  micro-benchmark / "does not block UI isolate" case. Surfaced here rather than invented as a sharp
  scenario, since the spec gives no concrete budget — escalate to `product-domain-expert` /
  `system-architect` if a numeric threshold is wanted.
- **Implementation-independence (TC-011) is only meaningful after the spike resolves.** Until the
  spike picks package-vs-custom, TC-011 cannot be exercised; it must be (re-)run whenever the
  underlying implementation changes.
