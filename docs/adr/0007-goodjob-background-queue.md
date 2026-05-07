# Background job queue: GoodJob

GoodJob is the background job queue for the Rails control plane. Postgres-backed (no Redis dependency), fits the monolith cleanly.

Chosen for its built-in dashboard and mature observability — CallSession state visibility (queued, dialing, stuck, failed) is operationally important and GoodJob's UI covers it without custom tooling.

CallSession execution flow: user approves CallPlan → `PlaceCallJob` enqueued → job calls Vapi API → Vapi webhooks update CallSession state via a dedicated controller.
