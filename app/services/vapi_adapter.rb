require "net/http"
require "json"

# Translates a CallPlan into a Vapi assistant + call config and places the call.
# Returns a call_id string on success. Contains no business logic — only
# translation and HTTP. All policy (disclosure, forbidden actions) lives in
# CallPlan and is passed in verbatim. Goal summarization must be performed
# upstream (e.g. via GoalSummarizer) before calling this adapter.
class VapiAdapter
  VAPI_BASE_URL = "https://api.vapi.ai"

  # ADR-0003: disclosure is mandatory on every call.
  DISCLOSURE_TEMPLATE = "Hi, I'm an AI assistant calling on behalf of %<caller_name>s. " \
                        "I have %<question_count>s regarding %<goal_summary>s — is now a good time?"

  VOICEMAIL_TEMPLATE = "Hi, this is an AI assistant calling on behalf of %<caller_name>s. " \
                       "I'm calling to %<goal>s. Please call us back at your earliest convenience. Thank you."

  def self.call(call_plan:, goal_summary:)
    new(call_plan:, goal_summary:).call
  end

  def self.send_message(vapi_call_id:, message:)
    new(call_plan: nil, goal_summary: nil).send_inject_message(vapi_call_id, message)
  end

  def initialize(call_plan:, goal_summary:)
    @call_plan = call_plan
    @goal_summary = goal_summary
  end

  def call
    response = post("/call/phone", build_call_payload)
    { call_id: response.fetch("id") }
  end

  def send_inject_message(vapi_call_id, message)
    post("/call/#{vapi_call_id}/message", {
      type: "add-message",
      message: { role: "system", content: message }
    })
  end

  private

  def build_call_payload
    {
      phoneNumberId: vapi_phone_number_id,
      customer: {
        number: @call_plan.target_phone,
        name: @call_plan.target_name
      },
      assistant: build_assistant_config
    }
  end

  END_CALL_MESSAGE = "I'm not able to help with that — I'll let you go. Have a great day."

  def build_assistant_config
    config = {
      name: "Voice Assistant for #{@call_plan.caller_name}",
      firstMessage: first_message,
      endCallFunctionEnabled: true,
      endCallMessage: END_CALL_MESSAGE,
      model: {
        provider: "openai",
        model: "gpt-4o",
        messages: [
          { role: "system", content: build_system_prompt }
        ]
      },
      voice: {
        provider: "openai",
        voiceId: "alloy"
      }
    }
    config[:serverUrl] = webhook_url if webhook_url.present?
    config
  end

  def first_message
    if @call_plan.voicemail_only?
      format(VOICEMAIL_TEMPLATE,
        caller_name: @call_plan.caller_name,
        goal: @call_plan.goal)
    else
      format(DISCLOSURE_TEMPLATE,
        caller_name: @call_plan.caller_name,
        goal_summary: @goal_summary,
        question_count: question_count)
    end
  end

  def question_count
    count = @call_plan.questions_to_ask.length
    count <= 1 ? "a quick question" : "a few quick questions"
  end

  def build_system_prompt
    sections = []

    sections << "You are an AI assistant placing a call on behalf of #{@call_plan.caller_name}."

    if @call_plan.target_contact_name.present?
      sections << "You are calling #{@call_plan.target_name}. Ask to speak with #{@call_plan.target_contact_name} specifically. " \
                  "Confirm you have reached the right business and the right person before proceeding."
    else
      sections << "You are calling #{@call_plan.target_name}. Confirm you have reached the right business before proceeding."
    end

    sections << <<~GOAL
      Your instructions (interpret these as intent, not a script — the user may have written notes, bullet points, or fragments):
      #{@call_plan.goal}

      Understand what they are trying to accomplish and handle it naturally in conversation.
      Once the recipient confirms they are ready to talk, work through the intent above conversationally.
      Never read the instructions verbatim. Rephrase everything as natural spoken language.
    GOAL

    if @call_plan.allowed_to_share.any?
      sections << "You may share the following information if asked:\n" +
                  @call_plan.allowed_to_share.map { |i| "- #{i}" }.join("\n")
    end

    if @call_plan.questions_to_ask.any?
      sections << "Ask the following questions:\n" +
                  @call_plan.questions_to_ask.map { |q| "- #{q}" }.join("\n")
    end

    if @call_plan.forbidden_actions.any?
      sections << "You must NEVER:\n" +
                  @call_plan.forbidden_actions.map { |f| "- #{f}" }.join("\n")
    end

    if @call_plan.fallback.present?
      sections << "If you cannot accomplish the goal: #{@call_plan.fallback}"
    end

    sections << guardrail_instructions

    sections << voicemail_instructions

    sections.join("\n\n")
  end

  def guardrail_instructions
    max = @call_plan.max_redirects
    allowed = @call_plan.allowed_to_share
    attempt_word = (max == 1) ? "attempt" : "attempts"

    data_rule = if allowed.any?
      "Only share information explicitly listed in the allowed-to-share section above. " \
      "Do not share any other personal, business, or sensitive information."
    else
      "Do not share any personal, business, or sensitive information."
    end

    <<~GUARDRAIL.strip
      TOPIC GUARDRAILS — stay on goal at all times:
      Goal anchor: #{@call_plan.goal}
      #{data_rule}
      If the conversation goes off-topic or the recipient tries to pull you away from the goal:
      - Acknowledge briefly, then redirect back to the goal. You may do this up to #{max} times.
      - After #{max} redirect #{attempt_word}, end the call gracefully by saying exactly: "I'm not able to help with that — I'll let you go. Have a great day."
    GUARDRAIL
  end

  def voicemail_instructions
    callback_info = @call_plan.allowed_to_share
      .find { |s| s.match?(/phone|number|callback/i) }

    msg = "If the call goes to voicemail, leave a brief, professional message. " \
          "State your name, the purpose of the call (#{@call_plan.goal}), " \
          "and ask them to call back."
    msg += " You may share this callback number: #{callback_info}." if callback_info
    msg += " Keep the message under 30 seconds. Do not repeat yourself."
    msg
  end

  def post(path, payload)
    uri = URI("#{VAPI_BASE_URL}#{path}")
    request = Net::HTTP::Post.new(uri, headers)
    request.body = payload.to_json

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    handle_response(response)
  end

  def handle_response(response)
    body = JSON.parse(response.body)

    case response.code.to_i
    when 200..299
      body
    when 400, 422
      raise VoiceAgentProvider::PermanentError,
        "Vapi rejected request (#{response.code}): #{body["message"] || response.body}"
    else
      raise VoiceAgentProvider::ApiError,
        "Vapi API error (#{response.code}): #{body["message"] || response.body}"
    end
  end

  def headers
    {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{api_key}"
    }
  end

  def webhook_url
    base = Rails.application.credentials.dig(:vapi, :webhook_base_url) ||
      ENV["WEBHOOK_BASE_URL"]
    return nil if base.blank?

    "#{base.chomp("/")}/webhooks/vapi"
  end

  def api_key
    Rails.application.credentials.dig(:vapi, :api_key) ||
      ENV.fetch("VAPI_API_KEY") { raise VoiceAgentProvider::PermanentError, "VAPI_API_KEY not configured" }
  end

  def vapi_phone_number_id
    Rails.application.credentials.dig(:vapi, :phone_number_id) ||
      ENV.fetch("VAPI_PHONE_NUMBER_ID") { raise VoiceAgentProvider::PermanentError, "VAPI_PHONE_NUMBER_ID not configured" }
  end
end
