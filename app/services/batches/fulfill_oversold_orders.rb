module Batches
  # Phase 13C — when a fresh batch arrives, sweep oversold order items
  # for the same recipe whose delivery date falls inside the batch's
  # availability window and bind them to it. Releases the "sin stock"
  # chip on the kanban without the operator doing anything.
  #
  # Scans only orders in non-terminal fulfillment states (`placed`,
  # `confirmed`, `in_production`) — delivered/canceled orders stay as
  # historical records. Within those, resolves oldest-first (by
  # delivery_date, then created_at) so the customer who ordered first
  # is fulfilled first.
  #
  # Returns the count of order items resolved.
  class FulfillOversoldOrders < ApplicationService
    option :batch

    def call
      return 0 unless batch.account.inventory_enabled?
      return 0 if batch.canceled?

      resolved = 0
      Order.transaction do
        candidates_for(batch).find_each do |item|
          remaining = batch.units_remaining
          break if remaining <= 0

          qty = item.quantity.to_d
          next if remaining < qty

          item.update_columns(
            consumed_batch_id: batch.id,
            consumed_quantity: qty,
            oversold:          false
          )
          resolved += 1
        end
      end

      resolved
    end

    private

    def candidates_for(batch)
      OrderItem
        .joins(:order)
        .where(recipe_id: batch.recipe_id, oversold: true)
        .where(orders: {
          account_id:    batch.account_id,
          discarded_at:  nil,
          delivery_date: batch.available_from..batch.available_until,
          state:         %w[placed confirmed in_production]
        })
        .order("orders.delivery_date ASC, orders.created_at ASC")
    end
  end
end
