require "test_helper"

class CallPlanTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "callplan@example.com", password: "password123")
    @delegation = Delegation.create!(user: @user)
  end

  def valid_call_plan(overrides = {})
    CallPlan.new(
      {
        delegation: @delegation,
        target_name: "Maplewood Auto",
        target_phone: "555-867-5309",
        caller_name: "Alex",
        goal: "Find out if the car is ready for pickup"
      }.merge(overrides)
    )
  end

  test "valid call plan with all required fields" do
    assert valid_call_plan.valid?
  end

  test "requires a target name" do
    assert_not valid_call_plan(target_name: nil).valid?
  end

  test "requires a target phone number" do
    assert_not valid_call_plan(target_phone: nil).valid?
  end

  test "requires a caller name" do
    assert_not valid_call_plan(caller_name: nil).valid?
  end

  test "requires a goal" do
    assert_not valid_call_plan(goal: nil).valid?
  end

  test "starts in drafted status" do
    plan = valid_call_plan
    plan.save!

    assert_equal "drafted", plan.status
    assert plan.drafted?
    assert_not plan.approved?
  end

  test "approve! moves a drafted plan to approved and records the timestamp" do
    plan = valid_call_plan
    plan.save!

    plan.approve!

    assert plan.approved?
    assert_not plan.drafted?
    assert_not_nil plan.approved_at
  end

  test "approve! raises AlreadyApprovedError when called on an already-approved plan" do
    plan = valid_call_plan
    plan.save!
    plan.approve!

    assert_raises(CallPlan::AlreadyApprovedError) { plan.approve! }
  end

  test "jsonb fields default to empty arrays" do
    plan = valid_call_plan
    plan.save!

    assert_equal [], plan.allowed_to_share
    assert_equal [], plan.questions_to_ask
    assert_equal [], plan.allowed_decisions
    assert_equal [], plan.forbidden_actions
  end

  test "jsonb fields round-trip through the database" do
    plan = valid_call_plan
    plan.allowed_to_share = [ "my name", "appointment date" ]
    plan.questions_to_ask = [ "Is the part in stock?" ]
    plan.save!
    plan.reload

    assert_equal [ "my name", "appointment date" ], plan.allowed_to_share
    assert_equal [ "Is the part in stock?" ], plan.questions_to_ask
  end
end
