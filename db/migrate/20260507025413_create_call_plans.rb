class CreateCallPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :call_plans do |t|
      t.references :delegation, null: false, foreign_key: true
      t.string :target_name, null: false
      t.string :target_phone, null: false
      t.string :caller_name, null: false
      t.text :goal, null: false
      t.jsonb :allowed_to_share, null: false, default: []
      t.jsonb :questions_to_ask, null: false, default: []
      t.jsonb :allowed_decisions, null: false, default: []
      t.jsonb :forbidden_actions, null: false, default: []
      t.text :fallback
      t.string :status, null: false, default: "drafted"
      t.datetime :approved_at

      t.timestamps
    end

    add_index :call_plans, :status
  end
end
