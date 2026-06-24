---
description: Review the generated code and test scripts for a feature against its spec and test cases
argument-hint: <feature-slug>
---

Run a code review for `$ARGUMENTS`.

Preconditions (check before starting):
- [ ] `specs/$ARGUMENTS/spec.md` and `specs/$ARGUMENTS/acceptance-criteria.md` exist
- [ ] `tests/cases/$ARGUMENTS.md` exists
- [ ] At least some implementation exists under `src/` and tests under `tests/unit/`, `tests/integration/`, or `tests/e2e/`

If any precondition is missing, STOP and report what's missing. Do not proceed.

**Resolve the Reviewer role + Review-phase skills from the Agent roster** in `docs/architecture/overview.md` (default: `code-reviewer`).

Execution plan:
1. Identify the files in scope for this feature: production code under `src/` and test scripts under `tests/unit/`, `tests/integration/`, `tests/e2e/` that relate to `$ARGUMENTS`.
2. Delegate the review to the **Reviewer** role (default: `code-reviewer`). Pass it:
   - The spec path and acceptance criteria path
   - The cases file path (`tests/cases/$ARGUMENTS.md`)
   - The list of in-scope source and test files
3. Run any **Review-phase skills** the roster lists (e.g. a privacy audit) and fold their verdicts into the report.
4. Surface the agent's findings verbatim, grouped by severity.
5. If the verdict is `changes requested` or `blocked`, suggest which downstream agent should address each finding (e.g. `code-generator`/Implementer, `unit-test-writer`, or `test-script-author`).
6. Append the outcome to `planning/active/$ARGUMENTS.md` (status log + the **Review** row of its Phase ledger).

Do NOT apply fixes from this command — review only.
