require "openai"

# Summarizes a caller goal into a short phrase suitable for spoken disclosure.
# Falls back to string truncation if the LLM is unavailable or fails.
class GoalSummarizer
  def self.call(goal:)
    new(goal:).call
  end

  def initialize(goal:)
    @goal = goal
  end

  def call
    key = Rails.application.credentials[:openai_api_key] || ENV["OPENAI_API_KEY"]
    return fallback unless key.present?

    client = OpenAI::Client.new(access_token: key)
    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: "You summarize a caller's goal into a short, natural phrase (3-6 words) " \
                     "suitable for spoken disclosure, like \"a vehicle status check\" or " \
                     "\"a prescription refill request\". Lowercase. No punctuation at the end. " \
                     "Never quote the original text verbatim."
          },
          { role: "user", content: @goal }
        ],
        max_tokens: 20,
        temperature: 0.3
      }
    )
    result = response.dig("choices", 0, "message", "content").to_s.strip.downcase.gsub(/[.!?]+\z/, "")
    result.present? ? result : fallback
  rescue => e
    Rails.logger.warn("[GoalSummarizer] LLM failed: #{e.message}")
    fallback
  end

  private

  def fallback
    goal = @goal.strip
    first_line = goal.lines.first.to_s.strip.gsub(/\A[\-\*\d\.]+\s*/, "").gsub(/[?.!]+\z/, "").downcase
    first_line.length > 60 ? first_line[0, 60].sub(/\s+\S+\z/, "").strip : first_line
  end
end
