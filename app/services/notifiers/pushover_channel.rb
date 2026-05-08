require "net/http"
require "json"

module Notifiers
  class PushoverChannel
    PUSHOVER_URL = "https://api.pushover.net/1/messages.json"

    NotConfiguredError = Class.new(StandardError)

    def initialize(notification_channel)
      @channel = notification_channel
    end

    def deliver(escalation:)
      api_token = Rails.application.credentials.dig(:pushover, :api_token) ||
        ENV.fetch("PUSHOVER_API_TOKEN") { raise NotConfiguredError, "PUSHOVER_API_TOKEN not configured" }

      uri = URI(PUSHOVER_URL)
      response = Net::HTTP.post_form(uri, {
        token: api_token,
        user: @channel.pushover_user_key,
        title: "Call on hold",
        message: message(escalation),
        priority: 1,
        sound: "pushover",
        url: session_url(escalation),
        url_title: "Review & confirm"
      })

      body = parse_body(response)
      unless body["status"] == 1
        Rails.logger.warn("[Notifiers::PushoverChannel] Pushover returned status #{response.code}: #{response.body}")
      end
    end

    private

    def message(escalation)
      escalation.question.presence || "The AI needs your input to continue the call."
    end

    def session_url(escalation)
      Rails.application.routes.url_helpers.call_session_url(
        escalation.call_session,
        host: Rails.application.config.action_mailer.default_url_options[:host],
        protocol: Rails.application.config.action_mailer.default_url_options.fetch(:protocol, "https")
      )
    end

    def parse_body(response)
      JSON.parse(response.body)
    rescue JSON::ParserError
      {}
    end
  end
end
