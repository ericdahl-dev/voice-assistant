require "rails_helper"

RSpec.describe PlaceCallJob, type: :job do
  let(:call_plan) { create(:call_plan, :approved) }

  describe "#perform" do
    context "on success" do
      before do
        allow(VapiAdapter).to receive(:call).and_return({ call_id: "vapi-xyz-789" })
      end

      it "creates a CallSession and transitions to dialing" do
        described_class.perform_now(call_plan.id)

        session = call_plan.call_sessions.reload.first
        expect(session.status).to eq("dialing")
        expect(session.vapi_call_id).to eq("vapi-xyz-789")
        expect(session.started_at).not_to be_nil
      end
    end

    context "on permanent error" do
      before do
        allow(VapiAdapter).to receive(:call).and_raise(VoiceAgentProvider::PermanentError, "bad number")
      end

      it "transitions session to failed and does not re-raise" do
        described_class.perform_now(call_plan.id)

        expect(call_plan.call_sessions.reload.first.status).to eq("failed")
      end
    end

    context "idempotency" do
      it "does not create a second session if one already exists past drafted" do
        allow(VapiAdapter).to receive(:call).and_return({ call_id: "vapi-xyz-789" })

        described_class.perform_now(call_plan.id)
        described_class.perform_now(call_plan.id)

        expect(call_plan.call_sessions.count).to eq(1)
      end
    end
  end

  describe "enqueuing" do
    it "is enqueued by CallPlan#approve!" do
      plan = create(:call_plan)
      expect { plan.approve! }.to have_enqueued_job(described_class).with(plan.id)
    end
  end
end
