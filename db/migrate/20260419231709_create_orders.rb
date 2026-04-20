class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :account, null: false, foreign_key: true, index: true
      # client_id is nullable — storefront orders arrive from anonymous
      # visitors before a Client record is resolved (handled in
      # Orders::PlaceOrder).
      t.references :client, foreign_key: true

      t.string   :state, null: false, default: "placed"

      # Delivery date + local time window (minutes from midnight). Integer
      # times avoid TZ/DST drift on recurring schedules; the operator's
      # timezone on Account resolves the window to an absolute moment when
      # we need one.
      t.date    :delivery_date, null: false
      t.integer :delivery_start_time
      t.integer :delivery_end_time
      t.integer :delivery_type, null: false, default: 0

      t.string   :delivery_address
      t.string   :colonia
      t.string   :city
      t.text     :delivery_notes

      t.bigint   :subtotal_cents, null: false, default: 0
      t.bigint   :tax_cents,      null: false, default: 0
      t.bigint   :total_cents,    null: false, default: 0
      t.bigint   :deposit_cents,  null: false, default: 0
      t.bigint   :balance_cents,  null: false, default: 0

      t.text     :notes
      t.integer  :source, null: false, default: 0   # enum

      t.integer  :position
      t.datetime :discarded_at, index: true

      t.timestamps

      t.check_constraint "delivery_start_time IS NULL OR (delivery_start_time >= 0 AND delivery_start_time <= 1440)",
        name: "chk_orders_delivery_start_time_range"
      t.check_constraint "delivery_end_time IS NULL OR (delivery_end_time >= 0 AND delivery_end_time <= 1440)",
        name: "chk_orders_delivery_end_time_range"
      t.check_constraint "delivery_start_time IS NULL OR delivery_end_time IS NULL OR delivery_start_time < delivery_end_time",
        name: "chk_orders_delivery_start_before_end"
    end

    add_index :orders, [ :account_id, :state, :position ]
    add_index :orders, [ :account_id, :delivery_date ]
  end
end
