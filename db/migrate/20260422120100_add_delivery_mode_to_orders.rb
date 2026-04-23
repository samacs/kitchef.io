class AddDeliveryModeToOrders < ActiveRecord::Migration[8.1]
  def change
    # Distinguishes "send this out as soon as it's ready" (same-day, Uber-style)
    # from "send this out during the scheduled window". ASAP pedidos keep
    # `delivery_start_time` + `delivery_end_time` as NULL — the operator's
    # kanban + production view surface "ASAP — dispatch when ready" for
    # them. `scheduled` is the default so existing data stays correct and
    # the storefront's default checkout still picks a concrete window.
    add_column :orders, :delivery_mode, :integer, default: 0, null: false
    add_index  :orders, [ :account_id, :delivery_date, :delivery_mode ],
      name: "idx_orders_account_date_delivery_mode"
  end
end
