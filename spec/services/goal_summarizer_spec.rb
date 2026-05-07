require "rails_helper"

RSpec.describe GoalSummarizer, type: :service do
  let(:goal) { "Check if the car is ready for pickup and get the total cost" }

  describe ".call" do
    context "when OpenAI is available" do
      let(:openai_response) do
        {
          "choices" => [
            {
              "message" => {
                "content" => "a vehicle status check"
              }
            }
          ]
        }
      end

      before do
        stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => "test-key"))
        client = instance_double(OpenAI::Client)
        allow(OpenAI::Client).to receive(:new).and_return(client)
        allow(client).to receive(:chat).and_return(openai_response)
      end

      it "returns the LLM-generated summary" do
        expect(described_class.call(goal:)).to eq("a vehicle status check")
      end

      it "strips trailing punctuation from the result" do
        client = instance_double(OpenAI::Client)
        allow(OpenAI::Client).to receive(:new).and_return(client)
        allow(client).to receive(:chat).and_return(
          "choices" => [ { "message" => { "content" => "a vehicle status check." } } ]
        )
        result = described_class.call(goal:)
        expect(result).not_to end_with(".")
      end
    end

    context "when no API key is configured" do
      before do
        stub_const("ENV", ENV.to_h.except("OPENAI_API_KEY"))
        allow(Rails.application.credentials).to receive(:[]).with(:openai_api_key).and_return(nil)
      end

      it "returns the fallback (first line of goal, truncated)" do
        result = described_class.call(goal:)
        expect(result).to be_present
        expect(result).not_to include("\n")
      end
    end

    context "when OpenAI raises an error" do
      before do
        stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => "test-key"))
        client = instance_double(OpenAI::Client)
        allow(OpenAI::Client).to receive(:new).and_return(client)
        allow(client).to receive(:chat).and_raise(StandardError, "connection refused")
      end

      it "returns the fallback without raising" do
        expect { described_class.call(goal:) }.not_to raise_error
      end

      it "returns a non-empty string" do
        expect(described_class.call(goal:)).to be_present
      end
    end

    context "fallback truncation" do
      before do
        stub_const("ENV", ENV.to_h.except("OPENAI_API_KEY"))
        allow(Rails.application.credentials).to receive(:[]).with(:openai_api_key).and_return(nil)
      end

      it "truncates long goals to at most 60 characters on a word boundary" do
        long_goal = "This is a very long goal description that goes well beyond sixty characters in total length"
        result = described_class.call(goal: long_goal)
        expect(result.length).to be <= 60
      end

      it "strips leading list markers from the first line" do
        result = described_class.call(goal: "- Check on my prescription refill status")
        expect(result).not_to start_with("-")
      end
    end
  end
end
