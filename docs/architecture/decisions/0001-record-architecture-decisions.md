# ADR-0001: Record architecture decisions

- Status: accepted
- Date: <YYYY-MM-DD>
- Deciders: <names / roles>

## Context
We need a lightweight way to capture why we made important architectural or process choices, so future contributors (human or agent) can understand the reasoning without archaeology. Architecture lives in `docs/architecture/` and is owned by the `system-architect` agent.

## Decision
Use Architecture Decision Records (ADRs), numbered sequentially, stored in `docs/architecture/decisions/`. Each ADR follows the shape defined in `_template.md`: Status, Date, Deciders, Context, Decision, Consequences, Alternatives considered.

## Consequences
- Every non-trivial architectural choice gets an ADR.
- Reversing a decision means writing a new ADR (with the old one marked `superseded by ADR-XXXX`), not editing history.
- `system-architect` is the only agent that creates ADRs; other agents reference them by ID.

## Alternatives considered
### Inline documentation only
Rejected: rules and rationale rot inside specs/code comments because they aren't searchable by ID and lack a clear lifecycle (proposed → accepted → superseded).

### A single rolling design doc
Rejected: a monolithic doc obscures which decisions were active at any point in time and makes superseding messy.
