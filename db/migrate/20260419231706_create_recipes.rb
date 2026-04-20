class CreateRecipes < ActiveRecord::Migration[8.1]
  def change
    create_table :recipes do |t|
      t.references :account, null: false, foreign_key: true, index: true

      t.string :name, null: false
      t.string :slug, null: false
      t.text   :description

      t.bigint  :sale_price_cents, null: false, default: 0
      t.boolean :is_saleable, null: false, default: true

      # Yield — how much one batch produces. "1 pieza" for a single tamal,
      # "1800 g" for an internal masa recipe.
      t.decimal :yield_quantity, precision: 10, scale: 3, null: false, default: 1
      t.string  :yield_unit,     null: false, default: "porcion"

      t.integer :category, null: false, default: 0  # enum
      t.integer :target_margin_percent, null: false, default: 60
      t.boolean :is_published, null: false, default: false

      # Fast-path cache of the fully resolved component tree cost. Live-
      # recalculated via Recipes::CostCalculator; invalidated via
      # Recipes::DependencyGraph when any component price changes.
      t.bigint  :cost_cents_cached

      t.integer  :position
      t.datetime :discarded_at, index: true

      t.timestamps
    end

    add_index :recipes, [ :account_id, :slug ], unique: true
    add_index :recipes, [ :account_id, :is_saleable ]
    add_index :recipes, [ :account_id, :category, :position ]
  end
end
