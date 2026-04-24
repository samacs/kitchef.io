class CreatePurchaseItems < ActiveRecord::Migration[8.1]
  def change
    create_table :purchase_items do |t|
      t.references :purchase,   null: false, foreign_key: { on_delete: :cascade }, index: true
      t.references :ingredient, null: false, foreign_key: { on_delete: :cascade }, index: true

      t.decimal :quantity, precision: 10, scale: 3, null: false
      t.string  :unit, null: false
      t.bigint  :unit_cost_cents, null: false, default: 0
      t.string  :currency, null: false, default: "MXN"
      t.integer :position
      t.text    :notes

      t.timestamps
    end

    add_index :purchase_items, [ :purchase_id, :position ]
  end
end
