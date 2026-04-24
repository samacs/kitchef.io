class SeedDefaultCategories < ActiveRecord::Migration[8.1]
  INGREDIENT_CATEGORIES = [
    "Abarrotes",           # pantry
    "Carnes",              # meats
    "Lácteos",             # dairy
    "Frutas y verduras",   # produce
    "Especias",            # spices
    "Otros"                # other
  ].freeze

  RECIPE_CATEGORIES = [
    "Platos fuertes",         # mains
    "Entradas",               # starters
    "Postres",                # desserts
    "Bebidas",                # drinks
    "Bases y preparaciones", # bases
    "Otros"                   # other
  ].freeze

  def up
    account_ids = select_values("SELECT id FROM accounts WHERE discarded_at IS NULL").map(&:to_i)
    account_ids.each { |aid| seed_for_account(aid) }
  end

  def down
    execute "DELETE FROM categories"
  end

  private

  def seed_for_account(account_id)
    now = Time.current

    INGREDIENT_CATEGORIES.each_with_index do |name, idx|
      execute ActiveRecord::Base.send(:sanitize_sql_array, [
        <<~SQL.squish, account_id, 0, name, idx, now, now
          INSERT INTO categories (account_id, kind, name, position, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?)
          ON CONFLICT DO NOTHING
        SQL
      ])
    end

    RECIPE_CATEGORIES.each_with_index do |name, idx|
      execute ActiveRecord::Base.send(:sanitize_sql_array, [
        <<~SQL.squish, account_id, 1, name, idx, now, now
          INSERT INTO categories (account_id, kind, name, position, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?)
          ON CONFLICT DO NOTHING
        SQL
      ])
    end
  end
end
