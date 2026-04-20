module Admin
  # Platform admin surface — Kitchef team only. NOT for operators.
  # Shows accounts created, platform-wide stats, activity, incident
  # signals. The routing layer (AdminConstraint in config/routes.rb)
  # is the primary access gate; require_admin here is belt-and-suspenders
  # for the case where a controller is ever reached outside the
  # constraint (e.g. direct dispatch from another controller or test).
  class BaseController < ApplicationController
    layout "admin"

    before_action :require_admin

    private

    def require_admin
      return if Current.user&.admin?

      if Current.user
        redirect_to root_path, alert: t("admin.errors.not_authorized")
      else
        redirect_to new_session_path
      end
    end
  end
end
