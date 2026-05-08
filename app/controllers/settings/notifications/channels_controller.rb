module Settings
  module Notifications
    class ChannelsController < ApplicationController
      before_action :set_channel, only: [ :update, :destroy ]

      def create
        @channel = current_user.notification_channels.build(channel_params)
        if @channel.save
          redirect_to settings_notifications_path, notice: "Notification channel added."
        else
          redirect_to settings_notifications_path, alert: @channel.errors.full_messages.to_sentence
        end
      end

      def update
        if @channel.update(channel_params)
          redirect_to settings_notifications_path, notice: "Notification channel updated."
        else
          redirect_to settings_notifications_path, alert: @channel.errors.full_messages.to_sentence
        end
      end

      def destroy
        @channel.destroy!
        redirect_to settings_notifications_path, notice: "Notification channel removed."
      end

      private

      def set_channel
        @channel = current_user.notification_channels.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        head :not_found
      end

      def channel_params
        params.require(:notification_channel).permit(
          :channel_type, :pushover_user_key, :telegram_chat_id, :enabled
        )
      end
    end
  end
end
