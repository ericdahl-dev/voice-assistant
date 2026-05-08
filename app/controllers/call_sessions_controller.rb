class CallSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_call_session, only: [ :show, :retry ]

  RETRYABLE_STATUSES = %w[voicemail failed completed].freeze

  def show
    @delegation = @call_session.call_plan.delegation
  end

  def retry
    unless RETRYABLE_STATUSES.include?(@call_session.status)
      return redirect_to call_session_path(@call_session),
        alert: "Cannot retry a call that is currently #{@call_session.status}."
    end

    new_session = @call_session.call_plan.call_sessions.create!(status: "drafted")
    PlaceCallJob.perform_later(new_session.call_plan_id, session_id: new_session.id)
    Analytics.capture(
      distinct_id: current_user.posthog_distinct_id,
      event: "call_session_retried",
      properties: { original_session_id: @call_session.id, new_session_id: new_session.id, previous_status: @call_session.status }
    )
    redirect_to call_session_path(new_session), notice: "Retrying call — a new session has been queued."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to call_session_path(@call_session), alert: "Could not retry: #{e.message}"
  end

  private

  def set_call_session
    @call_session = CallSession
      .joins(call_plan: :delegation)
      .where(delegations: { user_id: current_user.id })
      .find(params[:id])
  end
end
