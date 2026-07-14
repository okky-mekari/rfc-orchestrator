---
name: rfc-orchestrator
description: The full RFC development lifecycle orchestration protocol — PRD ingestion through architectural design, parallel review, synthesis, security clearance, and optional implementation. Load when running or resuming an RFC cycle that coordinates the tech-architect, hoe, qa-gatekeeper, merger, infosec, and implementor subagents, including the user-gated Phase 1.5 and 4.5 reviews. The main session acts as Orchestrator and dispatches specialists via the Task tool.
---

# Scenario: RFC Development Cycle

**scenario_version:** `1.5`
**Pinning:** the orchestrator records this `scenario_version` in the first `debug.json` event of every cycle.

> Full lifecycle from PRD ingestion through security clearance.
> Implementation is **opt-in** — the cycle's default deliverable is an approved RFC, not running code.
>
> **What's new in 1.5:**
> * **Phase 0: Requirements Grilling (opt-in via `--grill`).** If — and only if — the user's cycle-start message contains the `--grill` flag, the Orchestrator runs an interactive requirements interview (the `grilling` skill) in the main session BEFORE dispatching Phase 1. One question per turn, recommended answer offered each time, facts looked up from the environment rather than asked. Output: `grilling_notes.md`. Without the flag, the cycle starts at Phase 1 exactly as in 1.4 — Phase 0 never runs by default.
> * Phase 1 ingests `grilling_notes.md` when present: decisions recorded there are **settled** — the PRD Quality Check must not re-raise them as clarifying questions, and the draft cites them as `[GRILL-n]`. New Phase 1 verb: `grilling_notes_ingested`.
>
> **Carried over from 1.4:**
> * **Phase 2 lost-update race fixed:** HoE and QA no longer write `debug.json`. Each appends to its own event file (`hoe_events.json` / `qa_events.json`); the Orchestrator — sole `debug.json` writer in Phase 2 — folds both into `debug.json` in timestamp order during Inter-Phase Validation.
> * **Phase 2 verdicts:** each reviewer hands back `review_status: APPROVED | CHANGES_REQUIRED | REJECTED`. Either reviewer REJECTED → Tech Architect Revision Mode (budget: 2 review-rejection cycles).
> * **Impossible internal subagent gates removed** (Phase 1 Step 6; Revision Mode R3) — subagents have no user turns; the only Phase-1 review is the Orchestrator-owned 1.5 gate.
> * **Phase 5 gates are Orchestrator-owned:** the Orchestrator presents each task, logs `task_proposed`/`task_approved`, and dispatches the Implementor one task at a time; the Implementor logs `task_started`/`task_completed`.
> * **Anti-Hallucination Rules** (all phases), a **PRD Quality Check** in Phase 1, and a **`status` command** at gates.
>
> **Carried over from 1.3:**
> * **Hard turn-boundary enforcement at human gates (1.5 and 4.5).** The Orchestrator's presentation of a human gate MUST be the final action of its turn. Dispatching the next phase in the same turn as the gate presentation is a critical violation.
> * **Defensive precondition checks** required at the start of Phases 2, 3, 4, and 5. Subagents refuse to run if the preceding gate's approval event is missing from `debug.json`.
> * **Anti-fabrication rule:** the Orchestrator MUST NOT log `initial_review_approved`, `implementation_invoked`, or other user-decision events without an actual user message containing the routing input.
>
> **Carried over from 1.2:**
> * `PLAN_FINAL.md` replaces the "overwrite + archive" pattern. Two named files, two clean lifecycles. No archive logic.
> * **Document-Only Phases rule (1–4):** subagents must not write or execute scripts. Use direct file tools only. Phase 5 is exempt.
> * Phase 1.5 Initial Review Gate.

---

## Claude Code Execution Model (read first)

This protocol runs on Claude Code. Map the abstract roles onto Claude Code primitives as follows:

* **The Orchestrator is the main (top-level) session — never a subagent.** Two reasons this is mandatory:
  1. The human gates (Phase 1.5, 4.5) require *ending a turn and waiting for the user's next message*. Only the main session spans user turns; a subagent runs to completion and returns, with no user turns of its own.
  2. Only the main session can dispatch subagents via the `Task` tool. A subagent launched through `Task` does not itself receive `Task`, so it cannot launch the specialists. There is no reliable nested fan-out.
* **Dispatch is by subagent `name`, not filename.** When the Orchestrator dispatches a phase, it calls `Task` with `subagent_type` equal to the target agent's `name` frontmatter field. The "Subagent file" column below is for human reference; the `name` is the wire identifier. Keep filename, `name`, and every reference in this document in exact agreement.
* **Parallel review = two `Task` calls in one turn.** Phase 2 dispatches `hoe` and `qa-gatekeeper` by issuing both `Task` calls in the same assistant turn; they execute concurrently.
* **Subagents start blind.** A dispatched subagent sees only its own agent file (system prompt) plus the prompt the Orchestrator passes it. It does NOT inherit the main conversation. Therefore the Orchestrator MUST include, in each `Task` prompt, the absolute paths of that phase's declared Input artifacts (and the `trace_id`). The shared `debug.json` on disk is how each fresh-context subagent rediscovers cycle state — this is why the precondition checks read it as their first action.
* **Skill loading is explicit.** When a subagent (or the Merger at Phase 3) needs a `SKILL.md`, instruct it to `Read` the file by path. Do not assume markdown links auto-resolve or that user-level skills are inherited into a subagent's context.
* **File tools.** "Direct file tools" means Claude Code's `Read`, `Edit`, and `Write`. "Code-execution tools" means `Bash`. There is no `create_file` or `code_interpreter` tool — those names are Copilot-isms.

---

## Orchestration Model

This document is read and executed by an **Orchestrator** (the main session) that dispatches work to subagents. The Orchestrator is NOT a subagent itself. Its job:

1. Read this protocol.
2. At each phase, dispatch (via `Task`) the subagent named in the **Agent Dispatch Table** and instruct that agent to execute the phase, passing the phase's declared Input paths in the prompt.
3. Receive the phase's output, run the **Inter-Phase Validation Checklist**, then dispatch the next phase.
4. Present **Phase 1.5** and **Phase 4.5** hand-offs to the user and **end its turn** before routing based on the user's next message.
5. Track retry/iteration budgets and trigger escalation when exceeded.

> ⚠️ **Critical rule for subagents:** when a subagent finishes its phase, it MUST stop. Subagents do not continue into the next phase. Subagents do not present human gates that the Orchestrator owns (Phase 1.5, 4.5). Subagents log under their own role name only.

### Context Isolation Rule

Each `Task` dispatch starts a fresh, isolated context. The Orchestrator passes only this protocol's relevant phase contract, the dispatched subagent's own role (its agent file is its system prompt), and the paths to the artifacts that subagent's phase declares as Input. No other subagent files are shared.

