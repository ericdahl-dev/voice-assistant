class EscalationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_escalation

  TIMEOUT_SECONDS = (ENV["ESCALATION_TIMEOUT_SECONDS"] || 45).to_i

  def reply
    if @escalation.timed_out?
      return redirect_to call_session_path(@escalation.call_session),
        alert: "The timeout has passed — your reply was saved but the call has already moved on."
    end

    user_reply = params[:user_reply].to_s.strip
    return redirect_back(fallback_location: call_session_path(@escalation.call_session),
      alert: "Reply cannot be blank.") if user_reply.blank?

    @escalation.update!(user_reply: user_reply, resolved_at: Time.current)

    session = @escalation.call_session
    message = "The user has replied to your question: #{@escalation.question}\n" \
              "Their answer: #{user_reply}\n" \
              "Please continue the call using this information."

    VapiAdapter.send_message(vapi_call_id: session.vapi_call_id, message: message)
    session.transition_to!("in_conversation") if session.needs_user?

    redirect_to call_session_path(session), notice: "Your reply has been sent to the AI."
  rescue CallSession::InvalidTransitionError, VoiceAgentProvider::ApiError => e
    Rails.logger.error("[EscalationsController] #{e.message}")
    redirect_to call_session_path(@escalation.call_session),
      alert: "Reply saved, but could not resume the call automatically."
  end

  private

  def set_escalation
    @escalation = Escalation
      .joins(call_session: { call_plan: :delegation })
      .where(delegations: { user_id: current_user.id })
      .find(params[:id])
  end
end
