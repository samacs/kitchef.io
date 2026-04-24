class BackfillSuppliersFromIngredients < ActiveRecord::Migration[8.1]
  # Seeds one Supplier per distinct `ingredients.supplier_name` (per-account)
  # and links ingredients with a non-zero cost to a default SupplierIngredient
  # row. Ingredients with no supplier_name and no cost stay unlinked — the
  # UI will prompt "Agrega un proveedor" when the operator edits them.
  def up
    # One Supplier per (account_id, trimmed supplier_name).
    execute <<~SQL.squish
      INSERT INTO suppliers (account_id, name, created_at, updated_at)
      SELECT DISTINCT account_id, TRIM(supplier_name), NOW(), NOW()
      FROM ingredients
      WHERE supplier_name IS NOT NULL
        AND TRIM(supplier_name) <> ''
      ON CONFLICT DO NOTHING
    SQL

    # Link each ingredient to its supplier (where it had a name) with the
    # current unit_cost_cents as the default row.
    execute <<~SQL.squish
      INSERT INTO supplier_ingredients
        (supplier_id, ingredient_id, unit_cost_cents, currency, last_bought_on,
         is_default_cost_source, created_at, updated_at)
      SELECT suppliers.id,
             ingredients.id,
             ingredients.unit_cost_cents,
             ingredients.currency,
             CURRENT_DATE,
             TRUE,
             NOW(),
             NOW()
      FROM ingredients
      JOIN suppliers ON suppliers.account_id = ingredients.account_id
                    AND suppliers.name = TRIM(ingredients.supplier_name)
      WHERE ingredients.supplier_name IS NOT NULL
        AND TRIM(ingredients.supplier_name) <> ''
        AND ingredients.unit_cost_cents > 0
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    execute "DELETE FROM supplier_ingredients"
    execute "DELETE FROM suppliers"
  end
end
