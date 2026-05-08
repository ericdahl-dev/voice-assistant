require "net/http"
require "json"

module Notifiers
  class TelegramChannel
    NotConfiguredError = Class.new(StandardError)

    def initialize(notification_channel)
      @channel = notification_channel
    end

    def deliver(escalation:)
      bot_token = Rails.application.credentials.dig(:telegram, :bot_token) ||
        ENV.fetch("TELEGRAM_BOT_TOKEN") { raise NotConfiguredError, "TELEGRAM_BOT_TOKEN not configured" }

      uri = URI("https://api.telegram.org/bot#{bot_token}/sendMessage")
      response = Net::HTTP.post_form(uri, {
        chat_id: @channel.telegram_chat_id,
        text: message(escalation),
        parse_mode: "HTML"
      })

      body = parse_body(response)
      unless body["ok"]
        Rails.logger.warn("[Notifiers::TelegramChannel] Telegram returned ok=false: #{response.body}")
      end
    end

    private

    def message(escalation)
      question = escalation.question.presence || "The AI needs your input to continue the call."
      url = session_url(escalation)
      "#{question}\n\n<a href=\"#{url}\">Review &amp; confirm</a>"
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
