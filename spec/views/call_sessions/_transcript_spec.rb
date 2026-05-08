require "rails_helper"

RSpec.describe "call_sessions/_transcript", type: :view do
  let(:call_plan) { create(:call_plan, :approved) }

  it "renders Agent turn with agent class" do
    call_session = create(:call_session, call_plan:, transcript: "Agent: Hello there\nStaff: Hi, how can I help?")
    render partial: "call_sessions/transcript", locals: { call_session: }
    expect(rendered).to include("Hello there")
    expect(rendered).to include("call_session_transcript_#{call_session.id}")
  end

  it "renders recipient turn separately from agent turn" do
    call_session = create(:call_session, call_plan:, transcript: "Agent: Hi\nStaff: Yes, ready")
    render partial: "call_sessions/transcript", locals: { call_session: }
    expect(rendered).to include("Hi")
    expect(rendered).to include("Yes, ready")
  end

  it "renders empty state when transcript is blank" do
    call_session = create(:call_session, call_plan:, transcript: nil)
    render partial: "call_sessions/transcript", locals: { call_session: }
    expect(rendered).to include("No transcript yet")
  end
end
