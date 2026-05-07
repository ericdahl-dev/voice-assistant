# Rails monolith with Hotwire; no separate frontend

Single Rails app owns the control plane, web UI, webhooks, and background jobs. Hotwire (Turbo + Stimulus) handles the UI. No separate API or frontend framework.

Chosen over Rails API + React/Next.js to avoid maintaining an API surface before the product shape is known. Hotwire is sufficient for the real-time call status updates needed during a live CallSession (Turbo Streams over Action Cable).

Extract to API + frontend only if a native mobile app becomes a priority.
