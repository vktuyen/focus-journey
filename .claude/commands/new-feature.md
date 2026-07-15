---
description: Start a new feature by scaffolding a specs/<slug>/ folder from the template
argument-hint: <feature-slug>
---

Create a new feature spec folder. (For a small bug fix / tiny tweak, use `/quick-change <slug>` instead.)

1. Copy `specs/_template/` to `specs/$ARGUMENTS/` (one file: `spec.md`, plus `summary.html`). There is
   **no** separate `acceptance-criteria.md` or `test-plan.md` — ACs live inline in `spec.md`.
2. Open `specs/$ARGUMENTS/spec.md` and fill in the problem statement with me.
3. Delegate the domain framing to the `product-domain-expert` agent — have it propose the
   **Acceptance criteria** (functional `[ ] AC-N: Given/When/Then` + Non-functional) directly in the
   `## Acceptance criteria` section of `spec.md`.
4. Once the spec is reviewed, delegate test case design to `test-case-designer`. It writes
   `tests/cases/$ARGUMENTS.md` — human-readable scenarios, **each tagged with the AC-ID(s) it covers**
   (traceability), and a short coverage note at the top (which layers cover which ACs; what's risky or
   under-covered). It does **not** restate the ACs or write a separate test-plan file.
5. Add `planning/active/$ARGUMENTS.md` from the active template (single Phase ledger — no separate status log).
6. **Consume the backlog item (move, don't duplicate).** If `planning/backlog/$ARGUMENTS.md` exists, `git rm`
   it now — it has been promoted into `planning/active/`, and its domain framing / feasibility notes already
   fed the spec in steps 2-4. An initiative lives in exactly **one** stage (backlog → active → done); never
   leave a copy behind in `backlog/`. (Epic umbrella docs are not per-slug items and stay in `backlog/`.)

Do NOT start implementation until steps 1-4 are done and I've set `spec.md` `Status: approved`.
