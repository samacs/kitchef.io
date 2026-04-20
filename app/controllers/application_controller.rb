class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges,
  # import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses.
  stale_when_importmap_changes

  # Resolve Current.account from the signed-in user on every authenticated
  # request. For public pages (marketing, storefronts) Current.account stays
  # nil and the controller picks its own @storefront / session state.
  before_action :set_current_account

  private

  def set_current_account
    Current.account = Current.user&.owned_account
  end

  # Renders a minimal HTML placeholder page for Phase 6 controller stubs.
  # Every stub action that would otherwise return plain text goes through
  # here so Turbo Drive can replace the DOM after a form submit without
  # bailing on a non-HTML response.
  def render_stub(title:, meta: nil)
    render "shared/stub",
      locals: {
        title: title,
        kicker: controller_name.humanize,
        meta: meta,
        body: I18n.t("stubs.in_development")
      }
  end
end
