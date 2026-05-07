require "rails_helper"

RSpec.describe ExtractOutcomeJob, type: :job do
  let(:call_plan) { create(:call_plan, :approved) }

  def stub_extractor(result)
    allow(OutcomeExtractor).to receive(:call).and_return(result)
  end

  describe "#perform" do
    context "voicemail session with transcript" do
      let(:session) do
        create(:call_session, :voicemail, call_plan: call_plan,
          transcript: "Hi, this is an AI calling for Alex.")
      end

      it "delegates to OutcomeExtractor with session_status=voicemail" do
        stub_extractor({ "status" => "voicemail", "summary" => "Left a voicemail." })
        expect(OutcomeExtractor).to receive(:call).with(
          transcript: session.transcript,
          call_plan: call_plan,
          session_status: "voicemail"
        ).and_return({ "status" => "voicemail", "summary" => "Left a voicemail." })
        described_class.perform_now(session.id)
      end

      it "persists the outcome" do
        stub_extractor({ "status" => "voicemail", "summary" => "Left a voicemail." })
        described_class.perform_now(session.id)
        expect(session.reload.outcome["status"]).to eq("voicemail")
      end
    end

    context "voicemail session without transcript" do
      let(:session) { create(:call_session, :voicemail, call_plan: call_plan, transcript: nil) }

      it "still delegates to OutcomeExtractor" do
        stub_extractor({ "status" => "voicemail", "summary" => "Left a voicemail stating the purpose of the call." })
        expect(OutcomeExtractor).to receive(:call).with(
          transcript: nil,
          call_plan: call_plan,
          session_status: "voicemail"
        ).and_return({ "status" => "voicemail", "summary" => "Left a voicemail stating the purpose of the call." })
        described_class.perform_now(session.id)
      end
    end

    context "completed session" do
      let(:session) do
        create(:call_session, :completed, call_plan: call_plan,
          transcript: "The car is ready for pickup.")
      end

      it "delegates to OutcomeExtractor with session_status=completed" do
        stub_extractor({ "status" => "completed", "summary" => "Car ready." })
        expect(OutcomeExtractor).to receive(:call).with(
          transcript: session.transcript,
          call_plan: call_plan,
          session_status: "completed"
        ).and_return({ "status" => "completed", "summary" => "Car ready." })
        described_class.perform_now(session.id)
        expect(session.reload.outcome["status"]).to eq("completed")
      end
    end

    context "when outcome already set" do
      let(:session) do
        create(:call_session, :voicemail, call_plan: call_plan,
          outcome: { "status" => "voicemail", "summary" => "already set" })
      end

      it "does not call OutcomeExtractor" do
        expect(OutcomeExtractor).not_to receive(:call)
        described_class.perform_now(session.id)
        expect(session.reload.outcome["summary"]).to eq("already set")
      end
    end

    context "unsupported session status" do
      let(:session) { create(:call_session, call_plan: call_plan) }

      it "does not call OutcomeExtractor" do
        expect(OutcomeExtractor).not_to receive(:call)
        described_class.perform_now(session.id)
      end
    end
  end
end
