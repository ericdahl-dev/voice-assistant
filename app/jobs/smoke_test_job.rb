class SmokeTestJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "SmokeTestJob executed successfully"
  end
end
