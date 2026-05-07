require "test_helper"
require "services/voice_agent_provider_contract"

class VapiAdapterTest < ActiveSupport::TestCase
  include VoiceAgentProviderContract

  def setup
    @user = User.create!(email: "vapi@example.com", password: "password123")
    @delegation = Delegation.create!(user: @user)
    @call_plan = CallPlan.create!(
      delegation: @delegation,
      target_name: "Maplewood Auto",
      target_phone: "555-867-5309",
      caller_name: "Alex",
      goal: "Check if the car is ready",
      forbidden_actions: ["Approve new repairs"],
      allowed_to_share: ["My first name"],
      questions_to_ask: ["Is the car ready?"]
    )
    @call_plan.update_column(:status, "approved")

    @adapter = VapiAdapter.new(call_plan: @call_plan)
  end

  test "disclosure message includes caller name and goal" do
    msg = @adapter.send(:disclosure_message)
    assert_includes msg, "Alex"
    assert_includes msg, "Check if the car is ready"
  end

  test "system prompt includes forbidden actions" do
    prompt = @adapter.send(:build_system_prompt)
    assert_includes prompt, "Approve new repairs"
    assert_includes prompt, "NEVER"
  end

  test "system prompt includes questions to ask" do
    prompt = @adapter.send(:build_system_prompt)
    assert_includes prompt, "Is the car ready?"
  end

  test "system prompt includes allowed to share" do
    prompt = @adapter.send(:build_system_prompt)
    assert_includes prompt, "My first name"
  end

  private

  def stub_adapter_server_error
    Net::HTTP.stub(:start, ->(*) { raise_server_error }) {}
    @adapter.stub(:post, ->(*) { raise VoiceAgentProvider::ApiError, "500" }) {}
  end

  def stub_adapter_client_error
    @adapter.stub(:post, ->(*) { raise VoiceAgentProvider::PermanentError, "422" }) {}
  end

  # Contract test helpers — stub post directly so no real HTTP fires
  def test_returns_call_id_on_success
    fake_call_id = "vapi-call-abc123"
    @adapter.stub(:post, ->(*) { {"id" => fake_call_id} }) do
      result = @adapter.call(call_plan: @call_plan)
      assert_equal fake_call_id, result[:call_id]
    end
  end

  def test_raises_api_error_on_server_error
    @adapter.stub(:post, ->(*) { raise VoiceAgentProvider::ApiError, "500" }) do
      assert_raises(VoiceAgentProvider::ApiError) { @adapter.call(call_plan: @call_plan) }
    end
  end

  def test_raises_permanent_error_on_client_error
    @adapter.stub(:post, ->(*) { raise VoiceAgentProvider::PermanentError, "422" }) do
      assert_raises(VoiceAgentProvider::PermanentError) { @adapter.call(call_plan: @call_plan) }
    end
  end
end
