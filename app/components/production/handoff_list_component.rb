module Production
  # "Entregar hoy" — one row per delivery-type pedido for the day. Each
  # row surfaces the client, window, address, directions link, and the
  # primary next-step action. Pickup pedidos are excluded (they don't
  # need a handoff row — the customer walks in).
  class HandoffListComponent < ApplicationComponent
    include MapsHelper
    include OrdersHelper

    option :plan     # Production::DailyPlan::Result
    option :on_date

    def empty?
      plan.handoffs.empty?
    end

    def kicker
      I18n.t("production.handoff_list.kicker")
    end

    def headline
      I18n.t("production.handoff_list.headline")
    end

    def runner_url(controller_url_helpers)
      controller_url_helpers.runner_url(token: Runner::Token.encode(account: Current.account, date: on_date))
    end

    def runner_path(controller_url_helpers)
      controller_url_helpers.runner_path(token: Runner::Token.encode(account: Current.account, date: on_date))
    end
  end
end
