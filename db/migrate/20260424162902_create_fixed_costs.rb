class CreateFixedCosts < ActiveRecord::Migration[8.1]
  def change
    create_table :fixed_costs do |t|
      t.references :account,
        null: false, foreign_key: true, index: true
      t.references :fixed_cost_category,
        null: false, foreign_key: true, index: true

      t.bigint  :amount_cents, null: false, default: 0
      t.string  :currency,     null: false, default: "MXN"
      t.integer :recurrence,   null: false, default: 0  # monthly:0, weekly:1, yearly:2, one_time:99
      t.bigint  :cost_per_pedido_cents

      t.date :start_date, null: false
      t.date :end_date

      t.text :notes

      t.datetime :discarded_at, index: true

      t.timestamps
    end

    add_index :fixed_costs, [ :account_id, :start_date ]
  end
end
