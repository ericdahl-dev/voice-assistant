class NotificationChannel < ApplicationRecord
  CHANNEL_TYPES = %w[pushover telegram].freeze

  belongs_to :user

  encrypts :pushover_user_key, :telegram_chat_id

  validates :channel_type, inclusion: { in: CHANNEL_TYPES }

  scope :enabled, -> { where(enabled: true) }
end
