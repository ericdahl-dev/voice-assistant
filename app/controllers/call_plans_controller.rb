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
    @template = @delegation.call_template
    attrs = call_plan_params

    if @template
      attrs = attrs.merge(
        goal: build_goal_from_template(@template, call_plan_variable_params(@template)),
        call_template_id: @template.id
      )
    end

    @call_plan = @delegation.build_call_plan(attrs)

    if @call_plan.save
      redirect_to delegation_call_plan_path(@delegation), notice: "Call plan saved. Review it below, then approve when ready."
    else
      @call_plan_variables = @template ? call_plan_variable_params(@template) : {}
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
    scheduled_at = parse_scheduled_at(params[:scheduled_at])
    @call_plan.update!(scheduled_at: scheduled_at) if scheduled_at
    @call_plan.approve!
    @call_plan.enqueue_place_call_job
    notice = @call_plan.scheduled? ? "Call scheduled for #{@call_plan.scheduled_at.strftime("%B %-d at %l:%M %p %Z")}." : "Call plan approved! The AI will make the call shortly."
    redirect_to delegation_call_plan_path(@delegation), notice: notice
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
    @call_plan.enqueue_place_call_job(session_id: session.id)
    notice = @call_plan.scheduled? ? "Call scheduled for #{@call_plan.scheduled_at.strftime("%B %-d at %l:%M %p %Z")}." : "Running the call again — a new session has been queued."
    redirect_to call_session_path(session), notice: notice
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
        :scheduled_at,
        allowed_to_share: [], questions_to_ask: [],
        allowed_decisions: [], forbidden_actions: []
      ]
    )
  end

  def call_plan_variable_params(template)
    allowed_keys = template.variable_schema.map { |e| e["key"] }
    params.fetch(:call_plan_variables, {}).permit(*allowed_keys).to_h
  end

  def build_goal_from_template(template, variables)
    goal = template.goal_template.dup
    variable_summary = variables.reject { |_, v| v.blank? }.map { |k, v| "#{k.humanize}: #{v}" }.join(", ")
    variable_summary.present? ? "#{goal} (#{variable_summary})" : goal
  end

  def parse_scheduled_at(value)
    return nil if value.blank?
    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
