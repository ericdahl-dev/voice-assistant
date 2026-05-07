class CallPlan < ApplicationRecord
  belongs_to :delegation
  has_many :call_sessions, dependent: :destroy

  STATUSES = %w[drafted approved].freeze

  validates :target_name, presence: true
  validates :target_phone, presence: true, format: {with: /\A\+[1-9]\d{7,14}\z/, message: "must be in E.164 format (e.g. +14155550123)"}
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
    PlaceCallJob.perform_later(id)
  end

  class AlreadyApprovedError < StandardError; end
end
