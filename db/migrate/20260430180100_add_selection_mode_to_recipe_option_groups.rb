class AddSelectionModeToRecipeOptionGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :recipe_option_groups, :selection_mode, :integer, default: 0, null: false
    add_column :recipe_option_groups, :unit_count,     :integer
  end
end
