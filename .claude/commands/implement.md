---
description: Implement an approved spec end-to-end by coordinating the code, unit-test, and test-script agents
argument-hint: <feature-slug>
---

Implement the approved spec at `specs/$ARGUMENTS/`.

Preconditions (check before starting):
- [ ] `specs/$ARGUMENTS/spec.md` status is `approved`
- [ ] `specs/$ARGUMENTS/acceptance-criteria.md` has concrete, testable items
- [ ] `tests/cases/$ARGUMENTS.md` exists with scenarios designed
- [ ] The project is scaffolded for the chosen stack. If `docs/architecture/overview.md`'s Agent roster names a one-time setup skill (e.g. a project bootstrap) and it hasn't run yet, run that first.

If any precondition is missing, STOP and report what's missing. Do not proceed.

**Resolve roles from the Agent roster** in `docs/architecture/overview.md` (role → project agent(s) + per-phase skills). Where the roster names no agent for a role, use the chassis default in parentheses.

Execution plan:
1. Delegate production code to the **Implementer** role (default: `code-generator`) — reference the spec and acceptance criteria. The roster may split this across specialist implementers (e.g. UI, native, game scene); coordinate them and keep pure logic framework-free.
2. In parallel, delegate unit tests to the **Unit-test** role (default: `unit-test-writer`) for the new/changed modules.
3. Once `src/` is stable, delegate automation to the **Test-automation** role (default: `test-script-author`) to turn `tests/cases/$ARGUMENTS.md` into executable tests.
4. Run any **Build-phase skills** the roster lists (e.g. asset sourcing, a self-review pass) before handing off to review.
5. Update `planning/active/$ARGUMENTS.md` after each step: append a status-log entry AND tick the **Build** row in its Phase ledger (set Current phase / Next command).

Summarize what each agent produced, list any open acceptance criteria, and point to the next command: `/review-code $ARGUMENTS`.
