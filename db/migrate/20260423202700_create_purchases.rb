class CreatePurchases < ActiveRecord::Migration[8.1]
  def change
    create_table :purchases do |t|
      t.references :account, null: false, foreign_key: true, index: true
      # Nullable — "sin proveedor" purchases still count in the gastos
      # report but never touch per-supplier price history.
      t.references :supplier, null: true, foreign_key: { on_delete: :nullify }, index: true

      t.date :purchased_on, null: false
      t.bigint :total_cents, null: false, default: 0
      t.bigint :total_cents_override   # null = derive from sum of items
      t.string :currency, null: false, default: "MXN"
      t.text   :notes

      t.datetime :discarded_at, index: true
      t.timestamps
    end

    add_index :purchases, [ :account_id, :purchased_on ]
  end
end
