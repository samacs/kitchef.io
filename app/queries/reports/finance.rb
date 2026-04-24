module Reports
  # Aggregates order-item snapshots (sale price + cost) into a period-shaped
  # money answer: revenue, COGS, gross margin, order count, and a per-day
  # breakdown. Everything is read from the `order_items` snapshots rather
  # than from live recipe cost, so a delivered pedido from three months
  # ago reflects that quarter's masa price, not today's.
  #
  # The "paid" axis for revenue recognition is AASM state — an order counts
  # once it's `delivered` or `paid`. The distinction between "delivered
  # but unpaid" and "paid" is A/R vs cash; both are recognized revenue.
  # Pass `only_paid: true` to drop the A/R side for a stricter cash basis.
  class Finance < ApplicationQuery
    # Default revenue states: the platillo is physically out of the kitchen.
    # `paid` is orthogonal to `delivered` in our data model — an order can
    # be paid-before-delivery (anticipos) or delivered-then-paid (cash on
    # hand-off), so both get folded in. Canceled orders never count.
    DEFAULT_STATES   = %w[delivered paid].freeze
    PAID_ONLY_STATES = %w[paid].freeze

    PRESETS = %i[this_week last_week this_month last_month last_30_days].freeze

    DayStats = Data.define(:date, :revenue_cents, :cogs_cents, :purchases_cents, :order_count) do
      def margin_cents = revenue_cents - cogs_cents

      def margin_pct
        return nil if revenue_cents.zero?
        (margin_cents.to_f / revenue_cents * 100).round
      end
    end

    PeriodStats = Data.define(
      :starting, :ending,
      :revenue_cents, :cogs_cents, :purchases_cents,
      :order_count, :purchase_count, :avg_order_cents,
      :by_day
    ) do
      def gross_margin_cents = revenue_cents - cogs_cents

      def gross_margin_pct
        return nil if revenue_cents.zero?
        (gross_margin_cents.to_f / revenue_cents * 100).round
      end

      # "Margen real" — revenue minus *actual* money spent on
      # ingredients in the window, not the snapshotted COGS. Surfaces
      # the gap between the cost at order time and the cost of today's
      # reality. Only meaningful when we have purchase data.
      def real_margin_cents = revenue_cents - purchases_cents

      def real_margin_pct
        return nil if revenue_cents.zero? || purchases_cents.zero?
        (real_margin_cents.to_f / revenue_cents * 100).round
      end

      def empty?              = order_count.zero? && purchase_count.zero?
      def has_signal?         = order_count >= 3
      def has_purchase_signal? = purchase_count.positive?
    end

    option :account
    option :starting
    option :ending
    option :only_paid, default: -> { false }

    # ----- Convenience entry points ------------------------------------

    # Returns [range, stats] for a named preset. The resolved range is
    # useful for the view's "Del 20 al 26 de abril" subtitle.
    def self.for_preset(account:, preset:, today: Date.current, only_paid: false)
      starting, ending = resolve_preset(preset, today)
      stats = call(account: account, starting: starting, ending: ending, only_paid: only_paid)
      [ (starting..ending), stats ]
    end

    def self.resolve_preset(preset, today = Date.current)
      case preset.to_sym
      when :this_week
        start = today.beginning_of_week(:monday)
        [ start, start + 6 ]
      when :last_week
        start = (today - 1.week).beginning_of_week(:monday)
        [ start, start + 6 ]
      when :this_month
        [ today.beginning_of_month, today.end_of_month ]
      when :last_month
        start = (today - 1.month).beginning_of_month
        [ start, start.end_of_month ]
      when :last_30_days
        [ today - 29, today ]
      else
        raise ArgumentError, "unknown preset: #{preset.inspect}"
      end
    end

    # --------------------------------------------------------------------

    def call
      rows_by_date     = aggregate.index_by { |r| r[:date] }
      purchases_by_day = aggregate_purchases.index_by { |r| r[:date] }

      by_day = (starting..ending).map do |date|
        row  = rows_by_date[date]
        prow = purchases_by_day[date]
        DayStats.new(
          date:            date,
          revenue_cents:   row  ? row[:revenue]  : 0,
          cogs_cents:      row  ? row[:cogs]     : 0,
          purchases_cents: prow ? prow[:total]   : 0,
          order_count:     row  ? row[:orders]   : 0
        )
      end

      revenue_total    = by_day.sum(&:revenue_cents)
      cogs_total       = by_day.sum(&:cogs_cents)
      purchases_total  = by_day.sum(&:purchases_cents)
      order_total      = by_day.sum(&:order_count)
      purchase_count   = purchases_by_day.values.sum { |r| r[:purchases_count].to_i }

      PeriodStats.new(
        starting:         starting,
        ending:           ending,
        revenue_cents:    revenue_total,
        cogs_cents:       cogs_total,
        purchases_cents:  purchases_total,
        order_count:      order_total,
        purchase_count:   purchase_count,
        avg_order_cents:  order_total.zero? ? 0 : (revenue_total.to_f / order_total).round,
        by_day:           by_day
      )
    end

    private

    # One SQL round-trip per period: revenue/COGS/order-count per delivery
    # date. Joins items → orders so we can filter by state + delivery_date
    # and still sum the snapshotted prices. Grouping on `delivery_date`
    # (not `created_at`) so the operator's week is defined by when the
    # food shipped, not when the form got filled.
    def aggregate
      states = only_paid ? PAID_ONLY_STATES : DEFAULT_STATES
      placeholders = Array.new(states.length, "?").join(", ")

      sql = ActiveRecord::Base.send(:sanitize_sql_array, [ <<~SQL.squish, account.id, starting, ending, *states ])
        SELECT
          orders.delivery_date AS date,
          COALESCE(SUM(order_items.unit_price_cents * order_items.quantity), 0)::bigint AS revenue,
          COALESCE(SUM(order_items.unit_cost_cents  * order_items.quantity), 0)::bigint AS cogs,
          COUNT(DISTINCT orders.id)::bigint AS orders
        FROM orders
        LEFT JOIN order_items ON order_items.order_id = orders.id
        WHERE orders.account_id = ?
          AND orders.discarded_at IS NULL
          AND orders.delivery_date BETWEEN ? AND ?
          AND orders.state IN (#{placeholders})
        GROUP BY orders.delivery_date
        ORDER BY orders.delivery_date
      SQL

      ActiveRecord::Base.connection.exec_query(sql, "Reports::Finance").map do |row|
        {
          date:    row["date"].is_a?(Date) ? row["date"] : Date.parse(row["date"].to_s),
          revenue: row["revenue"].to_i,
          cogs:    row["cogs"].to_i,
          orders:  row["orders"].to_i
        }
      end
    end

    # Phase 9 — "gastos reales" per day. Sums the line-item subtotals
    # (qty × unit_cost_cents) across every non-discarded Purchase whose
    # `purchased_on` falls in the window. One SQL round-trip, same shape
    # as `aggregate` above so the per-day merge in `#call` stays trivial.
    def aggregate_purchases
      sql = ActiveRecord::Base.send(:sanitize_sql_array, [ <<~SQL.squish, account.id, starting, ending ])
        SELECT
          purchases.purchased_on AS date,
          COALESCE(SUM(purchase_items.quantity * purchase_items.unit_cost_cents), 0)::bigint AS total,
          COUNT(DISTINCT purchases.id)::bigint AS purchases_count
        FROM purchases
        LEFT JOIN purchase_items ON purchase_items.purchase_id = purchases.id
        WHERE purchases.account_id = ?
          AND purchases.discarded_at IS NULL
          AND purchases.purchased_on BETWEEN ? AND ?
        GROUP BY purchases.purchased_on
        ORDER BY purchases.purchased_on
      SQL

      ActiveRecord::Base.connection.exec_query(sql, "Reports::Finance.purchases").map do |row|
        {
          date:            row["date"].is_a?(Date) ? row["date"] : Date.parse(row["date"].to_s),
          total:           row["total"].to_i,
          purchases_count: row["purchases_count"].to_i
        }
      end
    end
  end
end
