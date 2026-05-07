class WebhooksController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token

  def vapi
    unless valid_signature?
      head :unauthorized
      return
    end

    event = JSON.parse(request.raw_post)
    WebhookProcessor.new(event).process

    head :ok
  rescue JSON::ParserError
    head :bad_request
  end

  private

  def valid_signature?
    secret = Rails.application.credentials.vapi_webhook_secret
    return true if secret.blank? && !Rails.env.production?

    request.headers["Authorization"] == "Bearer #{secret}"
  end
end