### Document-Only Phases Rule (Phases 1–4)

Phases 1, 1.5, 2, 3, 4, and 4.5 are **document-only operations**. Subagents in these phases:

* MUST use direct file tools (`Read`, `Edit`, `Write`) to manipulate documents
* MUST NOT write Python, bash, JavaScript, or any other scripts to disk
* MUST NOT use code-execution tools (`Bash`, etc.) to manipulate files
* MUST NOT delegate file-writing to scripts saved in `/tmp/` or any other location

Rationale: auditability (direct tool calls appear in `debug.json`), variance reduction (deterministic), anti-over-engineering. **Phase 5 (Implementor) is exempt** — writing code is its purpose, but Phase 5 still doesn't manipulate RFC documents via scripts.

If a subagent finds itself thinking "I'll write a Python script to do this," it should stop and use direct file tools instead.

---

## 🚨 Human Gate Turn-Boundary Rule (NEW in 1.3 — CRITICAL)

This is the single most important rule in the scenario. Read it twice.

**Phase 1.5 and Phase 4.5 are user-gated.** They REQUIRE an actual user message between the gate being presented and the next phase being dispatched. The Orchestrator MUST enforce this by treating each gate presentation as a turn-terminating action.

### What the Orchestrator MUST do at a human gate

1. Verify the preceding subagent's `phase_completed` event and file state.
2. Log the gate presentation event (`initial_review_presented` for 1.5; `handoff_presented` for 4.5).
3. Output the gate prompt block to the user.
4. **END THE TURN.** No further tool calls. No further text. No subagent dispatch. The prompt block is the final output of the turn.
5. Wait for the user's next message — which arrives as a new turn.
6. In that next turn, parse the user's input and route accordingly.

### What the Orchestrator MUST NOT do

* ❌ Present the gate prompt and then immediately dispatch HoE / QA / Implementor in the same turn.
* ❌ Log `initial_review_approved` or `implementation_invoked` without a corresponding user message containing an approval/invocation phrase.
* ❌ Treat its own narration ("the user will likely approve") as a user response.
* ❌ Assume silence equals approval. Silence is wait, not consent.
* ❌ Fabricate `metadata.user_feedback` content. If the user hasn't typed it, it doesn't exist.
* ❌ Re-present the gate in the same turn as the presentation itself "to be sure."

### Anti-Fabrication Rule

The Orchestrator MUST NOT log any of the following events unless they correspond to an actual user message in the immediately preceding turn:

* `initial_review_approved` (Phase 1.5)
* `initial_review_revision_requested` (Phase 1.5)
* `initial_review_rejected` (Phase 1.5)
* `implementation_invoked` (Phase 4.5)
* `implementation_skipped` (Phase 4.5 — only on explicit `done` / `RFC only` / etc.)
* `revision_requested` (Phase 4.5)
* `task_approved` (Phase 5 per-task gate — NEW in 1.4)

