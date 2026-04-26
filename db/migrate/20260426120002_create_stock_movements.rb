class CreateStockMovements < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_movements do |t|
      t.references :account,    null: false, foreign_key: true, index: true
      t.references :ingredient, null: false, foreign_key: true, index: true

      # Signed: positive = restock, negative = deplete. Stored in the
      # ingredient's canonical unit so reading the row needs no
      # conversion.
      t.decimal :quantity, precision: 14, scale: 3, null: false
      t.string  :unit,     null: false

      # Why this movement happened. The polymorphic source_type/source_id
      # pair points back at the originating record (production_run,
      # purchase, order, or nil for manual adjustments) so the audit log
      # can deep-link to the source.
      t.string  :source,      null: false   # purchase / production_deplete / production_cancel / order_consume / order_restock / manual_adjust / initial
      t.string  :source_type
      t.bigint  :source_id
      t.text    :note

      # Snapshot of the cost basis at movement time. Future variance and
      # COGS reports read this rather than the (possibly-changed)
      # ingredient.unit_cost_cents — same invariant as
      # OrderItem#unit_cost_cents.
      t.bigint  :unit_cost_cents_at_movement

      t.timestamps
    end

    add_index :stock_movements, [ :account_id, :ingredient_id, :created_at ],
      name: "idx_stock_movements_account_ingredient_time"
    add_index :stock_movements, [ :source_type, :source_id ],
      name: "idx_stock_movements_source"
  end
end
