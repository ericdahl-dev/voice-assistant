# Extracts a structured outcome from a completed or voicemail CallSession.
# Delegates all LLM work to OutcomeExtractor.
class ExtractOutcomeJob < ApplicationJob
  queue_as :default

  SUPPORTED_STATUSES = %w[voicemail completed].freeze

  def perform(call_session_id)
    session = CallSession.find(call_session_id)
    return if session.outcome.present?
    return unless SUPPORTED_STATUSES.include?(session.status)

    outcome = OutcomeExtractor.call(
      transcript: session.transcript,
      call_plan: session.call_plan,
      session_status: session.status
    )

    session.update!(outcome: outcome)
  rescue => e
    Rails.logger.error("[ExtractOutcomeJob] session=#{call_session_id} error=#{e.message}")
  end
end
