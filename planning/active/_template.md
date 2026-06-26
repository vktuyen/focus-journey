# <Initiative name>

**Promoted from backlog:** <YYYY-MM-DD>
**Target:** <YYYY-MM-DD or milestone>
**Spec:** [specs/<slug>/](../../specs/)

## Goal
<Single sentence. What "done" looks like.>

## Phase ledger
The **single** status tracker — one row per phase, updated in place after each phase command.
Each row carries the date + a one-line note + verdict, so a fresh session (`/status`) can resume
from this table alone. Do not keep a separate status log; the ledger IS the log.

| ✓ | Phase | Command | Date | Verdict / note |
|---|-------|---------|------|----------------|
| [ ] | 2 · Spec | `/new-feature` → review & approve `spec.md` |  |  |
| [ ] | 3 · Build | `/implement` (includes self-review pass) |  |  |
| [ ] | 4 · Review | `/review-code` |  | verdict: |
| [ ] | 5 · Test | `/execute-tests` |  | verdict: |
| [ ] | 6 · Ship | `/ship` |  |  |

**Current phase:** <n>   **Next command:** `/…`

## Decisions made along the way
<Link to ADRs or inline notes. Don't let decisions evaporate.>
