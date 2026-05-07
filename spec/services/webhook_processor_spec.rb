require "rails_helper"

RSpec.describe WebhookProcessor do
  let(:call_plan) { create(:call_plan, :approved) }
  let(:call_session) { create(:call_session, call_plan: call_plan, status: "dialing", vapi_call_id: "vapi-123") }

  def event(type, extra = {})
    { "type" => type, "call" => { "id" => call_session.vapi_call_id } }.merge(extra)
  end

  describe "#process" do
    context "with unknown vapi_call_id" do
      it "does nothing" do
        evt = { "type" => "call.started", "call" => { "id" => "not-found" } }
        expect { described_class.new(evt).process }.not_to(change { CallSession.count })
      end
    end

    context "with missing call.id" do
      it "does nothing" do
        expect { described_class.new({ "type" => "call.started" }).process }.not_to raise_error
      end
    end

    context "call.started" do
      let(:call_session) { create(:call_session, call_plan: call_plan, status: "queued", vapi_call_id: "vapi-123") }

      it "transitions to dialing" do
        described_class.new(event("call.started")).process
        expect(call_session.reload.status).to eq("dialing")
      end
    end

    context "call.connected" do
      it "transitions to connected" do
        described_class.new(event("call.connected")).process
        expect(call_session.reload.status).to eq("connected")
      end
    end

    context "call.ended" do
      context "when ended reason is voicemail" do
        before { call_session.update!(status: "connected") }

        it "transitions to voicemail" do
          described_class.new(event("call.ended", "call" => { "id" => call_session.vapi_call_id, "endedReason" => "voicemail" })).process
          expect(call_session.reload.status).to eq("voicemail")
        end
      end

      context "when in connected state" do
        before { call_session.update!(status: "connected") }

        it "transitions to completed" do
          described_class.new(event("call.ended")).process
          expect(call_session.reload.status).to eq("completed")
        end
      end

      context "when in dialing state (never answered)" do
        it "transitions to failed" do
          described_class.new(event("call.ended")).process
          expect(call_session.reload.status).to eq("failed")
        end
      end

      context "when already in terminal state" do
        before { call_session.update!(status: "completed") }

        it "is idempotent — does not raise" do
          expect { described_class.new(event("call.ended")).process }.not_to raise_error
          expect(call_session.reload.status).to eq("completed")
        end
      end
    end

    context "call.declined" do
      it "transitions to completed with declined outcome" do
        described_class.new(event("call.declined")).process
        session = call_session.reload
        expect(session.status).to eq("completed")
        expect(session.outcome["status"]).to eq("declined")
        expect(session.outcome["summary"]).to include("declined")
      end

      it "is idempotent when already completed" do
        call_session.update!(status: "completed")
        expect { described_class.new(event("call.declined")).process }.not_to raise_error
      end
    end

    context "transcript.chunk" do
      before { call_session.update!(status: "connected") }

      it "appends chunk to transcript" do
        described_class.new(event("transcript.chunk", "transcript" => { "text" => "Hello there" })).process
        expect(call_session.reload.transcript).to eq("Hello there")
      end

      it "concatenates successive chunks" do
        call_session.update!(transcript: "Hello")
        described_class.new(event("transcript.chunk", "transcript" => { "text" => " world" })).process
        expect(call_session.reload.transcript).to eq("Hello world")
      end

      it "ignores blank chunks" do
        described_class.new(event("transcript.chunk", "transcript" => { "text" => "" })).process
        expect(call_session.reload.transcript).to be_nil
      end
    end

    context "escalation.triggered" do
      before { call_session.update!(status: "in_conversation") }

      it "transitions to needs_user" do
        described_class.new(event("escalation.triggered")).process
        expect(call_session.reload.status).to eq("needs_user")
      end
    end

    context "unknown event type" do
      it "logs and returns without raising" do
        expect(Rails.logger).to receive(:info).with(/Unknown event type/)
        described_class.new(event("some.unknown")).process
      end
    end

    context "duplicate event (idempotency)" do
      before { call_session.update!(status: "connected") }

      it "does not double-transition" do
        described_class.new(event("call.connected")).process
        expect(call_session.reload.status).to eq("connected")
      end
    end
  end
end
