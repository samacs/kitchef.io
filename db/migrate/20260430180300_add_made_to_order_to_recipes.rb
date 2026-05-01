class AddMadeToOrderToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :made_to_order, :boolean, default: false, null: false
  end
end
