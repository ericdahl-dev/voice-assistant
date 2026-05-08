require "rails_helper"

RSpec.describe EscalationNotifier, type: :service do
  let(:user) { create(:user) }
  let(:delegation) { create(:delegation, user: user) }
  let(:call_plan) { create(:call_plan, :approved, delegation: delegation) }
  let(:session) { create(:call_session, call_plan: call_plan, status: "needs_user") }
  let(:escalation) { create(:escalation, call_session: session) }

  before do
    allow(Rails.application.credentials).to receive(:dig).with(:pushover, :api_token).and_return("test-pushover-token")
    allow(Rails.application.credentials).to receive(:dig).with(:pushover, :user_key).and_return("test-user-key")
  end

  def stub_pushover(status: "1")
    fake_response = instance_double(Net::HTTPResponse, code: "200", body: { status: status }.to_json)
    allow(Net::HTTP).to receive(:post_form).and_return(fake_response)
    fake_response
  end

  describe ".notify" do
    it "sends a Pushover notification with the question" do
      stub_pushover
      described_class.notify(escalation: escalation, user: user)
      expect(Net::HTTP).to have_received(:post_form) do |_uri, params|
        expect(params[:message]).to include(escalation.question)
        expect(params[:title]).to eq("Call on hold")
      end
    end

    it "sets notified_at after dispatch" do
      stub_pushover
      described_class.notify(escalation: escalation, user: user)
      expect(escalation.reload.notified_at).to be_present
    end

    it "includes a reply URL as the Pushover url param" do
      stub_pushover
      described_class.notify(escalation: escalation, user: user)
      expect(Net::HTTP).to have_received(:post_form) do |_uri, params|
        expect(params[:url]).to include("call_sessions")
        expect(params[:url_title]).to eq("Review & confirm")
        expect(params[:message]).not_to include("call_sessions")
      end
    end

    it "raises NotConfiguredError when PUSHOVER_API_TOKEN is missing" do
      allow(Rails.application.credentials).to receive(:dig).with(:pushover, :api_token).and_return(nil)
      stub_const("ENV", ENV.to_h.except("PUSHOVER_API_TOKEN"))
      expect {
        described_class.new(escalation: escalation, user: user).send(:send_pushover)
      }.to raise_error(EscalationNotifier::NotConfiguredError, /PUSHOVER_API_TOKEN/)
    end

    it "logs a warning when Pushover returns non-success status" do
      fake_response = instance_double(Net::HTTPResponse, code: "200", body: { status: 0 }.to_json)
      allow(Net::HTTP).to receive(:post_form).and_return(fake_response)
      expect(Rails.logger).to receive(:warn).with(/Pushover returned/)
      described_class.notify(escalation: escalation, user: user)
    end
  end
end
