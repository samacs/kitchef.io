class CreatePromotions < ActiveRecord::Migration[8.1]
  def change
    create_table :promotions do |t|
      t.references :account, null: false, foreign_key: true

      t.string  :name,               null: false
      t.string  :code
      t.integer :kind,               null: false, default: 0
      t.integer :discount_type,      null: false, default: 0
      t.integer :scope_type,         null: false, default: 0
      t.integer :discount_value,     null: false
      t.integer :bogo_buy_quantity,  default: 1
      t.integer :bogo_get_quantity,  default: 1
      t.bigint  :min_order_cents,    null: false, default: 0
      t.bigint  :max_discount_cents
      t.datetime :starts_at
      t.datetime :ends_at
      t.integer :total_usage_limit
      t.integer :per_client_limit
      t.integer :total_usage_count,  null: false, default: 0
      t.integer :priority,           null: false, default: 0
      t.boolean :active,             null: false, default: true

      t.datetime :discarded_at
      t.timestamps
    end

    add_index :promotions, %i[account_id active kind], name: "idx_promotions_account_active_kind"
    add_index :promotions, %i[account_id code],
              name: "uniq_promotions_account_code",
              unique: true,
              where: "code IS NOT NULL AND discarded_at IS NULL"
    add_index :promotions, :discarded_at
  end
end
