class AddTargetContactNameToCallPlans < ActiveRecord::Migration[8.1]
  def change
    add_column :call_plans, :target_contact_name, :string
  end
end
