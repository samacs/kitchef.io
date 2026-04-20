# Sentry — error and performance monitoring.
#
# Boots as a no-op when SENTRY_DSN is blank, which is the case in local
# development. When a DSN is present we tag releases with the current Git SHA
# (set by the deploy) and exclude noisy health-check and asset requests.

return if ENV["SENTRY_DSN"].blank?

Sentry.init do |config|
  config.dsn = ENV.fetch("SENTRY_DSN")
  config.environment = Rails.env
  config.release = ENV["GIT_REVISION"].presence
  config.breadcrumbs_logger = %i[active_support_logger http_logger]

  # Sample 100% of errors (low volume in v1) and 10% of performance traces.
  config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", 0.1).to_f
  config.profiles_sample_rate = ENV.fetch("SENTRY_PROFILES_SAMPLE_RATE", 0.0).to_f

  config.excluded_exceptions += [
    "ActionController::RoutingError",
    "ActiveRecord::RecordNotFound"
  ]
end
