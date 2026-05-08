class NotificationChannel < ApplicationRecord
  CHANNEL_TYPES = %w[pushover telegram].freeze

  belongs_to :user

  validates :channel_type, inclusion: { in: CHANNEL_TYPES }

  scope :enabled, -> { where(enabled: true) }
end
