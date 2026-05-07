class Delegation < ApplicationRecord
  belongs_to :user
  belongs_to :call_template, optional: true
  has_one :call_plan, dependent: :destroy

  scope :newest_first, -> { order(created_at: :desc) }
end
