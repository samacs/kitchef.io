module Production
  # Aggregated shopping list for the next 7 days. Simple-mode v1: groups
  # by recipe name, summing quantities across all orders in the window.
  # Only confirmed-or-later orders count — `placed` pedidos are still
  # awaiting the operator's decision, so driving the market run off them
  # would have her buying for pedidos she might cancel.
  #
  # Phase 8 will replace this aggregation layer: recipes will expand into
  # their ingredient trees via `Recipes::CostCalculator`'s traversal, and
  # this service will return ingredient rows instead of recipe rows. The
  # call signature stays identical — the view switches when the account
  # flips `use_composable_recipes`.
  class WeeklyShoppingList < ApplicationService
    ShoppingRow = Data.define(:recipe, :recipe_name, :total_qty, :unit, :prep_notes) do
      def display_qty
        formatted = total_qty.to_s("F").sub(/\.0+\z/, "").sub(/(\.\d*?)0+\z/, '\1')
        formatted.presence || total_qty.to_s
      end
    end

    Result = Data.define(:starting, :ending, :rows) do
      def empty? = rows.empty?
    end

    QUALIFYING_STATES = %w[confirmed in_production ready en_route delivered].freeze
    WINDOW_DAYS = 7

    option :account
    option :starting, default: -> { Date.current }

    def self.for(account:, starting: Date.current)
      call(account: account, starting: starting)
    end

    def call
      ending = starting + (WINDOW_DAYS - 1).days
      orders = account.orders.kept
        .where(delivery_date: starting..ending)
        .where(state: QUALIFYING_STATES)
        .includes(items: :recipe)

      Result.new(
        starting: starting,
        ending:   ending,
        rows:     aggregate(orders)
      )
    end

    private

    def aggregate(orders)
      buckets = Hash.new { |h, k| h[k] = { recipe: nil, total: BigDecimal("0"), notes: [] } }

      orders.each do |order|
        order.items.each do |item|
          next if item.recipe.nil?

          bucket = buckets[item.recipe.id]
          bucket[:recipe] ||= item.recipe
          bucket[:total]  += BigDecimal(item.quantity.to_s)
          bucket[:notes] << item.notes.strip if item.notes.present?
        end
      end

      buckets.values
        .sort_by { |b| [ -b[:total], b[:recipe].name.to_s.downcase ] }
        .map do |b|
          ShoppingRow.new(
            recipe:      b[:recipe],
            recipe_name: b[:recipe].name,
            total_qty:   b[:total],
            unit:        b[:recipe].yield_unit,
            prep_notes:  b[:notes]
          )
        end
    end
  end
end
