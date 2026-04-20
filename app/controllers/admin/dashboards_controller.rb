module Admin
  class DashboardsController < BaseController
    def show
      render_stub(title: t("admin.dashboard.title"), meta: "admin — #{Current.user.name.full}")
    end
  end
end
