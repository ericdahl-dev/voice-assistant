require "rails_helper"

RSpec.describe VapiAdapter, type: :service do
  let(:call_plan) { create(:call_plan, :approved, forbidden_actions: [ "Approve new repairs" ], allowed_to_share: [ "My first name" ], questions_to_ask: [ "Is the car ready?" ]) }
  let(:adapter) { described_class.new(call_plan:) }

  before do
    allow(adapter).to receive(:vapi_phone_number_id).and_return("phone-num-stub")
    allow(adapter).to receive(:api_key).and_return("key-stub")
  end

  describe "#call" do
    it "returns a call_id on success" do
      allow(adapter).to receive(:post).and_return({ "id" => "vapi-abc-123" })
      expect(adapter.call).to eq({ call_id: "vapi-abc-123" })
    end

    it "raises ApiError on Vapi 5xx" do
      allow(adapter).to receive(:post).and_raise(VoiceAgentProvider::ApiError, "500")
      expect { adapter.call }.to raise_error(VoiceAgentProvider::ApiError)
    end

    it "raises PermanentError on Vapi 4xx" do
      allow(adapter).to receive(:post).and_raise(VoiceAgentProvider::PermanentError, "422")
      expect { adapter.call }.to raise_error(VoiceAgentProvider::PermanentError)
    end
  end

  describe "first_message (disclosure)" do
    it "includes caller name but not the raw goal" do
      msg = adapter.send(:first_message)
      expect(msg).to include(call_plan.caller_name)
      expect(msg).not_to include(call_plan.goal)
    end
  end

  describe "system prompt" do
    subject(:prompt) { adapter.send(:build_system_prompt) }

    it "includes forbidden actions under a NEVER heading" do
      expect(prompt).to include("NEVER")
      expect(prompt).to include("Approve new repairs")
    end

    it "includes questions to ask" do
      expect(prompt).to include("Is the car ready?")
    end

    it "includes allowed-to-share facts" do
      expect(prompt).to include("My first name")
    end
  end
  describe "voicemail_only path" do
    let(:call_plan) { create(:call_plan, :approved, :voicemail_only) }
    let(:adapter) { described_class.new(call_plan:) }

    before do
      allow(adapter).to receive(:vapi_phone_number_id).and_return("phone-num-stub")
      allow(adapter).to receive(:api_key).and_return("key-stub")
    end

    it "firstMessage does not contain the consent question" do
      msg = adapter.send(:first_message)
      expect(msg).not_to include("Is it okay if I continue?")
    end

    it "firstMessage includes caller name, goal, and callback request" do
      msg = adapter.send(:first_message)
      expect(msg).to include(call_plan.caller_name)
      expect(msg).to include(call_plan.goal)
      expect(msg).to include("call us back")
    end

    it "build_assistant_config uses the voicemail firstMessage" do
      config = adapter.send(:build_assistant_config)
      expect(config[:firstMessage]).to include("call us back")
    end
  end
  describe "disclosure enforcement" do
    it "firstMessage contains caller name and AI disclosure but not raw goal" do
      config = adapter.send(:build_assistant_config)
      expect(config[:firstMessage]).to include(call_plan.caller_name)
      expect(config[:firstMessage]).to include("AI assistant")
      expect(config[:firstMessage]).not_to include(call_plan.goal)
    end

    it "every build_call_payload includes firstMessage" do
      payload = adapter.send(:build_call_payload)
      expect(payload.dig(:assistant, :firstMessage)).to be_present
    end
  end
end
