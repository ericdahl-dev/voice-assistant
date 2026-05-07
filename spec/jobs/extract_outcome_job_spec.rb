require "rails_helper"

RSpec.describe ExtractOutcomeJob, type: :job do
  let(:call_plan) { create(:call_plan, :approved) }

  def stub_openai(response_text)
    client_double = instance_double(OpenAI::Client)
    allow(OpenAI::Client).to receive(:new).and_return(client_double)
    allow(client_double).to receive(:chat).and_return({
      "choices" => [ { "message" => { "content" => response_text } } ]
    })
    client_double
  end

  describe "#perform" do
    context "voicemail session with transcript" do
      let(:session) do
        create(:call_session, :voicemail, call_plan: call_plan,
          transcript: "Hi, this is an AI calling for Alex. I wanted to check if the car is ready.")
      end

      it "sets outcome status=voicemail with summary" do
        stub_openai("Left a voicemail asking if the vehicle is ready for pickup.")
        described_class.perform_now(session.id)
        outcome = session.reload.outcome
        expect(outcome["status"]).to eq("voicemail")
        expect(outcome["summary"]).to be_present
      end
    end

    context "voicemail session without transcript" do
      let(:session) { create(:call_session, :voicemail, call_plan: call_plan, transcript: nil) }

      it "sets fallback summary without calling OpenAI" do
        expect(OpenAI::Client).not_to receive(:new)
        described_class.perform_now(session.id)
        outcome = session.reload.outcome
        expect(outcome["status"]).to eq("voicemail")
        expect(outcome["summary"]).to include("voicemail")
      end
    end

    context "completed session" do
      let(:session) do
        create(:call_session, :completed, call_plan: call_plan,
          transcript: "The car is ready for pickup. Call ended successfully.")
      end

      it "extracts outcome via OpenAI" do
        stub_openai('{"status": "success", "summary": "Confirmed the car is ready for pickup."}')
        described_class.perform_now(session.id)
        outcome = session.reload.outcome
        expect(outcome["status"]).to eq("success")
        expect(outcome["summary"]).to include("ready for pickup")
      end
    end

    context "when outcome already set" do
      let(:session) do
        create(:call_session, :voicemail, call_plan: call_plan,
          outcome: { "status" => "voicemail", "summary" => "already set" })
      end

      it "does not overwrite" do
        expect(OpenAI::Client).not_to receive(:new)
        described_class.perform_now(session.id)
        expect(session.reload.outcome["summary"]).to eq("already set")
      end
    end
  end
end
