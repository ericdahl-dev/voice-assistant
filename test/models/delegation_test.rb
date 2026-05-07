require "test_helper"

class DelegationTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "delegation@example.com", password: "password123")
  end

  test "valid delegation requires a user" do
    delegation = Delegation.new(user: @user)
    assert delegation.valid?
  end

  test "invalid without a user" do
    delegation = Delegation.new
    assert_not delegation.valid?
  end

  test "call_template association is optional" do
    delegation = Delegation.new(user: @user, call_template_id: nil)
    assert delegation.valid?
  end
end
