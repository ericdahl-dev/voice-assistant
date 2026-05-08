require "rails_helper"

RSpec.describe "Settings::NotificationChannels", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /settings/notifications" do
    it "returns 200" do
      get settings_notifications_path
      expect(response).to have_http_status(:ok)
    end

    it "shows existing channels" do
      create(:notification_channel, :pushover, user: user)
      get settings_notifications_path
      expect(response.body).to include("Pushover")
    end
  end

  describe "POST /settings/notifications/channels" do
    context "pushover channel" do
      it "creates a new pushover channel and redirects" do
        expect {
          post settings_notifications_channels_path, params: {
            notification_channel: { channel_type: "pushover", pushover_user_key: "my-key" }
          }
        }.to change(NotificationChannel, :count).by(1)
        expect(response).to redirect_to(settings_notifications_path)
      end
    end

    context "telegram channel" do
      it "creates a new telegram channel and redirects" do
        expect {
          post settings_notifications_channels_path, params: {
            notification_channel: { channel_type: "telegram", telegram_chat_id: "123456" }
          }
        }.to change(NotificationChannel, :count).by(1)
        expect(response).to redirect_to(settings_notifications_path)
      end
    end

    it "does not allow creating channel for another user" do
      other_user = create(:user)
      post settings_notifications_channels_path, params: {
        notification_channel: { channel_type: "pushover", pushover_user_key: "key", user_id: other_user.id }
      }
      created = NotificationChannel.last
      expect(created.user).to eq(user)
    end
  end

  describe "PATCH /settings/notifications/channels/:id" do
    let!(:channel) { create(:notification_channel, :pushover, user: user) }

    it "updates the channel and redirects" do
      patch settings_notifications_channel_path(channel), params: {
        notification_channel: { pushover_user_key: "new-key", enabled: false }
      }
      expect(response).to redirect_to(settings_notifications_path)
      expect(channel.reload.pushover_user_key).to eq("new-key")
      expect(channel.reload.enabled).to be false
    end

    it "cannot update another user's channel" do
      other_channel = create(:notification_channel, :pushover, user: create(:user))
      patch settings_notifications_channel_path(other_channel), params: {
        notification_channel: { pushover_user_key: "hacked" }
      }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /settings/notifications/channels/:id" do
    let!(:channel) { create(:notification_channel, :pushover, user: user) }

    it "deletes the channel and redirects" do
      expect {
        delete settings_notifications_channel_path(channel)
      }.to change(NotificationChannel, :count).by(-1)
      expect(response).to redirect_to(settings_notifications_path)
    end

    it "cannot delete another user's channel" do
      other_channel = create(:notification_channel, :pushover, user: create(:user))
      expect {
        delete settings_notifications_channel_path(other_channel)
      }.not_to change(NotificationChannel, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end
