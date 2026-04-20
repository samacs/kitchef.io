class DashboardsController < AuthenticatedController
  def show
    render_stub(
      title: t("dashboard.title"),
      meta: "#{Current.account.name} · #{Current.account.to_param}"
    )
  end
end
