require "sidekiq"

valkey_url = ENV.fetch("VALKEY_URL", "redis://localhost:6379/0")

Sidekiq.configure_server do |config|
  config.redis = { url: valkey_url, size: ENV.fetch("SIDEKIQ_SERVER_POOL", 10).to_i }
end

Sidekiq.configure_client do |config|
  config.redis = { url: valkey_url, size: ENV.fetch("SIDEKIQ_CLIENT_POOL", 5).to_i }
end
