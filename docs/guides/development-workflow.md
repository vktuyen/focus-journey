# Development Workflow

A complete reference for how work moves from idea to shipped feature in this repo.

> **Optimized in 2026-06.** The pipeline was trimmed to ship faster: acceptance criteria now live
> **inline in `spec.md`** (no separate `acceptance-criteria.md` / `test-plan.md`); self-review is a
> **pass built into `/implement`** (no separate command); status lives in **one place** (the Phase
> ledger in `planning/active/<slug>.md`); there is **one roadmap** (`planning/roadmap.md`); and a
> **small-change lane** (`/quick-change`) skips the ceremony for bug fixes and tiny tweaks.

---

## Two lanes

| Lane | When | Commands |
|------|------|----------|
| **Full feature loop** | A genuine feature; needs a spec, test design, maybe an ADR | `/capture-idea` → `/new-feature` → `/implement` → `/review-code` → `/execute-tests` → `/ship` |
| **Small-change lane** | Bug fix / tiny tweak; statable in a few sentences + 1–4 ACs; no new ADR or dependency | `/quick-change <slug>` (does it all in one lean pass) |

Pick the small-change lane unless the work genuinely needs the full treatment. `/quick-change` still
enforces the two gates that matter — a review and a machine-verified green test run.

---

## Full-loop pipeline at a glance

```
 Idea
  │ /capture-idea <slug>   (optional — skip if already well-scoped)
  ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 1 · CAPTURE        planning/backlog/<slug>.md             │
│  domain framing · feasibility · success signals                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │ /new-feature <slug>
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 2 · SPEC                                                 │
│  specs/<slug>/spec.md   (problem + scope + ACs inline)          │
│  tests/cases/<slug>.md  (scenarios tagged to AC-IDs)            │
│  planning/active/<slug>.md  (Phase ledger)                      │
│                                        status: approved  ◄─ gate│
└──────────────────────────┬──────────────────────────────────────┘
                           │ /implement <slug>   (incl. self-review pass)
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 3 · BUILD                                                │
│  src/ (code) · src/test/ · src/integration_test/               │
│  self-review pass (built in) → fix Blocking before handoff      │
│  planning/active/<slug>.md  ◄─ Build row of the ledger ticked   │
└──────────────────────────┬──────────────────────────────────────┘
                           │ /review-code <slug>   (+ /privacy-audit)
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 4 · REVIEW    flutter-code-reviewer verdict              │
│                      ready / changes requested / blocked        │
│                                             ready  ◄─ gate      │
└──────────────────────────┬──────────────────────────────────────┘
                           │ /execute-tests <slug>
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 5 · TEST EXECUTION                                       │
│  test-executor runs the configured runner                      │
│  tests/_runner/reports/<slug>/<timestamp>/summary.md (verdict)  │
│  tick each P0 AC in spec.md                                     │
│  Verdict: green + P0 ACs [x]    ◄─ gate                         │
└──────────────────────────┬──────────────────────────────────────┘
                           │ /ship <slug>
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 6 · SHIP    spec.md status: shipped                      │
│  planning/done/<slug>.md (archived) · roadmap updated           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Phase 1 — Capture

**Command:** `/capture-idea <slug>`

**Goal:** Turn a fuzzy ask into a well-framed backlog item before committing to a spec or any canonical docs.

Scaffolds `planning/backlog/<slug>.md` and coordinates three agents to enrich it — `product-domain-expert`
(Why + Domain notes, flags candidate glossary/business-rule updates), `system-architect` (Feasibility,
`Size (rough)`, flags candidate ADRs), `test-case-designer` (2–4 Headline success signals). Everything stays
*contained in the backlog item*; agents only **flag** candidates — they do not write to `docs/`.

Large ideas fork into an **epic + child slices** (a Breakdown table + one light child item per slice, each
promotable via `/new-feature`). This is how *wave discipline* becomes executable.

**Skip Phase 1** when the ask is already well-scoped (jump to `/new-feature`), or use `/quick-change` for a small fix.

**Gate to Phase 2:** the idea answers "what problem, for whom?" → `/new-feature <slug>`.

> Phase 1 is commitment-free. Nothing under `docs/` or `src/` changes.

---

## Phase 2 — Spec

**Command:** `/new-feature <slug>`

Copies `specs/_template/` → `specs/<slug>/` (just `spec.md` + `summary.html`) and runs two agents:

1. **`product-domain-expert`** — reads [docs/domain/](../domain/) and drafts `spec.md`: problem, user &
   outcome, scope (in/out), constraints, and the **`## Acceptance criteria`** section inline
   (`[ ] AC-N: Given/When/Then` + Non-functional). **ACs live in the spec — there is no separate
   `acceptance-criteria.md`.**
