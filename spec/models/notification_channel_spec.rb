require "rails_helper"

RSpec.describe NotificationChannel, type: :model do
  let(:user) { create(:user) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_inclusion_of(:channel_type).in_array(%w[pushover telegram]) }

    it "is valid with pushover type and user key" do
      channel = build(:notification_channel, :pushover, user: user)
      expect(channel).to be_valid
    end

    it "is valid with telegram type and chat_id" do
      channel = build(:notification_channel, :telegram, user: user)
      expect(channel).to be_valid
    end
  end

  describe "defaults" do
    it "defaults enabled to true" do
      channel = build(:notification_channel, :pushover, user: user)
      expect(channel.enabled).to be true
    end
  end

  describe "scopes" do
    it ".enabled returns only enabled channels" do
      enabled = create(:notification_channel, :pushover, user: user, enabled: true)
      _disabled = create(:notification_channel, :telegram, user: user, enabled: false)
      expect(NotificationChannel.enabled).to contain_exactly(enabled)
    end
  end

  describe "User association" do
    it "user has many notification_channels" do
      create(:notification_channel, :pushover, user: user)
      create(:notification_channel, :telegram, user: user)
      expect(user.notification_channels.count).to eq(2)
    end
  end
end
