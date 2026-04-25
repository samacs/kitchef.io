class CreateFixedCostCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :fixed_cost_categories do |t|
      t.references :account, null: false, foreign_key: true, index: true

      t.integer :kind, null: false, default: 99  # rent:0, utilities:1, packaging:2, platform:3, other:99
      t.string  :name, null: false
      t.integer :position

      t.datetime :discarded_at, index: true

      t.timestamps
    end

    # One category name per account. Case-insensitive via LOWER().
    add_index :fixed_cost_categories,
      "account_id, LOWER(name)",
      unique: true,
      name: "uniq_fixed_cost_categories_account_name",
      where: "discarded_at IS NULL"

    add_index :fixed_cost_categories, [ :account_id, :kind, :position ]
  end
end
