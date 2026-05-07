# Phone numbers: import Twilio numbers into Vapi

## Decision

Outbound calls use a Twilio phone number imported into Vapi, not a Vapi-provisioned number.

## Reason

Vapi-provisioned numbers have a daily outbound call limit. Importing your own Twilio number removes this limit entirely.

## How it works

1. Purchase a number in the Twilio console.
2. In the Vapi dashboard → Phone Numbers → Import, provide Twilio Account SID + Auth Token. Vapi configures the Twilio number's webhooks automatically.
3. Vapi returns a `phone_number_id` for the imported number.
4. Store this ID in `credentials.vapi.phone_number_id` (or `ENV["VAPI_PHONE_NUMBER_ID"]`).

No code changes are required — `VapiAdapter#vapi_phone_number_id` reads whatever is in credentials.

## Credentials shape

```yaml
vapi:
  api_key: "..."
  phone_number_id: "pn_..."   # ID of the imported Twilio number in Vapi
  webhook_base_url: "https://yourdomain.com"
```
