# Shared Valkey (Redis-compatible) connection pool.
#
# ActionCable, Rails.cache, and Sidekiq each own their own pool because they
# have different timeout/retry profiles. Application code that needs direct
# Valkey access (e.g. rate limiters, cursors, ephemeral state) should use
# `VALKEY_POOL` defined here.

require "connection_pool"
require "redis"

VALKEY_POOL = ConnectionPool.new(size: ENV.fetch("VALKEY_POOL_SIZE", 10).to_i, timeout: 3) do
  Redis.new(
    url: ENV.fetch("VALKEY_URL", "redis://localhost:6379/0"),
    timeout: 1.0,
    reconnect_attempts: 1
  )
end
