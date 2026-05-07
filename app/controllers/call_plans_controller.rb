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

  private

  def set_delegation
    @delegation = current_user.delegations.find(params[:delegation_id])
  end

  def call_plan_params
    params.expect(
      call_plan: [
        :target_name, :target_phone, :caller_name, :goal, :fallback, :voicemail_only,
        allowed_to_share: [], questions_to_ask: [],
        allowed_decisions: [], forbidden_actions: []
      ]
    )
  end
end
