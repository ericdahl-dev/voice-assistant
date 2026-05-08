require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    context "when not signed in" do
      it "returns 200" do
        get root_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when signed in" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "redirects to delegations" do
        get root_path
        expect(response).to redirect_to(delegations_path)
      end
    end
  end
end
