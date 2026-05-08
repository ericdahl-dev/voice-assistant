#!/usr/bin/env ruby
# Usage: bin/rails runner script/test_pushover.rb
#
# Fires a real Pushover notification using a fake escalation object so you
# can confirm credentials, delivery, and the reply URL look correct without
# needing a live call session in the DB.

require "ostruct"

# Minimal stand-ins so EscalationNotifier doesn't need real ActiveRecord rows.
fake_session = OpenStruct.new(id: 0)
fake_escalation = OpenStruct.new(
  question: "Can you approve a $500 charge for an emergency repair?",
  call_session: fake_session
)
def fake_escalation.update!(**); end
fake_user = OpenStruct.new(pushover_user_key: nil)

puts "Sending test Pushover notification..."
EscalationNotifier.notify(escalation: fake_escalation, user: fake_user)
puts "Done. Check your Pushover device."
