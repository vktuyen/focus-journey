---
description: Show where each active initiative stands and the exact next command to run — the entry point when you start a fresh Claude session. Reads planning/active, spec status, and review/test reports. Read-only; no agents, no writes.
argument-hint: "[feature-slug]  (optional; defaults to all active initiatives)"
---

Report the current phase + next step for `$ARGUMENTS` (or every initiative in `planning/active/` if no slug). **Run this first in a fresh session to resume.**

This is **READ-ONLY** — make no changes and spawn no agents. For each slug, determine the phase from artifacts (per `docs/guides/development-workflow.md` → "Status tracking cheat-sheet"):

1. **Located?** `planning/active/<slug>.md` exists (in progress) vs `planning/done/<slug>.md` (shipped) vs only `planning/backlog/` (not promoted).
2. **Phase ledger** — if `planning/active/<slug>.md` has a `## Phase ledger`, read it (current phase + next command). Otherwise derive from:
   - spec `Status:` (draft / in-review / approved / shipped) in `specs/<slug>/spec.md`
   - ACs: count `[x]` vs `[ ]` in `specs/<slug>/acceptance-criteria.md`
   - is there code under `src/`? tests under `tests/`?
   - latest `tests/_runner/reports/<slug>/<timestamp>/summary.md` `verdict:`
   - latest `## Status log` entry in the active file
3. **Compute NEXT command:** no spec → `/new-feature <slug>`; spec not `approved` → review & approve `spec.md`; approved, no code → `/implement <slug>`; code present, not reviewed → `/review-code <slug>`; review `ready`, no green report → `/execute-tests <slug>`; green + all P0 ACs `[x]` → `/ship <slug>`.

Output a compact table — **Slug · Phase (1–6) · Spec status · ACs x/total · Last test verdict · NEXT command** — then one line per slug with its most recent status-log note, so a fresh session has full context. Surface any `[blocked by: …]` from the planning item, and for an epic, the current **wave** from its Breakdown table.
