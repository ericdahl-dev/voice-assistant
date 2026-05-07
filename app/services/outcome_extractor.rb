require "net/http"
require "json"

# Extracts a structured Outcome from a completed call transcript using an LLM.
# Takes a transcript string and CallPlan; returns an Outcome hash.
# Contains no business logic — only prompt construction and HTTP.
class OutcomeExtractor
  OPENAI_URL = "https://api.openai.com/v1/chat/completions"
  MODEL = "gpt-4o-mini"

  def self.call(transcript:, call_plan:)
    new(transcript:, call_plan:).call
  end

  def initialize(transcript:, call_plan:)
    @transcript = transcript
    @call_plan = call_plan
  end

  def call
    response = post_to_openai(build_messages)
    parse_outcome(response)
  end

  private

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
        "status": "completed" | "voicemail" | "failed" | "declined" | "unknown",
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
    uri = URI(OPENAI_URL)
    request = Net::HTTP::Post.new(uri, {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{openai_api_key}"
    })
    request.body = {
      model: MODEL,
      messages: messages,
      temperature: 0,
      response_format: { type: "json_object" }
    }.to_json

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
