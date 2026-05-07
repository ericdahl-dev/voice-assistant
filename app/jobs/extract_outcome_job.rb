require "openai"

# Extracts a structured outcome from a completed or voicemail CallSession.
# For voicemail sessions: synthesises a summary from the transcript.
# For completed sessions: uses OpenAI to classify and summarise.
class ExtractOutcomeJob < ApplicationJob
  queue_as :default

  VOICEMAIL_PROMPT = <<~PROMPT
    The AI left a voicemail. Based on the transcript below, write a one-sentence summary
    of the voicemail message that was left. If no transcript is available, use:
    "Left a voicemail stating the purpose of the call."
    Return only the summary sentence, no preamble.
  PROMPT

  COMPLETED_PROMPT = <<~PROMPT
    You are summarising an AI phone call. Based on the transcript below, provide:
    1. status: one of "success", "failed", "partial", "declined"
    2. summary: one sentence describing what happened and whether the goal was achieved

    Respond with valid JSON only: {"status": "...", "summary": "..."}
  PROMPT

  def perform(call_session_id)
    session = CallSession.find(call_session_id)
    return if session.outcome.present?

    outcome = case session.status
    when "voicemail"
      extract_voicemail_outcome(session)
    when "completed"
      extract_completed_outcome(session)
    else
      return
    end

    session.update!(outcome: outcome)
  rescue => e
    Rails.logger.error("[ExtractOutcomeJob] session=#{call_session_id} error=#{e.message}")
  end

  private

  def extract_voicemail_outcome(session)
    summary = if session.transcript.present?
      ask_openai("#{VOICEMAIL_PROMPT}\n\nTranscript:\n#{session.transcript}")
    else
      "Left a voicemail stating the purpose of the call."
    end

    { "status" => "voicemail", "summary" => summary }
  end

  def extract_completed_outcome(session)
    return { "status" => "unknown", "summary" => "No transcript available." } if session.transcript.blank?

    raw = ask_openai("#{COMPLETED_PROMPT}\n\nTranscript:\n#{session.transcript}")
    JSON.parse(raw)
  rescue JSON::ParserError
    { "status" => "unknown", "summary" => raw.to_s.truncate(200) }
  end

  def ask_openai(prompt)
    client = OpenAI::Client.new(access_token: openai_api_key)
    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [ { role: "user", content: prompt } ],
        max_tokens: 200,
        temperature: 0.2
      }
    )
    response.dig("choices", 0, "message", "content").to_s.strip
  end

  def openai_api_key
    Rails.application.credentials[:openai_api_key] ||
      ENV.fetch("OPENAI_API_KEY") { raise "OPENAI_API_KEY not configured" }
  end
end
