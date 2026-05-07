require "rails_helper"

RSpec.describe "CallSessions retry", type: :request do
  let(:user) { create(:user) }
  let(:delegation) { create(:delegation, user: user) }
  let(:call_plan) { create(:call_plan, :approved, delegation: delegation) }

  before { sign_in user }

  shared_examples_for "successful retry" do |status|
    let(:session) { create(:call_session, call_plan: call_plan, status: status, vapi_call_id: "vapi-#{status}") }
    before { session }

    it "creates a new drafted CallSession" do
      expect {
        post retry_call_session_path(session)
      }.to change(CallSession, :count).by(1)

      new_session = call_plan.call_sessions.order(:created_at).last
      expect(new_session.status).to eq("drafted")
      expect(response).to redirect_to(call_session_path(new_session))
    end

    it "enqueues PlaceCallJob with session_id" do
      expect {
        post retry_call_session_path(session)
      }.to have_enqueued_job(PlaceCallJob)
    end

    it "does not modify the original session" do
      allow(PlaceCallJob).to receive(:perform_later)
      post retry_call_session_path(session)
      expect(session.reload.status).to eq(status)
    end
  end

  it_behaves_like "successful retry", "voicemail"
  it_behaves_like "successful retry", "failed"
  it_behaves_like "successful retry", "completed"

  context "when session is in progress" do
    let(:session) do
      create(:call_session, call_plan: call_plan, status: "in_conversation", vapi_call_id: "vapi-ip")
    end
    before { session }

    it "redirects with alert and does not create session" do
      expect {
        post retry_call_session_path(session)
      }.not_to change(CallSession, :count)

      expect(response).to redirect_to(call_session_path(session))
      expect(flash[:alert]).to match(/cannot retry/i)
    end
  end

  context "cross-user isolation" do
    let(:other_user) { create(:user) }
    let(:other_session) do
      other_plan = create(:call_plan, :approved, delegation: create(:delegation, user: other_user))
      create(:call_session, call_plan: other_plan, status: "voicemail")
    end

    it "returns 404" do
      post retry_call_session_path(other_session)
      expect(response).to have_http_status(:not_found)
    end
  end
end
