require "rails_helper"

RSpec.describe "POST /escalations/:id/reply", type: :request do
  let(:user) { create(:user) }
  let(:call_plan) { create(:call_plan, :approved, delegation: create(:delegation, user: user)) }
  let(:call_session) do
    create(:call_session, call_plan: call_plan, status: "needs_user", vapi_call_id: "vapi-esc-123")
  end
  let(:escalation) { create(:escalation, :notified, call_session: call_session) }

  before { sign_in user }

  describe "successful reply" do
    before do
      allow(VapiAdapter).to receive(:send_message).and_return({})
    end

    it "stores the reply and transitions session to in_conversation" do
      post reply_escalation_path(escalation), params: { user_reply: "Yes, accept it." }

      expect(response).to redirect_to(call_session_path(call_session))
      escalation.reload
      expect(escalation.user_reply).to eq("Yes, accept it.")
      expect(escalation.resolved_at).not_to be_nil
      expect(call_session.reload.status).to eq("in_conversation")
    end

    it "injects message via VapiAdapter" do
      expect(VapiAdapter).to receive(:send_message).with(
        vapi_call_id: "vapi-esc-123",
        message: a_string_including("Yes, proceed")
      )
      post reply_escalation_path(escalation), params: { user_reply: "Yes, proceed" }
    end
  end

  describe "blank reply" do
    it "redirects back with alert" do
      post reply_escalation_path(escalation), params: { user_reply: "  " }
      expect(response).to redirect_to(call_session_path(call_session))
      expect(flash[:alert]).to match(/blank/)
    end
  end

  describe "timed-out escalation" do
    let(:escalation) { create(:escalation, :timed_out, call_session: call_session) }

    it "redirects with alert and does not call Vapi" do
      expect(VapiAdapter).not_to receive(:send_message)
      post reply_escalation_path(escalation), params: { user_reply: "Too late" }
      expect(response).to redirect_to(call_session_path(call_session))
      expect(flash[:alert]).to match(/timeout|passed/i)
    end
  end

  describe "cross-user isolation" do
    let(:other_user) { create(:user) }
    let(:other_escalation) do
      other_plan = create(:call_plan, :approved, delegation: create(:delegation, user: other_user))
      other_session = create(:call_session, call_plan: other_plan, status: "needs_user")
      create(:escalation, :notified, call_session: other_session)
    end

    it "returns 404 for another user's escalation" do
      post reply_escalation_path(other_escalation), params: { user_reply: "hack" }
      expect(response).to have_http_status(:not_found)
    end
  end
end
