class AddPaymentFieldsToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :payment_method,           :integer
    add_column :orders, :tip_cents,                :bigint, default: 0, null: false
    add_column :orders, :cash_payment_amount_cents, :bigint
    add_column :orders, :terms_accepted_at,        :datetime
  end
end
