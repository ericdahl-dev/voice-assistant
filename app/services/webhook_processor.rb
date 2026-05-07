class WebhookProcessor
  class UnknownEventError < StandardError; end

  EVENT_HANDLERS = {
    "call.started"          => :handle_call_started,
    "call.connected"        => :handle_call_connected,
    "call.ended"            => :handle_call_ended,
    "call.declined"         => :handle_call_declined,
    "transcript.chunk"      => :handle_transcript_chunk,
    "escalation.triggered"  => :handle_escalation_triggered
  }.freeze

  def initialize(event)
    @event = event
  end

  def process
    vapi_call_id = @event.dig("call", "id")
    return if vapi_call_id.blank?

    @session = CallSession.find_by(vapi_call_id: vapi_call_id)
    return unless @session

    handler = EVENT_HANDLERS[@event["type"]]
    if handler
      send(handler)
    else
      Rails.logger.info("[WebhookProcessor] Unknown event type: #{@event["type"].inspect}")
    end
  end

  private

  def handle_call_started
    safely_transition_to("dialing")
  end

  def handle_call_connected
    safely_transition_to("connected")
  end

  def handle_call_ended
    return if @session.terminal?

    end_reason = @event.dig("call", "endedReason")
    new_status = if end_reason == "voicemail"
      "voicemail"
    else
      currently_connected? ? "completed" : "failed"
    end

    safely_transition_to(new_status)
    enqueue_outcome_extraction if %w[completed voicemail].include?(new_status)
  end

  def handle_transcript_chunk
    chunk = @event.dig("transcript", "text").to_s
    return if chunk.blank?

    @session.with_lock do
      @session.update!(transcript: [ @session.transcript, chunk ].compact.join)
    end
  end

  def handle_call_declined
    return if @session.terminal?

    @session.transition_to!("completed")
    @session.update!(outcome: {
      "status" => "declined",
      "summary" => "The business declined to continue after the AI disclosure."
    })
  end

  def handle_escalation_triggered
    safely_transition_to("needs_user")
    question = @event.dig("escalation", "question").presence ||
      @event.dig("message", "content").presence ||
      "The AI needs your input to continue."
    escalation = @session.escalations.create!(question: question)
    user = @session.call_plan.delegation.user
    EscalationNotifier.notify(escalation: escalation, user: user)
  rescue => e
    Rails.logger.error("[WebhookProcessor] EscalationNotifier failed: #{e.message}")
  end

  def safely_transition_to(new_status)
    return if @session.status == new_status
    return if @session.terminal?

    allowed = CallSession::TRANSITIONS.fetch(@session.status, [])
    return unless allowed.include?(new_status)

    @session.transition_to!(new_status)
  rescue CallSession::InvalidTransitionError => e
    Rails.logger.warn("[WebhookProcessor] #{e.message}")
  end

  def currently_connected?
    %w[connected in_conversation needs_user].include?(@session.status)
  end

  def enqueue_outcome_extraction
    ExtractOutcomeJob.perform_later(@session.id)
  end
end
