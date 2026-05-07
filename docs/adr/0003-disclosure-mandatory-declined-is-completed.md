# Disclosure is mandatory and non-negotiable; declined calls are completed, not failed

Every CallSession opens with a Disclosure: AI identity, user's first name, and call purpose. This is not configurable.

If the business declines to continue after Disclosure, the CallSession is recorded as `completed` with outcome `declined`. The agent does not negotiate, explain further, or retry with a different approach. The user is notified immediately.

`declined` is distinct from `failed` — failed means a technical or process error; declined means the business exercised a legitimate choice.

User's first name is always disclosed. Full name and other PII are governed by the CallPlan's `allowed_to_share` list.
