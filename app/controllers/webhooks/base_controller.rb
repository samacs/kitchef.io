module Webhooks
  # Webhooks never have a session and never submit forms — they POST JSON
  # signed by the third-party provider. Inherit from ActionController::API
  # to skip view lookup, cookie loading, and CSRF protection, all of which
  # are meaningless here.
  class BaseController < ActionController::API
    rescue_from ActionController::BadRequest, with: :bad_request

    private

    def bad_request(exception)
      Rails.logger.warn("webhook rejected: #{exception.class}: #{exception.message}")
      head :bad_request
    end
  end
end
