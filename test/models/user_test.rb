require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid user requires email and password" do
    user = User.new(email: "test@example.com", password: "password123")
    assert user.valid?
  end

  test "invalid without email" do
    user = User.new(password: "password123")
    assert_not user.valid?
  end
end
