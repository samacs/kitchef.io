class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :order, null: false, foreign_key: true, index: true

      t.bigint   :amount_cents, null: false, default: 0
      t.integer  :method,       null: false, default: 0  # enum
      t.datetime :received_at,  null: false

      t.string   :reference
      t.text     :notes

      t.timestamps
    end

    add_index :payments, [ :order_id, :received_at ]
  end
end
