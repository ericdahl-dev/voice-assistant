require "rails_helper"

RSpec.describe "Navigation", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "authenticated nav" do
    it "includes a link to delegations" do
      get delegations_path
      expect(response.body).to include(delegations_path)
    end

    it "includes a link to notification settings" do
      get delegations_path
      expect(response.body).to include(settings_notifications_path)
    end

    it "includes a sign out link" do
      get delegations_path
      expect(response.body).to include(destroy_user_session_path)
    end
  end
end
