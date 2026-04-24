module Reports
  # One cell in the three-up KPI triptych at the top of /reports/finance —
  # a money headline, a one-line supporting stat, and an optional delta
  # badge for week-over-week comparisons.
  #
  #   <%= render Reports::KpiCardComponent.new(
  #         label: t("reports.finance.kpi.this_week"),
  #         amount_cents: stats.revenue_cents,
  #         sub: t("reports.finance.kpi.orders_margin", count: stats.order_count, pct: stats.gross_margin_pct),
  #         delta_pct: +19) %>
  class KpiCardComponent < ApplicationComponent
    option :label
    option :amount_cents
    option :sub, optional: true
    option :delta_pct, optional: true
    option :muted, default: -> { false }
    option :href, optional: true

    def amount
      Money.new(amount_cents.to_i, "MXN")
    end

    def delta_label
      return nil if delta_pct.nil?
      sign = delta_pct.positive? ? "+" : ""
      "#{sign}#{delta_pct}%"
    end

    def delta_tone
      return :flat if delta_pct.nil? || delta_pct.zero?
      delta_pct.positive? ? :up : :down
    end
  end
end
