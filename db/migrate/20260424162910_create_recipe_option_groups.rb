class CreateRecipeOptionGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :recipe_option_groups do |t|
      t.references :account,  null: false, foreign_key: true
      t.references :recipe,   null: false, foreign_key: true
      t.integer    :kind,     null: false, default: 0
      t.string     :label,    null: false
      t.string     :sub
      t.boolean    :required, null: false, default: false
      t.integer    :position
      t.integer    :max_length
      t.datetime   :discarded_at

      t.timestamps
    end

    add_index :recipe_option_groups, :discarded_at
    add_index :recipe_option_groups, %i[recipe_id position]
  end
end
