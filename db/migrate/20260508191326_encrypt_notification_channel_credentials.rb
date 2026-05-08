class EncryptNotificationChannelCredentials < ActiveRecord::Migration[8.1]
  def up
    NotificationChannel.find_each(&:encrypt)
  end

  def down
    NotificationChannel.find_each(&:decrypt)
  end
end
