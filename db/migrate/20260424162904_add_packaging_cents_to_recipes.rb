class AddPackagingCentsToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :packaging_cents, :bigint, null: false, default: 0
  end
end
