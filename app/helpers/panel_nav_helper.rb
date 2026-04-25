module PanelNavHelper
  PanelNavItem = Data.define(:id, :label, :icon, :href, :badge)

  # Canonical dashboard navigation — shared between the sidebar and the
  # top-bar mobile drawer. Lives in a helper (rather than a component
  # method) so both surfaces can reach it inside their render contexts
  # without having to spin up a throwaway sidebar instance — which trips
  # ViewComponent's `TranslateCalledBeforeRenderError` because its #t
  # isn't wired up until after the render pipeline starts.
  def panel_nav_sections
    [
      {
        kicker: t("panel.nav.section"),
        items: [
          PanelNavItem.new(:home,           t("panel.nav.home"),           :home,           root_path,                    nil),
          PanelNavItem.new(:orders,         t("panel.nav.orders"),         :clipboard_list, orders_path,                  nil),
          PanelNavItem.new(:recipes,        t("panel.nav.recipes"),        :book_open,      recipes_path,                 nil),
          PanelNavItem.new(:ingredients,    t("panel.nav.ingredients"),    :carrot,         ingredients_path,             nil),
          PanelNavItem.new(:suppliers,      t("panel.nav.suppliers"),      :store,          suppliers_path,               nil),
          PanelNavItem.new(:purchases,      t("panel.nav.purchases"),      :receipt,        purchases_path,               nil),
          PanelNavItem.new(:fixed_costs,    t("panel.nav.fixed_costs"),    :calendar_range, fixed_costs_path,             nil),
          PanelNavItem.new(:clients,        t("panel.nav.clients"),        :users,          clients_path,                 nil),
          PanelNavItem.new(:schedule,       t("panel.nav.schedule"),       :calendar,       schedule_path,                nil),
          PanelNavItem.new(:production,     t("panel.nav.production"),     :chef_hat,       production_path,              nil)
        ]
      },
      {
        kicker: t("panel.nav.reports_section"),
        items: [
          PanelNavItem.new(:reports_menu,    t("panel.nav.reports_menu"),    :bar_chart_3, reports_menu_engineering_path, nil),
          PanelNavItem.new(:reports_finance, t("panel.nav.reports_finance"), :line_chart,  reports_finance_path,          nil)
        ]
      },
      {
        kicker: t("panel.nav.account_section"),
        items: [
          PanelNavItem.new(:account,      t("panel.nav.account"),      :settings,    account_path,      nil),
          PanelNavItem.new(:subscription, t("panel.nav.subscription"), :credit_card, subscription_path, nil)
        ]
      }
    ]
  end

  # Matches an item against the current request path. Exact match for the
  # home ("/") route; prefix match for everything else so nested pages
  # (e.g. /orders/123/edit) keep their parent section highlighted.
  def panel_nav_active?(item, current_path)
    return false if current_path.blank?
    path = current_path.split("?").first
    target = item.href.to_s.split("?").first
    return path == "/" if item.id == :home
    path == target || path.start_with?("#{target}/")
  end
end
