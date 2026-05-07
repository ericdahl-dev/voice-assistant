# Escalation pattern: async hold-and-notify, not live transfer

When a CallSession hits something outside the CallPlan's allowed scope, the agent places the caller on hold and sends the user a push notification with the blocking question. The user replies asynchronously; the agent resumes or falls back on timeout. The user never joins the call.

Live call transfer (bridging the user into the active call) is explicitly deferred. It adds telephony complexity and breaks the core async delegation experience — the user's whole reason for using the product is to not be on the call.

Live transfer may be revisited as a premium feature in a later phase.
