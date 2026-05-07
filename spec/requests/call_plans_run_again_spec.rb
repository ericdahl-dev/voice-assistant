require "rails_helper"

RSpec.describe "CallPlans run_again", type: :request do
  let(:user) { create(:user) }
  let(:delegation) { create(:delegation, user: user) }
  let(:call_plan) { create(:call_plan, :approved, delegation: delegation) }

  before { sign_in user }

  def run_again
    post run_again_delegation_call_plan_path(delegation)
  end

  context "when no active session exists" do
    before { create(:call_session, call_plan: call_plan, status: "completed") }

    it "creates a new drafted CallSession" do
      expect { run_again }.to change(CallSession, :count).by(1)
      new_session = call_plan.call_sessions.order(:created_at).last
      expect(new_session.status).to eq("drafted")
    end

    it "enqueues PlaceCallJob with session_id" do
      expect { run_again }.to have_enqueued_job(PlaceCallJob)
    end

    it "redirects to the new session" do
      run_again
      new_session = call_plan.call_sessions.order(:created_at).last
      expect(response).to redirect_to(call_session_path(new_session))
    end
  end

  context "when a session is already active" do
    %w[drafted queued dialing connected in_conversation needs_user].each do |active_status|
      it "blocks run_again when a session is #{active_status}" do
        create(:call_session, call_plan: call_plan, status: active_status, vapi_call_id: "vapi-#{active_status}")
        expect { run_again }.not_to change(CallSession, :count)
        expect(response).to redirect_to(delegation_call_plan_path(delegation))
        expect(flash[:alert]).to match(/already in progress/i)
      end
    end
  end

  context "with various terminal prior sessions" do
    %w[completed failed voicemail].each do |terminal_status|
      it "allows run_again when prior session is #{terminal_status}" do
        create(:call_session, call_plan: call_plan, status: terminal_status, vapi_call_id: "vapi-#{terminal_status}")
        expect { run_again }.to change(CallSession, :count).by(1)
      end
    end
  end

  context "cross-user isolation" do
    let(:other_user) { create(:user) }
    let(:other_delegation) { create(:delegation, user: other_user) }
    let(:other_plan) { create(:call_plan, :approved, delegation: other_delegation) }

    it "returns 404 for another user's call plan" do
      post run_again_delegation_call_plan_path(other_delegation)
      expect(response).to have_http_status(:not_found)
    end
  end
end
