require "test_helper"

# Shared contract every VoiceAgentProvider adapter must satisfy.
# Include this module in an adapter-specific test and set @adapter and @call_plan.
module VoiceAgentProviderContract
  def test_returns_call_id_on_success
    result = @adapter.call(call_plan: @call_plan)
    assert result.key?(:call_id), "expected result to have a :call_id key"
    assert_kind_of String, result[:call_id]
    assert result[:call_id].present?
  end

  def test_raises_api_error_on_server_error
    stub_adapter_server_error
    assert_raises(VoiceAgentProvider::ApiError) { @adapter.call(call_plan: @call_plan) }
  end

  def test_raises_permanent_error_on_client_error
    stub_adapter_client_error
    assert_raises(VoiceAgentProvider::PermanentError) { @adapter.call(call_plan: @call_plan) }
  end
end
