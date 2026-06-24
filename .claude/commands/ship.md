---
description: Mark an initiative shipped — move planning/active/<slug> to planning/done, update spec status
argument-hint: <feature-slug>
---

Wrap up the initiative `$ARGUMENTS`:

1. Confirm all acceptance criteria in `specs/$ARGUMENTS/acceptance-criteria.md` are checked. If not, stop and report.
2. Confirm the case file `tests/cases/$ARGUMENTS.md` has no P0/P1 scenarios marked unimplemented.
3. **Verify a green test execution report exists** (hard gate — do NOT skip):
   - Find the most recent timestamped folder under `tests/_runner/reports/$ARGUMENTS/`.
   - If the folder does not exist, STOP. Tell the user to run `/execute-tests $ARGUMENTS` first.
   - Read its `summary.md`. If the file is missing, STOP and report — the last run is not machine-verifiable.
   - Parse the `verdict:` field from the front-matter. It MUST equal `green`. If it is `failures` or `blocked`, STOP and surface the failing tests / blockers from the summary; do not ship.
   - Sanity-check: if the report's `run_at` timestamp predates the most recent commit touching `src/` or `tests/` for this slug, warn the user the report is stale and ask whether to re-run `/execute-tests $ARGUMENTS` before continuing.
4. Update `specs/$ARGUMENTS/spec.md` status to `shipped` with today's date.
5. Move `planning/active/$ARGUMENTS.md` → `planning/done/$ARGUMENTS.md`, filling in the "What shipped" and "What we'd do differently" sections from the status log. Include a link to the green report folder used in step 3.
6. Summarize the outcome in 3 bullets so I can paste into a release note. Include the report timestamp and pass count.
