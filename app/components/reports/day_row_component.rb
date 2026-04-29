module Reports
  # One row in the per-day breakdown on /reports/finance. Keeps the list
  # scannable on a phone: date, revenue, order count, margin % — and that's
  # it. Empty days render muted so an operator's "this week" view isn't
  # dominated by zeros.
  class DayRowComponent < ApplicationComponent
    option :day_stats
    option :show_expenses,    default: -> { false }
    option :show_fixed_costs, default: -> { false }
    option :show_discounts,   default: -> { false }

    def empty?
      day_stats.order_count.zero? && day_stats.purchases_cents.zero? && day_stats.fixed_costs_cents.zero?
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

    def expenses
      Money.new(day_stats.purchases_cents, "MXN")
    end

    def fixed
      Money.new(day_stats.fixed_costs_cents, "MXN")
    end

    def has_expenses?
      day_stats.purchases_cents.positive?
    end

    def has_fixed?
      day_stats.fixed_costs_cents.positive?
    end

    def discount
      Money.new(day_stats.discount_cents, "MXN")
    end

    def has_discount?
      day_stats.discount_cents.positive?
    end
  end
end
