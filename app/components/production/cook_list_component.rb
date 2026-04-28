module Production
  # "Cocinar hoy" — a flat, summed table of recipe × quantity for every
  # non-canceled pedido on a given day. Notes roll up as a muted sub-line
  # so the operator doesn't have to click into each pedido to find the
  # "sin cilantro" requests.
  #
  # State-aware: each row shows a breakdown of waiting / cooking / done
  # quantities. Rows where every quantity is in a "done" state collapse
  # under a summary so the operator focuses on actual remaining work.
  class CookListComponent < ApplicationComponent
    option :plan     # Production::DailyPlan::Result
    option :on_date

    def active_rows  = plan.active_cook_list
    def done_rows    = plan.done_cook_list

    def empty?
      plan.cook_list.empty?
    end

    def kicker
      I18n.t("production.cook_list.kicker")
    end

    def headline
      I18n.t("production.cook_list.headline")
    end

    def bulk_action_visible?
      plan.counts.fetch("confirmed", 0).positive?
    end
  end
end
