# Development Workflow

A complete reference for how work moves from idea to shipped feature in this repo.

---

## Pipeline at a glance

```
 Idea
  │ /capture-idea <slug>
  ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 1 · CAPTURE                                              │
│  planning/backlog/<slug>.md                  status: queued     │
│  domain framing · feasibility · success signals                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │ /new-feature <slug>
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 2 · SPEC                                                 │
│  specs/<slug>/spec.md                  status: draft            │
│  specs/<slug>/acceptance-criteria.md                            │
│  specs/<slug>/test-plan.md                                      │
│  tests/cases/<slug>.md                                          │
│  planning/active/<slug>.md                                      │
│                                        status: approved  ◄─ gate│
└──────────────────────────┬──────────────────────────────────────┘
                           │ /implement <slug>
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 3 · BUILD                                                │
│  src/  (production code)                                        │
│  tests/unit/                                                    │
│  tests/integration/ · tests/e2e/                                │
│  planning/active/<slug>.md  ◄─ status log updated each step     │
└──────────────────────────┬──────────────────────────────────────┘
                           │ /review-code <slug>
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 4 · REVIEW                                               │
│  code-reviewer verdict: ready / changes requested / blocked     │
│                                             ready  ◄─ gate      │
└──────────────────────────┬──────────────────────────────────────┘
                           │ /execute-tests <slug>
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 5 · TEST EXECUTION                                       │
│  /execute-tests → test-executor runs the configured runner     │
│  tests/_runner/reports/<slug>/<timestamp>/  (auto report)       │
│  Manual smoke: tick each P0 AC in acceptance-criteria.md        │
│  Verdict: green + all P0 ACs [x]    ◄─ gate                     │
└──────────────────────────┬──────────────────────────────────────┘
                           │ /ship <slug>
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 6 · SHIP                                                 │
│  specs/<slug>/spec.md                  status: shipped          │
│  planning/done/<slug>.md               (archived)               │
└─────────────────────────────────────────────────────────────────┘
```

---

## Phase 1 — Capture

**Command:** `/capture-idea <slug>`

**Goal:** Turn a fuzzy ask into a well-framed backlog item before it gets lost — without committing to a spec or to any canonical docs yet.

The command scaffolds `planning/backlog/<slug>.md` from [planning/backlog/_template.md](../../planning/backlog/_template.md) and coordinates three agents to enrich it. Everything stays *contained in the backlog item* — agents only **flag** candidate domain terms, business rules, and ADRs; they do **not** write to `docs/domain/` or `docs/architecture/`.

1. **`product-domain-expert`** — fills **Why** (problem / who / why now) and a **Domain notes** section (personas, edge cases, conflicts with existing business rules), flagging candidate glossary terms / business rules.
2. **`system-architect`** — adds a **Feasibility (high-level)** section (fit with current architecture, key risks), sets the `Size (rough)` field, and flags candidate ADRs. (Gets the idea framing directly — it deliberately does not read `docs/domain/`.)
3. **`test-case-designer`** — sketches 2–4 **Headline success signals**: observable, testable indicators of success, so the idea carries testable intent early.

| Artifact | Agent | Status field |
|---|---|---|
| `planning/backlog/<slug>.md` (or an epic + child slices) | `/capture-idea` (+ 3 agents) | `queued` (implicit — being in backlog means queued) |

### Large ideas → epic + slices

If the architect sizes the idea **L/XL** or the domain expert finds it spans several coherent features, `/capture-idea` forks: instead of one item it proposes a **breakdown** (slices, suggested wave order, `[blocked by: …]` dependencies) and — once you confirm — scaffolds:

- an **epic** `planning/backlog/<epic>.md` with a **Breakdown** table linking each slice, and
- one **child** `planning/backlog/<slice>.md` per slice (flat sibling slugs, no nesting), each tagged `Part of epic:` + its wave, and independently promotable via `/new-feature <slice>`.

