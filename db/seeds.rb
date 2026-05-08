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

CallTemplate.find_or_create_by!(name: "Appointment Confirmation") do |t|
  t.description = "Call a doctor, dentist, vet, or other provider to confirm an upcoming appointment."

  t.goal_template = "Confirm that the appointment for the patient is still scheduled for the requested date and time. " \
                    "If the appointment needs to be rescheduled, ask for the next available time. " \
                    "Note any preparation instructions or items to bring."

  t.variable_schema = [
    { "key" => "provider_name", "label" => "Provider or clinic name", "required" => true },
    { "key" => "target_phone", "label" => "Provider phone number", "required" => true },
    { "key" => "caller_name", "label" => "Your first name", "required" => true },
    { "key" => "patient_name", "label" => "Patient's full name", "required" => true },
    { "key" => "appointment_date", "label" => "Appointment date and time", "required" => true }
  ]

  t.default_allowed_to_share = [
    "The patient's first and last name",
    "The appointment date and time"
  ]

  t.default_questions_to_ask = [
    "Is the appointment still confirmed for the requested date and time?",
    "Are there any preparation instructions (fasting, forms, etc.)?",
    "What should the patient bring to the appointment?",
    "Is there a cancellation policy?"
  ]

  t.default_allowed_decisions = [
    "Accept a reschedule within one week of the original appointment if the original time is unavailable"
  ]

  t.default_forbidden_actions = [
    "Provide or confirm any insurance or payment information",
    "Cancel the appointment without explicit instruction",
    "Share any medical history or health details"
  ]

  t.default_fallback = "Leave a voicemail asking them to call back to confirm the appointment details."
end

CallTemplate.find_or_create_by!(name: "Contractor Quote Follow-up") do |t|
  t.description = "Follow up with a contractor who submitted a quote but hasn't been heard from since."

  t.goal_template = "Follow up on the quote that was submitted for the described work. " \
                    "Confirm whether the quote is still valid and ask about availability to start the job. " \
                    "Ask if any additional information is needed before proceeding."

  t.variable_schema = [
    { "key" => "contractor_name", "label" => "Contractor or company name", "required" => true },
    { "key" => "target_phone", "label" => "Contractor phone number", "required" => true },
    { "key" => "caller_name", "label" => "Your first name", "required" => true },
    { "key" => "job_description", "label" => "Description of the job", "required" => true },
    { "key" => "quote_date", "label" => "Approximate date the quote was given", "required" => false }
  ]

  t.default_allowed_to_share = [
    "The customer's first name",
    "The description of the job",
    "The approximate date the quote was given"
  ]

  t.default_questions_to_ask = [
    "Is the quote still valid?",
    "What is the earliest available start date?",
    "Is any additional information or site visit needed before starting?",
    "What is the estimated timeline for completing the job?"
  ]

  t.default_allowed_decisions = []

  t.default_forbidden_actions = [
    "Accept or reject the quote on the customer's behalf",
    "Provide or confirm any payment or credit card information",
    "Authorize any work or schedule a start date without explicit confirmation"
  ]

  t.default_fallback = "Leave a voicemail asking them to call back regarding the pending quote."
end

CallTemplate.find_or_create_by!(name: "Package Delivery Issue") do |t|
  t.description = "Call a carrier or shipper to report a missing, delayed, or damaged package."

  t.goal_template = "Report the issue with the package and ask for a resolution timeline. " \
                    "Get a case or ticket number if one is created. " \
                    "Ask about the next steps and estimated resolution time."

  t.variable_schema = [
    { "key" => "carrier_name", "label" => "Carrier name (e.g. FedEx, UPS)", "required" => true },
    { "key" => "target_phone", "label" => "Carrier phone number", "required" => true },
    { "key" => "caller_name", "label" => "Your first name", "required" => true },
    { "key" => "tracking_number", "label" => "Tracking number", "required" => true },
    { "key" => "issue_type", "label" => "Issue type (missing, delayed, or damaged)", "required" => true }
  ]

  t.default_allowed_to_share = [
    "The caller's first name",
    "The tracking number",
    "The issue type",
    "The delivery address"
  ]

  t.default_questions_to_ask = [
    "What is the current status of the package?",
    "What is the estimated resolution or re-delivery date?",
    "Is a claim or ticket being opened?",
    "What is the case or ticket number if one is created?"
  ]

  t.default_allowed_decisions = []

  t.default_forbidden_actions = [
    "Provide or confirm any payment or credit card information",
    "Waive any claims or accept a resolution without confirming with the customer",
    "Provide any personal identification numbers beyond the tracking number"
  ]

  t.default_fallback = "Leave a voicemail describing the package issue and asking for a callback with a resolution update."
