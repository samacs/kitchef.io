require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Kitchef
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Locale and timezone — Kitchef ships as es-MX only and stores timestamps
    # in UTC while presenting them in America/Mexico_City. We fall back to the
    # generic `es` locale (provided by the rails-i18n gem) for anything we
    # haven't localized specifically.
    config.i18n.default_locale = :"es-MX"
    config.i18n.available_locales = [ :"es-MX", :es ]
    config.i18n.fallbacks = { "es-MX": [ :es ] }
    config.i18n.load_path += Dir[Rails.root.join("config/locales/**/*.{rb,yml}")]
    config.time_zone = "America/Mexico_City"
    config.active_record.default_timezone = :utc

    # Our own domain lives under app/ per convention; add the directories we
    # introduce in Phase 5+ so autoloading picks them up without fuss.
    config.autoload_paths += %W[
      #{config.root}/app/commands
      #{config.root}/app/constraints
      #{config.root}/app/queries
      #{config.root}/app/services
    ]

    # Shared Valkey (Redis-compatible) connection config used by Sidekiq, the
    # Rails cache store, and any gem that asks for it via `config.redis_config`.
    # Keeping a single source of truth means flipping URL, driver, or retry
    # policy in one place.
    config.redis_config = {
      url: ENV.fetch("VALKEY_URL", "redis://localhost:6379/0"),
      driver: :hiredis
    }

    # Keep generators quiet — no system tests, no helpers, no fixtures (we
    # defer testing to a later milestone).
    config.generators do |g|
      g.system_tests = nil
      g.helper = false
      g.test_framework = nil
    end
  end
end
