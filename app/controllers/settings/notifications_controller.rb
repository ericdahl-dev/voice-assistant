module Settings
  class NotificationsController < ApplicationController
    def show
      @channels = current_user.notification_channels.order(:channel_type)
      @new_channel = NotificationChannel.new
    end
  end
end
