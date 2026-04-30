class AddOptionsCostDeltaToOrderItems < ActiveRecord::Migration[8.1]
  def change
    add_column :order_items, :options_cost_delta_cents, :bigint, default: 0, null: false
  end
end
