class AddConsumptionToOrderItems < ActiveRecord::Migration[8.1]
  def change
    add_reference :order_items, :consumed_run,
      foreign_key: { to_table: :production_runs, on_delete: :nullify },
      index: true,
      null: true
    add_column :order_items, :consumed_quantity, :decimal, precision: 12, scale: 3,
      null: false, default: 0
    add_column :order_items, :oversold, :boolean, null: false, default: false
  end
end