2. **`test-case-designer`** — writes `tests/cases/<slug>.md`: human-readable scenarios, each **tagged with
   the AC-ID(s) it covers**, with a short **Coverage note** at the top (which layers cover which ACs; risks).
   This replaces the old `test-plan.md`. It does not restate AC text.

Also creates `planning/active/<slug>.md` with its **Phase ledger** (the single status tracker), and
**consumes** the backlog item — `planning/backlog/<slug>.md` is `git rm`'d, since the initiative has moved
from CAPTURE into SPEC. An initiative lives in exactly one stage (backlog → active → done); no duplicates.

| Artifact | Agent | Status field |
|---|---|---|
| `specs/<slug>/spec.md` (incl. inline ACs) | `product-domain-expert` | `draft` → `approved` → `shipped`; AC checkboxes |
| `tests/cases/<slug>.md` | `test-case-designer` | Coverage note + P0/P1/P2 per case |
| `planning/active/<slug>.md` | `/new-feature` | Phase ledger |

**Gate to Phase 3:** `spec.md` `status: approved`; every AC is testable; `tests/cases/<slug>.md` exists.

> Review the spec yourself and set `status: draft` → `approved`. Agents won't proceed without it.

---

## Phase 3 — Build

**Command:** `/implement <slug>`

Preconditions checked automatically: spec approved (with inline ACs), test cases exist, project scaffolded.

Agents are **named directly** (this is a Flutter project — no role-indirection):

1. **`flutter-app-developer`** (UI/Bloc) writes production code under `src/`, pulling in
   **`flutter-native-plugin-engineer`** (native idle/tray/window) or **`flame-game-developer`** (Flame scenes)
   for those slices. Pure domain logic stays framework-free.
2. **`unit-test-writer`** writes fast, isolated tests (mirroring `src/`, under `src/test/`).
3. **`/source-assets`** (uses `ui-asset-curator`) gathers license-clean art if needed.
4. **`test-script-author`** turns each case in `tests/cases/<slug>.md` into executable tests
   (`src/test/` / `src/integration_test/`), one case = one test, names matching for traceability.
5. **Self-review pass (built in).** `flutter-code-reviewer` reviews the diff adversarially and returns
   **Blocking / Suggestion / Nit** findings; obvious Blocking fixes are applied before handoff. This is a fast
   internal loop — it does not replace the Phase-4 `/review-code` gate. (There is no separate `/self-review` command.)

After the work, the command ticks the **Build** row of the Phase ledger (date + note).

**Gate to Phase 4:** all ACs have code; unit tests pass; self-review Blocking cleared.

---

## Phase 4 — Review

**Command:** `/review-code <slug>`

**`flutter-code-reviewer`** performs a read-only audit against the spec's ACs, the cases, and repo patterns,
checking correctness per AC, test coverage, scope discipline, pattern/Clean-Arch/Bloc alignment, security,
and test quality. **`/privacy-audit`** (`privacy-guardian`) runs alongside — the trust-promise gate.

**Verdict:** `ready` (→ Phase 5) · `changes requested` (route findings back) · `blocked`. Route each finding:

| Finding type | Route to |
|---|---|
| Business logic / AC misread | `product-domain-expert` |
| Production code issue | `flutter-app-developer` (or the relevant specialist) |
| Unit test gap | `unit-test-writer` |
| E2E/integration test gap | `test-script-author` |

The command ticks the **Review** row of the Phase ledger (date + verdict + note).

**Gate to Phase 5:** verdict = `ready`; no unresolved P0/P1 findings.

---

## Phase 5 — Test Execution

**Command:** `/execute-tests <slug>`

**`test-executor`** reads `tests/cases/<slug>.md`, finds the in-scope scripts (`src/test/`,
`src/integration_test/`), resolves the runner from `docs/architecture/overview.md`, runs them, and writes a
report to `tests/_runner/reports/<slug>/<timestamp>/` — including a machine-checkable `summary.md` with a
`verdict:` field. Mechanical flakes may be patched in place; functional failures route back:

| Failure type | Route to |
|---|---|
| Functional regression | `flutter-app-developer` |
| Wrong / weak assertion | `test-script-author` |
| Missing scenario | `test-case-designer` |

After `green`, walk each P0 AC in `spec.md`'s `## Acceptance criteria` and tick it `[x]`. The command then
ticks the **Test** row of the Phase ledger (date + verdict + report path).

**Gate to Phase 6:** verdict = `green`; all P0 ACs `[x]`.

---

## Phase 6 — Ship

**Command:** `/ship <slug>`

1. Confirms all ACs in `spec.md`'s `## Acceptance criteria` are checked (legacy slugs: a separate
   `acceptance-criteria.md`), and no P0/P1 cases are unimplemented.
2. **Verifies a green test report** — reads the latest `summary.md` and requires `verdict: green` (refuses
   on missing / stale / `failures` / `blocked`). Machine-checked hard gate.
