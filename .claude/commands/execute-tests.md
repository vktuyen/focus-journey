---
description: Execute automated tests for a feature using the project's configured runner and produce a run report
argument-hint: <feature-slug>
---

Execute the automated tests for `$ARGUMENTS`.

Preconditions (check before starting):
- [ ] `specs/$ARGUMENTS/spec.md` and `tests/cases/$ARGUMENTS.md` exist
- [ ] At least one automated script exists under `tests/e2e/` or `tests/integration/` matching `$ARGUMENTS`
- [ ] `docs/architecture/overview.md` declares the chosen runner(s) and invocation command(s) for the relevant layer
- [ ] A runner config exists under `tests/_runner/` (or wherever `overview.md` points)
- [ ] `/review-code $ARGUMENTS` has been run and is not `blocked` (advisory — note in output if not yet run)

If any required precondition is missing, STOP and report what's missing. Do not proceed.

Execution plan:
1. Identify in-scope test files for the feature across `tests/e2e/` and `tests/integration/`.
2. Read `docs/architecture/overview.md` to resolve the runner choice and invocation command(s).
3. Delegate execution to the `test-executor` agent. Pass it:
   - The cases file path (`tests/cases/$ARGUMENTS.md`)
   - The list of in-scope test script paths
   - The runner config path (default `tests/_runner/`)
   - The invocation command(s) from `overview.md`
   - The target report folder (`tests/_runner/reports/$ARGUMENTS/<timestamp>/`)
4. Surface the agent's run summary verbatim, including the per-test → case-ID mapping and verdict (`green` / `failures` / `blocked`).
   - Confirm the agent wrote `tests/_runner/reports/$ARGUMENTS/<timestamp>/summary.md` with a `verdict:` field. If the file is missing, treat the run as incomplete and re-prompt the agent — `/ship` relies on this artifact as a hard gate.
5. If the verdict is `failures`, suggest which downstream agent should address each finding:
   - Functional regression → `code-generator`
   - Wrong/weak assertion or wrong scenario coverage → `test-script-author`
   - Missing case → `test-case-designer`

Do NOT apply functional fixes from this command — execution and mechanical flake-patching only.
