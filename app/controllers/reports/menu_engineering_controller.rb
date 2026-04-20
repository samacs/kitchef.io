module Reports
  class MenuEngineeringController < AuthenticatedController
    def show
      render_stub(title: t("reports.menu_engineering.title"), meta: "reports/menu_engineering#show")
    end
  end
end
