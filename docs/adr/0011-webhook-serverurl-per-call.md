# Webhook delivery: serverUrl per call via WEBHOOK_BASE_URL

## Decision

The Vapi webhook destination (`serverUrl`) is set on the assistant config at call-initiation time, not in the Vapi dashboard. It is driven by `WEBHOOK_BASE_URL` env var (or `credentials.vapi.webhook_base_url`).

## Why per-call, not dashboard-configured

- Allows different environments (production, staging, local ngrok) to receive their own webhooks without changing Vapi dashboard settings.
- Keeps the configuration self-contained in Rails credentials/env — no out-of-band Vapi dashboard state to manage.

## Implementation

`VapiAdapter#webhook_url` constructs the full URL:

```ruby
"#{base.chomp("/")}/webhooks/vapi"
```

It is appended to the assistant config hash only when present; calls without a `WEBHOOK_BASE_URL` configured will not have `serverUrl` set (acceptable for local dev without ngrok).

## Local development with ngrok

Set `WEBHOOK_BASE_URL` to your ngrok URL and add the ngrok domain to `config.hosts` in `config/environments/development.rb`. The wildcard `/.+\.ngrok-free\.dev\z/` is already present.

## Auth

Webhooks are authenticated via `Authorization: Bearer <vapi_webhook_secret>`. See ADR-0005.
