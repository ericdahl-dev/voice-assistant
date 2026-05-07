class CallPlan < ApplicationRecord
  belongs_to :delegation
  has_many :call_sessions, dependent: :destroy

  STATUSES = %w[drafted approved].freeze

  validates :target_name, presence: true
  before_validation :normalize_phone
  validates :target_phone, presence: true, format: { with: /\A\+[1-9]\d{7,14}\z/, message: "must be in E.164 format (e.g. +14155550123)" }
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
    enqueue_place_call_job
  end

  def scheduled?
    scheduled_at.present? && scheduled_at.future?
  end

  def enqueue_place_call_job(session_id: nil)
    if scheduled?
      PlaceCallJob.set(wait_until: scheduled_at).perform_later(id, session_id: session_id)
    else
      PlaceCallJob.perform_later(id, session_id: session_id)
    end
  end

  class AlreadyApprovedError < StandardError; end

  private

  def normalize_phone
    return if target_phone.blank?
    digits = target_phone.gsub(/\D/, "")
    self.target_phone = if target_phone.start_with?("+")
      target_phone
    elsif digits.length == 10
      "+1#{digits}"
    else
      "+#{digits}"
    end
  end
end
