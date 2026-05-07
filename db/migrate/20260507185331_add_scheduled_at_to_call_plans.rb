class AddScheduledAtToCallPlans < ActiveRecord::Migration[8.1]
  def change
    add_column :call_plans, :scheduled_at, :datetime
  end
end
