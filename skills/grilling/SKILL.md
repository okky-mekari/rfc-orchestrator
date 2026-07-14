---
name: grilling
description: Grill the user relentlessly about a plan, decision, or PRD until the decision tree is resolved. Use when the user wants to stress-test their thinking before a design or RFC cycle, passes a `--grill` flag, or uses any "grill" trigger phrase. Adapted from mattpocock/skills (grill-me).
---

# Grilling Protocol

Interview the user relentlessly about every aspect of the plan/PRD/idea until you reach a shared understanding. Walk down each branch of the decision tree, resolving dependencies between decisions one by one.

## Rules

1. **One question per turn.** Ask exactly one question, then END YOUR TURN and wait for the answer. Asking multiple questions at once is bewildering.
2. **Always offer a recommended answer** with each question, with a one-line rationale. The user can accept it with a short reply (`yes` / `agree` / `rec`).
3. **Facts vs decisions.** If a *fact* can be found by exploring the environment (filesystem, repo, Confluence, Figma, tools), look it up yourself — never ask the user to explain what already exists. The *decisions* are the user's — put each one to them and wait.
4. **Push back.** If an answer contradicts an earlier decision, a repo convention, or the PRD, say so and re-ask. The goal is challenge, not agreement.
5. **Walk the tree in dependency order.** Resolve upstream decisions (scope, data model, ownership) before downstream ones (API shape, UI, rollout).
6. **Do not act on the plan** until the user confirms shared understanding has been reached.

## Exit conditions

* The decision tree is resolved (no unresolved branches), OR
* The user says `enough`, `stop grilling`, `proceed`, or similar.

## Output

On exit, write the resolved decisions to a notes file (default `grilling_notes.md`, or the path the caller specifies), formatted as:

```markdown
# Grilling Notes — {topic}
date: {ISO 8601}
status: RESOLVED | STOPPED_EARLY

## Decisions
### GRILL-1: {question, one line}
- **Decision:** {what was decided}
- **Rationale:** {why}
- **Decided by:** user | recommendation-accepted

### GRILL-2: ...

## Unresolved (only if STOPPED_EARLY)
- TBD: {open branch}
```

Each decision gets a stable `GRILL-n` ID so downstream documents can cite it.
