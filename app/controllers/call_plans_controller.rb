class CallPlansController < ApplicationController
  before_action :authenticate_user!
  before_action :set_delegation

  def new
    @call_plan = @delegation.build_call_plan
    @template = @delegation.call_template

    if @template
      @call_plan = @template.build_call_plan(@delegation)
    end
  end

  def create
    @call_plan = @delegation.build_call_plan(call_plan_params)

    if @call_plan.save
      redirect_to delegation_call_plan_path(@delegation), notice: "Call plan saved. Review it below, then approve when ready."
    else
      @template = @delegation.call_template
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @call_plan = @delegation.call_plan
    if @call_plan
      @active_session = @call_plan.call_sessions.where.not(status: %w[completed failed voicemail]).order(created_at: :desc).first
      @recent_sessions = @call_plan.call_sessions.order(created_at: :desc).limit(5)
    end
  end

  def edit
    @call_plan = @delegation.call_plan
    redirect_to delegation_call_plan_path(@delegation), alert: "An approved call plan cannot be edited." if @call_plan.approved?
  end

  def update
    @call_plan = @delegation.call_plan

    if @call_plan.approved?
      redirect_to delegation_call_plan_path(@delegation), alert: "An approved call plan cannot be edited."
      return
    end

    if @call_plan.update(call_plan_params)
      redirect_to delegation_call_plan_path(@delegation), notice: "Call plan updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def approve
    @call_plan = @delegation.call_plan
    @call_plan.approve!
    redirect_to delegation_call_plan_path(@delegation), notice: "Call plan approved! The AI will make the call shortly."
  rescue CallPlan::AlreadyApprovedError
    redirect_to delegation_call_plan_path(@delegation), alert: "This call plan has already been approved."
  end

  def run_again
    @call_plan = @delegation.call_plan

    if @call_plan.call_sessions.where(status: %w[drafted queued dialing connected in_conversation needs_user]).exists?
      return redirect_to delegation_call_plan_path(@delegation),
        alert: "A call is already in progress — wait for it to finish before running again."
    end

    session = @call_plan.call_sessions.create!(status: "drafted")
    PlaceCallJob.perform_later(@call_plan.id, session_id: session.id)
    redirect_to call_session_path(session), notice: "Running the call again — a new session has been queued."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to delegation_call_plan_path(@delegation), alert: "Could not run again: #{e.message}"
  end

  private

  def set_delegation
    @delegation = current_user.delegations.find(params[:delegation_id])
  end

  def call_plan_params
    params.expect(
      call_plan: [
        :target_name, :target_phone, :target_contact_name, :caller_name, :goal, :fallback, :voicemail_only,
        allowed_to_share: [], questions_to_ask: [],
        allowed_decisions: [], forbidden_actions: []
      ]
    )
  end
end
