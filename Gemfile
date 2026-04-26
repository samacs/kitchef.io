source "https://rubygems.org"

# Core framework
gem "rails", "~> 8.1"
gem "rails-i18n", "~> 8.0"
gem "puma", ">= 5.0"
gem "thruster", require: false
gem "propshaft"
gem "bootsnap", require: false
gem "importmap-rails"

# Database & caching
gem "pg", "~> 1.1"
gem "redis", ">= 4.0.1"
gem "hiredis", "~> 0.6.3"
gem "hiredis-client", "~> 0.28.0"
gem "connection_pool", "~> 3.0"

# Auth & security
gem "bcrypt", "~> 3.1.22"
gem "omniauth", "~> 2.1"
gem "omniauth-google-oauth2", "~> 1.2"
gem "omniauth-rails_csrf_protection", "~> 2.0"
gem "rack-attack", "~> 6.8"
gem "rack-cors", "~> 3.0"

# UI & frontend
gem "tailwindcss-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "view_component", "~> 4.6"
gem "lucide-rails", "~> 0.7.4"
gem "local_time", "~> 3.0"
gem "simple_calendar", "~> 3.1"

# Domain-specific
gem "money", "~> 7.0"
gem "money-rails", "~> 3.0"
gem "phonelib", "~> 0.10.18"
gem "phony_rails", "~> 0.15.0"
gem "name_of_person", "~> 1.1"
gem "interval_set", "~> 0.2"
gem "positioning", "~> 0.4.8"
gem "friendly_id", "~> 5.6"
gem "prefixed_ids", "~> 1.8"
gem "aasm", "~> 5.5"
gem "discard", "~> 1.4"
gem "paper_trail", "~> 17.0"
gem "store_model", "~> 4.5"
gem "ransack", "~> 4.4"

# Background & async
gem "sidekiq", "~> 8.1"
gem "sidekiq-cron", "~> 2.3"
gem "noticed", "~> 3.0"

# Views & formatting
gem "decent_exposure", "~> 3.0"
gem "draper", "~> 4.0"
gem "pagy", "~> 43.5"
gem "chartkick", "~> 5.1"
gem "groupdate", "~> 6.8"
gem "caxlsx", "~> 4.4"
gem "rqrcode", "~> 3.2"
gem "oj", "~> 3.17"
gem "oj_serializers", "~> 3.0"

# Storage & media
gem "active_storage_validations", "~> 3.0"
gem "image_processing", "~> 1.2"
gem "ruby-vips", "~> 2.3"
gem "aws-sdk-s3", "~> 1.219"

# Integrations
gem "stripe", "~> 19.0"
gem "resend", "~> 1.3"
gem "twilio-ruby", "~> 7.10"
gem "geocoder", "~> 1.8"

# Configuration & patterns
gem "rails-settings-cached", "~> 2.9"
gem "dry-initializer", "~> 3.2"
gem "dry-initializer-rails", "~> 3.1"
gem "dry-types", "~> 1.9"
gem "light-service", "~> 0.21.0"
gem "validate_url", "~> 1.0"

# Deployment & observability
gem "kamal", require: false
gem "sentry-rails", "~> 6.5"
gem "sentry-ruby", "~> 6.4"
gem "sentry-sidekiq", "~> 6.4"
gem "posthog-rails", "~> 3.6"
gem "posthog-ruby", "~> 3.6"
gem "sitemap_generator", github: "kjvarga/sitemap_generator", branch: "master"

# Windows / JRuby
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "dotenv-rails", "~> 3.2"
  gem "database_cleaner-active_record", "~> 2.2"
  gem "factory_bot_rails", "~> 6.5"
  gem "faker", "~> 3.8"
  gem "pry", "~> 0.16.0"
  gem "pry-doc", "~> 1.7"
  gem "pry-rails", "~> 0.3.11"
  gem "rubocop-factory_bot", "~> 2.28", require: false
  gem "rubocop-faker", "~> 1.3", require: false
  gem "rubocop-performance", "~> 1.26", require: false
  gem "rubocop-rails", "~> 2.34", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "annotaterb", "~> 4.22"
  gem "foreman", require: false
  gem "hotwire-spark", "~> 0.1.13"
  gem "letter_opener", "~> 1.10"
  gem "letter_opener_web", "~> 3.0"
  gem "rack-mini-profiler", "~> 4.0"
  gem "solargraph-rails", "~> 1.3"
  gem "web-console"
end
