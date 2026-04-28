module Production
  # Read-side aggregation that answers the two questions an operator asks
  # the moment she opens /production for a given day:
  #
  #   1. What do I cook today?  → cook_list (recipe × total qty, rolled-up notes)
  #   2. Who gets what, and in what order? → handoffs (deliveries, ordered by window)
  #
  # Canceled orders are excluded — they don't drive cooking. Placed and
  # later live states are all in-scope because the operator needs visibility
  # on pedidos she may still accept. Phase 8 will rewrite the cook list
  # against the recipe dependency graph (ingredient-level rollups) without
  # changing this call signature.
  class DailyPlan < ApplicationService
    DONE_STATES = %w[ready en_route delivered].freeze

    CookRow = Data.define(:recipe, :recipe_name, :total_qty, :unit, :notes_roll_up, :state_breakdown) do
      def display_qty
        formatted = total_qty.to_s("F").sub(/\.0+\z/, "").sub(/(\.\d*?)0+\z/, '\1')
        formatted.presence || total_qty.to_s
      end

      def done?
        state_breakdown.except(*DONE_STATES).values.none?(&:positive?)
      end

      def waiting_qty
        (state_breakdown.fetch("placed", 0) + state_breakdown.fetch("confirmed", 0))
      end

      def cooking_qty
        state_breakdown.fetch("in_production", 0)
      end

      def done_qty
        DONE_STATES.sum { |s| state_breakdown.fetch(s, 0) }
      end
    end

    Result = Data.define(:date, :cook_list, :handoffs, :counts) do
      def empty? = cook_list.empty? && handoffs.empty?

      def active_cook_list = cook_list.reject(&:done?)
      def done_cook_list   = cook_list.select(&:done?)
    end

    option :account
    option :on, default: -> { Date.current }

    def self.for(account:, on: Date.current)
      call(account: account, on: on)
    end

    def call
      orders = account.orders.kept
        .where(delivery_date: on)
        .where.not(state: "canceled")
        .includes(:client, items: :recipe)
        .order(:delivery_start_time, :created_at)

      counts = orders.group_by(&:state).transform_values(&:size)
      Result.new(
        date:      on,
        cook_list: build_cook_list(orders),
        handoffs:  build_handoffs(orders),
        counts:    counts
      )
    end

    private

    def build_cook_list(orders)
      buckets = Hash.new do |h, k|
        h[k] = { recipe: nil, total: BigDecimal("0"), notes: [], states: Hash.new(BigDecimal("0")) }
      end

      orders.each do |order|
        order.items.each do |item|
          next if item.recipe.nil?

          bucket = buckets[item.recipe.id]
          bucket[:recipe] ||= item.recipe
          qty = BigDecimal(item.quantity.to_s)
          bucket[:total]  += qty
          bucket[:states][order.state] += qty
          if item.notes.present?
            client_label = order.client&.name.presence || I18n.t("production.cook_list.anonymous_client")
            bucket[:notes] << "#{client_label}: #{item.notes.strip}"
          end
        end
      end

      buckets.values
        .sort_by { |b| [ -b[:total], b[:recipe].name.to_s.downcase ] }
        .map do |b|
          CookRow.new(
            recipe:          b[:recipe],
            recipe_name:     b[:recipe].name,
            total_qty:       b[:total],
            unit:            b[:recipe].yield_unit,
            notes_roll_up:   b[:notes],
            state_breakdown: b[:states]
          )
        end
    end

    def build_handoffs(orders)
      orders.select(&:delivery?)
    end
  end
end
