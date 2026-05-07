# Voice Assistant

An AI-powered outbound personal calling assistant. Users delegate annoying life-admin calls to an AI agent that places the call, completes a constrained task, and reports back.

## Language

**CallPlan**:
The user-authored specification for a call: goal, allowed facts to share, questions to ask, allowed decisions, forbidden actions, and fallback behavior. A CallPlan is approved by the user before any call is placed.
_Avoid_: task, request, brief, job

**CallSession**:
A single live execution of a CallPlan — from dial to hangup. Owns the lifecycle state machine, transcript, and outcome. Many CallSessions can reference one CallPlan (e.g. retries).
_Avoid_: call, run, execution

**Outcome**:
The structured result extracted after a CallSession ends: status, summary, important details, follow-up needed, confidence level.
_Avoid_: result, response, summary (summary is a field inside Outcome)

**Escalation**:
The act of pausing a CallSession mid-call (caller placed on hold), notifying the user via push with the blocking question, and waiting for a user reply before resuming. If no reply arrives within the timeout, the agent falls back to the CallPlan's fallback behavior.
_Avoid_: handoff, transfer, fallback (fallback is a field in CallPlan, not an Escalation)

**Delegation**:
The overall user-facing concept — a user delegates a call to the AI. A Delegation produces one CallPlan and one or more CallSessions.
_Avoid_: task, job, assignment

**Disclosure**:
The required opening statement every CallSession must make: the agent identifies itself as AI, names the user (first name minimum), and states the call's purpose. A business may decline after Disclosure; this is recorded as a `completed` CallSession with outcome `declined` — the agent never negotiates.
_Avoid_: introduction, greeting, consent

## Relationships

- A **Delegation** has exactly one **CallPlan**
- A **CallPlan** can produce one or more **CallSessions** (e.g. retry after voicemail)
- A **CallSession** produces exactly one **Outcome**
- An **Escalation** suspends a **CallSession** and notifies the user

## CallSession states

`drafted` → `approved` → `queued` → `dialing` → `connected` → `voicemail` | `in_conversation` → `needs_user` | `completed` | `failed`

## Example dialogue

> **Dev:** "Should we store the transcript on the CallPlan or the CallSession?"
> **Domain expert:** "CallSession — the plan is just the spec, the transcript is what actually happened during execution."

> **Dev:** "If the call goes to voicemail, do we create a new CallSession for the retry?"
> **Domain expert:** "Yes — same CallPlan, new CallSession."

**CallTemplate**:
A product-owned, curated blueprint for a common Delegation type (e.g. "auto repair status check", "prescription refill message"). Defines the default goal, suggested questions, and safe boundaries. Users fill in the blanks; power users can customise further.
_Avoid_: preset, workflow, recipe

## Flagged ambiguities

- "call" was used to mean both the spec and the execution — resolved: **CallPlan** is the spec, **CallSession** is the execution.
- "fallback" appears in the brief as both a CallPlan field and an escalation behavior — resolved: **fallback** is a field on CallPlan (what to say if stuck); **Escalation** is the act of pausing and notifying the user.
