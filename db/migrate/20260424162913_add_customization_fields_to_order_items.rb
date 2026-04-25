class AddCustomizationFieldsToOrderItems < ActiveRecord::Migration[8.1]
  def change
    add_column :order_items, :selected_options,        :jsonb,  default: {}
    add_column :order_items, :removed_components,      :jsonb,  default: []
    add_column :order_items, :options_price_delta_cents, :bigint, default: 0, null: false
  end
end
