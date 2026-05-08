require "rails_helper"

RSpec.describe Notifiers::PushoverChannel, type: :service do
  let(:user) { create(:user) }
  let(:channel) { create(:notification_channel, :pushover, user: user) }
  let(:delegation) { create(:delegation, user: user) }
  let(:call_plan) { create(:call_plan, :approved, delegation: delegation) }
  let(:session) { create(:call_session, call_plan: call_plan, status: "needs_user") }
  let(:escalation) { create(:escalation, call_session: session) }

  before do
    allow(Rails.application.credentials).to receive(:dig).with(:pushover, :api_token).and_return("test-api-token")
  end

  def stub_pushover(status: "1")
    fake_response = instance_double(Net::HTTPResponse, code: "200", body: { status: status }.to_json)
    allow(Net::HTTP).to receive(:post_form).and_return(fake_response)
    fake_response
  end

  describe "#deliver" do
    it "posts to Pushover with channel's user key" do
      stub_pushover
      described_class.new(channel).deliver(escalation: escalation)
      expect(Net::HTTP).to have_received(:post_form) do |_uri, params|
        expect(params[:user]).to eq(channel.pushover_user_key)
        expect(params[:token]).to eq("test-api-token")
        expect(params[:message]).to include(escalation.question)
        expect(params[:title]).to eq("Call on hold")
      end
    end

    it "logs warning on non-success Pushover status" do
      fake_response = instance_double(Net::HTTPResponse, code: "200", body: { status: 0 }.to_json)
      allow(Net::HTTP).to receive(:post_form).and_return(fake_response)
      expect(Rails.logger).to receive(:warn).with(/Pushover/)
      described_class.new(channel).deliver(escalation: escalation)
    end

    it "raises NotConfiguredError when api_token missing" do
      allow(Rails.application.credentials).to receive(:dig).with(:pushover, :api_token).and_return(nil)
      stub_const("ENV", ENV.to_h.except("PUSHOVER_API_TOKEN"))
      expect {
        described_class.new(channel).deliver(escalation: escalation)
      }.to raise_error(Notifiers::PushoverChannel::NotConfiguredError)
    end
  end
end
