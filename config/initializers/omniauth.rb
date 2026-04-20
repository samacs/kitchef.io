# OmniAuth — Google sign-in for operator accounts.
#
# Rails 8 auth is the primary path (email + password). Google OAuth is offered
# as a secondary path for operators who prefer it. We use omniauth-rails_csrf_protection
# to turn GET /auth/:provider into a POST-only form (protects against CSRF
# drive-by auth).

OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.silence_get_warning = true

Rails.application.config.middleware.use OmniAuth::Builder do
  if ENV["GOOGLE_OAUTH_CLIENT_ID"].present? && ENV["GOOGLE_OAUTH_CLIENT_SECRET"].present?
    provider :google_oauth2,
      ENV.fetch("GOOGLE_OAUTH_CLIENT_ID"),
      ENV.fetch("GOOGLE_OAUTH_CLIENT_SECRET"),
      scope: "email,profile",
      prompt: "select_account"
  end
end
