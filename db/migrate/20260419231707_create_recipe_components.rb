class CreateRecipeComponents < ActiveRecord::Migration[8.1]
  def change
    create_table :recipe_components do |t|
      t.references :recipe, null: false, foreign_key: true, index: true
      t.references :componentable, polymorphic: true, null: false, index: true

      t.decimal :quantity, precision: 10, scale: 3, null: false
      t.string  :unit,     null: false
      t.text    :notes
      t.integer :position

      t.timestamps
    end

    add_index :recipe_components, [ :recipe_id, :position ]
  end
end
