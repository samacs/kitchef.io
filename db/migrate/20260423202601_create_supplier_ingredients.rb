class CreateSupplierIngredients < ActiveRecord::Migration[8.1]
  def change
    create_table :supplier_ingredients do |t|
      t.references :supplier,   null: false, foreign_key: { on_delete: :cascade }, index: true
      t.references :ingredient, null: false, foreign_key: { on_delete: :cascade }, index: true

      t.bigint  :unit_cost_cents, null: false, default: 0
      t.string  :currency, null: false, default: "MXN"
      t.date    :last_bought_on
      t.boolean :is_default_cost_source, null: false, default: false
      t.text    :notes

      t.timestamps
    end

    add_index :supplier_ingredients, [ :supplier_id, :ingredient_id ],
      unique: true, name: "uniq_supplier_ingredient"

    # Only one default per ingredient — enforced at the DB level so a race
    # between two submits can never leave an ingredient with two defaults.
    add_index :supplier_ingredients, :ingredient_id,
      unique: true,
      where: "is_default_cost_source = true",
      name: "uniq_default_supplier_per_ingredient"
  end
end
