class PlaceCallJob < ApplicationJob
  queue_as :default

  # Retry on transient errors (network issues, Vapi 5xx) with exponential backoff.
  retry_on VoiceAgentProvider::ApiError, wait: :polynomially_longer, attempts: 5

  # Do not retry on permanent errors (bad phone number, misconfigured credentials, etc.).
  discard_on VoiceAgentProvider::PermanentError do |job, error|
    job.mark_session_failed!(error.message)
  end

  # Idempotent: if a CallSession already exists for this CallPlan and is past
  # drafted state, a previous run succeeded — skip silently.
  def perform(call_plan_id)
    call_plan = CallPlan.find(call_plan_id)

    existing = call_plan.call_sessions.where.not(status: "drafted").first
    return if existing

    session = call_plan.call_sessions.create!(status: "drafted")
    @session_id = session.id

    session.transition_to!("queued")

    result = VapiAdapter.call(call_plan:)

    session.update!(vapi_call_id: result[:call_id])
    session.transition_to!("dialing")
  rescue VoiceAgentProvider::ApiError
    mark_session_failed!("Vapi API error — will retry")
    raise
  end

  def mark_session_failed!(reason)
    session = CallSession.find_by(id: @session_id)
    return unless session
    return if session.terminal?

    session.transition_to!("failed")
    Rails.logger.error("[PlaceCallJob] CallSession ##{session.id} failed: #{reason}")
  end
end
