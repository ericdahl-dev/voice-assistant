require "rails_helper"

RSpec.describe EscalationTimeoutJob, type: :job do
  let(:call_plan) { create(:call_plan, :approved) }
  let(:call_session) do
    create(:call_session, call_plan: call_plan, status: "needs_user", vapi_call_id: "vapi-timeout-1")
  end
  let(:escalation) { create(:escalation, :notified, call_session: call_session) }

  describe "#perform" do
    context "when unresolved" do
      it "marks timed_out and sends fallback via Vapi" do
        expect(VapiAdapter).to receive(:send_message).with(
          vapi_call_id: "vapi-timeout-1",
          message: a_string_including("did not reply")
        )
        described_class.perform_now(escalation.id)
        expect(escalation.reload.timed_out).to be true
      end
    end

    context "when already resolved" do
      let(:escalation) { create(:escalation, :resolved, call_session: call_session) }

      it "does nothing" do
        expect(VapiAdapter).not_to receive(:send_message)
        described_class.perform_now(escalation.id)
        expect(escalation.reload.timed_out).to be false
      end
    end

    context "when already timed_out" do
      let(:escalation) { create(:escalation, :timed_out, call_session: call_session) }

      it "does nothing" do
        expect(VapiAdapter).not_to receive(:send_message)
        described_class.perform_now(escalation.id)
      end
    end
  end
end
