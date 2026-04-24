module Reports
  # Per-recipe performance in a date range. Aggregates snapshots from
  # `order_items` over the orders that shipped in the window, returning
  # one row per saleable recipe with units sold, revenue, COGS, and two
  # rankings (by revenue, by margin) so the view can bucket into
  # "estrellas / estables / revisa estos" without re-sorting in Ruby.
  #
  # Recipes that have zero sales in the window still appear — the "revisa
  # estos" bucket relies on knowing which saleable platillos went
  # untouched. `last_sold_on` lets the view print "último pedido hace N
  # días" for those recipes, even if the last sale falls outside the
  # chosen window.
  class RecipePerformance < ApplicationQuery
    DEFAULT_STATES = %w[delivered paid].freeze

    RecipeRow = Data.define(
      :recipe,
      :units_sold,
      :revenue_cents,
      :cogs_cents,
      :last_sold_on
    ) do
      def margin_cents = revenue_cents - cogs_cents

      def margin_pct
        return nil if revenue_cents.zero?
        (margin_cents.to_f / revenue_cents * 100).round
      end

      def avg_unit_price_cents
        return 0 if units_sold.zero?
        (revenue_cents.to_f / units_sold).round
      end

      def idle? = units_sold.zero?
    end

    option :account
    option :starting
    option :ending

    def call
      sold_rows = sold_rows_by_recipe_id
      last_sold = last_sold_dates

      # Show every currently-saleable recipe. Internal / draft / discarded
      # recipes stay hidden so the list reads as "your menu" — not "every
      # record that ever existed".
      recipes = account.recipes.kept.saleable

      recipes.map do |recipe|
        sold = sold_rows[recipe.id]
        RecipeRow.new(
          recipe:        recipe,
          units_sold:    sold ? sold[:units] : 0,
          revenue_cents: sold ? sold[:revenue] : 0,
          cogs_cents:    sold ? sold[:cogs] : 0,
          last_sold_on:  last_sold[recipe.id]
        )
      end
    end

    private

    def sold_rows_by_recipe_id
      sql = ActiveRecord::Base.send(:sanitize_sql_array, [ <<~SQL.squish, account.id, starting, ending, *DEFAULT_STATES ])
        SELECT
          order_items.recipe_id AS recipe_id,
          COALESCE(SUM(order_items.quantity), 0) AS units,
          COALESCE(SUM(order_items.unit_price_cents * order_items.quantity), 0)::bigint AS revenue,
          COALESCE(SUM(order_items.unit_cost_cents  * order_items.quantity), 0)::bigint AS cogs
        FROM order_items
        INNER JOIN orders ON orders.id = order_items.order_id
        WHERE orders.account_id = ?
          AND orders.discarded_at IS NULL
          AND orders.delivery_date BETWEEN ? AND ?
          AND orders.state IN (#{Array.new(DEFAULT_STATES.length, "?").join(", ")})
        GROUP BY order_items.recipe_id
      SQL

      rows = ActiveRecord::Base.connection.exec_query(sql, "Reports::RecipePerformance")
      rows.each_with_object({}) do |row, memo|
        memo[row["recipe_id"]] = {
          units:   BigDecimal(row["units"].to_s),
          revenue: row["revenue"].to_i,
          cogs:    row["cogs"].to_i
        }
      end
    end

    # One extra query: when was each recipe last sold, ever? Scopes to this
    # account and all delivered/paid orders — not bounded by the window —
    # so the "revisa estos" bucket can say "último pedido hace 21 días"
    # even when the window is "last 7 days".
    def last_sold_dates
      rows = OrderItem
        .joins(:order)
        .where(orders: { account_id: account.id, state: DEFAULT_STATES })
        .where(orders: { discarded_at: nil })
        .group(:recipe_id)
        .maximum("orders.delivery_date")

      rows.transform_values { |d| d.is_a?(Date) ? d : Date.parse(d.to_s) }
    end
  end
end
