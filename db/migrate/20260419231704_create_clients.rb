class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.references :account, null: false, foreign_key: true, index: true

      t.string :first_name, null: false
      t.string :last_name
      t.string :phone
      t.string :phone_normalized
      t.string :email

      t.string :colonia
      t.string :city
      t.string :street_address
      t.text   :references_note   # "toca dos veces, puerta café"

      t.text   :notes
      t.text   :allergies
      t.date   :birthday

      t.datetime :discarded_at, index: true

      t.timestamps
    end

    add_index :clients, [ :account_id, :phone_normalized ]
    add_index :clients, [ :account_id, :email ]
  end
end