3. Sets `spec.md` → `status: shipped` with today's date.
4. Ticks the **Ship** row, then moves `planning/active/<slug>.md` → `planning/done/<slug>.md` with
   "What shipped" + "What we'd do differently" notes and the green-report link.
5. Updates `planning/roadmap.md` "Where I am right now" + "Immediate next action".
6. Outputs a 3-bullet release summary.

> **Why the gate is machine-checked.** The green verdict lives in a structured `summary.md` (YAML `verdict:`),
> not free text, so `/ship` can refuse a stale or red run.

---

## Status — single source of truth

The **Phase ledger** in `planning/active/<slug>.md` is the *only* per-slug status record. Each phase command
ticks its row in place (date + verdict + one-line note). There is **no separate status-log table** to keep in
sync, and **no `execution-roadmap.md`** — `planning/roadmap.md` is the single human-facing tracker.

**Start each session with `/status`** — it derives the current phase + next command from the ledger (falling
back to spec status / AC checkboxes / latest report verdict).

| What to check | Where to look | What to look for |
|---|---|---|
| In progress? | `planning/active/` | File exists |
| Current phase / next step / blocker | `planning/active/<slug>.md` `## Phase ledger` | Last ticked row + Current phase / Next command |
| Spec approved? | `specs/<slug>/spec.md` | `status: approved` |
| Which ACs done? | `specs/<slug>/spec.md` `## Acceptance criteria` | `[x]` vs `[ ]` (legacy: `acceptance-criteria.md`) |
| Test cases + coverage | `tests/cases/<slug>.md` | Coverage note + P0/P1/P2 list |
| Last test run | `tests/_runner/reports/<slug>/` (latest) | `verdict:` in `summary.md` |
| Shipped? | `planning/done/` | File exists AND `spec.md` status = `shipped` |
| Roadmap / what next | `planning/roadmap.md` | "Where I am right now" + "Immediate next action" |

---

## Artifact chain

| Artifact | Created by | Status values | Feeds into |
|---|---|---|---|
| `planning/backlog/<slug>.md` (or epic + slices) | `/capture-idea` | (queued) | Phase 2 |
| `planning/active/<slug>.md` | `/new-feature` | Phase ledger (single tracker) | `/ship` |
| `specs/<slug>/spec.md` (incl. inline ACs) | `product-domain-expert` | `draft`→`approved`→`shipped`; AC `[ ]`/`[x]` | `flutter-app-developer`, `flutter-code-reviewer` |
| `tests/cases/<slug>.md` | `test-case-designer` | Coverage note + P0/P1/P2 per case | `test-script-author`, `flutter-code-reviewer` |
| `src/` | `flutter-app-developer` (+ specialists) | — | `unit-test-writer`, `flutter-code-reviewer` |
| `src/test/`, `src/integration_test/` | `unit-test-writer`, `test-script-author` | pass / fail | `flutter-code-reviewer`, `test-executor` |
| `tests/_runner/reports/<slug>/<timestamp>/summary.md` | `test-executor` | `verdict: green` ⇒ `/ship` gate | `/ship` (hard gate) |
| `planning/done/<slug>.md` | `/ship` | shipped (archived) | roadmap / release notes |

---

## Quick-reference commands

| Command | When to run | What it does |
|---|---|---|
| `/quick-change <slug>` | Bug fix / tiny tweak | Lean lane: stub spec + ACs → implement+test+self-review → review → test → ship |
| `/capture-idea <slug>` | New, fuzzy idea | Frames a backlog item (domain + feasibility + success signals) |
| `/new-feature <slug>` | Idea is scoped | Scaffolds `spec.md` (with inline ACs) + test cases + active ledger |
| `/implement <slug>` | Spec `approved` | Code + unit tests + automation + built-in self-review pass |
| `/review-code <slug>` | Build complete | Read-only critique (+ `/privacy-audit`); findings by severity |
| `/execute-tests <slug>` | Review `ready` | Runs the runner; writes `summary.md` with a `verdict:` |
| `/ship <slug>` | Green report + P0 ACs `[x]` | Marks shipped, archives, updates roadmap, release summary |

---

## Domain knowledge

[docs/domain/](../domain/) feeds every spec: `business-rules.md` (BR-N), `glossary.md`, `personas.md`.
`product-domain-expert` reads these before drafting any spec. When business rules change, update `docs/domain/`
first, then re-run the affected spec sections — don't let rules rot inside specs.

---

## Guardrails (summary)

- No code in `src/` before a spec is `approved` (or a `/quick-change` stub is confirmed).
- No automated tests without a corresponding case in `tests/cases/`.
- No speculative abstractions — scope = the spec's ACs only.
- Reviewers are **read-only** — they surface findings, they don't fix them.
- Shipping requires manual P0-AC verification AND a machine-verified green `summary.md`. `/ship` enforces both.
