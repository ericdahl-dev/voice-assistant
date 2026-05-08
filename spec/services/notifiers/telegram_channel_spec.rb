require "rails_helper"

RSpec.describe Notifiers::TelegramChannel, type: :service do
  let(:user) { create(:user) }
  let(:channel) { create(:notification_channel, :telegram, user: user) }
  let(:delegation) { create(:delegation, user: user) }
  let(:call_plan) { create(:call_plan, :approved, delegation: delegation) }
  let(:session) { create(:call_session, call_plan: call_plan, status: "needs_user") }
  let(:escalation) { create(:escalation, call_session: session) }

  before do
    allow(Rails.application.credentials).to receive(:dig).with(:telegram, :bot_token).and_return("test-bot-token")
  end

  def stub_telegram(ok: true)
    fake_response = instance_double(Net::HTTPResponse, code: "200", body: { ok: ok }.to_json)
    allow(Net::HTTP).to receive(:post_form).and_return(fake_response)
    fake_response
  end

  describe "#deliver" do
    it "posts to Telegram with channel's chat_id" do
      stub_telegram
      described_class.new(channel).deliver(escalation: escalation)
      expect(Net::HTTP).to have_received(:post_form) do |_uri, params|
        expect(params[:chat_id]).to eq(channel.telegram_chat_id)
        expect(params[:text]).to include(escalation.question)
      end
    end

    it "logs warning when Telegram returns ok=false" do
      stub_telegram(ok: false)
      expect(Rails.logger).to receive(:warn).with(/Telegram/)
      described_class.new(channel).deliver(escalation: escalation)
    end

    it "raises NotConfiguredError when bot_token missing" do
      allow(Rails.application.credentials).to receive(:dig).with(:telegram, :bot_token).and_return(nil)
      stub_const("ENV", ENV.to_h.except("TELEGRAM_BOT_TOKEN"))
      expect {
        described_class.new(channel).deliver(escalation: escalation)
      }.to raise_error(Notifiers::TelegramChannel::NotConfiguredError)
    end
  end
end
