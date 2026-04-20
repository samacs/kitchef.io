redis_config  = Rails.application.config.redis_config
schedule_file = Rails.root.join("config/schedule.yml")

# Default the underlying RedisClient driver for any gem that opens its own
# connection (geocoder cache, ad-hoc consumers). Keeps the whole app on
# hiredis when that's selected in config/application.rb.
RedisClient.default_driver = redis_config.fetch(:driver, :redis)

Sidekiq.configure_server do |config|
  config.redis = redis_config

  # Jobs generating Active Storage URLs need host/port options because there's
  # no incoming request to pick them up from. Set them once on blob load so
  # mailers and jobs produce correct absolute links.
  ActiveSupport.on_load(:active_storage_blob) do
    ActiveStorage::Current.url_options = Rails.application.config.default_url_options
  end
end

Sidekiq.configure_client { |config| config.redis = redis_config }

# sidekiq-cron picks up schedule.yml if present. The file is optional;
# create it when we ship the first cron job (daily digest, ingredient
# staleness sweep, etc.).
if File.exist?(schedule_file) && Sidekiq.server?
  Sidekiq::Cron::Job.load_from_hash YAML.safe_load(ERB.new(File.read(schedule_file)).result)
end