It also offers to seed [planning/roadmap.md](../../planning/roadmap.md) — Wave-1 slices under **Next**, later waves under **Later**. This is how *wave discipline* (deliver value wave-by-wave; don't start Wave N+1 until N ships) becomes executable rather than just a principle. Each slice then flows through Phases 2–6 on its own.

**Gate to Phase 2:** The idea is specific enough to answer "what problem does this solve and for whom?" — then promote it with `/new-feature <slug>` (or, for an epic, promote its Wave-1 slice).

> Phase 0 is intentionally commitment-free. Nothing under `docs/` or `src/` changes here. Candidate domain/architecture updates land as checklists inside the backlog item and are revisited when the idea is promoted.

---

## Phase 2 — Spec

**Command:** `/new-feature <slug>`

This command scaffolds all spec artifacts and runs two agents in sequence:

1. **`product-domain-expert`** — reads [docs/domain/](../domain/) (business rules, glossary, personas) and drafts:
   - `specs/<slug>/spec.md` — problem statement, user & outcome, scope (in/out), constraints, open questions
   - `specs/<slug>/acceptance-criteria.md` — `[ ] AC-N: Given / When / Then` statements, plus non-functional requirements

2. **`test-case-designer`** — reads the spec and ACs, then writes:
   - `tests/cases/<slug>.md` — human-readable test scenarios (P0/P1/P2 × happy-path/edge/negative/regression)
   - `specs/<slug>/test-plan.md` — coverage matrix (AC × Unit/Integration/E2E/Manual) and risk notes

The command also creates `planning/active/<slug>.md` to track initiative progress.

| Artifact | Agent | Status field |
|---|---|---|
| `specs/<slug>/spec.md` | `product-domain-expert` | `draft` → `approved` |
| `specs/<slug>/acceptance-criteria.md` | `product-domain-expert` | checkboxes `[ ]` |
| `specs/<slug>/test-plan.md` | `test-case-designer` | coverage matrix |
| `tests/cases/<slug>.md` | `test-case-designer` | P0/P1/P2 per case |
| `planning/active/<slug>.md` | `/new-feature` | status log |

**Gate to Phase 3:** `spec.md` `status: approved`; every AC is testable and concrete; `tests/cases/<slug>.md` exists.

> Review the spec yourself and change `status: draft` → `status: approved` when you're satisfied. Agents won't proceed without it.

---

## Phase 3 — Build

**Command:** `/implement <slug>`

Preconditions checked automatically: spec is approved, ACs exist, test cases exist.

Three agents run in order:

1. **`code-generator`** — reads the approved spec and ACs, writes production code under `src/`. Follows existing patterns in `docs/architecture/`.
2. **`unit-test-writer`** — writes fast, isolated unit tests under `tests/unit/` mirroring the `src/` layout. One behavior per test. No network or filesystem unless the unit *is* that boundary.
3. **`test-script-author`** — converts every case in `tests/cases/<slug>.md` into an executable script under `tests/integration/` or `tests/e2e/`. One case = one automated test; test names match case titles for full traceability.

After each agent finishes, the command appends a dated entry to `planning/active/<slug>.md`'s status log.

| Artifact | Agent | Notes |
|---|---|---|
| `src/` | `code-generator` | Scope = spec ACs only |
| `tests/unit/` | `unit-test-writer` | Mirrors `src/` layout |
| `tests/integration/` or `tests/e2e/` | `test-script-author` | One test per case |
| `planning/active/<slug>.md` | command | Updated after each step |

**Gate to Phase 4:** All ACs have corresponding code; unit tests pass locally.

---

## Phase 4 — Review

**Command:** `/review-code <slug>`

**`code-reviewer`** performs a read-only audit against the spec, ACs, test cases, and repo patterns. It does not modify files.

It checks:
- Correctness against each AC
- Test coverage (unit + integration + e2e)
- Scope discipline (no speculative abstractions)
- Pattern alignment with `docs/architecture/`
- Security (OWASP top-10 surface)
- Test quality (isolation, naming, traceability to cases)

**Verdict:**
- `ready` — proceed to Phase 5
- `changes requested` — route findings back to the relevant agent
- `blocked` — a fundamental issue must be resolved before continuing

Findings are grouped by severity (P0 blocking / P1 important / P2 nice-to-have). Route each finding to the agent responsible:

| Finding type | Route to |
|---|---|
| Business logic / AC misread | `product-domain-expert` |
| Production code issue | `code-generator` |
| Unit test gap | `unit-test-writer` |
| E2E/integration test gap | `test-script-author` |

**Gate to Phase 5:** Verdict = `ready`; no unresolved P0 or P1 findings.

---

## Phase 5 — Test Execution

**Command:** `/execute-tests <slug>`

**`test-executor`** reads the cases in `tests/cases/<slug>.md`, finds the in-scope scripts under `tests/e2e/` and `tests/integration/`, resolves the runner choice from `docs/architecture/overview.md`, runs them using the configured runner with config under `tests/_runner/`, and writes a full run report to `tests/_runner/reports/<slug>/<timestamp>/`.

The agent surfaces a summary: total / passed / failed / flaky / skipped, with each failing test mapped back to its case ID. Mechanical flakes (selector drift, timing, wait conditions) may be patched in place with a 1-line note in the report; functional failures are not fixed by this agent.

**Verdict:**
- `green` — proceed to manual AC walkthrough
- `failures` — route each failure to the responsible agent (see below)
- `blocked` — preconditions missing (no runner declared in `overview.md`, no runner config, no scripts, no cases)

| Failure type | Route to |
|---|---|
| Functional regression | `code-generator` |
| Wrong / weak assertion | `test-script-author` |
| Missing scenario | `test-case-designer` |

After automation is `green`, perform a manual smoke test: walk through each P0 AC in `specs/<slug>/acceptance-criteria.md` and tick it (`[x]`).

Record a dated entry in `planning/active/<slug>.md`:
```
YYYY-MM-DD  /execute-tests: green (12/12). Report: tests/_runner/reports/<slug>/2026-05-10T1430/. AC-1..AC-5 manually verified. No blockers.
```

If blockers exist, log them explicitly and resolve before shipping.

**Gate to Phase 6:** Verdict = `green`; all P0 ACs checked `[x]`; no open blockers in status log.

---

## Phase 6 — Ship

**Command:** `/ship <slug>`

The command:
1. Confirms all ACs are checked and no P0/P1 test cases are unimplemented.
2. **Verifies a green test execution report.** Reads the most recent `tests/_runner/reports/<slug>/<timestamp>/summary.md` and requires `verdict: green`. If the report is missing, stale, or shows `failures`/`blocked`, the command stops and reports — shipping is blocked until `/execute-tests <slug>` produces a fresh green run.
3. Updates `specs/<slug>/spec.md` → `status: shipped` with today's date.
4. Moves `planning/active/<slug>.md` → `planning/done/<slug>.md`, linking the report folder used as the green gate.
5. Outputs a 3-bullet release summary (including report timestamp + pass count) for changelog / release notes.

The initiative is now archived. The spec remains as a permanent record of what was built and why.

> **Why the gate is machine-checked.** Earlier the green verdict lived only in `/execute-tests` console output and a free-text status log line. That made it easy to ship after a stale or red run. The `test-executor` agent now writes a structured `summary.md` (with a YAML `verdict:` field) to each run folder, and `/ship` refuses to proceed unless the latest one is `green`.

---

## Artifact chain

| Artifact | Created by | Status values | Feeds into |
|---|---|---|---|
| `planning/backlog/<slug>.md` | `/capture-idea` (+ domain/architecture/test-design agents) | (queued) | Phase 2 |
| `planning/backlog/<epic>.md` + child slices | `/capture-idea` (epic fork) | (queued) | Phase 2 (per slice, in wave order) |
| `planning/active/<slug>.md` | `/new-feature` | status log entries | `/ship` |
| `specs/<slug>/spec.md` | `product-domain-expert` | `draft` → `approved` → `shipped` | `code-generator` |
| `specs/<slug>/acceptance-criteria.md` | `product-domain-expert` | `[ ]` / `[x]` checkboxes | `test-case-designer`, `code-reviewer` |
| `specs/<slug>/test-plan.md` | `test-case-designer` | coverage matrix | `test-script-author` |
| `tests/cases/<slug>.md` | `test-case-designer` | P0/P1/P2 + type per case | `test-script-author`, `code-reviewer` |
| `src/` | `code-generator` | — | `unit-test-writer`, `code-reviewer` |
| `tests/unit/` | `unit-test-writer` | pass / fail | `code-reviewer` |
| `tests/e2e/` & `tests/integration/` | `test-script-author` | pass / fail | `code-reviewer`, `test-executor` |
| `tests/_runner/reports/<slug>/<timestamp>/` | `test-executor` | green / failures / blocked | release notes / regression triage |
| `tests/_runner/reports/<slug>/<timestamp>/summary.md` | `test-executor` | `verdict: green` ⇒ `/ship` gate passes | `/ship` (hard gate) |
| `planning/done/<slug>.md` | `/ship` | shipped (archived) | roadmap / release notes |

---

## Status tracking cheat-sheet

| What to check | Where to look | What to look for |
|---|---|---|
| Is this initiative in progress? | `planning/active/` | File exists |
| What's the current blocker? | `planning/active/<slug>.md` | Latest status log entry |
| Is the spec approved? | `specs/<slug>/spec.md` line 1 | `status: approved` |
| Which ACs are done? | `specs/<slug>/acceptance-criteria.md` | `[x]` vs `[ ]` |
| What test cases exist? | `tests/cases/<slug>.md` | P0/P1/P2 list |
| Which tests are automated? | `tests/unit/`, `tests/e2e/`, `tests/integration/` | File names match case titles |
| What's the test coverage plan? | `specs/<slug>/test-plan.md` | AC × layer matrix |
| What did the review find? | Last `/review-code` output | Verdict + severity list |
| What did the last test run say? | `tests/_runner/reports/<slug>/` (latest timestamp) | Verdict + per-test → case-ID mapping |
| Is this shipped? | `planning/done/` | File exists AND `spec.md` status = `shipped` |

---

## Quick-reference commands

| Command | When to run | What it does |
|---|---|---|
| `/capture-idea <slug>` | New idea, not yet scoped | Frames a backlog item (domain + feasibility + success signals) via 3 agents |
| `/new-feature <slug>` | Idea is scoped | Scaffolds spec + ACs + test-plan + cases + active initiative |
| `/implement <slug>` | Spec is `approved` | Code + unit tests + e2e/integration automation |
| `/review-code <slug>` | Implementation complete | Read-only critique; surfaces findings by severity |
| `/execute-tests <slug>` | Code review is `ready` | Runs the configured runner via `test-executor`; writes report under `tests/_runner/reports/` |
| `/ship <slug>` | All P0 ACs green, no blockers | Marks shipped, archives initiative, outputs release summary |

---

## Domain knowledge

[docs/domain/](../domain/) is the shared source of truth that feeds every spec:

| File | Contains |
|---|---|
| `business-rules.md` | Numbered rules (BR-N) the product must enforce |
| `glossary.md` | Canonical definitions for all domain terms |
| `personas.md` | Who uses the product and what they need |

`product-domain-expert` reads these files before drafting any spec. When business rules change — even mid-initiative — update `docs/domain/` first, then re-run the affected spec sections. Do not encode business rules only inside specs; they rot there.

---

## Guardrails (summary)

- No code in `src/` before a spec is `approved`.
- No automated tests without a corresponding case in `tests/cases/`.
- No speculative abstractions — scope = spec ACs only.
- `code-reviewer` is read-only — it surfaces findings, it does not fix them.
- Shipping requires manual AC verification AND a machine-verified green `summary.md` from the latest `/execute-tests` run. `/ship` enforces both.
