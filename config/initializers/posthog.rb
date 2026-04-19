# PostHog — product analytics.
#
# Self-hosted PostHog is a non-goal for v1; we use the gem to emit events to
# whatever instance the API key points at. No-ops in development when
# POSTHOG_API_KEY is blank so local runs don't emit junk.

return if ENV["POSTHOG_API_KEY"].blank?

POSTHOG_CLIENT = PostHog::Client.new(
  api_key: ENV.fetch("POSTHOG_API_KEY"),
  host: ENV.fetch("POSTHOG_HOST", "https://app.posthog.com")
)
