# Seeds are idempotent — safe to re-run in any environment.
# Use find_or_create_by! on a stable unique key so re-seeding doesn't create duplicates.

CallTemplate.find_or_create_by!(name: "Auto Repair Status Check") do |t|
  t.description = "Call an auto repair shop to ask whether a vehicle is ready for pickup."

  t.goal_template = "Ask whether the vehicle is ready for pickup. " \
                    "If it is ready, find out if there are any additional charges beyond the original estimate. " \
                    "If it is not ready, ask for an estimated completion date and time."

  t.variable_schema = [
    { "key" => "shop_name",    "label" => "Shop name",            "required" => true },
    { "key" => "target_phone", "label" => "Shop phone number",    "required" => true },
    { "key" => "caller_name",  "label" => "Your first name",      "required" => true },
    { "key" => "vehicle",      "label" => "Vehicle (year, make, model)", "required" => true }
  ]

  t.default_allowed_to_share = [
    "The customer's first name",
    "The vehicle make, model, and year"
  ]

  t.default_questions_to_ask = [
    "Is the vehicle ready for pickup?",
    "Are there any additional charges beyond the original estimate?",
    "If not ready, what is the estimated completion date and time?"
  ]

  t.default_allowed_decisions = []

  t.default_forbidden_actions = [
    "Approve any new repairs or additional work",
    "Provide or confirm any payment information",
    "Make any commitments on behalf of the customer"
  ]

  t.default_fallback = "Leave a voicemail asking them to call back with an update on the repair status."
end

puts "Seeded #{CallTemplate.count} call template(s)."

# Dev user — only created in development, never in production.
if Rails.env.development?
  User.find_or_create_by!(email: "dev@example.com") do |u|
    u.password = "password"
  end
  puts "Dev user: dev@example.com / password"
end
