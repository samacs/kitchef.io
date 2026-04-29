class CreatePromotionRecipes < ActiveRecord::Migration[8.1]
  def change
    create_table :promotion_recipes do |t|
      t.references :promotion, null: false, foreign_key: { on_delete: :cascade }
      t.references :recipe,    null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    add_index :promotion_recipes, %i[promotion_id recipe_id],
              name: "uniq_promotion_recipes", unique: true
  end
end
