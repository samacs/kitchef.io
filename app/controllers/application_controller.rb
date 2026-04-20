class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges,
  # import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses.
  stale_when_importmap_changes

  # Resolve Current.account from the signed-in user on every authenticated
  # request. For public pages (marketing, storefronts) we still try to
  # resume the session so the marketing header can render the user menu
  # when a signed-in operator visits `/pricing` — `resume_session` is a
  # no-op without a valid cookie, so anonymous requests stay anonymous.
  before_action :resume_current_session
  before_action :set_current_account

  private

  def resume_current_session
    # `resume_session` is defined on the Authentication concern and is
    # already called by `require_authentication`; re-invoking it here is
    # idempotent (it's guarded by `Current.session ||=`) and cheap.
    resume_session
  end

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
