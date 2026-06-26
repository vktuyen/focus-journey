---
description: Mark an initiative shipped — move planning/active/<slug> to planning/done, update spec status
argument-hint: <feature-slug>
---

Wrap up the initiative `$ARGUMENTS`:

1. Confirm all acceptance criteria are checked. They live inline in the `## Acceptance criteria` section
   of `specs/$ARGUMENTS/spec.md` (legacy features may instead have a separate
   `specs/$ARGUMENTS/acceptance-criteria.md` — check that if present). If any AC is unchecked, stop and report.
2. Confirm the case file `tests/cases/$ARGUMENTS.md` has no P0/P1 scenarios marked unimplemented.
3. **Verify a green test execution report exists** (hard gate — do NOT skip):
   - Find the most recent timestamped folder under `tests/_runner/reports/$ARGUMENTS/`.
   - If the folder does not exist, STOP. Tell the user to run `/execute-tests $ARGUMENTS` first.
   - Read its `summary.md`. If the file is missing, STOP and report — the last run is not machine-verifiable.
   - Parse the `verdict:` field from the front-matter. It MUST equal `green`. If it is `failures` or `blocked`, STOP and surface the failing tests / blockers from the summary; do not ship.
   - Sanity-check: if the report's `run_at` timestamp predates the most recent commit touching `src/` or `tests/` for this slug, warn the user the report is stale and ask whether to re-run `/execute-tests $ARGUMENTS` before continuing.
4. Update `specs/$ARGUMENTS/spec.md` status to `shipped` with today's date.
5. Tick the **Ship** row of the Phase ledger in `planning/active/$ARGUMENTS.md`, then move the file →
   `planning/done/$ARGUMENTS.md`, adding "What shipped" + "What we'd do differently" notes and a link to
   the green report folder used in step 3. (The ledger is the single status record — there is no separate log.)
6. Update `planning/roadmap.md` "Where I am right now" + "Immediate next action" to reflect the ship.
7. Summarize the outcome in 3 bullets so I can paste into a release note. Include the report timestamp and pass count.
