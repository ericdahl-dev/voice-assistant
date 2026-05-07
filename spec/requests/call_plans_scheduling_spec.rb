require "rails_helper"

RSpec.describe "CallPlans scheduling", type: :request do
  let(:user) { create(:user) }
  let(:delegation) { create(:delegation, user: user) }
  let!(:call_plan) { create(:call_plan, delegation: delegation) }

  before { sign_in user }

  def approve(scheduled_at: nil)
    post approve_delegation_call_plan_path(delegation),
      params: { scheduled_at: scheduled_at }
  end

  describe "POST approve" do
    context "without scheduled_at" do
      it "enqueues PlaceCallJob immediately (no delay)" do
        expect { approve }.to have_enqueued_job(PlaceCallJob).with(call_plan.id, session_id: nil)
      end

      it "redirects with immediate notice" do
        approve
        expect(flash[:notice]).to match(/shortly/i)
      end

      it "approves the call plan" do
        approve
        expect(call_plan.reload.status).to eq("approved")
      end
    end

    context "with a future scheduled_at" do
      let(:future_time) { 2.hours.from_now.change(usec: 0) }

      it "saves scheduled_at on the call plan" do
        approve(scheduled_at: future_time.iso8601)
        expect(call_plan.reload.scheduled_at).to be_within(1.second).of(future_time)
      end

      it "enqueues PlaceCallJob with wait_until" do
        expect { approve(scheduled_at: future_time.iso8601) }
          .to have_enqueued_job(PlaceCallJob)
          .with(call_plan.id, session_id: nil)
          .at(be_within(1.second).of(future_time))
      end

      it "redirects with scheduled notice including the time" do
        approve(scheduled_at: future_time.iso8601)
        expect(flash[:notice]).to match(/scheduled/i)
      end
    end

    context "with a past scheduled_at" do
      it "enqueues PlaceCallJob immediately (treats past as now)" do
        expect { approve(scheduled_at: 1.hour.ago.iso8601) }
          .to have_enqueued_job(PlaceCallJob).with(call_plan.id, session_id: nil)
      end

      it "redirects with immediate notice" do
        approve(scheduled_at: 1.hour.ago.iso8601)
        expect(flash[:notice]).to match(/shortly/i)
      end
    end

    context "when already approved" do
      before { call_plan.approve! }

      it "redirects with already-approved alert" do
        approve
        expect(flash[:alert]).to match(/already been approved/i)
      end
    end

    context "cross-user isolation" do
      let(:other_user) { create(:user) }
      let(:other_delegation) { create(:delegation, user: other_user) }

      it "returns 404 for another user's delegation" do
        post approve_delegation_call_plan_path(other_delegation)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
