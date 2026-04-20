class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.references :owner, foreign_key: { to_table: :users }, null: false, index: true
      t.string  :name, null: false
      t.string  :slug, null: false
      t.string  :default_currency, null: false, default: "MXN"
      t.string  :time_zone, null: false, default: "America/Mexico_City"

      t.boolean :iva_enabled,     null: false, default: false
      t.decimal :iva_rate_percent, precision: 5, scale: 2, null: false, default: 16.0

      t.jsonb :public_profile, null: false, default: {}
      t.jsonb :branding,       null: false, default: {}
      t.jsonb :settings,       null: false, default: {}

      t.datetime :discarded_at, index: true

      t.timestamps
    end

    add_index :accounts, :slug, unique: true
    add_index :accounts, :settings, using: :gin
  end
end