end

CallTemplate.find_or_create_by!(name: "Pet Grooming Appointment") do |t|
  t.description = "Call a pet groomer to book an appointment for a pet."

  t.goal_template = "Book a grooming appointment for the pet on or near the preferred date. " \
                    "Confirm the services included, the duration, and the price. " \
                    "Note any special instructions or requirements for the pet."

  t.variable_schema = [
    { "key" => "groomer_name", "label" => "Groomer or salon name", "required" => true },
    { "key" => "target_phone", "label" => "Groomer phone number", "required" => true },
    { "key" => "caller_name", "label" => "Your first name", "required" => true },
    { "key" => "pet_name", "label" => "Pet's name", "required" => true },
    { "key" => "pet_breed", "label" => "Pet breed", "required" => true },
    { "key" => "preferred_date", "label" => "Preferred appointment date", "required" => true }
  ]

  t.default_allowed_to_share = [
    "The owner's first name",
    "The pet's name and breed",
    "The preferred appointment date"
  ]

  t.default_questions_to_ask = [
    "Is the preferred date and time available?",
    "What services are included and what is the price?",
    "How long does the appointment typically take?",
    "Are there any requirements (vaccinations, drop-off window, etc.)?"
  ]

  t.default_allowed_decisions = [
    "Accept any available appointment time on the preferred date"
  ]

  t.default_forbidden_actions = [
    "Provide or confirm any payment or credit card information",
    "Book more than one appointment",
    "Agree to any add-on services without confirming with the owner first"
  ]

  t.default_fallback = "Leave a voicemail asking them to call back to schedule a grooming appointment."
end

CallTemplate.find_or_create_by!(name: "Internet or Utility Outage Report") do |t|
  t.description = "Call an internet or utility provider to report an outage and get an estimated restoration time."

  t.goal_template = "Report the outage at the service address and ask for an estimated restoration time. " \
                    "Get a trouble ticket or case number if one is created. " \
                    "Ask whether a technician visit is needed and when the earliest appointment would be."

  t.variable_schema = [
    { "key" => "provider_name", "label" => "Provider name", "required" => true },
    { "key" => "target_phone", "label" => "Provider phone number", "required" => true },
    { "key" => "caller_name", "label" => "Your first name", "required" => true },
    { "key" => "service_address", "label" => "Service address", "required" => true },
    { "key" => "outage_type", "label" => "Type of outage (internet, power, gas, water)", "required" => true }
  ]

  t.default_allowed_to_share = [
    "The account holder's first name",
    "The service address",
    "The type of outage"
  ]

  t.default_questions_to_ask = [
    "Is there a known outage in the area?",
    "What is the estimated restoration time?",
    "Has a trouble ticket been created, and what is the number?",
    "Is a technician visit required, and when is the earliest available appointment?"
  ]

  t.default_allowed_decisions = []

  t.default_forbidden_actions = [
    "Provide or confirm any account number, password, or payment information",
    "Authorize any service changes or upgrades",
    "Schedule a technician visit without explicit confirmation from the customer"
  ]

  t.default_fallback = "Leave a voicemail reporting the outage and asking for a callback with a restoration estimate."
end

puts "Seeded #{CallTemplate.count} call template(s)."

# Dev user — only created in development, never in production.
if Rails.env.development?
  User.find_or_create_by!(email: "dev@example.com") do |u|
    u.password = "password"
  end
  puts "Dev user: dev@example.com / password"
end
