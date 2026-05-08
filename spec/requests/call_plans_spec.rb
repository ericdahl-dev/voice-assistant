require "rails_helper"

RSpec.describe "CallPlans", type: :request do
  let(:user) { create(:user) }
  let(:delegation) { create(:delegation, user: user) }

  before { sign_in user }

  describe "GET /delegations/:id/call_plan/new" do
    context "without a call template" do
      it "returns 200 and builds a blank call plan" do
        get new_delegation_call_plan_path(delegation)
        expect(response).to have_http_status(:ok)
      end
    end

    context "with a call template" do
      let(:template) { create(:call_template) }
      let(:delegation) { create(:delegation, user: user, call_template: template) }

      it "returns 200 and pre-fills from the template" do
        get new_delegation_call_plan_path(delegation)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /delegations/:id/call_plan" do
    let(:valid_params) do
      {
        call_plan: {
          target_name: "Maplewood Auto",
          target_phone: "+15558675309",
          caller_name: "Alex",
          goal: "Check if the car is ready",
          fallback: "Leave a voicemail",
          voicemail_only: false,
          allowed_to_share: [],
          questions_to_ask: [],
          allowed_decisions: [],
          forbidden_actions: []
        }
      }
    end

    context "with valid params" do
      it "creates a CallPlan and redirects to show" do
        expect { post delegation_call_plan_path(delegation), params: valid_params }
          .to change(CallPlan, :count).by(1)
        expect(response).to redirect_to(delegation_call_plan_path(delegation))
        expect(flash[:notice]).to match(/saved/i)
      end
    end

    context "with invalid params (missing target_name)" do
      it "re-renders new with unprocessable_entity" do
        post delegation_call_plan_path(delegation), params: {
          call_plan: valid_params[:call_plan].merge(target_name: "")
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /delegations/:id/call_plan" do
    context "when a call plan exists" do
      let!(:call_plan) { create(:call_plan, :approved, delegation: delegation) }
      let!(:active_session) { create(:call_session, call_plan: call_plan, status: "connected", vapi_call_id: "vapi-active") }
      let!(:done_session) { create(:call_session, call_plan: call_plan, status: "completed", vapi_call_id: "vapi-done") }

      it "returns 200" do
        get delegation_call_plan_path(delegation)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /delegations/:id/call_plan/edit" do
    context "when call plan is drafted" do
      let!(:call_plan) { create(:call_plan, delegation: delegation) }

      it "returns 200" do
        get edit_delegation_call_plan_path(delegation)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when call plan is approved" do
      let!(:call_plan) { create(:call_plan, :approved, delegation: delegation) }

      it "redirects with alert" do
        get edit_delegation_call_plan_path(delegation)
        expect(response).to redirect_to(delegation_call_plan_path(delegation))
        expect(flash[:alert]).to match(/cannot be edited/i)
      end
    end
  end

  describe "PATCH /delegations/:id/call_plan" do
    let!(:call_plan) { create(:call_plan, delegation: delegation) }

    context "with valid update" do
      it "updates and redirects" do
        patch delegation_call_plan_path(delegation), params: {
          call_plan: {
            target_name: "New Shop",
            target_phone: "+15558675309",
            caller_name: "Alex",
            goal: "Updated goal",
            allowed_to_share: [],
            questions_to_ask: [],
            allowed_decisions: [],
            forbidden_actions: []
          }
        }
        expect(response).to redirect_to(delegation_call_plan_path(delegation))
        expect(call_plan.reload.target_name).to eq("New Shop")
      end
    end

    context "when call plan is approved" do
      let!(:call_plan) { create(:call_plan, :approved, delegation: delegation) }

      it "blocks update and redirects with alert" do
        patch delegation_call_plan_path(delegation), params: {
          call_plan: { target_name: "Hack" }
        }
        expect(response).to redirect_to(delegation_call_plan_path(delegation))
        expect(flash[:alert]).to match(/cannot be edited/i)
      end
    end

    context "with invalid update" do
      it "re-renders edit with unprocessable_entity" do
        patch delegation_call_plan_path(delegation), params: {
          call_plan: {
            target_name: "",
            target_phone: "+15558675309",
            caller_name: "Alex",
            goal: "Goal",
            allowed_to_share: [],
            questions_to_ask: [],
            allowed_decisions: [],
            forbidden_actions: []
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "cross-user isolation" do
    let(:other_user) { create(:user) }
    let(:other_delegation) { create(:delegation, user: other_user) }

    it "returns 404 for show on another user's delegation" do
      get delegation_call_plan_path(other_delegation)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for new on another user's delegation" do
      get new_delegation_call_plan_path(other_delegation)
      expect(response).to have_http_status(:not_found)
    end
  end
end
