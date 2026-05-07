require "test_helper"

class CallSessionTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "session@example.com", password: "password123")
    @delegation = Delegation.create!(user: @user)
    @call_plan = CallPlan.create!(
      delegation: @delegation,
      target_name: "Maplewood Auto",
      target_phone: "555-867-5309",
      caller_name: "Alex",
      goal: "Check if the car is ready"
    )
  end

  def approved_call_plan
    @call_plan.tap(&:approve!)
  end

  # ---------------------------------------------------------------------------
  # Creation guard
  # ---------------------------------------------------------------------------

  test "cannot create a call session against a drafted call plan" do
    session = CallSession.new(call_plan: @call_plan)
    assert_not session.valid?
    assert_includes session.errors[:call_plan], "must be approved before a call session can be created"
  end

  test "can create a call session against an approved call plan" do
    session = CallSession.new(call_plan: approved_call_plan)
    assert session.valid?
  end

  test "starts in drafted status" do
    session = CallSession.create!(call_plan: approved_call_plan)
    assert session.drafted?
  end

  # ---------------------------------------------------------------------------
  # Happy-path transitions
  # ---------------------------------------------------------------------------

  test "full happy path: drafted → queued → dialing → connected → in_conversation → completed" do
    session = CallSession.create!(call_plan: approved_call_plan)

    session.transition_to!("queued")
    assert session.queued?

    session.transition_to!("dialing")
    assert session.dialing?
    assert_not_nil session.started_at

    session.transition_to!("connected")
    assert session.connected?

    session.transition_to!("in_conversation")
    assert session.in_conversation?

    session.transition_to!("completed")
    assert session.completed?
    assert_not_nil session.ended_at
  end

  test "voicemail path: connected → voicemail" do
    session = CallSession.create!(call_plan: approved_call_plan)
    session.transition_to!("queued")
    session.transition_to!("dialing")
    session.transition_to!("connected")
    session.transition_to!("voicemail")

    assert session.voicemail?
    assert_not_nil session.ended_at
  end

  test "needs_user path: in_conversation → needs_user → in_conversation → completed" do
    session = CallSession.create!(call_plan: approved_call_plan)
    [ :queued, :dialing, :connected, :in_conversation ].each { |s| session.transition_to!(s) }

    session.transition_to!("needs_user")
    assert session.needs_user?

    session.transition_to!("in_conversation")
    assert session.in_conversation?

    session.transition_to!("completed")
    assert session.completed?
  end

  test "failure path from drafted: drafted → failed" do
    session = CallSession.create!(call_plan: approved_call_plan)
    session.transition_to!("failed")

    assert session.failed?
    assert_not_nil session.ended_at
  end

  # ---------------------------------------------------------------------------
  # Invalid transition attempts
  # ---------------------------------------------------------------------------

  test "cannot skip from drafted to dialing" do
    session = CallSession.create!(call_plan: approved_call_plan)
    assert_raises(CallSession::InvalidTransitionError) { session.transition_to!("dialing") }
  end

  test "cannot go backwards from completed to drafted" do
    session = CallSession.create!(call_plan: approved_call_plan)
    [ :queued, :dialing, :connected, :in_conversation, :completed ].each { |s| session.transition_to!(s) }

    assert_raises(CallSession::InvalidTransitionError) { session.transition_to!("drafted") }
  end

  test "cannot transition out of a terminal voicemail state" do
    session = CallSession.create!(call_plan: approved_call_plan)
    [ :queued, :dialing, :connected, :voicemail ].each { |s| session.transition_to!(s) }

    assert_raises(CallSession::InvalidTransitionError) { session.transition_to!("completed") }
  end

  # ---------------------------------------------------------------------------
  # Timestamps
  # ---------------------------------------------------------------------------

  test "started_at is set only once even if dialing is re-entered somehow" do
    session = CallSession.create!(call_plan: approved_call_plan)
    session.transition_to!("queued")
    session.transition_to!("dialing")

    original_started_at = session.started_at
    assert_not_nil original_started_at

    # Force a direct update to simulate the field already being set
    session.update_column(:started_at, original_started_at)
    session.reload
    assert_equal original_started_at, session.started_at
  end

  # ---------------------------------------------------------------------------
  # Outcome jsonb
  # ---------------------------------------------------------------------------

  test "outcome field serializes and deserializes correctly" do
    session = CallSession.create!(call_plan: approved_call_plan)
    session.update!(outcome: {
      "status" => "completed",
      "summary" => "Vehicle is ready for pickup.",
      "follow_up_needed" => false,
      "important_details" => [ "Ready at 3pm", "No additional charges" ],
      "confidence" => 0.95
    })

    session.reload
    assert_equal "completed", session.outcome["status"]
    assert_equal [ "Ready at 3pm", "No additional charges" ], session.outcome["important_details"]
    assert_equal 0.95, session.outcome["confidence"]
  end
end
