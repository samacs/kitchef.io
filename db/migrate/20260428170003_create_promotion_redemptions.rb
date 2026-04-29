class CreatePromotionRedemptions < ActiveRecord::Migration[8.1]
  def change
    create_table :promotion_redemptions do |t|
      t.references :promotion, null: false, foreign_key: true
      t.references :order,     null: false, foreign_key: true
      t.references :client,    foreign_key: { on_delete: :nullify }

      t.bigint  :discount_cents, null: false, default: 0
      t.string  :discount_label, null: false
      t.integer :kind,           null: false, default: 0

      t.timestamps
    end

    add_index :promotion_redemptions, %i[order_id kind],
              name: "uniq_redemption_per_kind", unique: true
    add_index :promotion_redemptions, %i[promotion_id client_id],
              name: "idx_promotion_client_redemptions"
  end
end
