class AddDiscountFieldsToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :discount_cents, :bigint, default: 0, null: false
    add_column :orders, :discount_label, :string
  end
end
