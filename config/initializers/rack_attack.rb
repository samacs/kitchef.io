# Rate limits, IP throttles, and abuse controls.
#
# Stored in Rails.cache (Valkey in prod, Valkey in dev). TRD §7 lists the
# intent; this initializer implements the rules that matter in v1. Heavier
# patterns (login brute-force protection, per-account quotas) are layered on
# as we see abuse in the wild.

class Rack::Attack
  ### Safelist internal health checks so they never get throttled.
  safelist("allow health check") do |req|
    req.path == "/up"
  end

  ### Throttle all requests by IP — a relaxed global cap.
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets", "/rails/active_storage")
  end

  ### Storefront orders are the highest-risk public write surface.
  throttle("storefront-orders/ip", limit: 10, period: 10.minutes) do |req|
    req.ip if req.post? && req.path.match?(%r{\A/[a-z0-9-]+/pedidos\z})
  end

  ### Rails 8 auth — block password spraying on the login endpoint.
  throttle("sessions/ip", limit: 20, period: 5.minutes) do |req|
    req.ip if req.post? && req.path == "/entrar"
  end

  ### Webhook endpoints — Stripe will retry, but we cap per source IP anyway.
  throttle("webhooks/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/webhooks/")
  end

  ### Generic JSON response for throttled clients.
  self.throttled_responder = ->(env) {
    [ 429, { "content-type" => "application/json" }, [ { error: "rate_limited" }.to_json ] ]
  }
end

# Use Rails.cache (Valkey) as the backing store across all processes.
Rack::Attack.cache.store = Rails.cache
