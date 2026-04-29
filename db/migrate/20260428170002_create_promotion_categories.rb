class CreatePromotionCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :promotion_categories do |t|
      t.references :promotion, null: false, foreign_key: { on_delete: :cascade }
      t.references :category,  null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    add_index :promotion_categories, %i[promotion_id category_id],
              name: "uniq_promotion_categories", unique: true
  end
end
