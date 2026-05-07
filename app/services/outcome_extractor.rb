require "net/http"
require "json"

# Extracts a structured Outcome from a completed call transcript using an LLM.
# Takes a transcript string and CallPlan; returns an Outcome hash.
# Contains no business logic — only prompt construction and HTTP.
class OutcomeExtractor
  OPENAI_URL = "https://api.openai.com/v1/chat/completions"
  MODEL = "gpt-4o-mini"

  VOICEMAIL_PROMPT = <<~PROMPT.strip
    The AI left a voicemail. Based on the transcript below, write a one-sentence summary
    of the voicemail message that was left. Return only the summary sentence, no preamble.
  PROMPT

  def self.call(transcript:, call_plan:, session_status: "completed")
    new(transcript:, call_plan:, session_status:).call
  end

  def initialize(transcript:, call_plan:, session_status: "completed")
    @transcript = transcript
    @call_plan = call_plan
    @session_status = session_status
  end

  def call
    return voicemail_outcome if @session_status == "voicemail"
    response = post_to_openai(build_messages)
    parse_outcome(response)
  end

  private

  def voicemail_outcome
    summary = if @transcript.present?
      prompt = "#{VOICEMAIL_PROMPT}\n\nTranscript:\n#{@transcript}"
      request_openai(messages: [ { role: "user", content: prompt } ], temperature: 0.2)
    else
      "Left a voicemail stating the purpose of the call."
    end
    { "status" => "voicemail", "summary" => summary }
  end

  def build_messages
    [
      { role: "system", content: system_prompt },
      { role: "user", content: user_prompt }
    ]
  end

  def system_prompt
    <<~PROMPT.strip
      You are an assistant that extracts structured outcomes from phone call transcripts.
      Respond ONLY with valid JSON matching this schema exactly:
      {
        "status": "completed" | "voicemail" | "failed" | "declined" | "terminated_off_topic" | "unknown",
        "outcome": "<one sentence summary of what was achieved or learned>",
        "follow_up_needed": true | false,
        "summary": "<2-4 sentence narrative summary>",
        "important_details": ["<detail>", ...],
        "confidence": "high" | "medium" | "low"
      }
      Rules:
      - "confidence" is "high" when the transcript clearly answers the goal, "low" when unclear or off-topic.
      - "follow_up_needed" is true when the outcome is ambiguous, incomplete, or requires a human to act.
      - "important_details" must include answers to any specific questions asked during the call.
      - Do not include any text outside the JSON object.
    PROMPT
  end

  def user_prompt
    parts = []
    parts << "Goal: #{@call_plan.goal}"

    if @call_plan.questions_to_ask.any?
      parts << "Questions that were asked:\n" +
               @call_plan.questions_to_ask.map { |q| "- #{q}" }.join("\n")
    end

    parts << "Transcript:\n#{@transcript.presence || "(no transcript recorded)"}"
    parts.join("\n\n")
  end

  def post_to_openai(messages)
    request_openai(messages: messages, temperature: 0, response_format: { type: "json_object" })
  end

  def request_openai(messages:, temperature: 0, response_format: nil)
    uri = URI(OPENAI_URL)
    request = Net::HTTP::Post.new(uri, {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{openai_api_key}"
    })
    body = { model: MODEL, messages: messages, temperature: temperature }
    body[:response_format] = response_format if response_format
    request.body = body.to_json

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    raise ExtractionError, "OpenAI error (#{response.code}): #{response.body}" unless response.code.to_i == 200

    JSON.parse(response.body).dig("choices", 0, "message", "content")
  end

  def parse_outcome(json_string)
    JSON.parse(json_string)
  rescue JSON::ParserError => e
    raise ExtractionError, "Failed to parse LLM response: #{e.message}"
  end

  def openai_api_key
    Rails.application.credentials.dig(:openai_api_key) ||
      ENV.fetch("OPENAI_API_KEY") { raise ExtractionError, "OPENAI_API_KEY not configured" }
  end

  class ExtractionError < StandardError; end
end
