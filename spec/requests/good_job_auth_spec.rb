require "rails_helper"

RSpec.describe "GoodJob dashboard authorization", type: :request do
  describe "GET /good_job" do
    it "redirects unauthenticated users to sign in" do
      get "/good_job"
      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to end_with("/users/sign_in")
    end

    it "returns not found for signed-in non-admin users" do
      sign_in create(:user)
      get "/good_job"
      expect(response).to have_http_status(:not_found)
    end

    it "allows signed-in admin users" do
      sign_in create(:user, :admin)
      get "/good_job"
      follow_redirect! while response.redirect?
      expect(response).to be_successful
    end
  end
end
