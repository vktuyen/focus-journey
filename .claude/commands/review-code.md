---
description: Review the generated code and test scripts for a feature against its spec and test cases
argument-hint: <feature-slug>
---

Run a code review for `$ARGUMENTS`.

Preconditions (check before starting):
- [ ] `specs/$ARGUMENTS/spec.md` exists with an `## Acceptance criteria` section
- [ ] `tests/cases/$ARGUMENTS.md` exists
- [ ] At least some implementation exists under `src/` with tests (`src/test/`, `src/integration_test/`)

If any precondition is missing, STOP and report what's missing. Do not proceed.

Execution plan:
1. Identify the files in scope for this feature: production code and test scripts that relate to `$ARGUMENTS`.
2. Delegate the review to **`flutter-code-reviewer`** (read-only). Pass it:
   - The spec path (its `## Acceptance criteria` section is the contract)
   - The cases file path (`tests/cases/$ARGUMENTS.md`)
   - The list of in-scope source and test files (prefer the git diff for this slug)
3. **Run `/privacy-audit`** (uses `privacy-guardian`) and fold its verdict into the report — the
   trust-promise gate for this app.
4. Surface the agent's findings verbatim, grouped by severity.
5. If the verdict is `changes requested` or `blocked`, suggest which agent should address each finding
   (`flutter-app-developer` / the relevant specialist, `unit-test-writer`, or `test-script-author`).
6. Update the **Review** row of the Phase ledger in `planning/active/$ARGUMENTS.md` in place (date +
   verdict + one-line note) — single source of truth, no separate status log.

Note: a self-review pass already ran inside `/implement`; this is the formal Phase-4 gate.
Do NOT apply fixes from this command — review only.
