module Dashboards
  # Ambient "is the business OK this week?" card that lives at the top of
  # the operator's dashboard. Runs two Reports::Finance aggregations on
  # load (this week + last week); both are cheap enough (single GROUP BY)
  # to absorb on every dashboard render without caching. When the signal
  # is too thin (< 3 delivered pedidos this week), we render a muted
  # placeholder instead of a hard zero — nudging the operator without
  # shouting "¡$0 ingresos!" at them before they've even delivered.
  class WeeklySnapshotComponent < ApplicationComponent
    option :account
    option :today, default: -> { Date.current }

    def render?
      account.present?
    end

    def stats
      @stats ||= ::Reports::Finance.call(
        account:  account,
        starting: week_start,
        ending:   week_end
      )
    end

    def previous_stats
      @previous_stats ||= ::Reports::Finance.call(
        account:  account,
        starting: week_start - 7.days,
        ending:   week_end - 7.days
      )
    end

    def week_start = today.beginning_of_week(:monday)
    def week_end   = today.end_of_week(:monday)

    def muted?
      stats.order_count < 3
    end

    def revenue       = Money.new(stats.revenue_cents, "MXN")
    def prev_revenue  = Money.new(previous_stats.revenue_cents, "MXN")
    def margin_pct    = stats.gross_margin_pct
    def order_count   = stats.order_count

    def delta_pct
      return nil if previous_stats.revenue_cents.zero?
      ((stats.revenue_cents - previous_stats.revenue_cents).to_f / previous_stats.revenue_cents * 100).round
    end

    def compare_label
      return I18n.t("dashboard.weekly_snapshot.no_baseline") if previous_stats.revenue_cents.zero?

      amount = helpers.humanized_money_with_symbol(prev_revenue)
      case delta_pct
      when nil, 0 then I18n.t("dashboard.weekly_snapshot.compare_flat", amount: amount)
      when ->(x) { x > 0 } then I18n.t("dashboard.weekly_snapshot.compare_up", amount: amount, pct: delta_pct)
      else I18n.t("dashboard.weekly_snapshot.compare_down", amount: amount, pct: delta_pct)
      end
    end
  end
end
