class AddCallTemplateIdToCallPlans < ActiveRecord::Migration[8.1]
  def change
    add_reference :call_plans, :call_template, foreign_key: true, null: true, index: true
  end
end
