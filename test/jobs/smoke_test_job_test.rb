require "test_helper"

class SmokeTestJobTest < ActiveJob::TestCase
  test "performs without error" do
    assert_nothing_raised { SmokeTestJob.perform_now }
  end
end
