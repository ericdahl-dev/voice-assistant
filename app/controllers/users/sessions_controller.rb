class Users::SessionsController < Devise::SessionsController
  def create
    super do |resource|
      if resource.persisted?
        PostHog.identify(
          distinct_id: resource.posthog_distinct_id,
          properties: resource.posthog_properties
        )
        Analytics.capture(
          distinct_id: resource.posthog_distinct_id,
          event: "user_logged_in"
        )
      end
    end
  end
end
