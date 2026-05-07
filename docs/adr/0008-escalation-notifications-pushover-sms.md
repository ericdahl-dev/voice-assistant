# Escalation notifications: Pushover + SMS simultaneously

Escalation notifications are sent via both Pushover and SMS (Twilio) at the same time. Belt-and-suspenders approach ensures the user sees the escalation within the tight hold window.

No priority ordering or fallback logic for MVP — both fire in parallel. User-configurable notification preferences deferred to a later phase.

Twilio is already in the stack for outbound calls; Pushover adds negligible integration cost and delivers faster, richer notifications than SMS alone.
