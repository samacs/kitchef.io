class AddCategoryRefToIngredientsAndRecipes < ActiveRecord::Migration[8.1]
  def change
    add_reference :ingredients, :category, foreign_key: true, index: true, null: true
    add_reference :recipes,     :category, foreign_key: true, index: true, null: true
  end
end
