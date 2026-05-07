# OpenAI alloy voice and model selection

## Voice

The Vapi assistant uses `openai/alloy` as the voice. This replaced the original `11labs/rachel` choice.

**Reasons:**
- Simpler credential management — no separate ElevenLabs account or API key required
- Alloy is neutral, professional, and unlikely to be recognised as a celebrity/public voice
- Keeps the dependency footprint smaller in Phase 1

ElevenLabs voices (including custom clones) remain an option for Phase 2+ if voice quality becomes a differentiator.

## Conversation model

The in-call conversation model is `openai/gpt-4o` (configured in `VapiAdapter`).

## Supporting models

`gpt-4o-mini` is used for two offline tasks where cost and latency matter more than reasoning depth:

- **Outcome extraction** (`ExtractOutcomeJob`) — classifies and summarises the call transcript into a structured Outcome
- **Goal summarisation** (`VapiAdapter#summarize_goal`) — paraphrases the user's raw goal into a short natural phrase for the Disclosure opener (e.g. "a vehicle status check"). Falls back to plain-text truncation if OpenAI is unavailable.

## Credentials

`openai_api_key` is stored at the top level of `credentials.yml.enc` and read via `ENV["OPENAI_API_KEY"]` as a fallback.
