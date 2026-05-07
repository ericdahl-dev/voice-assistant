class WebhookProcessor
  class UnknownEventError < StandardError; end

  EVENT_HANDLERS = {
    "call.started"          => :handle_call_started,
    "call.connected"        => :handle_call_connected,
    "call.ended"            => :handle_call_ended,
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
  end

  def handle_transcript_chunk
    chunk = @event.dig("transcript", "text").to_s
    return if chunk.blank?

    @session.with_lock do
      @session.update!(transcript: [ @session.transcript, chunk ].compact.join)
    end
  end

  def handle_escalation_triggered
    safely_transition_to("needs_user")
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
end
