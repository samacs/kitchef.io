module ReportsHelper
  # "42 pedidos · 58% margen" — the one-liner under each KPI headline.
  # Falls back to just the pedido count when the margin is undefined
  # (zero-revenue window), so we never print "nil% margen".
  def finance_sub_text(stats)
    parts = [ I18n.t("reports.finance.kpi.orders_only", count: stats.order_count) ]
    if stats.respond_to?(:gross_margin_pct)
      pct = stats.gross_margin_pct
    else
      pct = stats.margin_pct
    end
    parts << I18n.t("reports.finance.kpi.margin_pct", pct: pct) if pct
    parts.join(" · ")
  end

  # Week-over-week delta as a rounded integer percentage. nil when the
  # previous window was empty (no divide-by-zero baseline) so the KPI card
  # just shows the raw revenue without a compare badge.
  def finance_delta_pct(current, previous)
    return nil if previous.nil? || previous.revenue_cents.zero?
    delta = current.revenue_cents - previous.revenue_cents
    ((delta.to_f / previous.revenue_cents) * 100).round
  end

  # Helper used by the weekly snapshot card on /. Keeps the dashboard view
  # free of math.
  def weekly_snapshot_delta_pct(stats, previous)
    finance_delta_pct(stats, previous)
  end
end
