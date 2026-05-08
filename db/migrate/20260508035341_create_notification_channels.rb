class CreateNotificationChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_channels do |t|
      t.references :user, null: false, foreign_key: true
      t.string :channel_type, null: false
      t.string :pushover_user_key
      t.string :telegram_chat_id
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end
  end
end
