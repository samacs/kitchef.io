class AddPackagingCentsToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :packaging_cents, :bigint, null: false, default: 0
  end
end
