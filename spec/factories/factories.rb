FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
  end

  factory :delegation do
    user
    call_template { nil }
  end

  factory :call_template do
    name { "Auto Repair Status Check" }
    description { "Call an auto repair shop to check if a vehicle is ready." }
    goal_template { "Ask whether the vehicle is ready for pickup." }
    variable_schema { [] }
    default_allowed_to_share { [ "Customer's first name" ] }
    default_questions_to_ask { [ "Is the vehicle ready?" ] }
    default_allowed_decisions { [] }
    default_forbidden_actions { [ "Approve new repairs", "Provide payment info" ] }
    default_fallback { "Leave a voicemail asking them to call back." }
  end

  factory :call_plan do
    delegation
    target_name { "Maplewood Auto" }
    target_phone { "555-867-5309" }
    caller_name { "Alex" }
    goal { "Check if the car is ready for pickup" }
    status { "drafted" }

    trait :approved do
      status { "approved" }
      approved_at { Time.current }
    end

    trait :voicemail_only do
      voicemail_only { true }
    end
  end

  factory :call_session do
    association :call_plan, factory: [ :call_plan, :approved ]
    status { "drafted" }

    trait :completed do
      status { "completed" }
    end

    trait :voicemail do
      status { "voicemail" }
    end
  end

  factory :escalation do
    association :call_session
    question { "Should I accept the extended warranty offer?" }
    timed_out { false }

    trait :notified do
      notified_at { 10.seconds.ago }
    end

    trait :resolved do
      notified_at { 20.seconds.ago }
      resolved_at { 5.seconds.ago }
      user_reply { "Yes, accept it." }
    end

    trait :timed_out do
      notified_at { 60.seconds.ago }
      timed_out { true }
    end
  end
end
