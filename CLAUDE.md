# Project context for Claude

This file is auto-loaded into every Claude Code session. Keep it short, durable, and actionable.

## What this repo is

A workspace set up for agentic software development. Tech stack is **not yet chosen** — the folder structure is deliberately tech-agnostic.

## How to work here

- **Right-size the process — two lanes.** For a **bug fix or tiny tweak**, use `/quick-change <slug>`: one lean pass (stub spec + 1–4 inline ACs → implement+test+self-review → review → test → ship) that skips `/capture-idea`, separate test-case design, ADRs, and summaries. Use the **full feature loop** below only for genuine features.
- **Capture ideas first (Phase 0).** New *features* start as a backlog item via `/capture-idea <slug>` — it coordinates `product-domain-expert`, `system-architect`, and `test-case-designer` to frame the business need and feasibility *before* committing to a spec. A large / multi-feature idea is split into an **epic + child backlog items** (one per wave, sequenced with `[blocked by: …]`), each promotable on its own via `/new-feature`. Stays commitment-free: docs/domain and docs/architecture are untouched; candidates are only flagged. (Skip this for a well-scoped feature or a small change.)
- **Plan before coding.** Non-trivial work starts with a spec under [specs/](specs/) (copy from [specs/_template/](specs/_template/)). Don't jump straight to [src/](src/). Promote a backlog item into a spec with `/new-feature <slug>`. **Acceptance criteria live inline in `spec.md`** (its `## Acceptance criteria` section) — there is no separate `acceptance-criteria.md` or `test-plan.md`.
- **Delegate by skill.** Use the specialized agents in [.claude/agents/](.claude/agents/) instead of doing everything yourself:
  - Domain questions / ambiguous requirements → `product-domain-expert`
  - System architecture, tech-stack & runner choice, ADRs → `system-architect` (bootstrap with `/init-architecture`, capture decisions with `/add-adr`)
  - Implementation → `code-generator`
  - Test design (scenarios) → `test-case-designer`
  - Test automation → `test-script-author`
  - Test execution (run automation, report results) → `test-executor` (triggered manually by `/execute-tests <feature-slug>`)
  - Unit tests alongside code → `unit-test-writer`
  - Review of generated code and test scripts → `code-reviewer` (triggered manually by `/review-code <feature-slug>`)
  - **This project's agents are named directly in the phase commands** (Flutter desktop — see the Agent roster in [docs/architecture/overview.md](docs/architecture/overview.md) for the full mapping): Implementer → `flutter-app-developer` (UI/Bloc) · `flutter-native-plugin-engineer` (native idle/tray/window) · `flame-game-developer` (Flame scenes); free license-clean art → `ui-asset-curator` (via `/source-assets`); Reviewer → `flutter-code-reviewer` (via `/review-code`, and the **self-review pass built into `/implement`**); privacy audit → `privacy-guardian` (via `/privacy-audit`). One-time project setup: `/flutter-bootstrap`. You don't invoke these directly — the phase commands do.
- **Keep domain knowledge in [docs/domain/](docs/domain/).** The domain-expert agent reads from there — update it when business rules change.
- **Architecture lives in [docs/architecture/](docs/architecture/).** Only `system-architect` writes to it. Other agents (including test agents) read [docs/architecture/overview.md](docs/architecture/overview.md) to resolve technical choices like the test runner. Domain knowledge deliberately does **not** influence architecture decisions.
- **Initiatives flow** backlog → active → done in [planning/](planning/). Move the folder; don't just edit status.
- **Tests split by purpose:** [tests/cases/](tests/cases/) for human-readable scenarios, [tests/unit/](tests/unit/) / [tests/integration/](tests/integration/) / [tests/e2e/](tests/e2e/) for executables; [tests/_runner/](tests/_runner/) holds the chosen runner's config + run reports.
- **Project-specific skills** live in [.claude/skills/](.claude/skills/) per branch. The generic chassis ships with none.

## Resuming across sessions (kill & restart between phases)

Every phase writes its progress to disk, so a session can be killed and a fresh one resumed cleanly:
- `planning/active/<slug>.md` — the **Phase ledger** (single status tracker: current phase, next command, per-row date/verdict). No separate status log.
- `specs/<slug>/spec.md` `Status:`; AC checkboxes in its `## Acceptance criteria` section.
- `tests/_runner/reports/<slug>/<timestamp>/summary.md` — last verdict.

**Start each new session with `/status [slug]`** — it derives the current phase from these artifacts and prints the exact next command. (Reference: [docs/guides/development-workflow.md](docs/guides/development-workflow.md) "Status — single source of truth".)

**Always keep [planning/roadmap.md](planning/roadmap.md) current** — the single human-facing "what command do I run next" tracker (it absorbed the old `execution-roadmap.md`). After **every** phase command and any state change (promote / approve a spec / implement / review / test / ship — or when the active slug changes), update its **"Where I am right now"** + **"Immediate next action"** sections and the relevant Now/Next/Later wave entries, so the user sees the exact next command without having to invoke `/status`.

## Versioned waves (v1 / v2 / v3)

A version is a **wave of the epic**, not a re-run of one feature.
- Each wave is a set of child backlog slugs listed in the epic's **Breakdown** table.
- **Start a wave** by promoting its slugs one at a time with `/new-feature <slug>` (Phase 2 — Spec), then `/implement → /review-code → /execute-tests → /ship` each. **There is no "start v2" button** — v2 *is* the next batch of `/new-feature` runs.
- **Don't re-run `/implement` on a shipped slug to add v2 behaviour.** An enhancement to a shipped component is a **new slug** in a later wave (e.g. `journey-energy-model` enhances the shipped `journey-engine`), tagged `[blocked by: journey-engine]`.
- Respect wave discipline: don't start wave N+1 until wave N's slugs ship. `planning/roadmap.md` tracks which wave is **Next** vs **Later**.

## Guardrails

- Don't hardcode tech-stack assumptions in shared docs, agents, or commands. The chosen stack (language, frameworks, test runner) is declared per project in [docs/architecture/overview.md](docs/architecture/overview.md) and downstream agents must read it from there.
- Don't create speculative abstractions in [src/](src/) before a spec exists.
- Don't write tests without a corresponding case in [tests/cases/](tests/cases/) or an acceptance criterion in the spec.
- Don't put test scripts under [tests/_runner/](tests/_runner/) — that folder is for runner config and run reports only. Scripts go under [tests/e2e/](tests/e2e/) or [tests/integration/](tests/integration/).
