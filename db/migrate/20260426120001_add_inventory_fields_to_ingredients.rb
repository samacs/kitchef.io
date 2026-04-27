class AddInventoryFieldsToIngredients < ActiveRecord::Migration[8.1]
  def change
    add_column :ingredients, :stock_quantity, :decimal, precision: 12, scale: 3,
      null: false, default: 0
    add_column :ingredients, :stock_updated_at,    :datetime
    add_column :ingredients, :low_stock_alert_at,  :datetime
    add_column :ingredients, :last_purchase_quantity, :decimal, precision: 12, scale: 3
  end
end
