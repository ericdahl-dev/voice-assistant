require "rails_helper"

RSpec.describe "call_sessions/_transcript", type: :view do
  let(:call_plan) { create(:call_plan, :approved) }

  it "renders Agent turn with agent class" do
    call_session = create(:call_session, call_plan:, transcript: "Agent: Hello there\nStaff: Hi, how can I help?")
    render partial: "call_sessions/transcript", locals: { call_session: }
    expect(rendered).to include("Hello there")
    expect(rendered).to include("call_session_transcript_#{call_session.id}")
    expect(rendered).to include("justify-end")
  end

  it "renders recipient turn separately from agent turn" do
    call_session = create(:call_session, call_plan:, transcript: "Agent: Hi\nStaff: Yes, ready")
    render partial: "call_sessions/transcript", locals: { call_session: }
    expect(rendered).to include("Hi")
    expect(rendered).to include("Yes, ready")
    expect(rendered).to include("justify-start")
  end

  it "groups consecutive turns under one speaker label" do
    call_session = create(:call_session, call_plan:, transcript: "Agent: First\nAgent: Second\nStaff: Third\nStaff: Fourth")
    render partial: "call_sessions/transcript", locals: { call_session: }
    doc = Nokogiri::HTML.fragment(rendered)
    labels = doc.css("span.transcript-speaker-label").map { _1.text.strip }

    expect(labels.count("Agent")).to eq(1)
    expect(labels.count("Staff")).to eq(1)
  end

  it "renders unknown lines with a neutral system label" do
    call_session = create(:call_session, call_plan:, transcript: "Connected to call bridge")
    render partial: "call_sessions/transcript", locals: { call_session: }

    expect(rendered).to include("Connected to call bridge")
    expect(rendered).to include("System")
  end

  it "renders empty state when transcript is blank" do
    call_session = create(:call_session, call_plan:, transcript: nil)
    render partial: "call_sessions/transcript", locals: { call_session: }
    expect(rendered).to include("No transcript yet")
  end
end
