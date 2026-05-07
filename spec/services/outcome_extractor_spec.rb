require "rails_helper"

RSpec.describe OutcomeExtractor, type: :service do
  let(:call_plan) do
    build(:call_plan, :approved,
      goal: "Find out if the car is ready for pickup",
      questions_to_ask: [ "What is the total cost?", "What time do you close?" ])
  end

  let(:clear_transcript) do
    "Agent: Hi, I'm calling to check if the Honda Odyssey is ready for pickup.\n" \
    "Staff: Yes, it's ready! The total is $284.17 and we close at 5:30 PM.\n" \
    "Agent: Great, thank you!"
  end

  let(:unclear_transcript) do
    "Agent: Hi, is the car ready?\n" \
    "Staff: I'm not sure, let me check... actually I can't find the record.\n" \
    "Agent: Okay, I'll have the owner call back."
  end

  let(:openai_response) do
    {
      "choices" => [
        {
          "message" => {
            "content" => JSON.generate({
              "status" => "completed",
              "outcome" => "Car is ready for pickup.",
              "follow_up_needed" => false,
              "summary" => "The Honda Odyssey is ready. Total is $284.17. Pickup before 5:30 PM.",
              "important_details" => [ "Total: $284.17", "Closes at 5:30 PM" ],
              "confidence" => "high"
            })
          }
        }
      ]
    }
  end

  let(:low_confidence_response) do
    {
      "choices" => [
        {
          "message" => {
            "content" => JSON.generate({
              "status" => "unknown",
              "outcome" => "Could not determine if the car is ready.",
              "follow_up_needed" => true,
              "summary" => "The staff could not locate the record. A human follow-up is needed.",
              "important_details" => [],
              "confidence" => "low"
            })
          }
        }
      ]
    }
  end

  def stub_openai(response_body, status: 200)
    fake_response = instance_double(Net::HTTPResponse,
      code: status.to_s,
      body: response_body.to_json)
    allow_any_instance_of(Net::HTTP).to receive(:request).and_return(fake_response)
  end

  before do
    allow(Rails.application.credentials).to receive(:dig).with(:openai_api_key).and_return("test-key")
  end

  describe ".call with voicemail session_status" do
    context "with transcript" do
      before do
        fake_response = instance_double(Net::HTTPResponse,
          code: "200",
          body: { "choices" => [ { "message" => { "content" => "Left a voicemail about car pickup." } } ] }.to_json)
        allow_any_instance_of(Net::HTTP).to receive(:request).and_return(fake_response)
      end

      it "returns status=voicemail with summary" do
        result = described_class.call(transcript: "Hi this is an AI...", call_plan: call_plan, session_status: "voicemail")
        expect(result["status"]).to eq("voicemail")
        expect(result["summary"]).to be_present
      end
    end

    context "without transcript" do
      it "returns fallback without calling OpenAI" do
        expect_any_instance_of(Net::HTTP).not_to receive(:request)
        result = described_class.call(transcript: nil, call_plan: call_plan, session_status: "voicemail")
        expect(result["status"]).to eq("voicemail")
        expect(result["summary"]).to include("voicemail")
      end
    end
  end

  describe ".call" do
    context "with a clear transcript" do
      before { stub_openai(openai_response) }

      it "returns a valid outcome hash" do
        result = described_class.call(transcript: clear_transcript, call_plan: call_plan)
        expect(result).to include(
          "status" => "completed",
          "confidence" => "high",
          "follow_up_needed" => false
        )
      end

      it "includes important details" do
        result = described_class.call(transcript: clear_transcript, call_plan: call_plan)
        expect(result["important_details"]).to include("Total: $284.17")
      end

      it "sets follow_up_needed to false when outcome is clear" do
        result = described_class.call(transcript: clear_transcript, call_plan: call_plan)
        expect(result["follow_up_needed"]).to be false
      end
    end

    context "with an unclear transcript" do
      before { stub_openai(low_confidence_response) }

      it "sets confidence to low" do
        result = described_class.call(transcript: unclear_transcript, call_plan: call_plan)
        expect(result["confidence"]).to eq("low")
      end

      it "sets follow_up_needed to true" do
        result = described_class.call(transcript: unclear_transcript, call_plan: call_plan)
        expect(result["follow_up_needed"]).to be true
      end
    end

    context "when OpenAI returns an error" do
      before { stub_openai({}, status: 500) }

      it "raises ExtractionError" do
        expect {
          described_class.call(transcript: clear_transcript, call_plan: call_plan)
        }.to raise_error(OutcomeExtractor::ExtractionError)
      end
    end

    context "when OpenAI returns invalid JSON" do
      before do
        fake_response = instance_double(Net::HTTPResponse, code: "200", body: '{"choices":[{"message":{"content":"not json"}}]}')
        allow_any_instance_of(Net::HTTP).to receive(:request).and_return(fake_response)
      end

      it "raises ExtractionError" do
        expect {
          described_class.call(transcript: clear_transcript, call_plan: call_plan)
        }.to raise_error(OutcomeExtractor::ExtractionError)
      end
    end
  end
end
