class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.references :account, null: false, foreign_key: true, index: true

      t.integer :kind, null: false, default: 0   # 0 = ingredient, 1 = recipe
      t.string  :name, null: false
      t.integer :position

      t.datetime :discarded_at, index: true

      t.timestamps
    end

    # One category name per (account, kind). Case-insensitive via LOWER().
    add_index :categories,
      "account_id, kind, LOWER(name)",
      unique: true,
      name: "uniq_categories_account_kind_name",
      where: "discarded_at IS NULL"

    add_index :categories, [ :account_id, :kind, :position ]
  end
end
