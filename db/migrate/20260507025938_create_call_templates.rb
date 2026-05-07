class CreateCallTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :call_templates do |t|
      t.string :name, null: false
      t.text :description, null: false

      # The goal field is a template string; variables are interpolated at CallPlan creation time.
      # Example: "Ask whether the %{vehicle} is ready for pickup at %{shop_name}"
      t.text :goal_template, null: false

      # Describes the variables a user must fill in to instantiate this template.
      # Schema: [{ "key": "shop_name", "label": "Shop name", "required": true }, ...]
      t.jsonb :variable_schema, null: false, default: []

      # Sensible defaults that pre-fill the CallPlan; the user can edit before approving.
      t.jsonb :default_allowed_to_share,  null: false, default: []
      t.jsonb :default_questions_to_ask,  null: false, default: []
      t.jsonb :default_allowed_decisions, null: false, default: []
      t.jsonb :default_forbidden_actions, null: false, default: []
      t.text  :default_fallback

      t.timestamps
    end
  end
end
