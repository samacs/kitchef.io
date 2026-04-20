class CreateIngredients < ActiveRecord::Migration[8.1]
  def change
    create_table :ingredients do |t|
      t.references :account, null: false, foreign_key: true, index: true

      t.string  :name, null: false
      t.string  :unit, null: false   # g, kg, ml, l, pieza
      t.bigint  :unit_cost_cents, null: false, default: 0
      t.string  :currency, null: false, default: "MXN"
      t.datetime :price_updated_at

      t.integer :category, null: false, default: 0  # enum
      t.string  :supplier_name
      t.text    :notes

      t.integer :position
      t.datetime :discarded_at, index: true

      t.timestamps
    end

    add_index :ingredients, [ :account_id, :category, :position ]
    add_index :ingredients, [ :account_id, :name ]
  end
end
