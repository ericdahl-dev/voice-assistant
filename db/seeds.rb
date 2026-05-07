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

CallTemplate.find_or_create_by!(name: "Restaurant Reservation") do |t|
  t.description = "Call a restaurant to make a dining reservation."

  t.goal_template = "Make a reservation for a party of the requested size on the requested date and time. " \
                    "If the exact time is unavailable, ask for the nearest available time slot. " \
                    "Confirm the reservation details before ending the call."

  t.variable_schema = [
    { "key" => "restaurant_name", "label" => "Restaurant name",        "required" => true },
    { "key" => "target_phone",    "label" => "Restaurant phone number", "required" => true },
    { "key" => "caller_name",     "label" => "Your first name",         "required" => true },
    { "key" => "party_size",      "label" => "Number of guests",        "required" => true },
    { "key" => "preferred_date",  "label" => "Preferred date",          "required" => true },
    { "key" => "preferred_time",  "label" => "Preferred time",          "required" => true }
  ]

  t.default_allowed_to_share = [
    "The customer's first name",
    "The party size",
    "The preferred date and time"
  ]

  t.default_questions_to_ask = [
    "Is the requested date and time available?",
    "If not, what is the nearest available time slot?",
    "Is there a dress code or any special requirements?",
    "Is a deposit or credit card required to hold the reservation?"
  ]

  t.default_allowed_decisions = [
    "Accept an alternative time within one hour of the preferred time on the same date"
  ]

  t.default_forbidden_actions = [
    "Provide or confirm any credit card or payment information",
    "Make more than one reservation",
    "Agree to any cancellation fees without confirming with the customer first"
  ]

  t.default_fallback = "Leave a voicemail asking them to call back to discuss making a reservation."
end

CallTemplate.find_or_create_by!(name: "Pharmacy Prescription Status") do |t|
  t.description = "Call a pharmacy to check if a prescription is ready for pickup."

  t.goal_template = "Ask whether the prescription for the patient is ready for pickup. " \
                    "If it is ready, confirm the pickup location and hours. " \
                    "If it is not ready, ask for the estimated ready time and whether there are any issues with the prescription."

  t.variable_schema = [
    { "key" => "pharmacy_name",  "label" => "Pharmacy name",          "required" => true },
    { "key" => "target_phone",   "label" => "Pharmacy phone number",   "required" => true },
    { "key" => "caller_name",    "label" => "Your first name",         "required" => true },
    { "key" => "patient_name",   "label" => "Patient's full name",     "required" => true }
  ]

  t.default_allowed_to_share = [
    "The patient's first and last name",
    "The patient's date of birth if needed for verification"
  ]

  t.default_questions_to_ask = [
    "Is the prescription ready for pickup?",
    "If not ready, what is the estimated ready time?",
    "Are there any issues or holds on the prescription?",
    "What are the pickup hours and location?"
  ]

  t.default_allowed_decisions = []

  t.default_forbidden_actions = [
    "Provide or confirm any insurance or payment information",
    "Authorize any changes to the prescription",
    "Request or confirm any personal health details beyond what is necessary to identify the prescription"
  ]

  t.default_fallback = "Leave a voicemail asking them to call back with a status update on the prescription."
end

CallTemplate.find_or_create_by!(name: "Home Service Scheduling") do |t|
  t.description = "Call a home service provider to schedule an appointment for repairs or maintenance."

  t.goal_template = "Schedule a home service appointment for the requested type of work. " \
                    "Ask about available appointment times on or near the preferred date. " \
                    "Confirm the service address, estimated duration, and any service call fee."

  t.variable_schema = [
    { "key" => "company_name",    "label" => "Company name",                   "required" => true },
    { "key" => "target_phone",    "label" => "Company phone number",            "required" => true },
    { "key" => "caller_name",     "label" => "Your first name",                 "required" => true },
    { "key" => "service_type",    "label" => "Type of service needed",          "required" => true },
    { "key" => "service_address", "label" => "Service address",                 "required" => true },
    { "key" => "preferred_date",  "label" => "Preferred appointment date",      "required" => true }
  ]

  t.default_allowed_to_share = [
    "The customer's first name",
    "The service address",
    "The type of service needed",
    "The preferred appointment date"
  ]

  t.default_questions_to_ask = [
    "What appointment times are available on or near the preferred date?",
    "How long is the service appointment expected to take?",
    "Is there a service call or diagnostic fee?",
    "Are there any instructions for accessing the property?"
  ]

  t.default_allowed_decisions = [
    "Accept any available appointment time on the preferred date"
  ]

  t.default_forbidden_actions = [
    "Provide or confirm any payment or credit card information",
    "Authorize any repairs or work beyond the initial appointment",
    "Make any commitments about access to the property or keys"
  ]

  t.default_fallback = "Leave a voicemail requesting a callback to schedule a service appointment."
end

puts "Seeded #{CallTemplate.count} call template(s)."

# Dev user — only created in development, never in production.
if Rails.env.development?
  User.find_or_create_by!(email: "dev@example.com") do |u|
    u.password = "password"
  end
  puts "Dev user: dev@example.com / password"
end
