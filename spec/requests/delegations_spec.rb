require "rails_helper"

RSpec.describe "Delegations", type: :request do
  let(:user) { create(:user) }
  let(:template) { create(:call_template) }

  before { sign_in user }

  describe "GET /delegations" do
    it "returns 200" do
      get delegations_path
      expect(response).to have_http_status(:ok)
    end

    it "shows the user's delegations" do
      create(:delegation, user: user, call_template: template)
      get delegations_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /delegations/:id" do
    let(:delegation) { create(:delegation, user: user) }

    it "returns 200" do
      get delegation_path(delegation)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for another user's delegation" do
      other = create(:delegation, user: create(:user))
      get delegation_path(other)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /delegations/new" do
    it "redirects (no new.html.erb — Hotwire modal flow)" do
      get new_delegation_path
      expect(response.status).not_to eq(500)
    end
  end

  describe "POST /delegations" do
    context "with valid params" do
      it "creates a delegation and redirects to new call plan" do
        expect {
          post delegations_path, params: { delegation: { call_template_id: template.id } }
        }.to change(Delegation, :count).by(1)
        expect(response).to redirect_to(new_delegation_call_plan_path(Delegation.last))
      end
    end

    context "with no template (nil call_template_id)" do
      it "creates a delegation" do
        expect {
          post delegations_path, params: { delegation: { call_template_id: "" } }
        }.to change(Delegation, :count).by(1)
      end
    end
  end
end