If you find yourself about to log one of these and the previous turn was your own (the Orchestrator's), STOP. You are about to fabricate a user decision. Re-present the gate and end your turn.

### Defensive backstop

Even if the Orchestrator fails to honor this rule, the subagents in Phases 2, 3, 4, and 5 are required to perform a precondition check (see each phase below) and will refuse to run if the appropriate user-approval event is missing from `debug.json`. This is a safety net, not a substitute.

---

## Anti-Hallucination Rules (all phases — NEW in 1.4)

* Every design claim in `PLAN.md` / `PLAN_FINAL.md` must trace to `prd_snapshot.md` (using the PRD's own labels) or to a cited source.
* Unknowns go to Open Questions as `TBD:` entries — never invented.
* No fabricated metrics, SLAs, API names, CVEs, or org standards. Org standards must be named with a source or explicitly marked `assumption`.
* Reviewers must cite the section of the document each finding responds to.

---

## Agent Dispatch Table

> Dispatch by `name` (`subagent_type`), not by filename. The `name` column is the identifier the Orchestrator passes to `Task`.

| Phase | Subagent file | Subagent `name` / Role name (`debug.json` `agent` field) | Runs |
|---|---|---|---|
| 0 (opt-in) | *no subagent — Orchestrator interviews in the main session (loads the `grilling` skill)* | `Orchestrator` | ONLY when the cycle-start message contains `--grill`; never by default |
| 1 | `tech-architect.md` | `tech-architect` / `Tech Architect` | once per cycle, plus on Phase 1.5 revision request, plus on REJECTED restart / architectural cycle-back |
| 1.5 | *no subagent — Orchestrator presents, then ENDS TURN* | `Orchestrator` | after every Phase 1 completion; loops until user approves or rejects |
| 2a | `hoe.md` | `hoe` / `Head of Engineering` | once per cycle (re-runs on architectural cycle-back) |
| 2b | `qa-gatekeeper.md` | `qa-gatekeeper` / `QA Gatekeeper` | once per cycle (re-runs on architectural cycle-back) |
| 3 | `merger.md` | `merger` / `Merger` | once per cycle, plus on every Phase 4 cycle-back |
| 4 | `infosec.md` | `infosec` / `Infosec Reviewer` | once per consolidation; repeats up to retry budget |
| 4.5 | *no subagent — Orchestrator presents, then ENDS TURN* | `Orchestrator` | once per APPROVED cycle |
| 5 | `implementor.md` | `implementor` / `Implementor` | only if explicitly invoked at Phase 4.5 |

---

## RFC Artifacts (Two-File Model)

### `docs/rfcs/{project-name}/PLAN.md` — the Original Draft

* **Created by:** Tech Architect (Phase 1)
* **Modified by:** Tech Architect only (Phase 1 first run, Phase 1.5 Revision Mode, or architectural cycle-back from Phase 4)
* **Read by:** Phase 1.5 (user reviews via Orchestrator), Phase 2 (HoE + QA), Phase 3 (Merger ingests as input)
* **Read-only after Phase 2 starts.** No agent overwrites `PLAN.md` once HoE/QA begin reviewing it.
* **Status lifecycle:** `DRAFT` → `AWAITING_USER_REVIEW` → `UNDER_REVIEW` → frozen
* **Rejected path:** if user rejects at Phase 1.5, status → `REJECTED_BY_USER`; cycle ends.

### `docs/rfcs/{project-name}/PLAN_FINAL.md` — the Consolidated RFC

* **Created by:** Merger (Phase 3)
* **Modified by:** Merger only (Phase 3 first run; cycle-back via localized fix)
* **Read by:** Phase 4 (Infosec), Phase 4.5 (Orchestrator hand-off), Phase 5 (Implementor)
* **Status lifecycle:** `CONSOLIDATED_PENDING_SECURITY` → `APPROVED` / `SECURITY_CHANGES_REQUIRED` / `SECURITY_REJECTED` → `IN_IMPLEMENTATION` → `IMPLEMENTED`
* **Closed-RFC path:** if user closes at Phase 4.5 without invoking implementation, status → `CLOSED_RFC_ONLY`.

### Cycle-Back File Behavior (No Archive)

| Event | What happens to PLAN.md | What happens to PLAN_FINAL.md |
|---|---|---|
| Phase 1.5 user requests `change` | Tech Architect modifies in place (revision_iteration++) | Doesn't exist yet; nothing |
| Phase 4 returns CHANGES_REQUIRED (localized) | Untouched | Merger modifies in place to address Infosec findings |
| Phase 4 returns CHANGES_REQUIRED (architectural) | Tech Architect overwrites with new draft (Phase 1 re-runs) | Merger overwrites when Phase 3 re-runs |
| Phase 4 returns REJECTED | Tech Architect overwrites with new draft (Phase 1 full restart) | Merger overwrites or creates fresh |
| User reviews and finds issue with `PLAN_FINAL.md` at Phase 4.5 ("revise") | Untouched | Re-dispatch Merger; modifies in place |

### `docs/rfcs/{project-name}/grilling_notes.md` — Phase 0 decisions (only when `--grill` was used)

* **Created by:** Orchestrator (Phase 0)
* **Modified by:** no one after Phase 1 dispatch — frozen user input
* **Read by:** Tech Architect (Phase 1 — decisions are settled, cited as `[GRILL-n]`); reviewers may cite it
* Absent in a normal (non-`--grill`) cycle; its absence is not a validation failure.

> History via git: every commit captures the file state. No `_archived.md` filesystem clutter.

---

## Default Deliverable & Optional Implementation

The default end state is a **security-approved `PLAN_FINAL.md`**. Phase 5 is opt-in and runs only on explicit user invocation at Phase 4.5.

### Phase 5 Invocation Triggers (explicit only)

* Direct: `implement`, `execute`, `build the code`, `start coding`, `code it up`, `run implementor`
* Task-specific: `implement T1`, `execute task 2`, `start with the auth module`
* RFC-then-code: `produce the RFC and then implement it`, `do the full cycle including code`

### NOT triggers

* Silence after Phase 4.5
* "Looks good", "thanks", any acknowledgement without an implementation verb
* The Orchestrator's own reasoning that "the user probably wants implementation"

### Stop phrases

* `RFC only`, `don't implement`, `stop here`, `we're done`

> Ambiguous → ask, don't proceed.

---

## Retry / Iteration Budget

| Loop | Limit | Action when exceeded |
|---|---|---|
| Phase 1.5 revision loop | 5 revisions of v1 PLAN.md | Orchestrator escalates: accept-as-is or restart |
| Phase 2 review-rejection cycle (either reviewer REJECTED) | 2 cycles | Halt and present options to the user |
| Phase 4 cycle-back (CHANGES_REQUIRED) | 3 iterations | `escalation_requested`; user options |
| Phase 1 REJECTED restart | 2 restarts | After 2nd, escalate |
| Tech Architect MCP fetch | 2 retries per source | Ask user for alternative |
| User no-response at any human gate | No timeout | Wait. Silence is wait, not assume. |

---

## Status Header (MANDATORY for both PLAN.md and PLAN_FINAL.md)

The machine state is the same set of `key: value` lines in both files. **The only difference is the wrapper**, and validation/edits operate on the `status:` line regardless of wrapper:

* **`PLAN.md` (internal draft)** uses a YAML frontmatter block (`--- … ---`). It is never shown to stakeholders, so the visible header is fine.
* **`PLAN_FINAL.md` (reader-facing RFC)** hides the same fields in an **HTML comment** (`<!-- RFC-META … -->`) so `trace_id`/`status` never render for stakeholders, followed by a visible human-readable metadata table (Status / Owner / Submitted Date / Approver / Related Documents). See `merger.md` §4 "Header".

Both carry these fields:

```markdown
project: {project-name}
trace_id: {uuid}
scenario_version: 1.5
plan_version: v{n}
status: {STATUS}
last_updated: {ISO 8601}
last_updated_by: {Role name}
```

> Reading/writing status is unchanged: agents `Read` the file, find the `status:` line, and `Edit` it in place — whether it sits inside `--- … ---` (PLAN.md) or `<!-- RFC-META … -->` (PLAN_FINAL.md).

### Status Values & Owners

| Status | File | Set by | When |
|---|---|---|---|
| `DRAFT` | PLAN.md | Tech Architect | While writing v1 |
| `AWAITING_USER_REVIEW` | PLAN.md | Tech Architect | End of Phase 1 / Revision Mode |
| `UNDER_REVIEW` | PLAN.md | Orchestrator | Phase 1.5 user approval — ONLY after actual user `approve` message |
| `REJECTED_BY_USER` | PLAN.md | Orchestrator | Phase 1.5 user rejection; cycle ends |
| `CONSOLIDATED_PENDING_SECURITY` | PLAN_FINAL.md | Merger | End of Phase 3 |
| `SECURITY_CHANGES_REQUIRED` | PLAN_FINAL.md | Infosec Reviewer | End of Phase 4 if CHANGES_REQUIRED |
| `SECURITY_REJECTED` | PLAN_FINAL.md | Infosec Reviewer | End of Phase 4 if REJECTED |
| `APPROVED` | PLAN_FINAL.md | Infosec Reviewer | End of Phase 4 if APPROVED |
| `IN_IMPLEMENTATION` | PLAN_FINAL.md | Implementor | Start of Phase 5 |
| `IMPLEMENTED` | PLAN_FINAL.md | Implementor | All Phase 5 tasks meet DoD |
| `CLOSED_RFC_ONLY` | PLAN_FINAL.md | Orchestrator | End of Phase 4.5 if no implementation |
| `ESCALATED_TO_USER` | both | Orchestrator | When budget exceeded |

> Note: PLAN.md status freezes at `UNDER_REVIEW` once Phase 2 starts. From Phase 3 onwards, the "active" status header is on `PLAN_FINAL.md`.

### Inter-Phase Validation: which file's status applies?

| Just-completed phase | File whose status header should be checked |
|---|---|
| 1 | PLAN.md (expects `AWAITING_USER_REVIEW`) |
| 1.5 (approved) | PLAN.md (expects `UNDER_REVIEW`) |
| 1.5 (rejected) | PLAN.md (expects `REJECTED_BY_USER`); cycle ends |
| 2 | PLAN.md (still `UNDER_REVIEW`); review files exist |
| 3 | PLAN_FINAL.md (expects `CONSOLIDATED_PENDING_SECURITY`) |
| 4 | PLAN_FINAL.md (expects one of `APPROVED` / `SECURITY_CHANGES_REQUIRED` / `SECURITY_REJECTED`) |
| 4.5 | PLAN_FINAL.md (expects `APPROVED` going in; `CLOSED_RFC_ONLY` or unchanged on exit) |
| 5 | PLAN_FINAL.md (expects `IN_IMPLEMENTATION` mid-phase, `IMPLEMENTED` on completion) |

---

## Inter-Phase Validation Checklist (Orchestrator)

Run after every subagent phase, before next dispatch.

| Check | What to verify |
|---|---|
| Role match *(single-agent phases: 1, 3, 4, 5)* | Latest `debug.json` event has `agent` = dispatched role name (exact match). *Not applicable after Phase 2 — two agents ran in parallel; use the "Phase 2 reviewer events" check instead.* |
| Phase match | Latest event has `phase` = just-completed phase number |
| Phase completion | Latest action is `phase_completed` (or a halt verb) |
| **Phase 2 reviewer events (v1.4 — replaces Role/Phase/Completion checks after Phase 2)** | Both `hoe_events.json` and `qa_events.json` exist and each contains `precondition_check_passed` and `phase_completed`. The Orchestrator (sole `debug.json` writer in Phase 2) then folds both event files into `debug.json` in timestamp order and deletes the side files (or marks them as merged). |
| Status header | The relevant file's status (per table above) reflects expected post-phase value |
| Required outputs | All declared output files exist and are non-empty |
| **No script artifacts** | `/tmp/` and the working directory contain no `.py`, `.sh`, or other script files written by the agent during the phase |
| Untrusted writes | No agent wrote to a file it doesn't own |
| **Gate approval present (for post-gate phases)** | Before Phase 2 dispatch: `initial_review_approved` event exists. Before Phase 5 dispatch: `implementation_invoked` event exists with a real user message in the preceding turn. |

Failure → log `validation_error`, halt, report.

---

## Resumability Protocol

Latest event in `debug.json` is the resume pointer. `phase_completed` → dispatch next; `phase_blocked` / `phase_failed` → user intervention; mid-phase or mid-gate → re-present and wait. **Always reuse `trace_id`.**

### `status` Command (NEW in 1.4)

At any gate — and as a response to any user message while the cycle is paused — a user message of `status` means: the Orchestrator reports the current phase, the active file's RFC status header value, and the last `debug.json` event, then **re-presents the pending gate** and ends its turn. `status` is NEVER a routing/approval signal and is NOT logged as a decision event.

---

## Debug & Logging Contract

### File Lifecycle

* **Creation:** Phase 1 (Tech Architect) initializes `docs/debug.json`, recording `scenario_version`.
* **`trace_id`:** UUID v4 from Phase 1.
* **Ownership:** Append-only. (No append primitive exists — `Read` the file, push the new event onto `events`, `Write` the whole file back, keeping it valid JSON.)
* **Phase 2 exception (NEW in 1.4):** during Phase 2, the Orchestrator is the SOLE `debug.json` writer. HoE and QA do NOT write `debug.json` — each appends its events to its own file (`docs/rfcs/{project-name}/hoe_events.json` and `docs/rfcs/{project-name}/qa_events.json`, same event schema). After both `Task` calls return, the Orchestrator folds both event files into `debug.json` in timestamp order during Inter-Phase Validation, then deletes the side files (or marks them as merged). This eliminates the concurrent whole-file read-modify-write lost-update race.

### Event Schema

```json
{
  "timestamp": "ISO 8601",
  "agent": "Role name — exact match required",
  "phase": "1 | 1.5 | 2 | 3 | 4 | 4.5 | 5",
  "action": "see verbs below",
  "skills": ["..."],
  "metadata": {
    "scenario_version": "1.5",
    "mcp_called": false,
    "file": "...",
    "sources": ["..."],
    "review_status": "APPROVED | CHANGES_REQUIRED | REJECTED",
    "findings": { "critical": 0, "high": 0, "medium": 0 },
    "cycle_iteration": 1,
    "revision_iteration": 0,
    "plan_version": "v1 | v2 | ...",
    "plan_status_before": "...",
    "plan_status_after": "...",
    "user_feedback": "...",
    "user_message_verbatim": "...",
    "invocation_trigger": "...",
    "task_id": "...",
    "failure_reason": "...",
    "failure_source": "...",
    "notes": "..."
  }
}
```

> **New in 1.3:** `metadata.user_message_verbatim` is REQUIRED on every event that records a user decision (`initial_review_approved`, `initial_review_revision_requested`, `initial_review_rejected`, `implementation_invoked`, `implementation_skipped`, `revision_requested`; v1.4 adds `task_approved`). It contains the user's literal message text. If you cannot fill this field with a real user message, you must not log the event.

### Universal Action Verbs

`phase_blocked`, `phase_failed`, `validation_error`, `tool_call_failed`, `escalation_requested`

### Phase-Specific Action Verbs

| Phase | Allowed actions |
|---|---|
| 1 (Normal) | `cycle_initialized`, `prd_fetched`, `prd_snapshot_saved`, `grilling_notes_ingested` *(only if Phase 0 ran)*, `prd_quality_checked`, `draft_finalized`, `status_updated`, `phase_completed`, `phase_aborted` |
| 1 (Revision) | `revision_request_received`, `revision_plan_presented`, `revision_applied`, `status_updated`, `phase_completed` |
| 1.5 | `initial_review_presented`, `initial_review_approved`, `initial_review_revision_requested`, `initial_review_rejected`, `status_updated` |
| 2 | `precondition_check_passed`, `review_started`, `test_cases_created` *(QA only)*, `plan_validated` *(QA only)*, `review_completed` *(carries `metadata.review_status`)*, `phase_completed` — **written to the reviewer's own event file (`hoe_events.json` / `qa_events.json`), never to `debug.json`** |
| 3 | `precondition_check_passed`, `consolidation_started`, `conflict_resolution_applied`, `status_updated`, `consolidation_completed`, `phase_completed` |
| 4 | `precondition_check_passed`, `security_review_started`, `security_review_completed`, `status_updated`, `phase_completed` |
| 4.5 | `handoff_presented`, `implementation_invoked`, `implementation_skipped`, `revision_requested`, `escalation_requested` |
| 5 (Orchestrator only) | `task_proposed`, `task_approved` |
| 5 (Implementor) | `precondition_check_passed`, `implementation_started`, `task_started`, `task_completed`, `cycle_paused`, `status_updated` |

> Note: `precondition_check_passed` is logged by each post-gate subagent (HoE, QA, Merger, Infosec, Implementor) as their first event after verifying the upstream gate's approval event exists. In Phase 2 (v1.4), HoE and QA log it to their own event files, not to `debug.json`.
> `task_proposed` / `task_approved` are logged by the **Orchestrator only** (Phase 5 gates). The Implementor logs `task_started` / `task_completed` directly to `debug.json` — it is the sole agent in Phase 5, so there is no write race.

### Self-Identification Rule

Every event MUST set `agent` to the exact role name. Inter-Phase Validation catches violations.

---

## Project Naming

Established at start of Phase 1: explicit user input → PRD-derived → prompted. Fixed for cycle lifetime. *(If Phase 0 runs, the name is established at the start of Phase 0 instead, using the same precedence, and carries into Phase 1.)*

---

## Phase 0: Requirements Grilling (opt-in — `--grill` flag only)

**Subagent:** *none — Orchestrator (main session)* | **Role:** `Orchestrator`
**Goal:** Resolve the PRD's decision tree with the user BEFORE the Tech Architect burns a drafting cycle on an under-specified PRD.

### Trigger (strict)

* Runs **only** when the user's cycle-start message contains the literal flag `--grill` (or an unambiguous natural-language equivalent such as `grill me first`).
* **No flag → no Phase 0.** The Orchestrator dispatches Phase 1 directly, exactly as in v1.4. The Orchestrator MUST NOT infer that a vague PRD "deserves" grilling — absence of the flag is a routing decision, not a quality judgment.

### Why the Orchestrator, not a subagent

Grilling is inherently multi-turn interactive (one question per user turn). Subagents have no user turns — a dispatched subagent runs to completion and returns. Therefore Phase 0 runs in the main session, under the same turn-boundary discipline as the human gates.

### Steps

1. Establish the project name and create the RFC directory (`docs/rfcs/{project-name}/`).
2. Load the `grilling` skill (`Read` `~/.claude/skills/grilling/SKILL.md` — skill loading is explicit).
3. If a PRD source was provided, fetch/read it first so questions are grounded in the actual document. Look up any *fact* answerable from the environment (repo, Confluence, Figma) yourself; only *decisions* go to the user.
4. Interview per the grilling protocol: **exactly one question per turn, with a recommended answer, then END THE TURN.** The same anti-fabrication discipline as the human gates applies — a user answer exists only if the user typed it.
5. On exit (decision tree resolved, or user says `enough` / `stop grilling` / `proceed`), write `docs/rfcs/{project-name}/grilling_notes.md` in the `GRILL-n` format defined by the grilling skill.
6. In the turn that receives the user's final answer/exit message, proceed to dispatch Phase 1, passing the absolute path of `grilling_notes.md` as an additional Input alongside the PRD source.

### Output

* `docs/rfcs/{project-name}/grilling_notes.md`

### Logging note

`debug.json` does not exist until Phase 1 initializes it, so Phase 0 logs no events. The audit artifact for Phase 0 is `grilling_notes.md` itself; the Tech Architect logs `grilling_notes_ingested` (Phase 1) as the bridge into the event stream.

### Budget

Max 15 questions. On hitting the budget, the Orchestrator writes the notes with `status: STOPPED_EARLY`, lists remaining branches under `Unresolved`, and proceeds — unresolved branches become `TBD:` Open Questions in the draft, same as today.

---

## Phase 1: Initiation

**Subagent:** `tech-architect` | **Role:** `Tech Architect`
**Goal:** Produce the first RFC draft.

### Steps (Normal Mode)

1. Initialize cycle artifacts (project name, RFC directory, `debug.json`).
2. Fetch PRD (retry budget: 2 per source).
3. Save `prd_snapshot.md`. Log `prd_snapshot_saved`.
3b. **Grilling notes ingestion (NEW in 1.5, only when the dispatch prompt provides a `grilling_notes.md` path):** `Read` the notes and log `grilling_notes_ingested`. Every `GRILL-n` decision is **settled user input** — treat it with the same authority as the PRD itself, and cite it in the draft as `[GRILL-n]`.
4. **PRD Quality Check (NEW in 1.4):** before designing, scan the PRD for contradictions, missing acceptance criteria, and vague requirements. Critical ambiguities become clarifying questions listed at the top of the Phase 1.5 hand-back (and `TBD:` entries in the draft's Open Questions) so the user resolves them at the gate. No new gate — this rides the existing Phase 1.5 presentation. **(1.5)** Ambiguities already resolved by a `GRILL-n` decision are NOT re-raised as clarifying questions — cite the decision instead.
5. Design architecture.
6. Map every PRD requirement.
7. Draft RFC and save to `PLAN.md` with `status: DRAFT`. *(No internal approval gate — subagents have no user turns. The architect completes the draft and hands back; the ONLY Phase-1 review is the Orchestrator-owned Phase 1.5 gate.)*
8. Update status to `AWAITING_USER_REVIEW`.

### Steps (Revision Mode — re-dispatched from Phase 1.5)

R1. Read user feedback from `metadata.user_feedback` of latest Orchestrator event.
R2. Map feedback to specific PLAN.md sections.
R3. Compose a revision plan — it goes into the hand-back message, NOT an internal gate (subagents cannot wait for user input).
R4. Apply changes to PLAN.md in place. Status stays `AWAITING_USER_REVIEW`. Increment `revision_iteration`.

### Output

* `PLAN.md` (status `AWAITING_USER_REVIEW`)
* `prd_snapshot.md`
* Initialized `debug.json`

### Hand-back

Tech Architect logs `phase_completed` and stops. The hand-back message lists any PRD Quality Check clarifying questions at the top (in Revision Mode, it carries the revision plan). Orchestrator validates, surfaces the clarifying questions in the Phase 1.5 presentation, then presents Phase 1.5 **and ends its turn**.

---

## Phase 1.5: Initial Review Gate

**Subagent:** *Orchestrator (main session)* | **Role:** `Orchestrator`

### Pre-conditions

* `PLAN.md` status: `AWAITING_USER_REVIEW`
* Latest Phase 1 event: `Tech Architect` `phase_completed`

### Steps

1. Verify Tech Architect's `phase_completed` event and `PLAN.md` status `AWAITING_USER_REVIEW`. If not, log `validation_error` and halt.

2. Log `initial_review_presented` to `debug.json` with current `revision_iteration`.

3. Output this prompt block as your FINAL message in this turn:

```
Phase 1 (Tech Architect) is complete.

  RFC:           docs/rfcs/{project-name}/PLAN.md (v1)
  PRD snapshot:  docs/rfcs/{project-name}/prd_snapshot.md
  Status:        AWAITING_USER_REVIEW
  Revision iter: {revision_iteration}/5

Please review the RFC before parallel review (HoE + QA) begins.

Your options:
  • approve                 → proceed to Phase 2
  • change: <your feedback> → re-invoke Tech Architect to revise PLAN.md
  • reject                  → abort the cycle

Waiting for your response.
```

4. **🛑 END TURN.** Do not call any tool. Do not output any further text. Do not dispatch Phase 2. The prompt block above is your turn's final output.

5. **(Next turn — only after the user responds)** Parse the user's literal message. Route as follows:

| User message contains | Route | Action | `metadata.user_message_verbatim` |
|---|---|---|---|
| `approve`, `looks good`, `lgtm`, `proceed`, `go ahead` | Phase 2 | Log `initial_review_approved`. Update `PLAN.md` status: `AWAITING_USER_REVIEW` → `UNDER_REVIEW`. Dispatch HoE and QA in parallel (two `Task` calls, one turn). | user's literal message |
| `change:`, `revise:`, `update:`, or feedback after a change verb | Tech Architect Revision Mode | Log `initial_review_revision_requested` with `metadata.user_feedback` set to text after `change:`. Re-dispatch Tech Architect. | user's literal message |
| `reject`, `abort`, `cancel`, `stop the cycle` | Cycle ends | Log `initial_review_rejected`. Update `PLAN.md` status: `AWAITING_USER_REVIEW` → `REJECTED_BY_USER`. | user's literal message |
| `status` | Stay at gate | Report current phase, RFC status header value, last `debug.json` event; re-present this gate and end turn. NOT a routing signal; NOT logged as a decision event. | n/a |
| Anything else (ambiguous) | Ask once | Output a clarification request and end turn again. Do NOT default to approve. | n/a |

### Forbidden behaviors

* ❌ Dispatching HoE / QA in the same turn as the gate presentation
* ❌ Logging `initial_review_approved` without an actual user message containing an approval phrase
* ❌ Treating "the user hasn't objected" as approval
* ❌ Fabricating `metadata.user_feedback` content
* ❌ Skipping to Phase 2 because the RFC "looks fine"

---

## Phase 2: Parallel Review

**Subagents:** `hoe` (Head of Engineering) + `qa-gatekeeper` (QA Gatekeeper), dispatched in parallel.

### Event Logging (NEW in 1.4 — no debug.json writes by reviewers)

During Phase 2, HoE and QA do **NOT** write `debug.json` (two concurrent whole-file read-modify-write writers = lost updates). Instead:

* HoE appends every event to `docs/rfcs/{project-name}/hoe_events.json` (same event schema as `debug.json`).
* QA appends every event to `docs/rfcs/{project-name}/qa_events.json` (same event schema).
* Reviewers READ `debug.json` (for the precondition check) but never write it.
* After both `Task` calls return, the **Orchestrator** — the sole `debug.json` writer in Phase 2 — folds both event files into `debug.json` in timestamp order during Inter-Phase Validation, then deletes the side files (or marks them as merged).

### MANDATORY Precondition Check (both subagents, first action)

Before reading `PLAN.md` or starting any review:

1. Read `docs/debug.json`.
2. Verify the most recent Orchestrator event has `action: "initial_review_approved"` AND `metadata.user_message_verbatim` is non-empty AND contains an approval phrase (`approve`, `looks good`, `lgtm`, `proceed`, or `go ahead`).
3. Verify `PLAN.md` status header reads `UNDER_REVIEW` (not `AWAITING_USER_REVIEW`).

If either check fails:

* Log `phase_blocked` (to the reviewer's OWN event file) with `metadata.failure_reason: "Phase 1.5 approval event missing or invalid. Cannot start Phase 2 without explicit user approval."`
* Output: `BLOCKED: Phase 1.5 approval not found in debug.json. The Orchestrator must present the Initial Review Gate to the user and receive explicit approval before Phase 2 can begin.`
* STOP. Do not proceed.

If both checks pass: log `precondition_check_passed` (to the reviewer's OWN event file) and proceed with review.

### Input

* `PLAN.md` (status `UNDER_REVIEW`)
* `prd_snapshot.md` (required by QA)

### Output

* `hoe_review.md`, `test_cases.md`, `qa_review.md`
* Each review file — and each reviewer's hand-back message — carries a verdict: `review_status: APPROVED | CHANGES_REQUIRED | REJECTED`
* `hoe_events.json`, `qa_events.json` (folded into `debug.json` by the Orchestrator, then deleted/marked merged)

### Hand-back & Verdict Routing (NEW in 1.4)

Both agents log `phase_completed` (with `metadata.review_status`) to their own event file and stop. After both `Task` calls return, the Orchestrator:

1. Folds `hoe_events.json` and `qa_events.json` into `debug.json` in timestamp order, then deletes the side files (or marks them as merged).
2. Runs Inter-Phase Validation: both reviewer event files existed and each contained `precondition_check_passed` and `phase_completed`.
3. Routes on the two verdicts:

| Verdicts | Route |
|---|---|
| Both `APPROVED` or `CHANGES_REQUIRED` | Phase 3 as today — the Merger addresses the findings |
| Either reviewer `REJECTED` (fatal architectural flaw) | Tech Architect Revision Mode, with BOTH review files passed as feedback. Budget: **2 review-rejection cycles**; after the 2nd, halt and present to the user. |

---

## Phase 3: Synthesis (creates PLAN_FINAL.md)

**Subagent:** `merger` | **Role:** `Merger`
**Goal:** Reconcile draft + reviews into the consolidated RFC at `PLAN_FINAL.md`.

### MANDATORY Precondition Check

Before any consolidation work:

1. Read `docs/debug.json`.
2. Verify `initial_review_approved` event exists with valid `metadata.user_message_verbatim`.
3. Verify both `hoe_review.md` and `qa_review.md` exist and the folded reviewer events in `debug.json` include `phase_completed` from both reviewers.
4. Verify `PLAN.md` status is `UNDER_REVIEW` (first run) or `PLAN_FINAL.md` status is `SECURITY_CHANGES_REQUIRED` (cycle-back).

If any check fails: log `phase_blocked` with the specific reason and STOP. Otherwise: log `precondition_check_passed` and proceed.

### Input

* `PLAN.md` (current draft, status `UNDER_REVIEW`) — read-only
* `hoe_review.md`, `qa_review.md`, `test_cases.md`, `prd_snapshot.md` — read-only

### Steps

1. Verify all input files present.
2. Ingest all inputs.
3. Resolve cross-reviewer conflicts via the tie-breaker skill — `Read` `~/.claude/skills/tie-breaker/SKILL.md` and apply R1/R2/R3/R4.
4. Compose consolidated RFC content addressing all QA Coverage Matrix gaps and HoE findings. The HoE effort estimate lands in the `### Cost Estimation` subsection of `PLAN_FINAL.md`.
5. **Write `PLAN_FINAL.md`** — single `Write` (or `Edit` on cycle-back) operation. `status: CONSOLIDATED_PENDING_SECURITY` set in the hidden machine-state block. This is the reader-facing RFC: it follows the **Mekari 7-section format** defined in `merger.md` §4 (Overview / Technical Design / High-Availability & Security / Backwards Compatibility and Rollout Plan / Concern, Questions, or Known Limitations / Tasks / Comment logs), led by a hidden `<!-- RFC-META -->` block and a visible metadata table. **Do NOT append a "Reviewer Findings Consolidated" section or a "Feedback Resolution Table" to the RFC** — those are process artifacts and make the RFC unreadable for stakeholders.
6. **Write `merge_report.md`** — the audit trail. The Reviewer Findings Consolidated table, the Feedback Resolution Table, and tie-breaker citations live HERE, not in the RFC. (See `merger.md` Step 5.)
7. Hand back.

### What is explicitly NOT done

* ❌ No archive of `PLAN.md` (it's preserved as-is)
* ❌ No copy/rename operations
* ❌ No Python/bash scripts
* ❌ No modification of `PLAN.md` (read-only from Phase 3 onwards)
* ❌ No "Reviewer Findings Consolidated" section or "Feedback Resolution Table" inside `PLAN_FINAL.md` — those go in `merge_report.md`

### Output

* `PLAN_FINAL.md` (the clean reader-facing RFC — the Mekari 7-section format per Step 5, status `CONSOLIDATED_PENDING_SECURITY`)
* `merge_report.md` (the process audit trail — findings tables, feedback resolution, tie-breaker citations)

### Hand-back

Merger logs `phase_completed`. Orchestrator validates, dispatches Phase 4.

---

## Phase 4: Security Gate

**Subagent:** `infosec` | **Role:** `Infosec Reviewer`

### MANDATORY Precondition Check

Before reviewing:

1. Read `docs/debug.json`.
2. Verify `initial_review_approved` event exists with valid `metadata.user_message_verbatim`.
3. Verify Merger logged `phase_completed` and its `metadata` notes consolidation complete, and `PLAN_FINAL.md` exists with status `CONSOLIDATED_PENDING_SECURITY`.

If any check fails: log `phase_blocked` and STOP. Otherwise: log `precondition_check_passed` and proceed.

### Input

* `PLAN_FINAL.md` (status must be `CONSOLIDATED_PENDING_SECURITY`)

### Decision & MANDATORY Status Update

| Decision | New PLAN_FINAL.md status | Next |
|---|---|---|
| APPROVED | `APPROVED` | Phase 4.5 |
| CHANGES_REQUIRED | `SECURITY_CHANGES_REQUIRED` | Cycle back |
| REJECTED | `SECURITY_REJECTED` | Phase 1 restart |

### Re-entry Rules

| Severity | Re-entry Point | Effect on files |
|---|---|---|
| Architectural change | Phase 1 (Tech Architect → 2 → 3 → 4) | `PLAN.md` overwritten by Tech Architect; `PLAN_FINAL.md` overwritten by Merger after Phase 3 re-runs |
| Localized fix | Phase 3 (Merger directly patches `PLAN_FINAL.md`) | `PLAN.md` untouched; `PLAN_FINAL.md` modified in place |
| REJECTED | Phase 1 full restart | Both files overwritten; `trace_id` reused |
| Phase 2 reviewer REJECTED (fatal architectural flaw — NEW in 1.4) | Tech Architect Revision Mode (→ 2 → 3 → 4), with both review files as feedback | `PLAN.md` revised in place; `PLAN_FINAL.md` untouched (does not exist yet on first pass). Budget: 2 review-rejection cycles, then halt and present to the user |

Budget exceeded → escalation.

### Output

* `infosec_review.md`
* `PLAN_FINAL.md` status header updated

---

## Phase 4.5: Hand-off (Implementation Invocation Gate)

**Subagent:** *Orchestrator (main session)* | **Role:** `Orchestrator`

### Pre-conditions

* `PLAN_FINAL.md` status: `APPROVED`
* Latest Phase 4 event: `Infosec Reviewer` with `review_status: "APPROVED"`

### Steps

1. Verify pre-conditions. If not met, log `validation_error` and halt.

2. Log `handoff_presented` to `debug.json`.

3. Output this hand-off prompt as your FINAL message in this turn:

```
Phase 4 (Infosec) is complete. The RFC is security-approved.

  RFC:            docs/rfcs/{project-name}/PLAN_FINAL.md
  Status:         APPROVED
  Infosec review: docs/rfcs/{project-name}/infosec_review.md

Your options:
  • implement / execute / build the code → start Phase 5 (Implementor)
  • implement T<n>                       → start Phase 5 with a specific task
  • revise: <feedback>                   → re-dispatch Merger to update PLAN_FINAL.md
  • done / RFC only / we're done         → close cycle (CLOSED_RFC_ONLY)

Waiting for your response.
```

4. **🛑 END TURN.** Do not dispatch Implementor. Do not call any tool. The prompt block above is your turn's final output.

5. **(Next turn — only after the user responds)** Parse the user's literal message. Route as follows:

| User message contains | Route | Action | `metadata.user_message_verbatim` |
|---|---|---|---|
| `implement`, `execute`, `build the code`, `start coding`, `run implementor`, or `implement T<n>` | Phase 5 | Log `implementation_invoked`. Dispatch Implementor. | user's literal message |
| `revise:`, `change:`, or feedback after a revise verb | Phase 3 (Merger) | Log `revision_requested`. Re-dispatch Merger. | user's literal message |
| `done`, `RFC only`, `stop here`, `we're done` | Cycle ends | Log `implementation_skipped`. Update `PLAN_FINAL.md` status to `CLOSED_RFC_ONLY`. | user's literal message |
| `status` | Stay at gate | Report current phase, RFC status header value, last `debug.json` event; re-present this gate and end turn. NOT a routing signal; NOT logged as a decision event. | n/a |
| Anything else (ambiguous — including bare acknowledgements like `thanks` with no implementation or close verb) | Ask once | Output a clarification request and end turn. Do NOT default to implement. Closing the cycle requires an explicit phrase (`done`, `RFC only`, `stop here`, `we're done`). | n/a |

### Forbidden behaviors

* ❌ Dispatching Implementor in the same turn as the hand-off presentation
* ❌ Logging `implementation_invoked` without a real user message containing an invocation verb
* ❌ Treating "looks good" or "thanks" as implementation approval
* ❌ Defaulting to implement on silence — silence is `CLOSED_RFC_ONLY` only after a follow-up confirmation

---

## Phase 5: Implementation — *opt-in*

**Subagent:** `implementor` | **Role:** `Implementor`

### MANDATORY Precondition Check

Before any implementation:

1. Read `docs/debug.json`.
2. Verify the most recent Orchestrator event has `action: "implementation_invoked"` AND `metadata.user_message_verbatim` is non-empty AND contains an invocation verb (`implement`, `execute`, `build`, `start coding`, `run implementor`).
3. Verify `PLAN_FINAL.md` status is `APPROVED`.

If any check fails:

* Log `phase_blocked` with `metadata.failure_reason: "Phase 4.5 implementation invocation event missing or invalid."`
* Output: `BLOCKED: Phase 4.5 implementation invocation not found in debug.json. The Orchestrator must present the hand-off and receive an explicit implementation invocation from the user before Phase 5 can begin.`
* STOP.

If checks pass: log `precondition_check_passed` and proceed.

### Inputs

* `PLAN_FINAL.md`, `infosec_review.md`, `test_cases.md`, user invocation phrase

### Per-Task Gate Loop (NEW in 1.4 — the ORCHESTRATOR owns all Phase 5 gates)

The Implementor cannot wait for user decisions — subagents have no user turns. All per-task approvals therefore live in the Orchestrator (main session):

a. **Orchestrator presents the next task** to the user (taken from `PLAN_FINAL.md` §Tasks, or from the Implementor's previous hand-back proposal), logs `task_proposed`, and **🛑 ENDS TURN** per the human-gate turn-boundary mechanics. (`status` command applies at this gate too.)
b. **(Next turn — only after the user responds)** On an approval message, the Orchestrator logs `task_approved` with `metadata.user_message_verbatim` (Anti-Fabrication Rule applies) and dispatches the Implementor for **THAT ONE TASK** only.
c. **Implementor executes the single task**, logs `task_started` / `task_completed` directly to `debug.json` (it is the sole agent in Phase 5 — no write race), reports results, and hands back with the proposed next task.
d. Repeat from (a) until all tasks meet DoD.

`task_proposed` / `task_approved` are logged by the **Orchestrator only**. The Implementor logs `task_started` / `task_completed` (plus its other Phase 5 verbs).

### Status Transitions

1. On its first dispatch, Implementor sets `PLAN_FINAL.md` status to `IN_IMPLEMENTATION`.
2. When all tasks meet DoD: status `IMPLEMENTED`.

> **Phase 5 is the only phase where writing code is allowed.** Even here, Implementor does not write scripts to manipulate `PLAN_FINAL.md` itself.

---

## Flow Summary

```text
                     ┌──────────────┐
   User prompt  ───→ │ Orchestrator │  main session, follows rfc-orchestrator (v1.5)
                     └──────┬───────┘
                            ▼
              ┌── contains `--grill`? ──┐
              │ yes                     │ no (default)
              ▼                         │
  Phase 0: Orchestrator (grilling)      │
             ├─ one question/turn,      │
             │  recommended answer,     │
             │  🛑 END TURN each time   │
             ├─ facts from environment, │
             │  decisions from user     │
             └─ → grilling_notes.md ────┤
                                        ▼

  Phase 1: Task → tech-architect → PLAN.md (v1, status: AWAITING_USER_REVIEW)
                                     (+ ingests grilling_notes.md if Phase 0 ran)
                                     prd_snapshot.md
                                     ↓ [validation]

  Phase 1.5: Orchestrator
             ├─ presents prompt + LOGS initial_review_presented
             └─ 🛑 ENDS TURN
                                     ↓ (user responds in new turn)
              ├── approve ─→ LOG initial_review_approved (with user_message_verbatim)
              │              status: UNDER_REVIEW ─→ dispatch Phase 2
              ├── change: <feedback> ─→ LOG initial_review_revision_requested
              │                         ─→ Tech Architect Revision Mode ─→ loop back
              └── reject ─→ LOG initial_review_rejected
                            status: REJECTED_BY_USER ─→ ❌ END

  Phase 2: Task → hoe + Task → qa-gatekeeper (parallel, one turn)
             ├─ FIRST ACTION: precondition check (initial_review_approved must exist)
             ├─ if missing → phase_blocked, halt
             ├─ events → hoe_events.json / qa_events.json (reviewers NEVER write debug.json)
             └─ if ok → review_started → ... → phase_completed (+ review_status verdict)
                                     ↓ [Orchestrator folds event files into debug.json
                                        in timestamp order, validates, routes on verdicts]
              ├── both APPROVED / CHANGES_REQUIRED ─→ Phase 3
              └── either REJECTED ─→ Tech Architect Revision Mode
                                     (both review files as feedback; budget: 2 cycles)

  Phase 3: Task → merger
             ├─ FIRST ACTION: precondition check
             └─ → PLAN_FINAL.md (status: CONSOLIDATED_PENDING_SECURITY)
                                     ↓ [validation]

  Phase 4: Task → infosec
             ├─ FIRST ACTION: precondition check
             └─ → infosec_review.md, status updated on PLAN_FINAL.md
                                     ↓ [validation + budget check]
              │
              ├── APPROVED ─→ Phase 4.5: Orchestrator
              │                 ├─ presents prompt + LOGS handoff_presented
              │                 └─ 🛑 ENDS TURN
              │                       ↓ (user responds in new turn)
              │                       ├── done/RFC only → LOG implementation_skipped
              │                       │                   CLOSED_RFC_ONLY ✅
              │                       ├── revise: <fb>  → LOG revision_requested
              │                       │                   → Phase 3
              │                       └── implement    → LOG implementation_invoked
              │                                          → Phase 5 (with precond check)
              │
              ├── CHANGES_REQUIRED (architectural) → Phase 1
              ├── CHANGES_REQUIRED (localized)     → Phase 3
              ├── REJECTED                         → Phase 1 full restart
              └── BUDGET EXCEEDED                  → escalation
```

---

## Hard Rules

> 🚫 **No phase skipping.** Phase 1.5 and 4.5 gates cannot be skipped.
> 🔥 **Phase 0 is flag-gated.** Grilling runs ONLY on an explicit `--grill` in the cycle-start message. No flag → straight to Phase 1; the Orchestrator never self-invokes grilling because a PRD "looks vague". During grilling: one question per turn, END TURN, never fabricate answers.
> 🛑 **Human gates END THE TURN.** Presenting Phase 1.5 or 4.5 is the Orchestrator's final action of that turn. Dispatching the next phase in the same turn is a critical violation.
> 🧑‍✈️ **The Orchestrator is the main session, not a subagent.** Human gates and `Task` dispatch both require it.
> 🚷 **No fabricated decisions.** Never log `initial_review_approved`, `implementation_invoked`, or any user-decision event without a real user message containing the routing input in `metadata.user_message_verbatim`.
> 🔒 **Precondition checks are mandatory.** HoE, QA, Merger, Infosec, and Implementor MUST verify the upstream gate's approval event exists before doing any work. If missing → `phase_blocked` and halt.
> 🔄 **CHANGES_REQUIRED / REJECTED** triggers cycle back, subject to retry budget.
> 🛑 **Phase 5 is opt-in.** Runs only on explicit invocation at Phase 4.5.
> 👤 **Phase 1.5 is user-gated.** Runs only on explicit `approve`.
> 📁 **Two-file model.** `PLAN.md` is the original draft (frozen after Phase 2 starts). `PLAN_FINAL.md` is the consolidated output (Phase 3 onwards). No archive files. History via git.
> 🐍 **No scripts in Phases 1–4.** Subagents use direct file tools only. Phase 5 is exempt only for the implementation deliverable.
> 🎯 **Subagent isolation.** One subagent per phase (or two parallel in Phase 2). Subagents stop at hand-back. Orchestrator dispatches. Subagents see only their `Task` prompt + their own agent file.
> 🔍 **Inter-Phase Validation is non-negotiable.**
> 📋 **Status header is law.**
> 🧱 **Context isolation is law.**
> ❓ **When in doubt, ask.**
