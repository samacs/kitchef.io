class CreateOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :order_items do |t|
      t.references :order,  null: false, foreign_key: true, index: true
      t.references :recipe, null: false, foreign_key: true, index: true

      t.decimal :quantity, precision: 10, scale: 3, null: false, default: 1
      # Snapshots taken at order time — never recomputed retroactively so
      # that a later price change doesn't rewrite historical orders.
      t.bigint  :unit_price_cents, null: false, default: 0
      t.bigint  :unit_cost_cents,  null: false, default: 0

      t.text    :notes
      t.integer :position

      t.timestamps
    end

    add_index :order_items, [ :order_id, :position ]
  end
end
