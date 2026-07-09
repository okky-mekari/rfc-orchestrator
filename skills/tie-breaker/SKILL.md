# Skill Profile: Executive Tie-Breaker & Conflict Resolution
**Focus:** Decision heuristics for resolving disagreements between reviewers

---

## Scope of This Document

This document defines **the heuristic hierarchy** the Merger applies when reviewers disagree. It is the answer to *"when HoE wants X and QA wants Y, who wins, and how?"*

This document does **NOT** define:
* When to look for conflicts or how to assemble inputs (see `merger.md` Step 2 — Ingest)
* How to write the resolution into PLAN.md or debug.json (see `merger.md` Step 4–6 and the Feedback Resolution Table contract)
* Synthesis competencies broader than tie-breaking (see `skills/merger/SKILL.md`)

This file is **knowledge** — a decision policy. The agent that *applies* this policy is the Merger; the *mechanics* of recording the application are in `merger.md` and `scenario.md`.

---

## Hierarchy of Decision Heuristics

When two reviewers disagree, apply these rules **in order**. The first matching rule wins. Always cite the rule that was applied (R1 / R2 / R3 / R4) in the Feedback Resolution Table.

### R1 — Critical Safety overrides Time-to-Market

**When it applies:** QA Gatekeeper identifies a critical safety issue — data loss, security vulnerability, integrity violation, irrecoverable failure mode — and HoE pushes against the safety measure on grounds of speed, cost, or simplicity.

**Resolution:** the safety concern wins.

**Examples:**
* QA: "Without a transactional outbox, payment events can be lost on crash." HoE: "Adds a week of work, ship without it." → **R1: adopt transactional outbox.**
* QA: "Logging full PII in audit logs creates a privacy risk." HoE: "Already built that way; redacting now adds 3 days." → **R1: redact before launch.**

**Why:** safety failures compound. A "we'll fix it post-launch" data-loss bug usually means data is already lost.

---

### R2 — Global Consistency overrides Local Preference

**When it applies:** HoE identifies a tech-stack violation — the architect or developer has chosen a tool, library, or pattern that conflicts with an established organizational standard.

**Resolution:** the org standard wins.

**Examples:**
* Architect proposes Redis; HoE: "Org standard is Memcached for caching." → **R2: use Memcached.**
* Architect proposes a new gRPC service; HoE: "All internal services are REST per platform standard." → **R2: REST.**

**Why:** tech sprawl has compounding cost — every additional tool fragments operational expertise, monitoring, on-call, and security review. The exception worth fighting for is rare.

**Carve-out:** if the architect can show that the org standard genuinely cannot meet a hard requirement (not just a preference), the conflict escalates to R4 rather than R2.

---

### R3 — Reliability vs. Cost → Phased Rollout

**When it applies:** the conflict is between a higher-reliability option (more redundancy, more observability, more headroom) and a lower-cost option, and *neither extreme is correct on its own*.

**Resolution:** propose a **Phased Rollout**.
* **Phase 1 (now):** Minimum Viable Resilience — the cheapest configuration that still meets the floor SLO and contains failure blast radius.
* **Phase 2 (later, conditional):** Full redundancy / scaling. Triggered by a specific signal — sustained SLO miss, growth threshold, or planned launch event.

**Examples:**
* QA: multi-region active-active for 99.99%. HoE: single-region for budget. → **R3: single-region with documented failover runbook + multi-region planned for sustained 99.9% SLO miss.**
* QA: full read-replica fleet. HoE: primary-only. → **R3: primary + 1 same-region read-replica from day 1; geo-distributed replicas added after RPS exceeds threshold.**

**Why:** infrastructure spend compounds, but so does technical debt from cutting too close to the bone. A phased plan with explicit triggers gives both sides what they need: HoE gets cost discipline, QA gets a documented path to resilience.

**Phase 2 must have a trigger.** "Phase 2 someday" is not a valid R3 resolution — it's silent deferral. The trigger is observable (SLO metric, RPS threshold, customer count) and lives in the RFC.

---

### R4 — Escalation (No Rule Resolves)

**When it applies:** none of R1, R2, R3 cleanly resolves the conflict — typically because the trade-off is genuinely strategic (time-to-market vs. quality at high stakes, build-vs-buy, organizational restructure required) and not a question for the synthesizer to settle alone.

**Resolution:** do NOT invent a heuristic. Mark the conflict as `ESCALATED` in the Feedback Resolution Table and propose **two viable concrete paths** for the user to choose between.

**Format requirement:** R4 entries must list two paths, not "let the user decide" with no options. The synthesizer's value here is framing the decision, even when not making it.

**Examples:**
* QA: 3 weeks of additional test infrastructure. HoE: hard 6-week deadline (regulatory). Architect: would prefer the test infra. → **R4: Path A — meet deadline with reduced test infra and documented quality risks; Path B — slip deadline 2 weeks, regulatory implications must be confirmed.**

**Why:** a synthesizer who "decides" a strategic trade-off is taking authority they don't have. R4 is the correct, humble answer.

---

## Resolution Process (How the Merger applies these rules)

For every conflict the Merger detects:

1. **Identify** — state the specific disagreement: *"Reviewer A says X (because reason A); Reviewer B says Y (because reason B)."*
2. **Match a rule** — walk R1, R2, R3, R4 in order. First match wins.
3. **Choose path** — per the matched rule's resolution.
4. **Rationalize** — write a one- or two-sentence explanation citing the rule and tying it back to long-term project health.
5. **Hand off the recording** — the Merger workflow (see `merger.md` Step 3 and §12 Feedback Resolution Table) takes care of writing this into PLAN.md and `debug.json`. This skill stops at "decided"; the agent does the writing.

---

## Mindset

* Conflicts are signal, not noise — they reveal real tensions between speed, safety, cost, and consistency.
* "Compromise" is not always the right answer. Sometimes one side is correct and the other side's concern is real but secondary; say so explicitly.
* Document the *why*, not just the *what*. Future readers need to understand the reasoning, not just inherit the choice.
* Surfacing trade-offs is more valuable than hiding them. R4 (escalation) is a feature, not a failure.

---

## Out of Scope

* The mechanics of writing resolutions into `PLAN.md`, the Feedback Resolution Table, or `debug.json` — those live in `merger.md` and `scenario.md`.
* Conflicts within a *single* reviewer's findings (that's a reviewer-quality issue, addressed by re-running Phase 2, not by the Merger).
* Conflicts between the PRD and the architecture — those belong to the Tech Architect at Phase 1; the Merger should not be patching missed requirements at Phase 3.
* Inventing new tie-breaker rules. R1–R4 is the complete hierarchy. If R1–R3 don't apply, the answer is R4 (escalate), not "make up R5."