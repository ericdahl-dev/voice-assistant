class ExtractOutcomeJob < ApplicationJob
  queue_as :default

  def perform(call_session_id)
    session = CallSession.find(call_session_id)
    return if session.outcome.present?

    outcome = OutcomeExtractor.call(
      transcript: session.transcript.to_s,
      call_plan: session.call_plan
    )

    session.update!(outcome: outcome)
  rescue OutcomeExtractor::ExtractionError => e
    Rails.logger.error("[ExtractOutcomeJob] #{e.message} — session #{call_session_id}")
    raise
  end
end
