module Production
  # Lightweight 7-day summary for the top strip on `/production`. Returns
  # one row per day with pedido counts grouped by high-level buckets the
  # day card surfaces as chips ("3 por confirmar", "5 a cocinar", "2 entregas").
  # Keeping this separate from `DailyPlan` so the strip's N+1-free query
  # stays single-shot — we group in Ruby after one window-wide SELECT.
  class WeekOverview < ApplicationService
    DayRow = Data.define(:date, :total, :to_confirm, :to_cook, :to_deliver, :canceled) do
      def empty? = total.zero?
    end

    # Bucketing for the day-card chips:
    #   to_confirm → `placed` pedidos awaiting the operator's decision
    #   to_cook    → confirmed + in_production (the kitchen queue)
    #   to_deliver → ready + en_route (live delivery-side work)
    TO_CONFIRM_STATES = %w[placed].freeze
    TO_COOK_STATES    = %w[confirmed in_production].freeze
    TO_DELIVER_STATES = %w[ready en_route].freeze
    CANCELED_STATES   = %w[canceled].freeze

    WINDOW_DAYS = 7

    option :account
    option :starting, default: -> { Date.current }

    def self.for(account:, starting: Date.current)
      call(account: account, starting: starting)
    end

    def call
      ending = starting + (WINDOW_DAYS - 1).days
      grouped = account.orders.kept
        .where(delivery_date: starting..ending)
        .group(:delivery_date, :state)
        .count

      (0...WINDOW_DAYS).map do |offset|
        date = starting + offset.days
        row_for(date, grouped)
      end
    end

    private

    def row_for(date, grouped)
      counts = Hash.new(0)
      grouped.each do |(day, state), count|
        next unless day == date
        counts[state] = count
      end

      total = counts.values.sum - counts.slice(*CANCELED_STATES).values.sum
      DayRow.new(
        date:       date,
        total:      total,
        to_confirm: counts.slice(*TO_CONFIRM_STATES).values.sum,
        to_cook:    counts.slice(*TO_COOK_STATES).values.sum,
        to_deliver: counts.slice(*TO_DELIVER_STATES).values.sum,
        canceled:   counts.slice(*CANCELED_STATES).values.sum
      )
    end
  end
end
