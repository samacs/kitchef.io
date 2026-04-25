class SeedDefaultFixedCostCategories < ActiveRecord::Migration[8.1]
  # Five starter buckets that cover ~everything a home kitchen tracks.
  # Kinds map: rent:0, utilities:1, packaging:2, platform:3, other:99.
  DEFAULT_CATEGORIES = [
    [ "Renta",             0 ],
    [ "Gas y servicios",   1 ],
    [ "Empaque",           2 ],
    [ "Plataformas",       3 ],
    [ "Otros",            99 ]
  ].freeze

  def up
    account_ids = select_values("SELECT id FROM accounts WHERE discarded_at IS NULL").map(&:to_i)
    account_ids.each { |aid| seed_for_account(aid) }
  end

  def down
    execute "DELETE FROM fixed_cost_categories"
  end

  private

  def seed_for_account(account_id)
    now = Time.current

    DEFAULT_CATEGORIES.each_with_index do |(name, kind), idx|
      execute ActiveRecord::Base.send(:sanitize_sql_array, [
        <<~SQL.squish, account_id, kind, name, idx, now, now
          INSERT INTO fixed_cost_categories (account_id, kind, name, position, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?)
          ON CONFLICT DO NOTHING
        SQL
      ])
    end
  end
end
