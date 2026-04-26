class CreateRunConsumptions < ActiveRecord::Migration[8.1]
  def change
    create_table :run_consumptions do |t|
      t.references :production_run, null: false, foreign_key: true, index: true

      # Polymorphic — an Ingredient (raw) or a Recipe (sub-recipe consumed
      # via composition). For Phase 13 only Ingredient is wired; Recipe
      # support is reserved for a future "recipe yield depletion" pass.
      t.string :consumable_type, null: false
      t.bigint :consumable_id,   null: false

      t.decimal :quantity_consumed, precision: 14, scale: 3, null: false
      t.string  :unit, null: false

      # Snapshot at consumption time — never recomputed retroactively.
      t.bigint :cost_cents_at_consumption, null: false, default: 0

      t.timestamps
    end

    add_index :run_consumptions, [ :consumable_type, :consumable_id ],
      name: "idx_run_consumptions_consumable"
  end
end
