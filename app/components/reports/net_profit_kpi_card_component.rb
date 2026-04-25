module Reports
  # Phase 10 — "Utilidad neta" card on /reports/finance. Sits alongside
  # the existing margen bruto / margen real cards in the KPI row.
  # Accepts the full PeriodStats so we can surface sub-info (fixed-cost
  # contribution, per-pedido fixed-cost tile).
  class NetProfitKpiCardComponent < ApplicationComponent
    option :stats

    def amount
      Money.new(stats.net_profit_cents, "MXN")
    end

    def fixed_costs
      Money.new(stats.fixed_costs_cents, "MXN")
    end

    def pct
      stats.net_profit_pct
    end

    def pct_tone
      return :flat if pct.nil?
      pct.negative? ? :down : :up
    end
  end
end
