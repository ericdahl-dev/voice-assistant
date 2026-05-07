class AddVoicemailOnlyToCallPlans < ActiveRecord::Migration[8.1]
  def change
    add_column :call_plans, :voicemail_only, :boolean, default: false, null: false
  end
end
