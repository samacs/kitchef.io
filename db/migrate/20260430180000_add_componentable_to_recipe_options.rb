class AddComponentableToRecipeOptions < ActiveRecord::Migration[8.1]
  def change
    add_column :recipe_options, :componentable_type, :string
    add_column :recipe_options, :componentable_id,   :bigint
    add_column :recipe_options, :quantity,            :decimal, precision: 10, scale: 3
    add_column :recipe_options, :unit,                :string
    add_column :recipe_options, :cost_delta_cents,    :bigint, default: 0, null: false

    add_index :recipe_options, [ :componentable_type, :componentable_id ],
      name: "idx_recipe_options_componentable"
  end
end
