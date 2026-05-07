require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "test@example.com", password: "password123")
  end

  test "redirects to login when unauthenticated" do
    get root_url
    assert_redirected_to new_user_session_url
  end

  test "renders dashboard when authenticated" do
    sign_in @user
    get root_url
    assert_response :success
  end
end
