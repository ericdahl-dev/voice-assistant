module Analytics
  def self.capture(distinct_id:, event:, properties: {})
    return unless ENV["POSTHOG_PROJECT_TOKEN"].present?

    PostHog.capture(distinct_id: distinct_id, event: event, properties: properties)
  end
end
