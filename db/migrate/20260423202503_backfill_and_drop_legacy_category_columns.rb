class BackfillAndDropLegacyCategoryColumns < ActiveRecord::Migration[8.1]
  # Ingredient enum values at migration time (Phase 8 schema).
  INGREDIENT_ENUM = {
    0  => "Abarrotes",
    1  => "Carnes",
    2  => "Lácteos",
    3  => "Frutas y verduras",
    4  => "Especias",
    99 => "Otros"
  }.freeze

  # Recipe enum values at migration time.
  RECIPE_ENUM = {
    0  => "Platos fuertes",
    1  => "Entradas",
    2  => "Postres",
    3  => "Bebidas",
    4  => "Bases y preparaciones",
    99 => "Otros"
  }.freeze

  def up
    # Backfill ingredient.category_id from the legacy integer enum.
    INGREDIENT_ENUM.each do |legacy, name|
      execute ActiveRecord::Base.send(:sanitize_sql_array, [
        <<~SQL.squish, name, legacy
          UPDATE ingredients
          SET category_id = categories.id
          FROM categories
          WHERE ingredients.account_id = categories.account_id
            AND categories.kind = 0
            AND categories.name = ?
            AND ingredients.category = ?
            AND ingredients.category_id IS NULL
        SQL
      ])
    end

    RECIPE_ENUM.each do |legacy, name|
      execute ActiveRecord::Base.send(:sanitize_sql_array, [
        <<~SQL.squish, name, legacy
          UPDATE recipes
          SET category_id = categories.id
          FROM categories
          WHERE recipes.account_id = categories.account_id
            AND categories.kind = 1
            AND categories.name = ?
            AND recipes.category = ?
            AND recipes.category_id IS NULL
        SQL
      ])
    end

    # Sanity check: every kept ingredient/recipe must now have a category.
    orphan_ings = select_value("SELECT COUNT(*) FROM ingredients WHERE category_id IS NULL AND discarded_at IS NULL").to_i
    orphan_recs = select_value("SELECT COUNT(*) FROM recipes WHERE category_id IS NULL AND discarded_at IS NULL").to_i
    if orphan_ings.positive? || orphan_recs.positive?
      raise ActiveRecord::MigrationError,
        "Category backfill left #{orphan_ings} ingredient(s) and #{orphan_recs} recipe(s) without a category. " \
        "Seed the Category rows for those accounts first."
    end

    # Remove the old integer-enum columns. Safe because no live code reads
    # them after this migration (model updates land in the same deploy).
    remove_index  :ingredients, [ :account_id, :category, :position ] if index_exists?(:ingredients, [ :account_id, :category, :position ])
    remove_index  :recipes,     [ :account_id, :category, :position ] if index_exists?(:recipes,     [ :account_id, :category, :position ])
    remove_column :ingredients, :category
    remove_column :recipes,     :category

    # Enforce NOT NULL now that every row has a category_id.
    change_column_null :ingredients, :category_id, false
    change_column_null :recipes,     :category_id, false

    add_index :ingredients, [ :account_id, :category_id, :position ]
    add_index :recipes,     [ :account_id, :category_id, :position ]
  end

  def down
    add_column :ingredients, :category, :integer, null: false, default: 0
    add_column :recipes,     :category, :integer, null: false, default: 0
    remove_index :ingredients, [ :account_id, :category_id, :position ] if index_exists?(:ingredients, [ :account_id, :category_id, :position ])
    remove_index :recipes,     [ :account_id, :category_id, :position ] if index_exists?(:recipes,     [ :account_id, :category_id, :position ])
    change_column_null :ingredients, :category_id, true
    change_column_null :recipes,     :category_id, true
  end
end
