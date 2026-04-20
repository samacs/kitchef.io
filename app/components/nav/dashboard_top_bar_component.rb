module Nav
  # Sticky dashboard top bar — matches Kitchef Dashboard.html lines
  # 339-372. Shows the current view's title + subtitle (serif + muted),
  # a search input, the theme toggle, the notifications chip, and a
  # primary action slot on the right.
  #
  # Pages customize via content_for from the template:
  #   <% content_for :page_title,    t(".title") %>
  #   <% content_for :page_subtitle, t(".subtitle") %>
  #   <% content_for :page_action do %>
  #     <a href="…" class="btn btn-primary">Nuevo pedido</a>
  #   <% end %>
  class DashboardTopBarComponent < ApplicationComponent
    option :current_user
    option :current_account, optional: true
    option :title,    optional: true
    option :subtitle, optional: true

    def display_title    = title.presence    || t("dashboard.title")
    def display_subtitle = subtitle.presence || t("dashboard.subtitle")
  end
end
