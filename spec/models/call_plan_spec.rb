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
      expect { plan.approve! }.to have_enqueued_job(PlaceCallJob).with(plan.id)
    end

    it "raises AlreadyApprovedError when called twice" do
      plan.approve!
      expect { plan.approve! }.to raise_error(CallPlan::AlreadyApprovedError)
    end
  end

  describe "jsonb round-trip" do
    it "persists and reloads array values" do
      plan = create(:call_plan, allowed_to_share: [ "my name", "appointment date" ])
      expect(plan.reload.allowed_to_share).to eq([ "my name", "appointment date" ])
    end
  end
end
