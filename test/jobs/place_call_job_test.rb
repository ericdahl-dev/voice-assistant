require "test_helper"

class PlaceCallJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    @user = User.create!(email: "job@example.com", password: "password123")
    @delegation = Delegation.create!(user: @user)
    @call_plan = CallPlan.new(
      delegation: @delegation,
      target_name: "Maplewood Auto",
      target_phone: "555-867-5309",
      caller_name: "Alex",
      goal: "Check if the car is ready"
    )
    # Bypass approve! to avoid enqueuing a second job during setup
    @call_plan.save!
    @call_plan.update_columns(status: "approved", approved_at: Time.current)
  end

  test "approve! enqueues PlaceCallJob" do
    call_plan = CallPlan.new(
      delegation: @delegation,
      target_name: "Maplewood Auto",
      target_phone: "555-867-5309",
      caller_name: "Alex",
      goal: "Check if the car is ready"
    )
    call_plan.save!

    assert_enqueued_with(job: PlaceCallJob) { call_plan.approve! }
  end

  test "job creates a CallSession and transitions to dialing on success" do
    VapiAdapter.stub(:call, ->(**) { { call_id: "vapi-xyz-789" } }) do
      PlaceCallJob.perform_now(@call_plan.id)
    end

    session = @call_plan.call_sessions.reload.first
    assert_not_nil session
    assert_equal "dialing", session.status
    assert_equal "vapi-xyz-789", session.vapi_call_id
    assert_not_nil session.started_at
  end

  test "job transitions session to failed on permanent error" do
    VapiAdapter.stub(:call, ->(**) { raise VoiceAgentProvider::PermanentError, "bad number" }) do
      PlaceCallJob.perform_now(@call_plan.id)
    end

    session = @call_plan.call_sessions.reload.first
    assert_equal "failed", session.status
  end

  test "job is idempotent — second run skips if session already past drafted" do
    VapiAdapter.stub(:call, ->(**) { { call_id: "vapi-xyz-789" } }) do
      PlaceCallJob.perform_now(@call_plan.id)
      PlaceCallJob.perform_now(@call_plan.id)
    end

    assert_equal 1, @call_plan.call_sessions.count
  end
end
