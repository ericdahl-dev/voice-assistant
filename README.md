# Voice Assistant

> **Delegate the calls you keep putting off.**

An AI-powered outbound calling assistant. You describe the call, approve a structured plan, and the AI agent makes the call — navigates IVR, talks to the person, and reports back with a summary. You never pick up the phone.

---

## What it does

- **Check repair status** — "Is my car ready? What's the total?"
- **Leave a refill message** — prescription admin without the hold music
- **Ask about availability** — hours, appointment slots, service status
- **Wait on hold for you** — and escalate to you if something needs a decision

The agent always identifies itself as AI calling on your behalf. It never acts outside the boundaries you set.

---

## How it works

1. **Pick a template** — e.g. "Auto Repair Status Check"
2. **Fill in the details** — shop name, phone, your name, what to ask
3. **Review and approve the CallPlan** — see exactly what it's allowed to say and do
4. **Agent places the call** — discloses it's AI, completes the task
5. **Get the Outcome** — structured summary, important details, transcript

If the call hits something outside your plan (payment request, unexpected decision), the agent puts the caller on hold and notifies you via push + SMS. You reply; the call resumes.

---

## Stack

| Layer | Technology |
|---|---|
| Control plane | Ruby on Rails 8 (monolith) |
| UI | Hotwire (Turbo + Stimulus) |
| Background jobs | GoodJob (Postgres-backed) |
| Voice provider | Vapi (Phase 1–2) |
| Telephony | Twilio |
| Push notifications | Pushover + Twilio SMS |
| Database | PostgreSQL |

---

## Project structure

```
app/
  models/          # Delegation, CallPlan, CallSession, Escalation, CallTemplate
  jobs/            # PlaceCallJob, ExtractOutcomeJob, EscalationTimeoutJob
  services/        # VoiceAgentProvider, VapiAdapter, OutcomeExtractor, EscalationNotifier
  controllers/
    webhooks/      # WebhookProcessor — Vapi event handling
docs/
  adr/             # Architectural decision records
  agents/          # Agent skill configuration (issue tracker, triage labels, domain docs)
CONTEXT.md         # Domain glossary and terminology
```

---

## Core concepts

| Term | Meaning |
|---|---|
| **Delegation** | A user delegating a call to the AI — the top-level container |
| **CallPlan** | The approved spec: goal, allowed facts, forbidden actions, fallback |
| **CallSession** | A single call execution — owns the transcript and Outcome |
| **CallTemplate** | A product-owned blueprint for a common call type |
| **Outcome** | Structured result: status, summary, important details, confidence |
| **Escalation** | Mid-call pause → notify user → wait for reply → resume |
| **Disclosure** | Mandatory opening: AI identity + user's first name + purpose |

See [`CONTEXT.md`](./CONTEXT.md) for the full domain glossary.

---

## Development

> App not yet bootstrapped — see [issue #2](https://github.com/ericdahl-dev/voice-assistant/issues/2) to start.

```bash
# Once the app exists:
bundle install
rails db:setup
bin/dev           # Rails + GoodJob + CSS watcher
rails test
```

---

## Architecture decisions

Key decisions are recorded in [`docs/adr/`](./docs/adr/):

- [ADR-0001](./docs/adr/0001-voice-agent-ownership.md) — Voice agent conversation ownership: provider-owned with abstraction seam
- [ADR-0002](./docs/adr/0002-escalation-async-hold-notify.md) — Escalation: async hold-and-notify, not live transfer
- [ADR-0003](./docs/adr/0003-disclosure-mandatory-declined-is-completed.md) — Disclosure is mandatory; declined = completed
- [ADR-0004](./docs/adr/0004-real-ai-calls-from-day-one.md) — Real AI calls from day one, no fake-door MVP
- [ADR-0005](./docs/adr/0005-vapi-phase-1-voice-provider.md) — Vapi as Phase 1 voice provider
- [ADR-0006](./docs/adr/0006-rails-monolith-hotwire.md) — Rails monolith with Hotwire
- [ADR-0007](./docs/adr/0007-goodjob-background-queue.md) — GoodJob for background queue
- [ADR-0008](./docs/adr/0008-escalation-notifications-pushover-sms.md) — Pushover + SMS simultaneously for escalation

---

## Roadmap

| Phase | Goal |
|---|---|
| **Phase 1** | Rails + Vapi + auto repair CallTemplate + Pushover/SMS escalation |
| **Phase 2** | More CallTemplates, scheduled calls, retry flows, Outcome polish |
| **Phase 3** | Replace Vapi with Pipecat/LiveKit — Rails owns conversation state |

---

## Safety principles

- **Always discloses AI** — no impersonation, ever
- **User-initiated only** — no unsolicited outbound calls
- **Constrained by design** — agent can only act within the approved CallPlan
- **Audit trail** — every call has a transcript and structured Outcome
- **No voice cloning** — the agent does not sound like the user
