class StaticPagesController < ApplicationController
  # Public marketing surface — no auth required.
  allow_unauthenticated_access

  layout "marketing"

  before_action :verify_page_exists

  # Single-action controller that renders a template matching the :page
  # route parameter (home, pricing, how_it_works, faq, legal/terms, …).
  # Adding a new static page means adding a view file — no controller
  # changes — and wiring one line in config/routes.rb.
  def show
    # The marketing layout renders auth-aware chrome (sign-in/up links or the
    # user menu). `Vary: Cookie` tells intermediate caches and the browser
    # to key cached HTML by cookie so a signed-in operator's header doesn't
    # leak to an anonymous visitor. Authenticated requests skip the public
    # cache entirely; anonymous requests cache publicly for an hour with
    # stale-while-revalidate so reloads stay instant while content edits
    # propagate within a few minutes.
    response.headers["Vary"] = "Cookie"

    if authenticated?
      expires_in 0, public: false, must_revalidate: true
    else
      expires_in 1.hour, public: true, stale_while_revalidate: 5.minutes
    end

    render page_view if stale?(etag: [ page_view, authenticated? ])
  end

  private

  # Maps route literals like "/como-funciona" → view template
  # "static_pages/how_it_works". A `:doc` param (legal pages) is nested
  # under the parent path segment.
  def page_view
    @page_view ||= if params[:doc].present?
      "static_pages/#{params[:page]}/#{params[:doc].tr("-", "_")}"
    else
      "static_pages/#{params[:page].tr("-", "_")}"
    end
  end

  def verify_page_exists
    return if lookup_context.template_exists?(page_view, [], false)

    raise ActionController::RoutingError, "Unknown static page: #{page_view}"
  end
end
