class Users::RegistrationsController < Devise::RegistrationsController
  def create
    super do |resource|
      if resource.persisted?
        PostHog.identify(
          distinct_id: resource.posthog_distinct_id,
          properties: resource.posthog_properties
        )
        PostHog.capture(
          distinct_id: resource.posthog_distinct_id,
          event: "user_signed_up"
        )
      end
    end
  end
end
