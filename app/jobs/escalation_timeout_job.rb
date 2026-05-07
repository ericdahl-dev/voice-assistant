class EscalationTimeoutJob < ApplicationJob
  queue_as :default

  TIMEOUT_SECONDS = (ENV["ESCALATION_TIMEOUT_SECONDS"] || 45).to_i

  def perform(escalation_id)
    escalation = Escalation.find(escalation_id)

    return if escalation.resolved_at.present?
    return if escalation.timed_out?

    escalation.update!(timed_out: true)

    session = escalation.call_session
    fallback = session.call_plan.fallback.presence || "End the call politely."

    message = "The user did not reply in time. Please execute the fallback: #{fallback}"
    VoiceAgentProvider.send_message(vapi_call_id: session.vapi_call_id, message: message)
  rescue VoiceAgentProvider::ApiError => e
    Rails.logger.error("[EscalationTimeoutJob] #{e.message}")
  end
end
