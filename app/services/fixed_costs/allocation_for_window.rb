module FixedCosts
  # Prorates every active FixedCost row across a date window and returns
  # the total in cents plus a per-category breakdown. Monthly rent = 1/30
  # per day, weekly = 1/7 per day, yearly = 1/365 per day — see Phase 10
  # plan §Locked decisions for why we don't fuss with fiscal months.
  #
  # Per-pedido rows (platform fees like Didi/Rappi) are multiplied by a
  # caller-supplied `delivered_pedido_count` rather than the date axis
  # — they scale with volume, not calendar.
  #
  #   result = FixedCosts::AllocationForWindow.call(
  #     account: Current.account,
  #     starting: Date.new(2026, 4, 1),
  #     ending:   Date.new(2026, 4, 7),
  #     pedido_count: 12
  #   )
  #   result.total_cents        # => 350_000
  #   result.by_category        # => { "Renta" => 350_000, ... }
  class AllocationForWindow < ApplicationService
    Result = Data.define(:total_cents, :by_category) do
      def empty? = total_cents.zero?
    end

    DAYS_PER_MONTH = 30
    DAYS_PER_WEEK  = 7
    DAYS_PER_YEAR  = 365

    option :account
    option :starting
    option :ending
    option :pedido_count, default: -> { 0 }

    def call
      totals_by_category = Hash.new(0)
      days_in_window     = (ending - starting).to_i + 1
      rows               = account.fixed_costs.kept
                                  .includes(:fixed_cost_category)
                                  .overlapping(starting, ending)

      rows.each do |row|
        cents = contribution_for(row, days_in_window)
        next if cents.zero?
        totals_by_category[row.fixed_cost_category.name] += cents
      end

      Result.new(
        total_cents: totals_by_category.values.sum,
        by_category: totals_by_category
      )
    end

    private

    # BigDecimal throughout; round to the cent at the end so a 14-day
    # prorate on a $15k/mo rent doesn't drift from 700_000 by ±1 cent
    # depending on integer-division order.
    def contribution_for(row, days_in_window)
      return per_pedido_contribution(row) if row.per_pedido?

      overlap = overlap_days(row)
      return 0 if overlap.zero?

      amount = BigDecimal(row.amount_cents.to_s)
      value =
        case row.recurrence.to_sym
        when :monthly  then amount * overlap / DAYS_PER_MONTH
        when :weekly   then amount * overlap / DAYS_PER_WEEK
        when :yearly   then amount * overlap / DAYS_PER_YEAR
        when :one_time
          # One-time cost lands on its start_date; bill the whole amount
          # if that date is inside the window, otherwise zero. end_date
          # is irrelevant for one-time rows.
          starting <= row.start_date && row.start_date <= ending ? amount : BigDecimal(0)
        else
          BigDecimal(0)
        end

      value.round(0).to_i
    end

    def per_pedido_contribution(row)
      return 0 if pedido_count.to_i.zero?
      return 0 if row.start_date > ending
      return 0 if row.end_date.present? && row.end_date < starting
      (row.cost_per_pedido_cents.to_i * pedido_count.to_i)
    end

    # Days the row is active within [starting, ending] — clamped by the
    # row's own start_date/end_date so a rent row that started April 15
    # only contributes 15 days of an April 1–30 window.
    def overlap_days(row)
      effective_start = [ row.start_date, starting ].max
      effective_end   = [ row.end_date || ending, ending ].min
      return 0 if effective_start > effective_end
      (effective_end - effective_start).to_i + 1
    end
  end
end
