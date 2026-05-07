module VoiceAgentProvider
  # Interface contract every adapter must satisfy.
  #
  # .call(call_plan:, goal_summary:) → { call_id: String }
  # .send_message(vapi_call_id:, message:) → void
  #
  # Raises VoiceAgentProvider::ApiError on any API-level failure.
  # Raises VoiceAgentProvider::PermanentError (subclass) for non-retryable failures
  # (bad phone number, invalid config, etc.).

  def self.send_message(vapi_call_id:, message:)
    VapiAdapter.send_message(vapi_call_id:, message:)
  end

  class ApiError < StandardError; end
  class PermanentError < ApiError; end
end
