# ADR-{{NNNN}}: {{Verb-phrase decision title}}

**Status:** Proposed / Accepted / Superseded by ADR-NNNN / Deprecated / Rejected
**Date:** {{YYYY-MM-DD}}
**Deciders:** {{names}}
**Related:** {{links to PRD, design doc, related ADRs}}

---

## Context

What is the situation that requires a decision? Include the forces at play — constraints, requirements, prior decisions that frame this one.

Be concrete. "We need faster queries" is not context. "Reporting queries scan 200M rows and currently take 90s P95 against the OLTP database, blocking the dashboard team's launch" is context.

## Decision

State the decision in one or two sentences. Use present tense.

> We will use a separate columnar store (replicated from the OLTP database via CDC) for all reporting queries.

## Alternatives Considered

At least two realistic options. Each gets:

### Option A — {{name}}
- **What it is:** one sentence.
- **Why rejected:** specific. Not "more complex" — quantify or describe.

### Option B — {{name}}
- **What it is:**
- **Why rejected:**

(Add more if useful. 2–4 is typical.)

## Consequences

### Positive
- {{What becomes easier or cheaper}}

### Negative
- {{What becomes harder, slower, more expensive, or impossible}}

### Neutral
- {{Things that change but aren't clearly good or bad}}

## Compliance / Verification

How will we know this decision is being followed? (e.g., "lint rule X enforces it", "code review checklist item Y", "architecture fitness function Z")
