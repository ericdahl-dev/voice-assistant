# Voice Assistant

An AI-powered outbound personal calling assistant. Users delegate life-admin phone calls to an AI agent that places the call, completes a constrained task, and reports back — so you never have to sit on hold again.

---

## How It Works

1. **Create a Delegation** — you pick a call type (or start from scratch) and describe who to call.
2. **Author a CallPlan** — specify the goal, what facts the AI may share, what questions to ask, what decisions it can make, and what it must never do.
3. **Approve the CallPlan** — once you approve, the call is placed automatically.
4. **AI places the call** — the agent opens with a mandatory AI disclosure, then works through the goal using GPT-4o with an ElevenLabs voice.
5. **Escalation if needed** — if the agent hits something outside the plan's scope, it puts the caller on hold and sends you a push/SMS notification. You reply; the agent resumes.
6. **Outcome reported** — when the call ends you see a structured result: status, summary, and any follow-up needed.

Live call status updates stream back to the dashboard in real-time via Turbo Streams over Action Cable — no page refresh required.

---

## Domain Concepts

| Term | Definition |
|---|---|
| **Delegation** | The top-level concept: a user delegates a call to the AI. Produces one CallPlan and one or more CallSessions. |
| **CallPlan** | The user-authored specification for a call: goal, allowed facts to share, questions to ask, allowed decisions, forbidden actions, and fallback behavior. Must be approved before any call is placed. |
| **CallSession** | A single live execution of a CallPlan — from dial to hangup. Owns the lifecycle state machine, transcript, and outcome. Many CallSessions can reference one CallPlan (e.g. retries). |
| **Outcome** | The structured result extracted after a CallSession ends: status, summary, important details, follow-up needed, confidence level. |
| **Escalation** | Pausing a CallSession mid-call (caller placed on hold), notifying the user via push + SMS, and waiting for a user reply before resuming. If no reply arrives in time, the agent falls back to the CallPlan's `fallback` behavior. |
| **Disclosure** | The mandatory opening statement every call must make: the agent identifies itself as AI, names the user (first name minimum), and states the call's purpose. A business may decline after Disclosure; this is a `completed` session with outcome `declined` — the agent never negotiates. |
| **CallTemplate** | A curated blueprint for a common Delegation type (e.g. "Auto Repair Status Check"). Defines default goal, questions, and safe boundaries. Users fill in the blanks. |

### CallSession State Machine

```
drafted → queued → dialing → connected → in_conversation → completed
                                        → voicemail              ↑
                                          in_conversation → needs_user ┘
                   ↓ (any non-terminal state can fail)
                 failed
```

Terminal states: `completed`, `failed`, `voicemail`

---

## Tech Stack

