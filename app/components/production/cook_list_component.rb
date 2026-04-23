module Production
  # "Cocinar hoy" — a flat, summed table of recipe × quantity for every
  # non-canceled pedido on a given day. Notes roll up as a muted sub-line
  # so the operator doesn't have to click into each pedido to find the
  # "sin cilantro" requests.
  class CookListComponent < ApplicationComponent
    option :plan     # Production::DailyPlan::Result
    option :on_date

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
