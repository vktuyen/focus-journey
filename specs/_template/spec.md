# <Feature name>

**Status:** draft | in-review | approved | shipped
**Owner:** <person or team>
**Last updated:** <YYYY-MM-DD>

## Problem
<What problem are we solving? For whom? Why now?>

## User & outcome
<Which persona benefits? What observable change in their experience indicates success?>

## Scope
### In
- <bullet>

### Out
- <bullet — explicit non-goals>

## Constraints & assumptions
- <regulatory, technical, timing, or business constraints>

## Acceptance criteria
Each item is a checkable, observable statement and the ship gate. If it isn't testable, rewrite it.
These ACs ARE the contract — `tests/cases/<slug>.md` references them by ID; there is no separate
acceptance-criteria file.

- [ ] AC-1: <Given / When / Then statement>
- [ ] AC-2: ...
- [ ] AC-3: ...

### Non-functional
- [ ] NFR-1 Performance: <e.g. p95 under 200ms for endpoint X>
- [ ] NFR-2 Security/Privacy: <e.g. no new unauthenticated surfaces; aggregate-only reads>
- [ ] NFR-3 Accessibility: <e.g. WCAG AA for new UI>

## Open questions
- [ ] <question> — owner: <who will answer>

## Related
- Domain rules: [docs/domain/business-rules.md](../../docs/domain/business-rules.md)
- Architecture: [docs/architecture/](../../docs/architecture/)
