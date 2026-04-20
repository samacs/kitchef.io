module Production
  class WeeklyController < AuthenticatedController
    def show
      render_stub(title: t("production.weekly.title"), meta: "production/weekly#show")
    end
  end
end
