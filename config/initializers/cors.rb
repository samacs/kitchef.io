# Same-origin only — Kitchef ships no public JSON API in v1. This file exists
# so that the day we open an endpoint we know where the config goes. Delete
# the comment and the commented block together if we ship an API we want to
# expose to third parties.

# Assets served via cdn.kitchef.mx are fetched cross-origin by pages on
# kitchef.mx. The browser blocks JS/CSS without CORS headers.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "https://kitchef.mx", "https://www.kitchef.mx"
    resource "/assets/*",
      headers: :any,
      methods: %i[get head options],
      credentials: false
  end
end
