class CallTemplate < ApplicationRecord
  has_many :delegations

  attribute :variable_schema,           :jsonb, default: []
  attribute :default_allowed_to_share,  :jsonb, default: []
  attribute :default_questions_to_ask,  :jsonb, default: []
  attribute :default_allowed_decisions, :jsonb, default: []
  attribute :default_forbidden_actions, :jsonb, default: []

  validates :name, presence: true
  validates :description, presence: true
  validates :goal_template, presence: true

  # Build a new CallPlan seeded with this template's defaults.
  # The caller must still supply the user-provided variables before saving.
  def build_call_plan(delegation)
    delegation.build_call_plan(
      allowed_to_share:  default_allowed_to_share.dup,
      questions_to_ask:  default_questions_to_ask.dup,
      allowed_decisions: default_allowed_decisions.dup,
      forbidden_actions: default_forbidden_actions.dup,
      fallback:          default_fallback
    )
  end
end
