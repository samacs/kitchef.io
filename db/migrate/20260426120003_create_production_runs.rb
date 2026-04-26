class CreateProductionRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :production_runs do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :recipe,  null: false, foreign_key: true, index: true

      t.date :cooked_on,        null: false
      t.date :available_from,   null: false
      t.date :available_until,  null: false

      t.decimal :planned_quantity, precision: 12, scale: 3, null: false, default: 0
      t.decimal :actual_quantity,  precision: 12, scale: 3, null: false, default: 0

      t.string  :state, null: false, default: "planned"

      # AASM lifecycle stamps.
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :canceled_at

      t.text :notes

      t.datetime :discarded_at, index: true
      t.timestamps
    end

    add_index :production_runs, [ :account_id, :cooked_on ]
    add_index :production_runs, [ :account_id, :recipe_id, :cooked_on ]
    add_index :production_runs, [ :account_id, :available_from, :available_until ],
      name: "idx_production_runs_account_window"
  end
end