| Layer | Technology |
|---|---|
| Web framework | Ruby on Rails 8.1 |
| Language | Ruby 3.4.6 |
| Database | PostgreSQL |
| Frontend | Hotwire (Turbo + Stimulus), Tailwind CSS |
| Real-time UI | Turbo Streams over Action Cable |
| Background jobs | GoodJob (Postgres-backed, includes dashboard at `/good_job`) |
| Authentication | Devise |
| Voice platform | [Vapi](https://vapi.ai) |
| LLM | OpenAI GPT-4o |
| Voice synthesis | OpenAI (`alloy` voice via Vapi) |
| Escalation notifications | Pushover + Twilio SMS (both fire in parallel) |
| Deployment | Coolify / Docker Compose |
| Asset pipeline | Propshaft + import maps |

---

## Prerequisites

- Ruby 3.4.6 (see `.ruby-version`)
- PostgreSQL
- A [Vapi](https://vapi.ai) account with a phone number and API key
- An [OpenAI](https://platform.openai.com) API key (used by Vapi)
- An [ElevenLabs](https://elevenlabs.io) account (used by Vapi for voice synthesis)

---

## Development Setup

### 1. Clone and install dependencies

```bash
git clone https://github.com/ericdahl-dev/voice-assistant.git
cd voice-assistant
bundle install
```

### 2. Configure credentials

Copy the example environment file and fill in your values:

```bash
cp .env.example .env   # if provided, otherwise create .env manually
```

Alternatively, use Rails credentials:

```bash
bin/rails credentials:edit
```

Required credential keys:

```yaml
vapi:
  api_key: your_vapi_api_key
  phone_number_id: your_vapi_phone_number_id
  webhook_secret: your_vapi_webhook_secret

# Or set as environment variables:
# VAPI_API_KEY=...
# VAPI_PHONE_NUMBER_ID=...
```

### 3. Set up the database

```bash
bin/rails db:create db:migrate db:seed
```

Seeding creates:
- One sample CallTemplate ("Auto Repair Status Check")
- A dev user (`dev@example.com` / `password`) in development only

### 4. Start the development server

```bash
bin/dev
```

This starts the Rails server and the Tailwind CSS watcher via Foreman/`Procfile.dev`. Visit [http://localhost:3000](http://localhost:3000).

---

## Running Tests

```bash
bundle exec parallel_rspec spec/
```

For continuous testing during development:

```bash
bundle exec guard
```

For a single targeted run:

```bash
bundle exec rspec spec/path/to/file_spec.rb
```

---

## Architecture Overview

This is a Rails monolith. No separate API or frontend framework.

```
Browser ──Turbo/Stimulus──▶ Rails controllers
                              │
                              ├── Delegations / CallPlans / CallSessions (CRUD)
                              └── WebhooksController ◀── Vapi webhooks
                                        │
                                        └── WebhookProcessor
                                                 │
                                              CallSession
                                           (state transitions,
                                            Turbo broadcast)

PlaceCallJob (GoodJob)
   └── VapiAdapter ──HTTP──▶ Vapi API (places call)
                                   │
                         live call events (webhooks)
                                   ▼
                         WebhooksController → WebhookProcessor
```

Key design decisions (see `docs/adr/` for full context):

- **Provider-owned conversation**: Vapi owns the conversation state machine during a live call. Rails hands off the CallPlan at dial time and receives webhooks when the session ends or needs escalation. A `VoiceAgentProvider` abstraction keeps this swappable.
- **Real AI calls from day one**: No fake-door / human-in-the-loop stub — Phase 1 ships real GPT-4o-powered calls.
- **GoodJob background processing**: GoodJob's built-in dashboard gives visibility into queued/failed jobs without custom tooling.
- **Escalation is async**: The user is never bridged into the live call. The agent puts the caller on hold, notifies the user via Pushover + SMS, and waits for a reply.
- **Disclosure is mandatory**: Every call opens with an AI identity disclosure. This is hardcoded and not configurable.

---

## Vapi Webhook Setup

Vapi sends call lifecycle events to your app. In your Vapi dashboard, configure the webhook URL to point to:

```
POST https://your-app.example.com/webhooks/vapi
```

Supported events: `call.started`, `call.connected`, `call.ended`, `call.declined`, `transcript.chunk`, `escalation.triggered`.

Set `vapi_webhook_secret` in your credentials (or `VAPI_WEBHOOK_SECRET` env var) to enable HMAC signature verification. Signature verification is bypassed in development if the secret is blank.

---

## Deployment

### Coolify (recommended)

Use `docker-compose.yml` at the repo root. Run **two** services from the same image: **web** (Thruster + Rails, port 80) and **worker** (`bundle exec good_job start`). Use an external Postgres URL (e.g. Neon) as `DATABASE_URL`.

```bash
# point Coolify at docker-compose.yml, or run locally:
docker compose up
```

**Required / common environment variables**

| Variable | Purpose |
|----------|---------|
| `RAILS_MASTER_KEY` | Decrypt `credentials.yml.enc` |
| `DATABASE_URL` | Postgres (single DB; includes Solid Cache/Cable tables) |
| `APP_HOST` | Public hostname (Host authorization + mailer URLs), e.g. `app.example.com` |
| `WEBHOOK_BASE_URL` | HTTPS origin for Vapi (`https://app.example.com` — path `/webhooks/vapi` is appended in code) |
| `VAPI_API_KEY`, `VAPI_PHONE_NUMBER_ID` | Vapi |
| `OPENAI_API_KEY` | Outcome extraction + optional goal summarization |
| `PUSHOVER_API_TOKEN`, `PUSHOVER_USER_KEY` | Escalation push |

Optional: `RAILS_ALLOWED_HOSTS` (comma-separated extra hosts, e.g. `www.example.com`), `RAILS_ASSUME_SSL` / `RAILS_FORCE_SSL` (default `true`; set to `false` only if not behind TLS termination), `RAILS_LOG_LEVEL`, `JOB_CONCURRENCY`, `WEB_CONCURRENCY`, `RAILS_MAX_THREADS`.

After first deploy, migrations run via `bin/docker-entrypoint` (`db:prepare` on web boot). Promote an admin user for `/good_job`.

The Docker image uses a multi-stage build. Migrations run automatically via `bin/docker-entrypoint` on web boot (`db:prepare`). Promote an admin user for `/good_job` after first deploy.

---

## Security Tools

```bash
bundle exec brakeman          # static security analysis
bundle exec bundler-audit     # check gems for known CVEs
```

---

## Project Structure

```
app/
  controllers/    # Delegations, CallPlans, CallSessions, Webhooks
  jobs/           # PlaceCallJob, ExtractOutcomeJob, EscalationTimeoutJob
  models/         # Delegation, CallPlan, CallSession, CallTemplate, User
  services/       # VapiAdapter, OutcomeExtractor, WebhookProcessor, VoiceAgentProvider, EscalationNotifier
  views/          # Hotwire/Turbo templates
config/
  routes.rb
docs/
  adr/            # Architecture decision records
db/
  schema.rb
  seeds.rb
spec/             # RSpec tests
```

---

## License

Private — all rights reserved.
