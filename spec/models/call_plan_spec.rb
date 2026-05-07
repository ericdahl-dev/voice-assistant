require "rails_helper"

RSpec.describe CallPlan, type: :model do
  it { is_expected.to belong_to(:delegation) }
  it { is_expected.to have_many(:call_sessions).dependent(:destroy) }

  it { is_expected.to validate_presence_of(:target_name) }
  it { is_expected.to validate_presence_of(:target_phone) }
  it { is_expected.to validate_presence_of(:caller_name) }
  it { is_expected.to validate_presence_of(:goal) }

  describe "defaults" do
    subject(:plan) { create(:call_plan) }

    it "starts in drafted status" do
      expect(plan).to be_drafted
    end

    it "initializes jsonb fields to empty arrays" do
      expect(plan.allowed_to_share).to eq([])
      expect(plan.questions_to_ask).to eq([])
      expect(plan.allowed_decisions).to eq([])
      expect(plan.forbidden_actions).to eq([])
    end
  end

  describe "#approve!" do
    subject(:plan) { create(:call_plan) }

    it "transitions to approved and records approved_at" do
      expect { plan.approve! }
        .to change { plan.status }.from("drafted").to("approved")
        .and change { plan.approved_at }.from(nil)
    end

    it "enqueues PlaceCallJob" do
      expect { plan.approve! }.to have_enqueued_job(PlaceCallJob).with(plan.id, session_id: nil)
    end

    it "raises AlreadyApprovedError when called twice" do
      plan.approve!
      expect { plan.approve! }.to raise_error(CallPlan::AlreadyApprovedError)
    end

    context "with a future scheduled_at" do
      let(:future) { 1.hour.from_now.change(usec: 0) }
      let(:plan) { create(:call_plan, scheduled_at: future) }

      it "enqueues PlaceCallJob with wait_until" do
        expect { plan.approve! }.to have_enqueued_job(PlaceCallJob)
          .with(plan.id, session_id: nil)
          .at(future)
      end
    end
  end

  describe "#scheduled?" do
    it "returns false when scheduled_at is nil" do
      plan = build(:call_plan, scheduled_at: nil)
      expect(plan.scheduled?).to be false
    end

    it "returns false when scheduled_at is in the past" do
      plan = build(:call_plan, scheduled_at: 1.hour.ago)
      expect(plan.scheduled?).to be false
    end

    it "returns true when scheduled_at is in the future" do
      plan = build(:call_plan, scheduled_at: 1.hour.from_now)
      expect(plan.scheduled?).to be true
    end
  end

  describe "#enqueue_place_call_job" do
    it "enqueues immediately when not scheduled" do
      plan = create(:call_plan)
      expect { plan.enqueue_place_call_job }.to have_enqueued_job(PlaceCallJob)
        .with(plan.id, session_id: nil)
    end

    it "enqueues with wait_until when scheduled" do
      future = 2.hours.from_now.change(usec: 0)
      plan = create(:call_plan, scheduled_at: future)
      expect { plan.enqueue_place_call_job }.to have_enqueued_job(PlaceCallJob)
        .with(plan.id, session_id: nil)
        .at(future)
    end

    it "passes session_id through" do
      plan = create(:call_plan, :approved)
      session = create(:call_session, call_plan: plan)
      expect { plan.enqueue_place_call_job(session_id: session.id) }
        .to have_enqueued_job(PlaceCallJob).with(plan.id, session_id: session.id)
    end
  end

  describe "jsonb round-trip" do
    it "persists and reloads array values" do
      plan = create(:call_plan, allowed_to_share: [ "my name", "appointment date" ])
      expect(plan.reload.allowed_to_share).to eq([ "my name", "appointment date" ])
    end
  end
end
