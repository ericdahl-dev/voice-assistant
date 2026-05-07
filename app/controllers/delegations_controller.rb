class DelegationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @delegations = current_user.delegations.newest_first
      .includes(:call_template, call_plan: :call_sessions)
    @call_templates = ::CallTemplate.order(:name)
  end

  def show
    @delegation = current_user.delegations.find(params[:id])
  end

  def new
    @call_templates = ::CallTemplate.order(:name)
    @delegation = current_user.delegations.build
  end

  def create
    @delegation = current_user.delegations.build(delegation_params)

    if @delegation.save
      redirect_to new_delegation_call_plan_path(@delegation)
    else
      @call_templates = ::CallTemplate.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def delegation_params
    params.expect(delegation: [ :call_template_id ])
  end
end
