class CreateSuppliers < ActiveRecord::Migration[8.1]
  def change
    create_table :suppliers do |t|
      t.references :account, null: false, foreign_key: true, index: true

      t.string  :name, null: false
      t.string  :phone
      t.string  :phone_normalized
      t.string  :whatsapp
      t.string  :colonia
      t.string  :city
      t.text    :notes

      t.datetime :discarded_at, index: true
      t.timestamps
    end

    add_index :suppliers, [ :account_id, :name ]
    # Per-account phone uniqueness. Mirrors Client's pattern so the same
    # normalized MX number can't land twice by accident.
    add_index :suppliers, [ :account_id, :phone_normalized ],
      unique: true,
      where: "phone_normalized IS NOT NULL AND discarded_at IS NULL",
      name: "uniq_suppliers_account_phone_active"
  end
end
