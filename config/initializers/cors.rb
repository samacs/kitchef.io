# Same-origin only — Kitchef ships no public JSON API in v1. This file exists
# so that the day we open an endpoint we know where the config goes. Delete
# the comment and the commented block together if we ship an API we want to
# expose to third parties.

# Rails.application.config.middleware.insert_before 0, Rack::Cors do
#   allow do
#     origins ENV.fetch("CORS_ALLOWED_ORIGINS", "").split(",")
#     resource "/api/*",
#       headers: :any,
#       methods: %i[get post put patch delete options head],
#       credentials: false
#   end
# end
