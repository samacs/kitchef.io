module Reports
  # One row in the per-day breakdown on /reports/finance. Keeps the list
  # scannable on a phone: date, revenue, order count, margin % — and that's
  # it. Empty days render muted so an operator's "this week" view isn't
  # dominated by zeros.
  class DayRowComponent < ApplicationComponent
    option :day_stats

    def empty?
      day_stats.order_count.zero?
    end

    def weekday_label
      I18n.l(day_stats.date, format: :weekday_long)
    end

    def date_label
      I18n.l(day_stats.date, format: :short_day)
    end

    def revenue
      Money.new(day_stats.revenue_cents, "MXN")
    end

    def margin
      Money.new(day_stats.margin_cents, "MXN")
    end
  end
end
