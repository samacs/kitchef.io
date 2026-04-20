module Reports
  class FinanceController < AuthenticatedController
    def show
      render_stub(title: t("reports.finance.title"), meta: "reports/finance#show")
    end
  end
end
