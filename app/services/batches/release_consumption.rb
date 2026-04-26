module Batches
  # Counterpart to FulfillOversoldOrders. Runs when a batch is canceled
  # so the order items that were consuming from it don't sit pointing
  # at a dead batch. For each affected item:
  #
  #   1. Try to rebind to another active batch via Orders::BatchPicker
  #      — if one has remaining stock for the same delivery date, the
  #      item moves over silently (kanban stays clean).
  #   2. Otherwise nullify `consumed_batch_id` and re-flag `oversold`
  #      so the kanban surfaces the "sin stock" chip again with the
  #      "Anotar un lote" CTA.
  #
  # Returns [rebound_count, oversold_count].
  class ReleaseConsumption < ApplicationService
    option :batch

    def call
      return [ 0, 0 ] unless batch.account.inventory_enabled?

      rebound = 0
      oversold = 0

      Order.transaction do
        affected_items.each do |item|
          replacement = Orders::BatchPicker.call(
            account:       batch.account,
            recipe:        item.recipe,
            delivery_date: item.order.delivery_date,
            quantity:      item.quantity
          )

          if replacement && replacement.id != batch.id
            item.update_columns(
              consumed_batch_id: replacement.id,
              consumed_quantity: item.quantity,
              oversold:          false
            )
            rebound += 1
          else
            item.update_columns(
              consumed_batch_id: nil,
              consumed_quantity: 0,
              oversold:          true
            )
            oversold += 1
          end
        end
      end

      [ rebound, oversold ]
    end

    private

    # Snapshot the affected items BEFORE we start mutating, so the
    # picker's "still available" math doesn't shift mid-loop. Skip
    # items belonging to canceled or delivered orders — those are
    # historical and shouldn't be rewritten.
    def affected_items
      OrderItem
        .joins(:order)
        .where(consumed_batch_id: batch.id)
        .where.not(orders: { state: %w[canceled delivered] })
        .includes(:order, :recipe)
        .to_a
    end
  end
end
