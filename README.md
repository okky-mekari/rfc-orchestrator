# RFC Orchestrator

A multi-agent RFC development pipeline for [Claude Code](https://claude.com/claude-code). It takes a PRD and drives it through architectural design, parallel engineering + QA review, synthesis, and a security gate — with human approval checkpoints — producing a consolidated, implementation-ready RFC (`PLAN_FINAL.md`). Optionally, it can then implement the plan.

```
PRD ──▶ Phase 1        Phase 1.5   Phase 2 (parallel)   Phase 3     Phase 4    Phase 4.5   Phase 5
        tech-architect  ── YOU ──▶  hoe                  merger      infosec    ── YOU ──▶  implementor
        drafts PLAN.md   review     qa-gatekeeper        PLAN_FINAL  security    approve    (optional)
                                    review in parallel   .md         gate                   build
```

## What's inside

```
agents/                  Subagent definitions  → install to ~/.claude/agents/
  tech-architect.md      Phase 1 — drafts PLAN.md from the PRD
  hoe.md                 Phase 2 — Head of Engineering review
  qa-gatekeeper.md       Phase 2 — QA / reliability / risk review + test cases
  merger.md              Phase 3 — reconciles draft + reviews into PLAN_FINAL.md
  infosec.md             Phase 4 — security gatekeeper (blocks unsafe designs)
  implementor.md         Phase 5 — optional implementation from the final plan

skills/                  Skills  → install to ~/.claude/skills/
  rfc-orchestrator/      The pipeline protocol — the /rfc-orchestrator entry point
  tech-architect/        Architect profile + ADR / C4 / plan templates + decision rubric
  hoe/                   Head of Engineering review profile
  gatekeeper/            QA gatekeeper review profile
  merger/                Synthesis profile + PLAN_FINAL template
  infosec/               Security review profile
  tie-breaker/           Conflict-resolution rules for contradicting reviewer feedback
  developer/             Implementor profile (backend engineering with AI fluency)
```

## Requirements

- [Claude Code](https://claude.com/claude-code) CLI (or desktop/IDE) — any recent version with subagent (Task/Agent tool) support
- No MCP servers required — the core flow is entirely file-based

## Install

```bash
git clone <this-repo>
cd rfc-orchestrator
./install.sh
```

Or manually:

```bash
mkdir -p ~/.claude/agents ~/.claude/skills
cp agents/*.md ~/.claude/agents/
cp -R skills/* ~/.claude/skills/
```

Then start a **new** Claude Code session so the agents and skills are picked up.

> **Heads-up:** if you already have agents or skills with the same names (`hoe`, `merger`, `infosec`, ...), the copy will overwrite them. Check first with `ls ~/.claude/agents ~/.claude/skills`.

## Usage

In a Claude Code session inside the project repo you want the RFC for:

```
/rfc-orchestrator
```

Provide your PRD when asked (a file path or pasted content). The orchestrator then runs the pipeline:

| Phase | Actor | Output |
|---|---|---|
| 1 — Design | `tech-architect` | `PLAN.md` (architecture draft, decision rationale) |
| 1.5 — Draft review | **you** | approve / request changes (gated) |
| 2 — Review | `hoe` + `qa-gatekeeper` in parallel | engineering review + QA review with scenario-level test cases |
| 3 — Synthesis | `merger` | `PLAN_FINAL.md` + `merge_report.md` (audit trail); conflicts resolved via tie-breaker rules |
| 4 — Security | `infosec` | security review report; decision written into `PLAN_FINAL.md` header |
| 4.5 — Final review | **you** | approve / reject the consolidated RFC (gated) |
| 5 — Implement (optional) | `implementor` | code implementing the plan |

Commands you can use at the gates and during the run: `approve`, `reject`, `change <feedback>`, `status`, `abort` (the full event list is documented in `skills/rfc-orchestrator/SKILL.md`).

All outputs land in your project's working directory, so they can be committed alongside your code.

## Customizing

- **Templates** — the ADR / C4 / plan templates live in `skills/tech-architect/assets/` and the final-RFC template in `skills/merger/assets/`; edit them to match your org's format.
- **Review focus** — each reviewer's rubric is its skill profile (`skills/hoe`, `skills/gatekeeper`, `skills/infosec`); adjust the checklists there.
- **Conflict policy** — how contradicting reviewer feedback gets resolved is defined in `skills/tie-breaker`.
