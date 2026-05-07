class CallPlan < ApplicationRecord
  belongs_to :delegation

  STATUSES = %w[drafted approved].freeze

  validates :target_name, presence: true
  validates :target_phone, presence: true
  validates :caller_name, presence: true
  validates :goal, presence: true
  validates :status, inclusion: { in: STATUSES }

  attribute :allowed_to_share, :jsonb, default: []
  attribute :questions_to_ask, :jsonb, default: []
  attribute :allowed_decisions, :jsonb, default: []
  attribute :forbidden_actions, :jsonb, default: []

  scope :drafted, -> { where(status: "drafted") }
  scope :approved, -> { where(status: "approved") }

  def drafted?
    status == "drafted"
  end

  def approved?
    status == "approved"
  end

  def approve!
    raise AlreadyApprovedError, "CallPlan ##{id} has already been approved" if approved?

    update!(status: "approved", approved_at: Time.current)
  end

  class AlreadyApprovedError < StandardError; end
end
