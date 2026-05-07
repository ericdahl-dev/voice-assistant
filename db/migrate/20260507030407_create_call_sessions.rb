class CreateCallSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :call_sessions do |t|
      t.references :call_plan, null: false, foreign_key: true

      # Tracks where this call is in its lifecycle. See CallSession::TRANSITIONS for the valid state machine.
      t.string :status, null: false, default: "drafted"

      # Set by Vapi once the call is successfully initiated. Null until then.
      t.string :vapi_call_id

      # Full call transcript, populated after the call ends.
      t.text :transcript

      # Structured result of the call. Schema:
      #   { status, outcome, summary, follow_up_needed, important_details, confidence }
      t.jsonb :outcome

      # Optional: when the call is scheduled to be placed (nil = as soon as possible).
      t.datetime :scheduled_at

      # Set automatically when the call transitions to :dialing.
      t.datetime :started_at

      # Set automatically when the call reaches a terminal state (completed, failed, voicemail).
      t.datetime :ended_at

      t.timestamps
    end

    add_index :call_sessions, :status
    add_index :call_sessions, :vapi_call_id, unique: true, where: "vapi_call_id IS NOT NULL"
  end
end
