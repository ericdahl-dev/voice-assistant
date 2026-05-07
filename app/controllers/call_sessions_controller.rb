class CallSessionsController < ApplicationController
  before_action :authenticate_user!

  def show
    @call_session = CallSession
      .joins(call_plan: :delegation)
      .where(delegations: { user_id: current_user.id })
      .find(params[:id])

    @delegation = @call_session.call_plan.delegation
  end
end
