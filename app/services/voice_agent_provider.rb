module VoiceAgentProvider
  # Interface contract every adapter must satisfy.
  #
  # .call(call_plan:) → { call_id: String }
  #
  # Raises VoiceAgentProvider::ApiError on any API-level failure.
  # Raises VoiceAgentProvider::PermanentError (subclass) for non-retryable failures
  # (bad phone number, invalid config, etc.).

  class ApiError < StandardError; end
  class PermanentError < ApiError; end
end
