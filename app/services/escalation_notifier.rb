require "net/http"
require "json"

class EscalationNotifier
  PUSHOVER_URL = "https://api.pushover.net/1/messages.json"

  def self.notify(escalation:, user:)
    new(escalation: escalation, user: user).notify
  end

  def initialize(escalation:, user:)
    @escalation = escalation
    @user = user
  end

  def notify
    send_pushover
  rescue StandardError => e
    Rails.logger.error("[EscalationNotifier] Failed to notify: #{e.class}: #{e.message}")
  ensure
    @escalation.update!(notified_at: Time.current)
  end

  private

  def send_pushover
    api_token = Rails.application.credentials.dig(:pushover, :api_token) ||
      ENV.fetch("PUSHOVER_API_TOKEN") { raise NotConfiguredError, "PUSHOVER_API_TOKEN not configured" }

    user_key = @user.try(:pushover_user_key) ||
      Rails.application.credentials.dig(:pushover, :user_key) ||
      ENV.fetch("PUSHOVER_USER_KEY") { raise NotConfiguredError, "PUSHOVER_USER_KEY not configured" }

    uri = URI(PUSHOVER_URL)
    response = Net::HTTP.post_form(uri, {
      token: api_token,
      user: user_key,
      title: "Call on hold",
      message: notification_message,
      priority: 1,
      sound: "pushover"
    })

    body = begin
      JSON.parse(response.body)
    rescue JSON::ParserError
      {}
    end
    unless response.code.to_i == 1 || body["status"] == 1
      Rails.logger.warn("[EscalationNotifier] Pushover returned status #{response.code}: #{response.body}")
    end
  end

  def notification_message
    question = @escalation.question.presence || "The AI needs your input to continue the call."
    session_path = Rails.application.routes.url_helpers.call_session_path(@escalation.call_session)
    "#{question}\n\nReply in app: #{session_path}"
  end

  class NotConfiguredError < StandardError; end
end
