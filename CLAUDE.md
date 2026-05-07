# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->

## Agent skills

### Issue tracker

GitHub Issues is the canonical tracker (+ bd/beads synced locally). See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context — `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Build & Test

```bash
bundle exec rspec          # run tests
bin/rubocop --parallel     # lint
bin/brakeman --no-pager -q # security scan
```

**Before opening any PR, always run all three and fix any failures.**

## Architecture Overview

Rails 8.1 monolith + Hotwire (Turbo + Stimulus). No separate frontend or API layer.

- **Vapi** — managed voice platform for outbound calls (Phase 1–2). Configured via `VapiAdapter`.
- **Twilio** — phone numbers imported into Vapi (Vapi's own numbers have a daily outbound limit).
- **OpenAI gpt-4o** — conversation model inside Vapi; gpt-4o-mini for outcome extraction and goal summarization.
- **GoodJob** — Postgres-backed background jobs (no Redis). Dashboard at `/good_job`.
- **PostHog** — product analytics. JS snippet in layout + server-side events from controllers/jobs.
- **Pushover + Twilio SMS** — escalation notifications sent in parallel.
- **Kamal** — deployment.

Webhooks from Vapi arrive at `POST /webhooks/vapi` → `WebhooksController` → `WebhookProcessor`.
The webhook destination (`serverUrl`) is set per-call via `WEBHOOK_BASE_URL` env var or `credentials.vapi.webhook_base_url`.

Key services: `VapiAdapter`, `WebhookProcessor`, `OutcomeExtractor` (via `ExtractOutcomeJob`), `EscalationNotifier`.

See `CONTEXT.md` for domain language and `docs/adr/` for all architectural decisions.

## Conventions & Patterns

- **Linter**: `rubocop-rails-omakase` (strict). Always run `bin/rubocop --parallel -a` before committing — it autocorrects most issues. CI will fail on offenses.
- **Tests**: RSpec + FactoryBot. Run `bundle exec rspec` before every PR.
- **Security**: `bin/brakeman --no-pager -q` before every PR.
- **Commits**: Include `Assisted-by: Claude Sonnet 4.6 via Crush <crush@charm.land>` trailer on AI-assisted commits.
- **PRs**: Always squash-merge via `gh pr merge --auto --squash`. Branch protection requires passing CI.
- **Credentials**: Use `bin/rails credentials:edit`. Never commit `config/master.key`. `credentials.yml.enc` is safe to commit.
- **Gemfile.lock**: Always include `x86_64-linux` platform (`bundle lock --add-platform x86_64-linux`) so CI doesn't fail on GitHub Actions runners.
- **Dev port**: Default is 3100 (set in `bin/dev`).
- **Domain language**: Use terms from `CONTEXT.md` exactly. Never use the avoided synonyms.
