require "rails_helper"

RSpec.describe ExtractOutcomeJob, type: :job do
  let(:call_plan) { create(:call_plan, :approved) }
  let(:session) { create(:call_session, :completed, call_plan: call_plan, transcript: "Agent: Done.") }

  it "calls OutcomeExtractor and persists the outcome" do
    outcome = { "status" => "completed", "outcome" => "Done.", "follow_up_needed" => false,
                "summary" => "Call completed.", "important_details" => [], "confidence" => "high" }
    allow(OutcomeExtractor).to receive(:call).and_return(outcome)

    described_class.perform_now(session.id)

    expect(session.reload.outcome).to eq(outcome)
  end

  it "skips extraction if outcome already present" do
    session.update!(outcome: { "status" => "completed" })
    expect(OutcomeExtractor).not_to receive(:call)

    described_class.perform_now(session.id)
  end

  it "re-raises ExtractionError so GoodJob can retry" do
    allow(OutcomeExtractor).to receive(:call).and_raise(OutcomeExtractor::ExtractionError, "boom")

    expect {
      described_class.perform_now(session.id)
    }.to raise_error(OutcomeExtractor::ExtractionError)
  end
end
