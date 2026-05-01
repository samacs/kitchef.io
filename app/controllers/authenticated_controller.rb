# Base class for every authenticated operator-facing controller — the
# working surface a kitchen owner uses after signing in.
#
# The `Authentication` concern on ApplicationController ensures there's a
# signed-in user and `set_current_account` in ApplicationController resolves
# Current.account; here we enforce that the account actually exists (an
# orphaned user without a kitchen can't be dropped into /orders).
#
# Nothing in here is specific to the removed `Panel::` namespace — the
# layout name is semantic ("panel" = operator dashboard panel), not a
# reference to a Ruby module.
class AuthenticatedController < ApplicationController
  include DrawerResponder
  include ResolvesRecord

  layout "panel"

  before_action :require_account
  around_action :use_account_time_zone

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  private

  def require_account
    return if Current.account

    redirect_to new_session_path, alert: t("panel.errors.account_missing")
  end

  def use_account_time_zone(&)
    tz = Current.account&.time_zone.presence || "America/Mexico_City"
    Time.use_zone(tz, &)
  end

  def record_not_found
    redirect_back fallback_location: root_path,
                  alert: t("panel.errors.record_not_found")
  end
end
