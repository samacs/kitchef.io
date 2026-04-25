class AddIsRemovableToRecipeComponents < ActiveRecord::Migration[8.1]
  def change
    add_column :recipe_components, :is_removable, :boolean, null: false, default: false
  end
end
