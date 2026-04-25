class CreateRecipeOptions < ActiveRecord::Migration[8.1]
  def change
    create_table :recipe_options do |t|
      t.references :recipe_option_group, null: false, foreign_key: true
      t.string     :label,              null: false
      t.string     :sub
      t.bigint     :price_delta_cents,  null: false, default: 0
      t.boolean    :is_default,         null: false, default: false
      t.string     :color_hex
      t.integer    :position
      t.datetime   :discarded_at

      t.timestamps
    end

    add_index :recipe_options, :discarded_at
    add_index :recipe_options, %i[recipe_option_group_id position]
  end
end
