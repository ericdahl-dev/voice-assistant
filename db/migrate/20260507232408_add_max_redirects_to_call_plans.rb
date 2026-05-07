class AddMaxRedirectsToCallPlans < ActiveRecord::Migration[8.1]
  def change
    add_column :call_plans, :max_redirects, :integer, default: 2, null: false
  end
end
