# Stripe SDK configuration. Reads keys from env so the same code path
# works in dev (test keys), staging (test or restricted), and prod
# (live keys). Webhook secret is read by `Webhooks::StripeController`
# at request time, not pinned here, so a key rotation can be picked up
# by a server reload without touching the SDK config.

Rails.application.config.to_prepare do
  Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY", nil)

  # Pin the API version so a Stripe-side default bump never reshapes a
  # webhook payload silently. Bump intentionally + verify webhooks
  # alongside the change.
  Stripe.api_version = "2025-01-27.acacia"

  # Surface SDK errors in our logs with the same formatting as Rails
  # logger so Sentry/PostHog wiring (when it lands) picks them up.
  Stripe.log_level = ENV["STRIPE_LOG_LEVEL"] || "info"

  # Module namespace used by Phase 14 services + commands.
  module Subscriptions
  end
end
