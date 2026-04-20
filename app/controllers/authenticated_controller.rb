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

  layout "panel"

  before_action :require_account

  private

  def require_account
    return if Current.account

    redirect_to new_session_path, alert: t("panel.errors.account_missing")
  end
end
