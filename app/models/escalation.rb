class Escalation < ApplicationRecord
  belongs_to :call_session

  scope :unresolved, -> { where(resolved_at: nil, timed_out: false) }
  scope :pending_reply, -> { unresolved.where.not(notified_at: nil) }
end
