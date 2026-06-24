---
description: Bootstrap docs/architecture/overview.md for a new project by walking through each section interactively, then optionally seed the first ADR(s).
argument-hint: (none)
---

Bootstrap the architecture for this project.

Delegate to the `system-architect` agent. The agent should:

1. Read the current state of `docs/architecture/overview.md` and any existing ADRs under `docs/architecture/decisions/`.
2. Walk through each section of `overview.md` interactively — one section at a time, asking for confirmation before writing:
   - **Components** — major parts and what each owns
   - **Data flow** — how requests / events move through the system
   - **External dependencies** — third-party services, role, failure modes
   - **Environments** — dev / staging / prod differences
   - **Automation testing** — runner(s) per layer (unit / integration / e2e), config location, invocation commands, report destination
3. After the overview is populated, ask whether to seed initial ADRs for the most consequential decisions (typical: primary language/runtime, persistence choice, chosen test runner). If yes, use `_template.md` and write each as `docs/architecture/decisions/NNNN-<slug>.md`, auto-numbering from the highest existing ADR.
4. Surface a summary of what was written and which decisions remain open.

Preconditions:
- [ ] `docs/architecture/overview.md` exists (it's a template by default — that's fine).
- [ ] `docs/architecture/decisions/_template.md` exists.

If preconditions are missing, STOP and report what's missing rather than guessing.

Do NOT read from `docs/domain/` — domain knowledge must not influence tech-stack or architecture decisions in this command.
