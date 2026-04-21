class AddPickupReminderSentAtToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :pickup_reminder_sent_at, :datetime

    # Partial index tuned for PickupReminderScanJob: the scan only cares
    # about pickup pedidos currently in `ready` that have not been pinged.
    # Keeping it partial keeps the index tiny (ready-pickup pedidos are
    # a small slice of the total orders table) while giving the cron scan
    # an index-only path.
    add_index :orders, :ready_at,
      where: "state = 'ready' AND delivery_type = 1 AND pickup_reminder_sent_at IS NULL",
      name: "idx_orders_pickup_reminder_pending"
  end
end
