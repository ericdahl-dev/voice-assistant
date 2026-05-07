class CreateEscalations < ActiveRecord::Migration[8.1]
  def change
    create_table :escalations do |t|
      t.references :call_session, null: false, foreign_key: true
      t.text :question
      t.text :user_reply
      t.datetime :notified_at
      t.datetime :resolved_at
      t.boolean :timed_out, default: false, null: false

      t.timestamps
    end
  end
end
