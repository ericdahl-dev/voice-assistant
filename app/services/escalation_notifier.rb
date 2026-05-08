class EscalationNotifier
  CHANNEL_CLASS = {
    "pushover" => Notifiers::PushoverChannel,
    "telegram" => Notifiers::TelegramChannel
  }.freeze

  def self.notify(escalation:, user:)
    new(escalation: escalation, user: user).notify
  end

  def initialize(escalation:, user:)
    @escalation = escalation
    @user = user
  end

  def notify
    channels = @user.notification_channels.enabled

    if channels.empty?
      Rails.logger.error("[EscalationNotifier] User #{@user.id} has no enabled notification channels")
    else
      channels.each do |channel|
        channel_class = CHANNEL_CLASS[channel.channel_type]
        channel_class.new(channel).deliver(escalation: @escalation)
      rescue StandardError => e
        Rails.logger.error("[EscalationNotifier] Channel #{channel.channel_type} failed: #{e.class}: #{e.message}")
      end
    end
  ensure
    @escalation.update!(notified_at: Time.current)
  end
end
