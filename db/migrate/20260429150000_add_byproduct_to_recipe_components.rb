class AddByproductToRecipeComponents < ActiveRecord::Migration[8.1]
  def change
    add_column :recipe_components, :is_byproduct, :boolean, default: false, null: false
  end
end
