class WebhookProcessor
  class UnknownEventError < StandardError; end

  # Vapi sends all server messages wrapped in a top-level "message" key.
  # Event types use Vapi's actual names (status-update, end-of-call-report, transcript).
  # Statuses inside status-update: queued, ringing, in-progress, forwarding, ended.
  EVENT_HANDLERS = {
    "status-update" => :handle_status_update,
    "end-of-call-report" => :handle_end_of_call_report,
    "transcript" => :handle_transcript,
    "tool-calls" => :handle_tool_calls
  }.freeze

  # Map Vapi call statuses → our CallSession statuses.
  # "in-progress" maps to "connected" (call was answered) — not in_conversation, so
  # voicemail is still reachable via connected → voicemail.
  # Transcripts arriving during the call advance to in_conversation.
  STATUS_MAP = {
    "queued" => "queued",
    "ringing" => "dialing",
    "in-progress" => "connected",
    "forwarding" => "connected",
    "ended" => nil # handled by end-of-call-report
  }.freeze

  def initialize(event)
    @event = event
  end

  def process
    msg = @event["message"]
    return if msg.blank?

    vapi_call_id = msg.dig("call", "id")
    return if vapi_call_id.blank?

    @session = CallSession.find_by(vapi_call_id: vapi_call_id)
    return unless @session

    handler = EVENT_HANDLERS[msg["type"]]
    if handler
      send(handler, msg)
    else
      Rails.logger.info("[WebhookProcessor] Unknown event type: #{msg["type"].inspect}")
    end
  end

  private

  def handle_status_update(msg)
    vapi_status = msg["status"]
    new_status = STATUS_MAP[vapi_status]

    if new_status
      safely_transition_to(new_status)
    elsif vapi_status != "ended"
      Rails.logger.info("[WebhookProcessor] Unhandled Vapi status: #{vapi_status.inspect}")
    end
  end

  def handle_end_of_call_report(msg)
    return if @session.terminal?

    end_reason = msg.dig("call", "endedReason") || msg["endedReason"]

    # Grab the transcript from the artifact if available
    artifact_transcript = msg.dig("artifact", "transcript").presence
    if artifact_transcript && @session.transcript.blank?
      @session.update!(transcript: artifact_transcript)
    end

    new_status = if end_reason&.include?("voicemail") || @session.call_plan.voicemail_only?
      "voicemail"
    else
      currently_connected? ? "completed" : "failed"
    end

    safely_transition_to(new_status)
    enqueue_outcome_extraction if %w[completed voicemail].include?(new_status)
  end

  def handle_transcript(msg)
    return unless msg["transcriptType"] == "final"

    chunk = msg["transcript"].to_s
    return if chunk.blank?

    # Advance to in_conversation once speech starts (connected → in_conversation)
    safely_transition_to("in_conversation")

    @session.with_lock do
      existing = @session.transcript.presence
      @session.update!(transcript: [ existing, chunk ].compact.join(" "))
    end
  end

  # tool-calls are used for escalation: the assistant calls an "escalate" tool
  # with a question, and we pause the session to notify the user.
  def handle_tool_calls(msg)
    tool_call = msg.dig("toolCallList")&.find { |t| t["name"] == "escalate" } ||
      msg.dig("toolWithToolCallList")&.find { |t| t["name"] == "escalate" }
    return unless tool_call

    safely_transition_to("needs_user")
    question = tool_call.dig("parameters", "question").presence ||
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
