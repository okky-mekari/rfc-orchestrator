# Decision Rubric

Use when writing an ADR or any "alternatives considered" section.

## A decision is worth recording when …

1. It's hard to reverse. (Database choice. Public API shape. Auth model.)
2. It costs money or time to change. (Hosting region. Build tooling.)
3. It's non-obvious. (We chose synchronous over async because of X.)
4. Future maintainers will ask "why did they do it this way?"

If none of those apply, don't write an ADR — just put a one-liner in the design doc and move on.

## Forces — name them explicitly

Every decision is a balance between forces. Common ones:

- **Time** — how fast must this ship?
- **Team skills** — what does the team already know?
- **Cost** — operational and developer-time cost.
- **Risk** — blast radius if this fails.
- **Reversibility** — how hard to undo.
- **Compliance** — regulatory or contractual constraints.
- **Existing investment** — sunk cost in current tooling (and whether it should sway the decision).
- **Future optionality** — does this lock us out of a likely future need?

## Alternatives — the test

The alternatives section must pass two tests:

1. **Realistic.** "We considered writing it in assembly" is not a serious alternative for a CRUD service. Don't write straw-men.
2. **Specific rejection.** "Too complex" is not a reason. "Adds two new dependencies and a 3-week learning curve for the team" is.

Aim for 2–4 serious alternatives per decision. Fewer than 2 and the decision wasn't really a decision; more than 4 and you're padding.

## Consequences — both sides

Every choice opens some doors and closes others. Write down both.

| Decision | What gets easier | What gets harder |
|----------|------------------|------------------|
| Event sourcing | Auditability, replayability | Read models, eventual consistency, mental model |
| Monorepo | Cross-cutting refactors, shared tooling | Build times, repo size, contributor onboarding |
| GraphQL | Frontend velocity, schema discoverability | Caching, query-complexity attacks, backend tooling |

If you can't think of anything that gets harder, you haven't thought hard enough. Try again.

## Status lifecycle

- **Proposed** — open for discussion. Anyone can edit.
- **Accepted** — locked. The system is being built / has been built around this.
- **Superseded by ADR-NNNN** — replaced. Link forward.
- **Deprecated** — no longer in effect but not replaced (e.g., the system itself was retired).
- **Rejected** — proposed and decided against. Keep for the historical record.

Once Accepted, an ADR is **immutable**. Don't edit it; write a new ADR that supersedes.

## Title style

`ADR-NNNN: <verb-phrase>` — the decision as a verb phrase.

- Good: `ADR-0007: Use Postgres for primary storage`
- Good: `ADR-0012: Adopt event sourcing for the orders aggregate`
- Bad: `ADR-0007: Database`
- Bad: `ADR-0007: Postgres vs. MySQL vs. DynamoDB`
