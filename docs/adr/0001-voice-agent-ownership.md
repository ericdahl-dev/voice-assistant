# Voice agent conversation ownership: provider-owned with abstraction seam

For Phase 1–2, the voice provider (Vapi, Retell, or equivalent) owns the conversation state machine during a live CallSession. Rails hands off the CallPlan at dial time and receives a webhook when the session ends or needs escalation. This matches how managed platforms work and minimises infrastructure in the early phases.

The `VoiceAgentProvider` abstraction is designed from day one so Rails can take over conversation ownership in Phase 3 — driving the goal state machine itself, using the provider as a pure audio I/O layer. Switching should require replacing the provider adapter, not rearchitecting the call lifecycle.

## Considered options

- **Rails-owned from day one** — more control over escalation and safety rules immediately, but requires building real-time conversation state infrastructure before validating demand.
- **Provider-owned with no abstraction** — fastest, but creates tight coupling that makes Phase 3 a rewrite.
- **Provider-owned with abstraction seam (chosen)** — ships fast, preserves optionality.
