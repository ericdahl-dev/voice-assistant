class Delegation < ApplicationRecord
  belongs_to :user
  belongs_to :call_template, optional: true
  has_one :call_plan, dependent: :destroy
  has_many :call_sessions, through: :call_plan

  scope :newest_first, -> { order(created_at: :desc) }
end
