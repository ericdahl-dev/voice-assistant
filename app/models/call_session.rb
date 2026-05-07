class CallSession < ApplicationRecord
  include ActionView::RecordIdentifier
  belongs_to :call_plan

  # ---------------------------------------------------------------------------
  # State machine
  #
  # Valid lifecycle paths:
  #
  #   drafted → queued → dialing → connected → in_conversation → completed
  #                                           → voicemail
  #                               → in_conversation → needs_user → in_conversation
  #                                                              → completed
  #                                                              → failed
  #   drafted → failed   (job error before the call was placed)
  #
  # Terminal states: completed, failed, voicemail
  # ---------------------------------------------------------------------------

  STATUSES = %w[
    drafted
    queued
    dialing
    connected
    in_conversation
    needs_user
    voicemail
    completed
    failed
  ].freeze

  TERMINAL_STATUSES = %w[completed failed voicemail].freeze

  TRANSITIONS = {
    "drafted"        => %w[queued failed],
    "queued"         => %w[dialing failed],
    "dialing"        => %w[connected failed],
    "connected"      => %w[in_conversation voicemail failed],
    "in_conversation" => %w[needs_user completed failed],
    "needs_user"     => %w[in_conversation completed failed],
    "voicemail"      => [],
    "completed"      => [],
    "failed"         => []
  }.freeze

  validates :status, inclusion: { in: STATUSES }
  validate :call_plan_must_be_approved, on: :create

  attribute :outcome, :jsonb

  # Automatically set timestamps on key transitions.
  before_save :set_timestamps_on_status_change, if: :status_changed?

  # Broadcast a Turbo Stream update whenever the session changes state so the
  # dashboard can reflect progress without a full page reload.
  after_update_commit :broadcast_status_update, if: :saved_change_to_status?

  STATUSES.each do |s|
    define_method(:"#{s}?") { status == s }
  end

  TERMINAL_STATUSES.each do |s|
    define_method(:"terminal?") { TERMINAL_STATUSES.include?(status) } if s == TERMINAL_STATUSES.first
  end

  def transition_to!(new_status)
    allowed = TRANSITIONS.fetch(status, [])

    unless allowed.include?(new_status.to_s)
      raise InvalidTransitionError,
        "Cannot transition CallSession ##{id} from '#{status}' to '#{new_status}'. " \
        "Allowed: #{allowed.any? ? allowed.join(", ") : "(none — terminal state)"}"
    end

    update!(status: new_status.to_s)
  end

  class InvalidTransitionError < StandardError; end

  private

  def call_plan_must_be_approved
    return if call_plan&.approved?

    errors.add(:call_plan, "must be approved before a call session can be created")
  end

  def set_timestamps_on_status_change
    self.started_at = Time.current if status == "dialing" && started_at.nil?

    if TERMINAL_STATUSES.include?(status) && ended_at.nil?
      self.ended_at = Time.current
    end
  end

  def broadcast_status_update
    broadcast_replace_to(
      [call_plan.delegation, :call_sessions],
      target: dom_id(self),
      partial: "call_sessions/call_session",
      locals: { call_session: self }
    )
  end
end
