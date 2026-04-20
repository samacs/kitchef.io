module Nav
  # Dashboard sidebar — 240px fixed rail with logo, primary nav, and the
  # user menu as an identity card at the bottom. Matches the dashboard
  # prototype (Kitchef Dashboard.html lines 272-321). Hidden under lg;
  # the top bar exposes the same nav inside a dropdown on narrow screens.
  #
  # The nav definition itself lives in PanelNavHelper so both surfaces
  # can reach it inside their render contexts without instantiating a
  # component just to read a config attribute.
  class DashboardSidebarComponent < ApplicationComponent
    option :current_user
    option :current_account, optional: true
    option :current_path,    optional: true
  end
end
