require "rails_helper"

RSpec.describe CallSession, type: :model do
  it { is_expected.to belong_to(:call_plan) }

  let(:call_plan) { create(:call_plan, :approved) }

  describe "creation guard" do
    it "rejects a session against a drafted call plan" do
      drafted_plan = create(:call_plan)
      session = build(:call_session, call_plan: drafted_plan)
      expect(session).not_to be_valid
      expect(session.errors[:call_plan]).to include("must be approved before a call session can be created")
    end

    it "accepts a session against an approved call plan" do
      expect(build(:call_session, call_plan:)).to be_valid
    end

    it "starts in drafted status" do
      expect(create(:call_session, call_plan:)).to be_drafted
    end
  end

  describe "#transition_to!" do
    subject(:session) { create(:call_session, call_plan:) }

    context "happy path" do
      it "completes the full drafted → queued → dialing → connected → in_conversation → completed path" do
        session.transition_to!("queued")
        session.transition_to!("dialing")
        session.transition_to!("connected")
        session.transition_to!("in_conversation")
        session.transition_to!("completed")

        expect(session).to be_completed
      end

      it "sets started_at on transition to dialing" do
        session.transition_to!("queued")
        expect { session.transition_to!("dialing") }
          .to change { session.started_at }.from(nil)
      end

      it "sets ended_at on transition to completed" do
        [:queued, :dialing, :connected, :in_conversation, :completed].each { |s| session.transition_to!(s) }
        expect(session.ended_at).not_to be_nil
      end

      it "sets ended_at on transition to voicemail" do
        [:queued, :dialing, :connected, :voicemail].each { |s| session.transition_to!(s) }
        expect(session.ended_at).not_to be_nil
      end

      it "supports needs_user detour: in_conversation → needs_user → in_conversation → completed" do
        [:queued, :dialing, :connected, :in_conversation, :needs_user, :in_conversation, :completed].each do |s|
          session.transition_to!(s)
        end
        expect(session).to be_completed
      end

      it "transitions drafted → failed (job error before dial)" do
        session.transition_to!("failed")
        expect(session).to be_failed
        expect(session.ended_at).not_to be_nil
      end
    end

    context "invalid transitions" do
      it "raises InvalidTransitionError when skipping states (drafted → dialing)" do
        expect { session.transition_to!("dialing") }
          .to raise_error(CallSession::InvalidTransitionError, /drafted.*dialing/)
      end

      it "raises InvalidTransitionError going backwards (completed → drafted)" do
        [:queued, :dialing, :connected, :in_conversation, :completed].each { |s| session.transition_to!(s) }
        expect { session.transition_to!("drafted") }
          .to raise_error(CallSession::InvalidTransitionError)
      end

      it "raises InvalidTransitionError leaving a terminal state (voicemail → completed)" do
        [:queued, :dialing, :connected, :voicemail].each { |s| session.transition_to!(s) }
        expect { session.transition_to!("completed") }
          .to raise_error(CallSession::InvalidTransitionError, /terminal/)
      end
    end
  end

  describe "outcome jsonb" do
    it "round-trips nested data through the database" do
      session = create(:call_session, call_plan:, outcome: {
        "status" => "completed",
        "summary" => "Vehicle ready for pickup.",
        "important_details" => ["Ready at 3pm", "No extra charges"],
        "confidence" => 0.95
      })

      session.reload
      expect(session.outcome["status"]).to eq("completed")
      expect(session.outcome["important_details"]).to eq(["Ready at 3pm", "No extra charges"])
      expect(session.outcome["confidence"]).to eq(0.95)
    end
  end
end
