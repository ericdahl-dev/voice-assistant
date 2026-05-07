require "rails_helper"

RSpec.describe WebhookProcessor do
  let(:call_plan) { create(:call_plan, :approved) }
  let(:call_session) { create(:call_session, call_plan: call_plan, status: "dialing", vapi_call_id: "vapi-123") }

  # Vapi wraps all events in a top-level "message" key
  def event(type, extra_message = {})
    {
      "message" => {
        "type" => type,
        "call" => { "id" => call_session.vapi_call_id }
      }.merge(extra_message)
    }
  end

  describe "#process" do
    context "with missing message key" do
      it "does nothing" do
        expect { described_class.new({}).process }.not_to raise_error
      end
    end

    context "with unknown vapi_call_id" do
      it "does nothing" do
        evt = { "message" => { "type" => "status-update", "call" => { "id" => "not-found" }, "status" => "ringing" } }
        expect { described_class.new(evt).process }.not_to(change { CallSession.count })
      end
    end

    context "with missing call.id" do
      it "does nothing" do
        expect { described_class.new({ "message" => { "type" => "status-update" } }).process }.not_to raise_error
      end
    end

    context "status-update: ringing" do
      let(:call_session) { create(:call_session, call_plan: call_plan, status: "queued", vapi_call_id: "vapi-123") }

      it "transitions to dialing" do
        described_class.new(event("status-update", "status" => "ringing")).process
        expect(call_session.reload.status).to eq("dialing")
      end
    end

    context "status-update: in-progress" do
      it "transitions to connected" do
        described_class.new(event("status-update", "status" => "in-progress")).process
        expect(call_session.reload.status).to eq("connected")
      end
    end

    context "status-update: ended" do
      it "is a no-op (end-of-call-report handles terminal state)" do
        described_class.new(event("status-update", "status" => "ended")).process
        expect(call_session.reload.status).to eq("dialing")
      end
    end

    context "end-of-call-report" do
      context "when ended from a connected state" do
        before { call_session.update!(status: "in_conversation") }

        it "transitions to completed and enqueues outcome extraction" do
          expect { described_class.new(event("end-of-call-report")).process }
            .to have_enqueued_job(ExtractOutcomeJob)
          expect(call_session.reload.status).to eq("completed")
        end
      end

      context "when ended from dialing (never answered)" do
        it "transitions to failed" do
          described_class.new(event("end-of-call-report")).process
          expect(call_session.reload.status).to eq("failed")
        end
      end

      context "when call_plan is voicemail_only" do
        let(:call_plan) { create(:call_plan, :approved, :voicemail_only) }

        before { call_session.update!(status: "connected") }

        it "transitions to voicemail regardless of endedReason" do
          described_class.new(event("end-of-call-report")).process
          expect(call_session.reload.status).to eq("voicemail")
        end

        it "enqueues outcome extraction" do
          expect { described_class.new(event("end-of-call-report")).process }
            .to have_enqueued_job(ExtractOutcomeJob)
        end
      end

      context "when endedReason includes voicemail" do
        before { call_session.update!(status: "connected") }

        it "transitions to voicemail" do
          described_class.new(event("end-of-call-report",
            "call" => { "id" => call_session.vapi_call_id, "endedReason" => "voicemail" })).process
          expect(call_session.reload.status).to eq("voicemail")
        end
      end

      context "with an artifact transcript" do
        before { call_session.update!(status: "in_conversation") }

        it "saves the transcript from the artifact" do
          described_class.new(event("end-of-call-report",
            "artifact" => { "transcript" => "Hello there." })).process
          expect(call_session.reload.transcript).to eq("Hello there.")
        end

        it "does not overwrite an existing transcript" do
          call_session.update!(transcript: "existing")
          described_class.new(event("end-of-call-report",
            "artifact" => { "transcript" => "new" })).process
          expect(call_session.reload.transcript).to eq("existing")
        end
      end

      context "when already in terminal state" do
        before { call_session.update!(status: "completed") }

        it "is idempotent — does not raise" do
          expect { described_class.new(event("end-of-call-report")).process }.not_to raise_error
          expect(call_session.reload.status).to eq("completed")
        end
      end
    end

    context "transcript (final)" do
      before { call_session.update!(status: "in_conversation") }

      it "appends final transcript chunks" do
        described_class.new(event("transcript",
          "transcriptType" => "final",
          "transcript" => "Hello there")).process
        expect(call_session.reload.transcript).to eq("Hello there")
      end

      it "concatenates successive final chunks" do
        call_session.update!(transcript: "Hello")
        described_class.new(event("transcript",
          "transcriptType" => "final",
          "transcript" => "world")).process
        expect(call_session.reload.transcript).to eq("Hello world")
      end

      it "ignores partial transcript events" do
        described_class.new(event("transcript",
          "transcriptType" => "partial",
          "transcript" => "Hel")).process
        expect(call_session.reload.transcript).to be_nil
      end

      it "ignores blank transcripts" do
        described_class.new(event("transcript",
          "transcriptType" => "final",
          "transcript" => "")).process
        expect(call_session.reload.transcript).to be_nil
      end
    end

    context "tool-calls with escalate tool" do
      before { call_session.update!(status: "in_conversation") }

      it "transitions to needs_user" do
        described_class.new(event("tool-calls",
          "toolCallList" => [
            { "name" => "escalate", "parameters" => { "question" => "Do you authorise payment?" } }
          ])).process
        expect(call_session.reload.status).to eq("needs_user")
      end

      it "ignores non-escalate tool calls" do
        described_class.new(event("tool-calls",
          "toolCallList" => [
            { "name" => "lookupOrder", "parameters" => {} }
          ])).process
        expect(call_session.reload.status).to eq("in_conversation")
      end
    end

    context "unknown event type" do
      it "logs and returns without raising" do
        expect(Rails.logger).to receive(:info).with(/Unknown event type/)
        described_class.new(event("some.unknown")).process
      end
    end

    context "duplicate event (idempotency)" do
      before { call_session.update!(status: "in_conversation") }

      it "does not double-transition on repeated status-update" do
        described_class.new(event("status-update", "status" => "in-progress")).process
        expect(call_session.reload.status).to eq("in_conversation")
      end
    end
  end
end
